import 'package:drift/drift.dart';
import '../model/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final MyDatabase db;
  final supabase = Supabase.instance.client;

  ProfileRepository(this.db);

  // profile_repository.dart
  Future<void> ensureProfile({String? displayName}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Supabaseのuser_metadataから名前を取得（Apple/Google共通）
    final userMeta = supabase.auth.currentUser?.userMetadata;
    final defaultName = displayName
        ?? userMeta?['full_name'] as String?
        ?? userMeta?['name'] as String?
        ?? 'ゲスト';

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
                displayName: Value(defaultName),
                currentFamilyId: const Value.absent(),
                updatedAt: DateTime.now(),
                onboardingCompleted: const Value(false),
                avatarPreset: const Value.absent(),
                avatarUrl: const Value.absent(),
              ),
            );
      } catch (e) {
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

  // 現在選択中の家族IDを更新する
  Future<void> updateCurrentFamily(String? familyId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await (db.update(db.profiles)..where((t) => t.id.equals(userId)))
    .write(ProfilesCompanion(currentFamilyId: Value(familyId)));
  }

  // オンボーディング完了をマーク
  Future<void> completeOnboarding() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await (db.update(db.profiles)..where((t) => t.id.equals(userId)))
        .write(const ProfilesCompanion(onboardingCompleted: Value(true)));
  }

  // アバター情報を更新
  Future<void> updateAvatar({String? preset, String? url}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await (db.update(db.profiles)..where((t) => t.id.equals(userId)))
        .write(ProfilesCompanion(
          avatarPreset: Value(preset),
          avatarUrl: Value(url),
        ));
  }

  // プロフィールと表示名を同時に更新
  Future<void> updateProfileWithName(String displayName) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await (db.update(db.profiles)..where((t) => t.id.equals(userId)))
        .write(ProfilesCompanion(displayName: Value(displayName)));
  }

  // OAuthから名前を取得するヘルパー
  String? getOAuthDisplayName() {
    final userMeta = supabase.auth.currentUser?.userMetadata;
    return userMeta?['full_name'] as String? ?? userMeta?['name'] as String?;
  }
}
