import 'package:drift/drift.dart';
import '../model/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamiliesRepository {
  final MyDatabase db;
  final supabase = Supabase.instance.client;

  FamiliesRepository(this.db);

  Future<void> createFirstFamily(String familyName) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // すべての処理が成功するか、失敗するかの「トランザクション」を開始
    await db.transaction(() async {
      // 1. Familiesテーブルに新しい家族を挿入し、その結果（生成されたID）を受け取る
      final newFamily = await db.into(db.families).insertReturning(
        FamiliesCompanion.insert(
          name: familyName,
          ownerId: userId,
        ),
      );

      // 2. FamilyMembersテーブルに、自分をこの家族のメンバーとして登録する
      await db.into(db.familyMembers).insert(
        FamilyMembersCompanion.insert(
          userId: userId,
          familyId: newFamily.id,
        ),
      );

      // 3. Profilesテーブル（自分の設定）の currentFamilyId を更新する
      await (db.update(db.profiles)..where((t) => t.id.equals(userId))).write(
        ProfilesCompanion(
          currentFamilyId: Value(newFamily.id),
        ),
      );
    });
  }

  // 自分が所属している家族のリストをストリームで監視する
Stream<List<Family>> watchJoinedFamilies() {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  // familyMembers と families を結合（Join）して、
  // 自分の userId が含まれる家族だけを取得します
  final query = db.select(db.families).join([
    innerJoin(
      db.familyMembers,
      db.familyMembers.familyId.equalsExp(db.families.id),
    ),
  ])..where(db.familyMembers.userId.equals(userId));

  // Joinした結果から、家族情報のリストを取り出して返します
  return query.watch().map((rows) {
    return rows.map((row) => row.readTable(db.families)).toList();
  });
}

Future<void> updateCurrentFamily(String? familyId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;
  
  await (db.update(db.profiles)..where((t) => t.id.equals(userId))).write(
    ProfilesCompanion(currentFamilyId: Value(familyId)),
  );
}
// families_repository.dart に追加
Future<void> deleteFamily(String familyId) async {
  await db.transaction(() async {

    await (db.delete(db.todoItems)..where((t) => t.familyId.equals(familyId))).go();
    
    // 2. 履歴も同様に削除
    await (db.delete(db.purchaseHistory)..where((t) => t.familyId.equals(familyId))).go();

    // 3. メンバー情報を削除
    await (db.delete(db.familyMembers)..where((t) => t.familyId.equals(familyId))).go();

    // 4. 最後に家族本体を削除
    await (db.delete(db.families)..where((t) => t.id.equals(familyId))).go();
    
    // 5. 自分の選択状態を解除
    await updateCurrentFamily(null);
  });
}

// 指定された家族に参加する
Future<void> joinFamily(String familyId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  await db.transaction(() async {
    // 1. FamilyMembers に自分を登録 (insertOrReplaceで二重登録を防ぐ)
    await db.into(db.familyMembers).insert(
      FamilyMembersCompanion.insert(
        userId: userId,
        familyId: familyId,
      ),
      mode: InsertMode.insertOrReplace,
    );

    // 2. プロフィールの currentFamilyId を更新
    await (db.update(db.profiles)..where((t) => t.id.equals(userId))).write(
      ProfilesCompanion(currentFamilyId: Value(familyId)),
    );
  });
}

}
