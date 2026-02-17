import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../model/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum InvitationFetchError {
  notFound,
  expired,
  unknown,
}

class InvitationFetchResult {
  final Map<String, dynamic>? details;
  final InvitationFetchError? error;

  const InvitationFetchResult._({this.details, this.error});

  const InvitationFetchResult.success(Map<String, dynamic> details)
      : this._(details: details);

  const InvitationFetchResult.failure(InvitationFetchError error)
      : this._(error: error);

  bool get isSuccess => details != null;
}

enum JoinFamilyResult {
  joined,
  alreadyMember,
  alreadyHasFamily,
  invalidInvite,
  notSignedIn,
  failed,
}

class InviteLinkInfo {
  final String inviteId;
  final String url;
  final DateTime expiresAt;

  const InviteLinkInfo({
    required this.inviteId,
    required this.url,
    required this.expiresAt,
  });
}

String buildInviteShareText({
  required String groupName,
  required String inviteUrl,
  required DateTime? expiresAt,
  String? inviteId,
  String groupLabel = '家族グループ',
  bool includeFallback = true,
}) {
  final fallbackUrl = (includeFallback && inviteId != null && inviteId.isNotEmpty)
      ? 'kaeta://invite/$inviteId'
      : null;
  final expiresText = expiresAt != null ? _formatInviteExpiryText(expiresAt) : null;

  return '買い物メモアプリで一緒にリストを共有しましょう！\n'
      'こちらのリンクから$groupLabel「$groupName」に参加できます。\n\n'
      '$inviteUrl\n\n'
      '${fallbackUrl != null ? '開けない場合: $fallbackUrl\n\n' : ''}'
      '${expiresText != null ? '有効期限: $expiresText' : ''}';
}

String _formatInviteExpiryText(DateTime dt) {
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.year}/${local.month}/${local.day} $hh:$mm';
}

class FamilyMemberWithProfile {
  final String userId;
  final String displayName;
  final String? avatarPreset;
  final String? avatarUrl;

  const FamilyMemberWithProfile({
    required this.userId,
    required this.displayName,
    this.avatarPreset,
    this.avatarUrl,
  });
}

class FamiliesRepository {
  final MyDatabase db;
  final supabase = Supabase.instance.client;

  FamiliesRepository(this.db);

  Future<bool> createFirstFamily(String familyName) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    // 既に家族に所属しているかチェック（1家族のみ作成/参加可能）
    final anyMembership = await (db.select(db.familyMembers)
      ..where((t) => t.userId.equals(userId)))
      .getSingleOrNull();
    if (anyMembership != null) {
      debugPrint('既に家族に所属しています');
      return false;
    }

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

Stream<List<FamilyMemberWithProfile>> watchFamilyMembers(String familyId) {
  final query = db.select(db.familyMembers).join([
    innerJoin(
      db.profiles,
      db.profiles.id.equalsExp(db.familyMembers.userId),
    ),
  ])..where(db.familyMembers.familyId.equals(familyId));

  return query.watch().map((rows) {
    return rows.map((row) {
      final member = row.readTable(db.familyMembers);
      final profile = row.readTable(db.profiles);
      final displayName = (profile.displayName?.trim().isNotEmpty ?? false)
          ? profile.displayName!.trim()
          : 'ゲスト';
      return FamilyMemberWithProfile(
        userId: member.userId,
        displayName: displayName,
        avatarPreset: profile.avatarPreset,
        avatarUrl: profile.avatarUrl,
      );
    }).toList();
  });
}

Future<void> updateFamilyName({
  required String familyId,
  required String newName,
}) async {
  await (db.update(db.families)..where((t) => t.id.equals(familyId))).write(
    FamiliesCompanion(name: Value(newName)),
  );
}

Future<void> updateCurrentFamily(String? familyId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;
  
  await (db.update(db.profiles)..where((t) => t.id.equals(userId))).write(
    ProfilesCompanion(currentFamilyId: Value(familyId)),
  );
}

Future<void> removeMemberFromFamily({
  required String familyId,
  required String memberUserId,
}) async {
  await db.transaction(() async {
    await (db.delete(db.familyMembers)
          ..where((t) => t.familyId.equals(familyId) & t.userId.equals(memberUserId)))
        .go();

    await (db.update(db.profiles)..where((t) => t.id.equals(memberUserId))).write(
      const ProfilesCompanion(currentFamilyId: Value(null)),
    );
  });
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
  final info = await getInviteLinkInfo(familyId, forceNew: true);
  return info?.url;
}

Future<InviteLinkInfo?> getInviteLinkInfo(
  String familyId, {
  bool forceNew = true,
}) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  if (!forceNew) {
    final activeInvite = await supabase
        .from('invitations')
        .select('id, expires_at')
        .eq('family_id', familyId)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('expires_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (activeInvite != null) {
      final inviteId = activeInvite['id'] as String;
      final expiresAt = DateTime.parse(activeInvite['expires_at'] as String);
      return InviteLinkInfo(
        inviteId: inviteId,
        url: 'https://kaeta-jointeam.com/invite/$inviteId',
        expiresAt: expiresAt,
      );
    }
  }

  // 公開運用では招待発行をRPCへ寄せ、ローカル同期遅延の影響を避ける。
  final createdInvite = await supabase.rpc(
    'create_invite',
    params: {
      'p_family_id': familyId,
    },
  );
  if (createdInvite is! Map<String, dynamic>) {
    return null;
  }
  final inviteId = createdInvite['id'] as String?;
  final expiresAtRaw = createdInvite['expires_at'] as String?;
  if (inviteId == null || expiresAtRaw == null) return null;
  final expiresAt = DateTime.parse(expiresAtRaw);
  return InviteLinkInfo(
    inviteId: inviteId,
    url: 'https://kaeta-jointeam.com/invite/$inviteId',
    expiresAt: expiresAt,
  );
}

// 招待状の情報を取得する（参加確認画面用）
Future<InvitationFetchResult> fetchInvitationDetails(String inviteId) async {
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
        .maybeSingle();

    if (response == null) {
      return const InvitationFetchResult.failure(InvitationFetchError.notFound);
    }

    // 期限切れチェック
    final expiresAt = DateTime.parse(response['expires_at']);
    if (expiresAt.isBefore(DateTime.now())) {
      return const InvitationFetchResult.failure(InvitationFetchError.expired);
    }

    return InvitationFetchResult.success(response);
  } catch (e) {
    debugPrint('招待情報の取得に失敗: $e');
    return const InvitationFetchResult.failure(InvitationFetchError.unknown);
  }
}

// 指定された家族に参加する
Future<JoinFamilyResult> joinFamily(String familyId, {String? inviteId}) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return JoinFamilyResult.notSignedIn;

  try {
    // 既に同じ家族のメンバーかチェック
    final existingMembership = await (db.select(db.familyMembers)
          ..where((t) => t.userId.equals(userId) & t.familyId.equals(familyId)))
        .getSingleOrNull();
    if (existingMembership != null) {
      return JoinFamilyResult.alreadyMember;
    }

    // 既に別の家族に所属しているかチェック（1家族のみ参加可能）
    final anyMembership = await (db.select(db.familyMembers)
          ..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
    if (anyMembership != null) {
      return JoinFamilyResult.alreadyHasFamily;
    }

    if (inviteId != null && inviteId.isNotEmpty) {
      // 招待はRPCで原子的に消費する（存在しない/期限切れ/使用済みなら false）。
      final rpcResult = await supabase.rpc(
        'consume_invite',
        params: {
          'p_invite_id': inviteId,
          'p_family_id': familyId,
        },
      );
      final consumed = rpcResult == true;
      if (!consumed) {
        return JoinFamilyResult.invalidInvite;
      }
    }

    await db.transaction(() async {
      // 1. FamilyMembers に自分を登録
      await db.into(db.familyMembers).insert(
        FamilyMembersCompanion.insert(
          userId: userId,
          familyId: familyId,
        ),
      );

      // 2. プロフィールの currentFamilyId を更新
      await (db.update(db.profiles)..where((t) => t.id.equals(userId))).write(
        ProfilesCompanion(currentFamilyId: Value(familyId)),
      );
    });

    return JoinFamilyResult.joined;
  } catch (e) {
    debugPrint('joinFamily failed: $e');
    return JoinFamilyResult.failed;
  }
}

}
