import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBottomActionSheet extends StatelessWidget {
  const AppBottomActionSheet({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            12,
            8,
            12,
            12 + MediaQuery.of(context).padding.bottom,
          ),
      decoration: BoxDecoration(
        color: colors.surfaceHighOnInverse,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, -2),
            blurRadius: 12,
          ),
        ],
      ),
      child: child,
    );
  }
}
