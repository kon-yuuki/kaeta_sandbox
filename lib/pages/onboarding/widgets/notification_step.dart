import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/services/notification_service.dart';
import '../providers/onboarding_provider.dart';

class NotificationStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const NotificationStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<NotificationStep> createState() => _NotificationStepState();
}

class _NotificationStepState extends ConsumerState<NotificationStep> {
  bool _isRequesting = false;

  Future<void> _handleNext() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    try {
      final granted = await NotificationService().requestPermission();
      ref.read(onboardingDataProvider.notifier).setNotificationEnabled(granted);
      if (!mounted) return;
      widget.onNext();
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 18),
          Text(
            'リストへの追加はまとめてお知らせします',
            style: TextStyle(
              color: colors.textHigh,
              fontSize: 24 / 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '複数アイテムの追加もまとめて通知\n購入完了 / アイテム編集などをお知らせします',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textLow,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF8BE2D0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/start/start_notice.png',
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: _isRequesting ? null : _handleNext,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _isRequesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('次へ', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          if (MediaQuery.of(context).padding.bottom > 0)
            SizedBox(height: MediaQuery.of(context).padding.bottom - 4),
        ],
      ),
    );
  }
}
