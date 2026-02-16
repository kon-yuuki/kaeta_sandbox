import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/app_button.dart';
import 'invite_start_screen.dart';

class InviteJoinPage extends StatefulWidget {
  const InviteJoinPage({super.key});

  @override
  State<InviteJoinPage> createState() => _InviteJoinPageState();
}

class _InviteJoinPageState extends State<InviteJoinPage> {
  final TextEditingController _inviteLinkController = TextEditingController();

  Future<void> _openLine(BuildContext context) async {
    final uri = Uri.parse('line://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LINEアプリが見つかりませんでした')),
      );
    }
  }

  Future<void> _openMailApp(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'Kaeta! チーム招待',
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアプリを開けませんでした')),
      );
    }
  }

  String? _extractInviteId(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null) return null;

    if (uri.pathSegments.contains('invite') && uri.pathSegments.isNotEmpty) {
      final id = uri.pathSegments.last.trim();
      return id.isEmpty ? null : id;
    }

    if (uri.scheme == 'kaeta') {
      if (uri.host == 'invite' && uri.pathSegments.isNotEmpty) {
        final id = uri.pathSegments.last.trim();
        return id.isEmpty ? null : id;
      }
      if (uri.pathSegments.contains('invite') && uri.pathSegments.isNotEmpty) {
        final id = uri.pathSegments.last.trim();
        return id.isEmpty ? null : id;
      }
    }

    return null;
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _inviteLinkController.text = text;
  }

  void _openInviteFromInput() {
    final inviteId = _extractInviteId(_inviteLinkController.text);
    if (inviteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('招待リンクの形式が正しくありません')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InviteStartPage(inviteId: inviteId)),
    );
  }

  @override
  void dispose() {
    _inviteLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('チームへの参加方法')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 42),
              child: Column(
                children: [
                  const Text(
                    '招待時に共有されたURLから\nチームに参加してください',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 31 / 2,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3B4A),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 280),
                    height: 360,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D8D8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Center(
                      child: Text(
                        '招待画面の\nスクリーンショット',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 37 / 2,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPressed: () => _openLine(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('LINEを開く'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPressed: () => _openMailApp(context),
                      variant: AppButtonVariant.outlined,
                      icon: const Icon(Icons.mail_outline),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('メールアプリを開く'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _inviteLinkController,
                    decoration: InputDecoration(
                      hintText: '招待リンクを貼り付けてください',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.content_paste),
                        tooltip: '貼り付け',
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPressed: _openInviteFromInput,
                      variant: AppButtonVariant.outlined,
                      child: const Text('リンクを開いて参加する'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
