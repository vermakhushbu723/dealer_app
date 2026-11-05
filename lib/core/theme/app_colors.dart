import 'package:flutter/material.dart';

/// Palette taken from the Tailwind tokens used on iceclubstore.in.
abstract final class AppColors {
  static const sky50 = Color(0xFFF0F9FF);
  static const sky100 = Color(0xFFDFF2FE);
  static const sky200 = Color(0xFFB8E6FE);
  static const sky400 = Color(0xFF00BCFE);
  static const sky500 = Color(0xFF00A5EF);
  static const sky600 = Color(0xFF0084CC);
  static const sky700 = Color(0xFF0069A8); // primary buttons, white text passes AA on it
  static const cyan100 = Color(0xFFCEFAFE);
  static const cyan300 = Color(0xFF53EAFD);

  static const neutral100 = Color(0xFFF5F5F5);
  static const neutral500 = Color(0xFF737373);
  static const neutral600 = Color(0xFF525252);
  static const neutral700 = Color(0xFF404040);
  static const neutral800 = Color(0xFF262626);
  static const neutral900 = Color(0xFF171717);

  static const green500 = Color(0xFF00C758);
  static const green600 = Color(0xFF00A544);
  static const green700 = Color(0xFF008138);

  // The site has no error or warning colour, these are standard Tailwind ones.
  static const red600 = Color(0xFFDC2626);
  static const red50 = Color(0xFFFEF2F2);
  static const amber600 = Color(0xFFD97706);
  static const amber50 = Color(0xFFFFFBEB);

  static const border = Color(0x1A000000); // border-black/10

  /// The site's accent gradient (from-sky-400 to-cyan-300).
  static const accentGradient = LinearGradient(colors: [sky400, cyan300]);

  /// The site's section background (from-sky-100 via cyan-100/40 to-white).
  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [sky100, Color(0x66CEFAFE), Colors.white],
  );
}
