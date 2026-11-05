import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Fonts and sizes from achivora.com at phone width, where 1rem is 15.5px.
/// Headings use Sora and text uses Manrope.
abstract final class AppTextStyles {
  static const bodyFont = 'Manrope';
  static const headingFont = 'Sora';

  static const xs = 11.625; // .75rem
  static const label = 13.0; // text-[13px]
  static const sm = 13.5625; // .875rem
  static const base = 15.5; // 1rem
  static const lg = 17.4375; // 1.125rem
  static const xl = 19.375; // 1.25rem
  static const xl2 = 24.8; // 1.6rem, the site's section title
  static const xl3 = 31.0; // 2rem, the site's page title
  static const eyebrow = 11.0; // the site's smallest label

  static TextStyle _heading(double size, FontWeight weight, double height) => TextStyle(
    fontFamily: headingFont,
    // Sora has no rupee sign, so that glyph comes from Manrope.
    fontFamilyFallback: const [bodyFont],
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: AppColors.neutral900,
  );

  static TextStyle _body(double size, FontWeight weight, double height, Color color) =>
      TextStyle(fontFamily: bodyFont, fontSize: size, fontWeight: weight, height: height, color: color);

  static final textTheme = TextTheme(
    displaySmall: _heading(xl3, FontWeight.w800, 1.15),
    headlineMedium: _heading(xl2, FontWeight.w800, 1.12),
    titleLarge: _heading(xl, FontWeight.w700, 1.3),
    titleMedium: _heading(lg, FontWeight.w700, 1.3),
    titleSmall: _heading(base, FontWeight.w700, 1.35),
    bodyLarge: _body(base, FontWeight.w500, 1.5, AppColors.neutral700),
    bodyMedium: _body(sm, FontWeight.w500, 1.45, AppColors.neutral700),
    bodySmall: _body(xs, FontWeight.w500, 1.35, AppColors.neutral600),
    labelLarge: _body(sm, FontWeight.w700, 1.3, AppColors.neutral900),
    labelMedium: _body(label, FontWeight.w600, 1.3, AppColors.neutral700),
    labelSmall: _body(eyebrow, FontWeight.w600, 1.3, AppColors.neutral600),
  );
}
