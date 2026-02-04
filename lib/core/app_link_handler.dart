import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // 例: https://kaeta.app/invite/xxxx-xxxx
    // pathSegments を使って ID（xxxx-xxxx）を抜き出す
    if (uri.pathSegments.contains('invite')) {
      final inviteId = uri.pathSegments.last;
      
      // ここで参加確認ダイアログを表示する関数を呼ぶ
      _showJoinDialog(context, ref, inviteId);
    }
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref, String inviteId) {
    // ここで前回の「fetchInvitationDetails」を呼んで、
    // 「〇〇さんのチームに参加しますか？」と出すダイアログを実装します。
    debugPrint("招待検知！ ID: $inviteId");
  }
}