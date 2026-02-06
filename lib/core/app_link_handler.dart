import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/providers/families_provider.dart';

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
    final details = await repo.fetchInvitationDetails(inviteId);

    if (!context.mounted) return;

    if (details == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('招待リンクが無効または期限切れです')),
      );
      return;
    }

    final familyId = details['family_id'] as String?;
    final familyName = details['families']?['name'] ?? '不明';
    final inviterName = details['profiles']?['display_name'] ?? '誰か';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('家族に参加'),
        content: Text('$inviterNameさんから「$familyName」への招待が届いています。\n\n参加しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              if (familyId != null) {
                await repo.joinFamily(familyId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('「$familyName」に参加しました')),
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