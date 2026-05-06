import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.horizontalPadding = 8,
  });

  final String title;
  final VoidCallback onBack;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          AppHeaderBackButton(onPressed: onBack),
          Text(
            title,
            style: typography.titleSm16B160.copyWith(color: colors.textHigh),
          ),
        ],
      ),
    );
  }
}

class AppHeaderBackButton extends StatelessWidget {
  const AppHeaderBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Image.asset('assets/icons/chevron-left.png', width: 24, height: 24),
    );
  }
}
