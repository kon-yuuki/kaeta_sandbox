import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/app_button.dart';

class InviteJoinPage extends StatelessWidget {
  const InviteJoinPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('チームへの参加方法')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
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
              const Spacer(),
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
            ],
          ),
        ),
      ),
    );
  }
}

