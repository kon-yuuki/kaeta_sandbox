import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.textAccentPrimary,
    required this.textAccentSecondary,
    required this.textAccentTertiary,
    required this.textAlert,
    required this.textDisabled,
    required this.textHigh,
    required this.textHighOnInverse,
    required this.textHighOnInverse80,
    required this.textLow,
    required this.textMedium,
    required this.blueDark,
    required this.bluePrimary,
    required this.accentPrimary,
    required this.accentPrimaryDark,
    required this.accentPrimaryLight,
    required this.accentPrimaryLight2X,
    required this.accentYellowDark,
    required this.accentYellowPrimary,
    required this.alert,
    required this.cautionLight,
    required this.surfaceDisabled,
    required this.surfaceHigh,
    required this.surfaceHighOnInverse,
    required this.surfaceLow,
    required this.surfaceMedium,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceTertiary,
    required this.backgroundBase,
    required this.backgroundGray,
    required this.borderAccentPrimary,
    required this.borderAlert,
    required this.borderDivider,
    required this.borderHigh,
    required this.borderLow,
    required this.borderMedium,
    required this.highlightedOutlineButton,
    required this.highlightedPrimary,
    required this.highlightedPrimaryDark,
    required this.overlayDark,
    required this.overlayMedium,
  });

  final Color textAccentPrimary;
  final Color textAccentSecondary;
  final Color textAccentTertiary;
  final Color textAlert;
  final Color textDisabled;
  final Color textHigh;
  final Color textHighOnInverse;
  final Color textHighOnInverse80;
  final Color textLow;
  final Color textMedium;
  final Color blueDark;
  final Color bluePrimary;
  final Color accentPrimary;
  final Color accentPrimaryDark;
  final Color accentPrimaryLight;
  final Color accentPrimaryLight2X;
  final Color accentYellowDark;
  final Color accentYellowPrimary;
  final Color alert;
  final Color cautionLight;
  final Color surfaceDisabled;
  final Color surfaceHigh;
  final Color surfaceHighOnInverse;
  final Color surfaceLow;
  final Color surfaceMedium;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceTertiary;
  final Color backgroundBase;
  final Color backgroundGray;
  final Color borderAccentPrimary;
  final Color borderAlert;
  final Color borderDivider;
  final Color borderHigh;
  final Color borderLow;
  final Color borderMedium;
  final Color highlightedOutlineButton;
  final Color highlightedPrimary;
  final Color highlightedPrimaryDark;
  final Color overlayDark;
  final Color overlayMedium;

  @override
  AppColors copyWith({
    Color? textAccentPrimary,
    Color? textAccentSecondary,
    Color? textAccentTertiary,
    Color? textAlert,
    Color? textDisabled,
    Color? textHigh,
    Color? textHighOnInverse,
    Color? textHighOnInverse80,
    Color? textLow,
    Color? textMedium,
    Color? blueDark,
    Color? bluePrimary,
    Color? accentPrimary,
    Color? accentPrimaryDark,
    Color? accentPrimaryLight,
    Color? accentPrimaryLight2X,
    Color? accentYellowDark,
    Color? accentYellowPrimary,
    Color? alert,
    Color? cautionLight,
    Color? surfaceDisabled,
    Color? surfaceHigh,
    Color? surfaceHighOnInverse,
    Color? surfaceLow,
    Color? surfaceMedium,
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? surfaceTertiary,
    Color? backgroundBase,
    Color? backgroundGray,
    Color? borderAccentPrimary,
    Color? borderAlert,
    Color? borderDivider,
    Color? borderHigh,
    Color? borderLow,
    Color? borderMedium,
    Color? highlightedOutlineButton,
    Color? highlightedPrimary,
    Color? highlightedPrimaryDark,
    Color? overlayDark,
    Color? overlayMedium,
  }) {
    return AppColors(
      textAccentPrimary: textAccentPrimary ?? this.textAccentPrimary,
      textAccentSecondary: textAccentSecondary ?? this.textAccentSecondary,
      textAccentTertiary: textAccentTertiary ?? this.textAccentTertiary,
      textAlert: textAlert ?? this.textAlert,
      textDisabled: textDisabled ?? this.textDisabled,
      textHigh: textHigh ?? this.textHigh,
      textHighOnInverse: textHighOnInverse ?? this.textHighOnInverse,
      textHighOnInverse80: textHighOnInverse80 ?? this.textHighOnInverse80,
      textLow: textLow ?? this.textLow,
      textMedium: textMedium ?? this.textMedium,
      blueDark: blueDark ?? this.blueDark,
      bluePrimary: bluePrimary ?? this.bluePrimary,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentPrimaryDark: accentPrimaryDark ?? this.accentPrimaryDark,
      accentPrimaryLight: accentPrimaryLight ?? this.accentPrimaryLight,
      accentPrimaryLight2X: accentPrimaryLight2X ?? this.accentPrimaryLight2X,
      accentYellowDark: accentYellowDark ?? this.accentYellowDark,
      accentYellowPrimary: accentYellowPrimary ?? this.accentYellowPrimary,
      alert: alert ?? this.alert,
      cautionLight: cautionLight ?? this.cautionLight,
      surfaceDisabled: surfaceDisabled ?? this.surfaceDisabled,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHighOnInverse: surfaceHighOnInverse ?? this.surfaceHighOnInverse,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceMedium: surfaceMedium ?? this.surfaceMedium,
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceTertiary: surfaceTertiary ?? this.surfaceTertiary,
      backgroundBase: backgroundBase ?? this.backgroundBase,
      backgroundGray: backgroundGray ?? this.backgroundGray,
      borderAccentPrimary: borderAccentPrimary ?? this.borderAccentPrimary,
      borderAlert: borderAlert ?? this.borderAlert,
      borderDivider: borderDivider ?? this.borderDivider,
      borderHigh: borderHigh ?? this.borderHigh,
      borderLow: borderLow ?? this.borderLow,
      borderMedium: borderMedium ?? this.borderMedium,
      highlightedOutlineButton:
          highlightedOutlineButton ?? this.highlightedOutlineButton,
      highlightedPrimary: highlightedPrimary ?? this.highlightedPrimary,
      highlightedPrimaryDark:
          highlightedPrimaryDark ?? this.highlightedPrimaryDark,
      overlayDark: overlayDark ?? this.overlayDark,
      overlayMedium: overlayMedium ?? this.overlayMedium,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      textAccentPrimary: Color.lerp(textAccentPrimary, other.textAccentPrimary, t)!,
      textAccentSecondary: Color.lerp(textAccentSecondary, other.textAccentSecondary, t)!,
      textAccentTertiary: Color.lerp(textAccentTertiary, other.textAccentTertiary, t)!,
      textAlert: Color.lerp(textAlert, other.textAlert, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textHigh: Color.lerp(textHigh, other.textHigh, t)!,
      textHighOnInverse: Color.lerp(textHighOnInverse, other.textHighOnInverse, t)!,
      textHighOnInverse80: Color.lerp(textHighOnInverse80, other.textHighOnInverse80, t)!,
      textLow: Color.lerp(textLow, other.textLow, t)!,
      textMedium: Color.lerp(textMedium, other.textMedium, t)!,
      blueDark: Color.lerp(blueDark, other.blueDark, t)!,
      bluePrimary: Color.lerp(bluePrimary, other.bluePrimary, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentPrimaryDark: Color.lerp(accentPrimaryDark, other.accentPrimaryDark, t)!,
      accentPrimaryLight: Color.lerp(accentPrimaryLight, other.accentPrimaryLight, t)!,
      accentPrimaryLight2X: Color.lerp(accentPrimaryLight2X, other.accentPrimaryLight2X, t)!,
      accentYellowDark: Color.lerp(accentYellowDark, other.accentYellowDark, t)!,
      accentYellowPrimary: Color.lerp(accentYellowPrimary, other.accentYellowPrimary, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      cautionLight: Color.lerp(cautionLight, other.cautionLight, t)!,
      surfaceDisabled: Color.lerp(surfaceDisabled, other.surfaceDisabled, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHighOnInverse: Color.lerp(surfaceHighOnInverse, other.surfaceHighOnInverse, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceMedium: Color.lerp(surfaceMedium, other.surfaceMedium, t)!,
      surfacePrimary: Color.lerp(surfacePrimary, other.surfacePrimary, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      surfaceTertiary: Color.lerp(surfaceTertiary, other.surfaceTertiary, t)!,
      backgroundBase: Color.lerp(backgroundBase, other.backgroundBase, t)!,
      backgroundGray: Color.lerp(backgroundGray, other.backgroundGray, t)!,
      borderAccentPrimary:
          Color.lerp(borderAccentPrimary, other.borderAccentPrimary, t)!,
      borderAlert: Color.lerp(borderAlert, other.borderAlert, t)!,
      borderDivider: Color.lerp(borderDivider, other.borderDivider, t)!,
      borderHigh: Color.lerp(borderHigh, other.borderHigh, t)!,
      borderLow: Color.lerp(borderLow, other.borderLow, t)!,
      borderMedium: Color.lerp(borderMedium, other.borderMedium, t)!,
      highlightedOutlineButton: Color.lerp(
        highlightedOutlineButton,
        other.highlightedOutlineButton,
        t,
      )!,
      highlightedPrimary:
          Color.lerp(highlightedPrimary, other.highlightedPrimary, t)!,
      highlightedPrimaryDark:
          Color.lerp(highlightedPrimaryDark, other.highlightedPrimaryDark, t)!,
      overlayDark: Color.lerp(overlayDark, other.overlayDark, t)!,
      overlayMedium: Color.lerp(overlayMedium, other.overlayMedium, t)!,
    );
  }

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;
}

const lightAppColors = AppColors(
  textAccentPrimary: Color(0xFF1E9475),
  textAccentSecondary: Color(0xFF2ECCA1),
  textAccentTertiary: Color(0xFF61DBBB),
  textAlert: Color(0xFFB2244A),
  textDisabled: Color(0xFFACB7C8),
  textHigh: Color(0xFF2C3844),
  textHighOnInverse: Color(0xFFFFFFFF),
  textHighOnInverse80: Color(0xCCFFFFFF),
  textLow: Color(0xFF667A99),
  textMedium: Color(0xFF4B5E72),
  blueDark: Color(0xFF2491B2),
  bluePrimary: Color(0xFF61BFDB),
  accentPrimary: Color(0xFF2ECCA1),
  accentPrimaryDark: Color(0xFF24B28C),
  accentPrimaryLight: Color(0xFFEDFCF9),
  accentPrimaryLight2X: Color(0xFF85E0C8),
  accentYellowDark: Color(0xFFB28C24),
  accentYellowPrimary: Color(0xFFDBBB61),
  alert: Color(0xFFCC2E59),
  cautionLight: Color(0xFFFAEBEF),
  surfaceDisabled: Color(0xFFC2CAD6),
  surfaceHigh: Color(0xFF2C3844),
  surfaceHighOnInverse: Color(0xFFFFFFFF),
  surfaceLow: Color(0xFF94A2B8),
  surfaceMedium: Color(0xFF4B5E72),
  surfacePrimary: Color(0xFFC6CDD7),
  surfaceSecondary: Color(0xFFEDF1F7),
  surfaceTertiary: Color(0xFFF5F7FA),
  backgroundBase: Color(0xFFFFFFFF),
  backgroundGray: Color(0xFFF5F7FA),
  borderAccentPrimary: Color(0xFF2ECCA1),
  borderAlert: Color(0xFFE07692),
  borderDivider: Color(0xFFF5F7FA),
  borderHigh: Color(0xFF4B5E72),
  borderLow: Color(0xFFD8DDE4),
  borderMedium: Color(0xFFACB7C8),
  highlightedOutlineButton: Color(0xFFEDFCF9),
  highlightedPrimary: Color(0xFFF5F7FA),
  highlightedPrimaryDark: Color(0xFFEDF1F7),
  overlayDark: Color(0x99000000),
  overlayMedium: Color(0x4D000000),
);
