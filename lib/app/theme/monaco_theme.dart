import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'monaco_colors.dart';
import 'monaco_typography.dart';

class MonacoTheme {
  MonacoTheme._();

  static ThemeData get dark {
    final textTheme = MonacoTypography.textTheme.apply(
      bodyColor: MonacoColors.foreground,
      displayColor: MonacoColors.foreground,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: MonacoColors.background,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: MonacoColors.primary,
        onPrimary: MonacoColors.primaryForeground,
        secondary: MonacoColors.secondary,
        onSecondary: MonacoColors.secondaryForeground,
        surface: MonacoColors.surface,
        onSurface: MonacoColors.foreground,
        error: MonacoColors.destructive,
        onError: MonacoColors.destructiveForeground,
        outline: MonacoColors.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: MonacoColors.background,
        foregroundColor: MonacoColors.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: MonacoColors.foreground,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: MonacoColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: MonacoColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MonacoColors.primary,
          foregroundColor: MonacoColors.primaryForeground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MonacoColors.foreground,
          side: const BorderSide(color: MonacoColors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MonacoColors.foreground,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MonacoColors.input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: MonacoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: MonacoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: MonacoColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: MonacoColors.destructive),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: MonacoColors.foregroundSubtle),
        labelStyle: const TextStyle(color: MonacoColors.foregroundMuted),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MonacoColors.surface,
        selectedItemColor: MonacoColors.primary,
        unselectedItemColor: MonacoColors.foregroundSubtle,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: MonacoColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MonacoColors.surface,
        contentTextStyle: const TextStyle(color: MonacoColors.foreground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MonacoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MonacoColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MonacoColors.secondary,
        labelStyle: const TextStyle(color: MonacoColors.foreground, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MonacoColors.primary,
      ),
    );
  }
}
