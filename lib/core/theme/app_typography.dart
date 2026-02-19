import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.dsp21B140,
    required this.jaOnl16M130,
    required this.jaOnl16R120,
    required this.jaOnl14B100,
    required this.jaOnl14Sb100,
    required this.jaOnl12B100,
    required this.jaOnl11M100,
    required this.egOnl26R120,
    required this.egOnl16M160,
    required this.egOnl12M140,
    required this.std20M160,
    required this.std18R160,
    required this.std16B150,
    required this.std16R160,
    required this.std16R175,
    required this.std14B160,
    required this.std14R160,
    required this.std12B160,
    required this.std12M160,
    required this.std11B140,
    required this.std11M160,
  });

  final TextStyle dsp21B140;
  final TextStyle jaOnl16M130;
  final TextStyle jaOnl16R120;
  final TextStyle jaOnl14B100;
  final TextStyle jaOnl14Sb100;
  final TextStyle jaOnl12B100;
  final TextStyle jaOnl11M100;
  final TextStyle egOnl26R120;
  final TextStyle egOnl16M160;
  final TextStyle egOnl12M140;
  final TextStyle std20M160;
  final TextStyle std18R160;
  final TextStyle std16B150;
  final TextStyle std16R160;
  final TextStyle std16R175;
  final TextStyle std14B160;
  final TextStyle std14R160;
  final TextStyle std12B160;
  final TextStyle std12M160;
  final TextStyle std11B140;
  final TextStyle std11M160;

  @override
  AppTypography copyWith({
    TextStyle? dsp21B140,
    TextStyle? jaOnl16M130,
    TextStyle? jaOnl16R120,
    TextStyle? jaOnl14B100,
    TextStyle? jaOnl14Sb100,
    TextStyle? jaOnl12B100,
    TextStyle? jaOnl11M100,
    TextStyle? egOnl26R120,
    TextStyle? egOnl16M160,
    TextStyle? egOnl12M140,
    TextStyle? std20M160,
    TextStyle? std18R160,
    TextStyle? std16B150,
    TextStyle? std16R160,
    TextStyle? std16R175,
    TextStyle? std14B160,
    TextStyle? std14R160,
    TextStyle? std12B160,
    TextStyle? std12M160,
    TextStyle? std11B140,
    TextStyle? std11M160,
  }) {
    return AppTypography(
      dsp21B140: dsp21B140 ?? this.dsp21B140,
      jaOnl16M130: jaOnl16M130 ?? this.jaOnl16M130,
      jaOnl16R120: jaOnl16R120 ?? this.jaOnl16R120,
      jaOnl14B100: jaOnl14B100 ?? this.jaOnl14B100,
      jaOnl14Sb100: jaOnl14Sb100 ?? this.jaOnl14Sb100,
      jaOnl12B100: jaOnl12B100 ?? this.jaOnl12B100,
      jaOnl11M100: jaOnl11M100 ?? this.jaOnl11M100,
      egOnl26R120: egOnl26R120 ?? this.egOnl26R120,
      egOnl16M160: egOnl16M160 ?? this.egOnl16M160,
      egOnl12M140: egOnl12M140 ?? this.egOnl12M140,
      std20M160: std20M160 ?? this.std20M160,
      std18R160: std18R160 ?? this.std18R160,
      std16B150: std16B150 ?? this.std16B150,
      std16R160: std16R160 ?? this.std16R160,
      std16R175: std16R175 ?? this.std16R175,
      std14B160: std14B160 ?? this.std14B160,
      std14R160: std14R160 ?? this.std14R160,
      std12B160: std12B160 ?? this.std12B160,
      std12M160: std12M160 ?? this.std12M160,
      std11B140: std11B140 ?? this.std11B140,
      std11M160: std11M160 ?? this.std11M160,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      dsp21B140: TextStyle.lerp(dsp21B140, other.dsp21B140, t)!,
      jaOnl16M130: TextStyle.lerp(jaOnl16M130, other.jaOnl16M130, t)!,
      jaOnl16R120: TextStyle.lerp(jaOnl16R120, other.jaOnl16R120, t)!,
      jaOnl14B100: TextStyle.lerp(jaOnl14B100, other.jaOnl14B100, t)!,
      jaOnl14Sb100: TextStyle.lerp(jaOnl14Sb100, other.jaOnl14Sb100, t)!,
      jaOnl12B100: TextStyle.lerp(jaOnl12B100, other.jaOnl12B100, t)!,
      jaOnl11M100: TextStyle.lerp(jaOnl11M100, other.jaOnl11M100, t)!,
      egOnl26R120: TextStyle.lerp(egOnl26R120, other.egOnl26R120, t)!,
      egOnl16M160: TextStyle.lerp(egOnl16M160, other.egOnl16M160, t)!,
      egOnl12M140: TextStyle.lerp(egOnl12M140, other.egOnl12M140, t)!,
      std20M160: TextStyle.lerp(std20M160, other.std20M160, t)!,
      std18R160: TextStyle.lerp(std18R160, other.std18R160, t)!,
      std16B150: TextStyle.lerp(std16B150, other.std16B150, t)!,
      std16R160: TextStyle.lerp(std16R160, other.std16R160, t)!,
      std16R175: TextStyle.lerp(std16R175, other.std16R175, t)!,
      std14B160: TextStyle.lerp(std14B160, other.std14B160, t)!,
      std14R160: TextStyle.lerp(std14R160, other.std14R160, t)!,
      std12B160: TextStyle.lerp(std12B160, other.std12B160, t)!,
      std12M160: TextStyle.lerp(std12M160, other.std12M160, t)!,
      std11B140: TextStyle.lerp(std11B140, other.std11B140, t)!,
      std11M160: TextStyle.lerp(std11M160, other.std11M160, t)!,
    );
  }

  static AppTypography of(BuildContext context) =>
      Theme.of(context).extension<AppTypography>()!;
}

final lightAppTypography = AppTypography(
  dsp21B140: GoogleFonts.notoSansJp(
    fontSize: 21,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: Color(0xFF2C3844),
  ),
  jaOnl16M130: GoogleFonts.notoSansJp(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: Color(0xFF2C3844),
  ),
  jaOnl16R120: GoogleFonts.notoSansJp(
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: Color(0xFF2C3844),
  ),
  jaOnl14B100: GoogleFonts.notoSansJp(
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: Color(0xFF2C3844),
  ),
  jaOnl14Sb100: GoogleFonts.notoSansJp(
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: Color(0xFF2C3844),
  ),
  jaOnl12B100: GoogleFonts.notoSansJp(
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: Color(0xFF2C3844),
  ),
  jaOnl11M100: GoogleFonts.notoSansJp(
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w500,
    color: Color(0xFF2C3844),
  ),
  egOnl26R120: GoogleFonts.inter(
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: Color(0xFF2C3844),
  ),
  egOnl16M160: GoogleFonts.inter(
    fontSize: 16,
    height: 1.6,
    fontWeight: FontWeight.w500,
    color: Color(0xFF2C3844),
  ),
  egOnl12M140: GoogleFonts.inter(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: Color(0xFF2C3844),
  ),
  std20M160: GoogleFonts.notoSansJp(
    fontSize: 20,
    height: 1.6,
    fontWeight: FontWeight.w500,
    color: Color(0xFF2C3844),
  ),
  std18R160: GoogleFonts.notoSansJp(
    fontSize: 18,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: Color(0xFF2C3844),
  ),
  std16B150: GoogleFonts.notoSansJp(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFF2C3844),
  ),
  std16R160: GoogleFonts.notoSansJp(
    fontSize: 16,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: Color(0xFF2C3844),
  ),
  std16R175: GoogleFonts.notoSansJp(
    fontSize: 16,
    height: 1.75,
    fontWeight: FontWeight.w400,
    color: Color(0xFF2C3844),
  ),
  std14B160: GoogleFonts.notoSansJp(
    fontSize: 14,
    height: 1.6,
    fontWeight: FontWeight.w700,
    color: Color(0xFF2C3844),
  ),
  std14R160: GoogleFonts.notoSansJp(
    fontSize: 14,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: Color(0xFF2C3844),
  ),
  std12B160: GoogleFonts.notoSansJp(
    fontSize: 12,
    height: 1.6,
    fontWeight: FontWeight.w700,
    color: Color(0xFF2C3844),
  ),
  std12M160: GoogleFonts.notoSansJp(
    fontSize: 12,
    height: 1.6,
    fontWeight: FontWeight.w500,
    color: Color(0xFF2C3844),
  ),
  std11B140: GoogleFonts.notoSansJp(
    fontSize: 11,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: Color(0xFF2C3844),
  ),
  std11M160: GoogleFonts.notoSansJp(
    fontSize: 11,
    height: 1.6,
    fontWeight: FontWeight.w500,
    color: Color(0xFF2C3844),
  ),
);
