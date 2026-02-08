import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppSuggestionChip extends StatelessWidget {
  const AppSuggestionChip({
    super.key,
    required this.label,
    this.avatar,
    this.onTap,
  });

  final String label;
  final Widget? avatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: colors.surfaceTertiary,
          border: Border.all(color: colors.borderMedium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[
              avatar!,
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.textHigh),
            ),
          ],
        ),
      ),
    );
  }
}

class AppChoiceChipX extends StatelessWidget {
  const AppChoiceChipX({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            fontSize: 12,
            color: selected ? colors.textAccentPrimary : colors.textHigh,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class AppConditionChip extends StatelessWidget {
  const AppConditionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.hasContent,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool hasContent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final Color bg = colors.surfaceHighOnInverse;
    final Color border = selected || hasContent
        ? colors.accentPrimary
        : colors.borderMedium;
    final Color fg = selected || hasContent
        ? colors.textAccentPrimary
        : colors.textHigh;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: bg,
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
