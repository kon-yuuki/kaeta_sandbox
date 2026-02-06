import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../model/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamiliesRepository {
  final MyDatabase db;
  final supabase = Supabase.instance.client;

  FamiliesRepository(this.db);

  Future<bool> createFirstFamily(String familyName) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    // 同じ名前の家族が既に存在するかチェック
    final existingFamily = await (db.select(db.families)
      ..where((t) => t.name.equals(familyName))
      ..where((t) => t.ownerId.equals(userId)))
      .getSingleOrNull();

    if (existingFamily != null) {
      debugPrint('同じ名前の家族「$familyName」は既に存在します');
      return false;
    }

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

    return true;
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

// 招待URLを生成する
Future<String?> createInviteUrl(String familyId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final inviteId = const Uuid().v4();
  final expiresAt = DateTime.now().add(const Duration(days: 7));

  await db.into(db.invitations).insert(
    InvitationsCompanion.insert(
      id: inviteId,
      familyId: familyId,
      inviterId: userId,
      expiresAt: expiresAt,
    ),
  );

  return 'https://kaeta-jointeam.com/invite/$inviteId';
}

// 招待状の情報を取得する（参加確認画面用）
Future<Map<String, dynamic>?> fetchInvitationDetails(String inviteId) async {
  try {
    // Supabaseから直接データを取得（招待テーブル ＋ 招待主の名前 ＋ 家族名）
    final response = await supabase
        .from('invitations')
        .select('''
          family_id,
          expires_at,
          families(name),
          profiles:inviter_id(display_name)
        ''')
        .eq('id', inviteId)
        .single();

    // 期限切れチェック
    final expiresAt = DateTime.parse(response['expires_at']);
    if (expiresAt.isBefore(DateTime.now())) {
      throw Exception('この招待リンクは有効期限が切れています。');
    }

    return response;
  } catch (e) {
    debugPrint('招待情報の取得に失敗: $e');
    return null;
  }
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
