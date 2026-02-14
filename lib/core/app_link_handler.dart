import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/invite/view/invite_start_screen.dart';

class AppLinkHandler {
  final _appLinks = AppLinks();
  String? _lastHandledInviteId;

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
    String? inviteId;

    // 例: https://kaeta-jointeam.com/invite/xxxx-xxxx
    if (uri.pathSegments.contains('invite') && uri.pathSegments.isNotEmpty) {
      inviteId = uri.pathSegments.last;
    }

    // フォールバック: kaeta://invite/xxxx-xxxx
    if (inviteId == null && uri.scheme == 'kaeta') {
      if (uri.host == 'invite' && uri.pathSegments.isNotEmpty) {
        inviteId = uri.pathSegments.last;
      } else if (uri.pathSegments.contains('invite') && uri.pathSegments.isNotEmpty) {
        inviteId = uri.pathSegments.last;
      }
    }

    if (inviteId != null && inviteId.isNotEmpty) {
      if (_lastHandledInviteId == inviteId) return;
      _lastHandledInviteId = inviteId;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InviteStartPage(inviteId: inviteId!),
        ),
      );
    }
  }
}
