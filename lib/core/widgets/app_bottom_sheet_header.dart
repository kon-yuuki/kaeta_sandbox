import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

class AppBottomSheetHeader extends StatelessWidget {
  const AppBottomSheetHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD4D4D4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(onPressed: onBack, icon: const Icon(Icons.chevron_left)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: typography.std16B150.copyWith(color: colors.textHigh),
            ),
            Padding(padding: const EdgeInsets.only(right: 12), child: trailing),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: colors.borderLow),
      ],
    );
  }
}

class AppBottomSheetSaveButton extends StatelessWidget {
  const AppBottomSheetSaveButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.label = '保存',
  });

  final bool enabled;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      variant: AppButtonVariant.filled,
      size: AppButtonSize.sm,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 34)),
        fixedSize: const WidgetStatePropertyAll(Size(48, 34)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      onPressed: enabled ? onPressed : null,
      child: Text(label),
    );
  }
}

class AppBottomSheetSectionHeading extends StatelessWidget {
  const AppBottomSheetSectionHeading({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    return Text(
      text,
      style: typography.std12B160.copyWith(color: colors.textHigh),
    );
  }
}
