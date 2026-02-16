import 'package:flutter/material.dart';

import '../../../core/widgets/app_button.dart';

class InviteErrorPage extends StatelessWidget {
  const InviteErrorPage({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('招待リンクエラー')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Color(0xFFCC2E59),
              ),
              const SizedBox(height: 16),
              const Text(
                '招待リンクを開けませんでした',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3844),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF687A95),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('トップへ戻る'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
