import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppHeadingType {
  primary,
  secondary,
  tertiary,
}

class AppHeading extends StatelessWidget {
  const AppHeading(
    this.text, {
    super.key,
    this.type = AppHeadingType.primary,
  });

  final String text;
  final AppHeadingType type;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = switch (type) {
      AppHeadingType.primary => const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      AppHeadingType.secondary => const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      AppHeadingType.tertiary => const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
    };

    return Text(
      text,
      style: style.copyWith(color: colors.textHigh),
    );
  }
}
