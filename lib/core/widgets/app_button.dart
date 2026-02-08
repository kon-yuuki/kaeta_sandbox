import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppButtonVariant {
  filled,
  outlined,
  text,
}

enum AppButtonSize {
  lg,
  sm,
}

enum AppButtonTone {
  normal,
  danger,
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.style,
    this.isSelected = false,
    this.size = AppButtonSize.lg,
    this.tone = AppButtonTone.normal,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AppButtonVariant variant;
  final Widget? icon;
  final ButtonStyle? style;
  final bool isSelected;
  final AppButtonSize size;
  final AppButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final shape = WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
    final isDanger = tone == AppButtonTone.danger;
    final minSize = size == AppButtonSize.sm
        ? const Size(0, 32)
        : const Size(0, 40);
    final horizontalPadding = size == AppButtonSize.sm ? 10.0 : 14.0;
    final verticalPadding = size == AppButtonSize.sm ? 6.0 : 10.0;

    ButtonStyle normalizeStyle(
      ButtonStyle? input, {
      required bool outlined,
      required bool filled,
      required bool text,
    }) {
      final isOutlineSelected = outlined && isSelected && !isDanger;
      final baseFg = isDanger
          ? appColors.textAlert
          : (filled || isOutlineSelected
                ? appColors.textHighOnInverse
                : appColors.textHigh);
      final baseIcon = isDanger
          ? appColors.textAlert
          : (filled || isOutlineSelected
                ? appColors.textHighOnInverse
                : appColors.surfaceMedium);
      final baseBg = isDanger
          ? appColors.cautionLight
          : (filled || isOutlineSelected
                ? appColors.surfaceHigh
                : appColors.surfaceHighOnInverse);
      final pressedBg = isDanger
          ? appColors.cautionLight
          : appColors.surfaceMedium;

      BorderSide resolveSide(Set<WidgetState> states) {
        if (text) return BorderSide.none;
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: appColors.surfaceDisabled);
        }
        if (filled || isOutlineSelected) {
          return BorderSide(color: baseBg);
        }
        return BorderSide(
          color: isDanger ? appColors.borderAlert : appColors.borderMedium,
        );
      }

      return (input ?? const ButtonStyle()).copyWith(
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.disabled)) return appColors.textDisabled;
          return baseFg;
        }),
        iconColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.disabled)) return appColors.textDisabled;
          return baseIcon;
        }),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (text) return Colors.transparent;
          if (states.contains(WidgetState.disabled)) return appColors.surfaceDisabled;
          if (states.contains(WidgetState.pressed)) return pressedBg;
          return baseBg;
        }),
        side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
          return resolveSide(states);
        }),
        overlayColor: WidgetStatePropertyAll<Color>(appColors.highlightedPrimaryDark),
        minimumSize: WidgetStatePropertyAll<Size>(minSize),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
        ),
        shape: shape,
      );
    }

    switch (variant) {
      case AppButtonVariant.filled:
        final resolvedStyle = normalizeStyle(
          style,
          outlined: false,
          filled: true,
          text: false,
        );
        if (icon != null) {
          return FilledButton.icon(
            onPressed: onPressed,
            style: resolvedStyle,
            icon: icon!,
            label: child,
          );
        }
        return FilledButton(
          onPressed: onPressed,
          style: resolvedStyle,
          child: child,
        );
      case AppButtonVariant.outlined:
        final resolvedStyle = normalizeStyle(
          style,
          outlined: true,
          filled: false,
          text: false,
        );
        if (icon != null) {
          return OutlinedButton.icon(
            onPressed: onPressed,
            style: resolvedStyle,
            icon: icon!,
            label: child,
          );
        }
        return OutlinedButton(
          onPressed: onPressed,
          style: resolvedStyle,
          child: child,
        );
      case AppButtonVariant.text:
        final resolvedStyle = normalizeStyle(
          style,
          outlined: false,
          filled: false,
          text: true,
        );
        if (icon != null) {
          return TextButton.icon(
            onPressed: onPressed,
            style: resolvedStyle,
            icon: icon!,
            label: child,
          );
        }
        return TextButton(
          onPressed: onPressed,
          style: resolvedStyle,
          child: child,
        );
    }
  }
}
