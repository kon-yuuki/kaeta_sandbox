import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../database/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final MyDatabase db;
  final supabase = Supabase.instance.client;

  ProfileRepository(this.db);

  // profile_repository.dart
  Future<void> ensureProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // 1. ローカルをチェック
    final localProfile = await (db.select(
      db.profiles,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();
    if (localProfile != null) return; // すでにあれば何もしない

    // 2. サーバーをチェック
    final remoteData = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    // 3. サーバーにも「絶対にない」場合だけ、新規作成する
    if (remoteData == null) {
      print('サーバーにもないので、完全新規作成します');
      try {
        await db
            .into(db.profiles)
            .insert(
              ProfilesCompanion.insert(
                id: userId,
                familyId: const Value.absent(),
                updatedAt:DateTime.now(),
              ),
            );
      } catch (e) {
        // 万が一、この数ミリ秒の間にPowerSyncがデータを入れてしまったら
        // 衝突エラーが出るが、それは「データがもうある」ということなので無視して良い
        print('衝突しましたが、データが同期された証拠なので問題ありません: $e');
      }
    }
  }

  Future<void> updateProfile(String newName) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await (db.update(db.profiles)..where((t) => t.id.equals(userId)))
    .write(ProfilesCompanion(displayName: Value(newName)));
  }
}
