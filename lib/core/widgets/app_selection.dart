import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppSelectionSize {
  lg,
  sm,
}

class AppChoicePill extends StatelessWidget {
  const AppChoicePill({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.size = AppSelectionSize.lg,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final AppSelectionSize size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final horizontal = size == AppSelectionSize.sm ? 10.0 : 14.0;
    final vertical = size == AppSelectionSize.sm ? 4.0 : 8.0;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? colors.highlightedOutlineButton : colors.surfaceHighOnInverse,
          border: Border.all(
            color: selected ? colors.accentPrimary : colors.borderMedium,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: size == AppSelectionSize.sm ? 11 : 12,
            color: selected ? colors.textAccentPrimary : colors.textHigh,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class AppRadioCircle extends StatelessWidget {
  const AppRadioCircle({
    super.key,
    required this.selected,
    this.onTap,
  });

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.accentPrimary : colors.borderMedium,
            width: 1.5,
          ),
        ),
        child: selected
            ? Center(
                child: Container(
                  width: 8,
                  height: 8,
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

enum AppCheckType {
  shoppingList,
  edit,
}

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
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? activeColor : Colors.transparent,
          border: Border.all(
            color: selected ? activeColor : colors.borderMedium,
            width: 1.5,
          ),
        ),
        child: selected
            ? const Icon(
                Icons.check,
                size: 14,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}
