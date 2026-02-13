import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppPlusButtonSize {
  lg,
  sm,
}

class AppPlusButton extends StatelessWidget {
  const AppPlusButton({
    super.key,
    required this.onPressed,
    this.size = AppPlusButtonSize.lg,
    this.highlighted = false,
    this.focused = false,
    this.icon = Icons.add,
  });

  final VoidCallback? onPressed;
  final AppPlusButtonSize size;
  final bool highlighted;
  final bool focused;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = onPressed != null;
    final isSm = size == AppPlusButtonSize.sm;

    final double width = isSm ? 32 : 72;
    final double height = isSm ? 32 : 40;
    final double iconSize = isSm ? 18 : 30;

    Color bgColor = colors.surfaceHigh;
    Color fgColor = colors.textHighOnInverse;
    Color borderColor = Colors.transparent;

    if (!enabled) {
      bgColor = colors.surfaceDisabled;
      fgColor = colors.textDisabled;
    } else if (focused) {
      bgColor = colors.surfaceHighOnInverse;
      fgColor = colors.surfaceMedium;
      borderColor = colors.borderMedium;
    } else if (highlighted) {
      bgColor = colors.surfaceMedium;
      fgColor = colors.textHighOnInverse80;
    }

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: borderColor),
        ),
        elevation: enabled && !focused ? 3 : 0,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Icon(icon, color: fgColor, size: iconSize),
        ),
      ),
    );
  }
}
