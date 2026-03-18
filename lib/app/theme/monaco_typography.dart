import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MonacoTypography {
  MonacoTypography._();

  static TextTheme get textTheme {
    return GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.25),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),
    );
  }
}
