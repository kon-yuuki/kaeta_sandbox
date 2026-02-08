import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppListItem extends StatelessWidget {
  const AppListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.showDivider = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  subtitle!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    final wrapped = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: content),
          );

    if (!showDivider) return wrapped;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.borderDivider, width: 1),
        ),
      ),
      child: wrapped,
    );
  }
}
