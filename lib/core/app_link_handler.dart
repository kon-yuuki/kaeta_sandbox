import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/app_button.dart';
import '../data/providers/families_provider.dart';
import '../data/providers/profiles_provider.dart';
import '../data/repositories/families_repository.dart';

class AppLinkHandler {
  final _appLinks = AppLinks();

  void listen(BuildContext context, WidgetRef ref) {
    // 1. アプリが完全に終了していた状態からリンクで起動した場合
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri, context, ref);
    });

    // 2. アプリが起動中にリンクをタップした場合（バックグラウンド含む）
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri, context, ref);
    });
  }

  void _handleDeepLink(Uri uri, BuildContext context, WidgetRef ref) {
    // 例: https://kaeta-jointeam.com/invite/xxxx-xxxx
    if (uri.pathSegments.contains('invite')) {
      final inviteId = uri.pathSegments.last;
      _showJoinDialog(context, ref, inviteId);
    }
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref, String inviteId) async {
    final repo = ref.read(familiesRepositoryProvider);

    // 招待情報を取得
    final invitation = await repo.fetchInvitationDetails(inviteId);

    if (!context.mounted) return;

    if (!invitation.isSuccess) {
      final message = switch (invitation.error) {
        InvitationFetchError.notFound => '招待リンクが見つかりません',
        InvitationFetchError.expired => '招待リンクの有効期限が切れています',
        _ => '招待リンクが無効または期限切れです',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    final details = invitation.details!;

    final familyId = details['family_id'] as String?;
    final familyName = details['families']?['name'] ?? '不明';
    final inviterName = details['profiles']?['display_name'] ?? '誰か';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('家族に参加'),
        content: Text('$inviterNameさんから「$familyName」への招待が届いています。\n\n参加しますか？'),
        actions: [
          AppButton(
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          AppButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              if (familyId != null) {
                final result = await repo.joinFamily(
                  familyId,
                  inviteId: inviteId,
                );
                if (result == JoinFamilyResult.joined) {
                  ref.invalidate(myProfileProvider);
                  ref.invalidate(selectedFamilyIdProvider);
                  ref.invalidate(joinedFamiliesProvider);
                }
                if (context.mounted) {
                  final message = switch (result) {
                    JoinFamilyResult.joined => '「$familyName」に参加しました',
                    JoinFamilyResult.alreadyMember => 'すでに「$familyName」に参加済みです',
                    JoinFamilyResult.alreadyHasFamily => '既に家族に参加しています。別の家族に参加するには、現在の家族を退出してください。',
                    JoinFamilyResult.notSignedIn => 'ログイン後に参加できます',
                    JoinFamilyResult.failed => '参加に失敗しました。再度お試しください',
                  };
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              }
            },
            child: const Text('参加する'),
          ),
        ],
      ),
    );
  }
}
