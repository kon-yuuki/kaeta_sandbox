import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AppSelectionSize { lg, sm }

class AppChoicePill extends StatelessWidget {
  const AppChoicePill({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.size = AppSelectionSize.lg,
    this.expand = false,
    this.horizontalPadding,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final AppSelectionSize size;
  final bool expand;
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final horizontal =
        horizontalPadding ?? (size == AppSelectionSize.sm ? 10.0 : 14.0);
    final vertical = size == AppSelectionSize.sm ? 4.0 : 8.0;
    final pill = InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: size == AppSelectionSize.lg ? 43 : 35,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: vertical,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? colors.highlightedOutlineButton
              : colors.surfaceTertiary,
          border: selected
              ? Border.all(color: colors.accentPrimary, width: 2)
              : null,
        ),
        child: Text(
          label,
          style: typography.std12B160.copyWith(
            color: selected ? colors.textAccentPrimary : colors.textMedium,
          ),
        ),
      ),
    );

    return expand ? pill : IntrinsicWidth(child: pill);
  }
}

class AppRadioCircle extends StatelessWidget {
  const AppRadioCircle({
    super.key,
    required this.selected,
    this.onTap,
    this.outerSize = 24,
    this.innerSize = 12,
    this.borderWidth = 2,
    this.inactiveBorderWidth = 1,
  });

  final bool selected;
  final VoidCallback? onTap;
  final double outerSize;
  final double innerSize;
  final double borderWidth;
  final double inactiveBorderWidth;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: outerSize,
        height: outerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.accentPrimary : colors.borderMedium,
            width: selected ? borderWidth : inactiveBorderWidth,
          ),
        ),
        child: selected
            ? Center(
                child: Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    color: colors.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

enum AppCheckType { shoppingList, edit }

class AppCheckCircle extends StatelessWidget {
  const AppCheckCircle({
    super.key,
    required this.selected,
    this.onTap,
    this.type = AppCheckType.shoppingList,
  });

  final bool selected;
  final VoidCallback? onTap;
  final AppCheckType type;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final activeColor = type == AppCheckType.shoppingList
        ? colors.accentPrimary
        : colors.bluePrimary;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? activeColor : Colors.transparent,
          border: Border.all(
            color: selected ? activeColor : colors.borderMedium,
            width: 1.5,
          ),
        ),
        child: selected
            ? Center(
                child: SvgPicture.asset(
                  'assets/icons/check.svg',
                  width: 16,
                  height: 16,
                ),
              )
            : null,
      ),
    );
  }
}
