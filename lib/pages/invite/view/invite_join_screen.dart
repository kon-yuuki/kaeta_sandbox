import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../login/view/login_screen.dart';
import 'invite_start_screen.dart';

class InviteJoinPage extends StatefulWidget {
  const InviteJoinPage({super.key});

  @override
  State<InviteJoinPage> createState() => _InviteJoinPageState();
}

class _InviteJoinPageState extends State<InviteJoinPage> {
  static const _heroAssetPath = 'assets/images/start/screen_joinconfirm.png';
  final TextEditingController _inviteLinkController = TextEditingController();
  String? _inputErrorText;

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
    setState(() {
      _inviteLinkController.text = text;
      _inputErrorText = null;
    });
  }

  void _openInviteFromInput() {
    final inviteId = _extractInviteId(_inviteLinkController.text);
    if (inviteId == null) {
      setState(() {
        _inputErrorText = '無効なURLです';
      });
      return;
    }
    setState(() {
      _inputErrorText = null;
    });
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
    final colors = AppColors.of(context);
    final canSubmit = _extractInviteId(_inviteLinkController.text) != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('参加するチームを確認')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  _heroAssetPath,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'チームに参加する',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF2D3B4A),
                  fontSize: 38 / 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'メッセージアプリで届いたリンクをタップしても\n参加ができます',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF687A95),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '招待リンクを入力',
                style: TextStyle(
                  color: Color(0xFF5C6F89),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD8E0EC)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const Icon(Icons.link, color: Color(0xFF9AA8BC)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _inviteLinkController,
                        onChanged: (_) => setState(() {
                          _inputErrorText = null;
                        }),
                        decoration: const InputDecoration(
                          hintText: 'https://kaeta.app/...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _pasteFromClipboard,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(90, 52),
                        side: const BorderSide(color: Color(0xFFB8C5D8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        '貼り付け',
                        style: TextStyle(
                          color: Color(0xFF3B4E66),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_inputErrorText != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _inputErrorText!,
                      style: const TextStyle(
                        color: Color(0xFFCC2E59),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: canSubmit ? _openInviteFromInput : null,
                  style: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(58)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return const Color(0xFFB7C2D2);
                      }
                      return colors.surfaceHigh;
                    }),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                  child: const Text(
                    '参加するチームを確認',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF5D6F86)),
                        SizedBox(width: 8),
                        Text(
                          '招待を受けていない方',
                          style: TextStyle(
                            color: Color(0xFF2D3B4A),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '家族にチームへの招待を依頼しましょう\nあなたがオーナーになる場合は、チームを作成し家族を招待してください',
                      style: TextStyle(
                        color: Color(0xFF475D79),
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        variant: AppButtonVariant.outlined,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('チームを作成してはじめる'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
