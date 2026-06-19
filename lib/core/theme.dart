import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants.dart';

ThemeData appTheme() {
  final baseText = GoogleFonts.poppinsTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppConstants.primaryColor,
      primary: AppConstants.primaryColor,
      secondary: AppConstants.secondaryColor,
      surface: AppConstants.surfaceColor,
      surfaceContainerHighest: AppConstants.backgroundColor,
      error: AppConstants.errorColor,
    ),
    scaffoldBackgroundColor: AppConstants.backgroundColor,
    textTheme: baseText.apply(
      bodyColor: AppConstants.textPrimaryColor,
      displayColor: AppConstants.textPrimaryColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppConstants.backgroundColor,
      foregroundColor: AppConstants.textPrimaryColor,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: baseText.titleLarge?.copyWith(
        color: AppConstants.textPrimaryColor,
        fontWeight: FontWeight.w900,
      ),
      iconTheme: const IconThemeData(color: AppConstants.textPrimaryColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppConstants.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppConstants.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppConstants.errorColor),
      ),
      filled: true,
      fillColor: AppConstants.surfaceColor,
      hintStyle: const TextStyle(color: AppConstants.textSubtleColor),
      labelStyle: const TextStyle(color: AppConstants.textSecondaryColor),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppConstants.surfaceColor,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppConstants.textPrimaryColor,
        side: const BorderSide(color: AppConstants.borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppConstants.primaryDarkColor,
        textStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppConstants.textPrimaryColor,
      contentTextStyle: baseText.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppConstants.surfaceColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppConstants.surfaceColor,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppConstants.primaryDarkColor,
      textColor: AppConstants.textPrimaryColor,
      subtitleTextStyle: TextStyle(color: AppConstants.textSecondaryColor),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppConstants.primaryColor,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppConstants.primaryLightColor;
          return AppConstants.surfaceColor;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppConstants.primaryDarkColor;
          return AppConstants.textPrimaryColor;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? AppConstants.primaryBorderColor
              : AppConstants.borderColor;
          return BorderSide(color: color);
        }),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
    ),
  );
}

ThemeData appDarkTheme() {
  final text = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
    bodyColor: const Color(0xFFF3F4F6),
    displayColor: const Color(0xFFF9FAFB),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: AppConstants.primaryColor, brightness: Brightness.dark),
    scaffoldBackgroundColor: const Color(0xFF111827),
    textTheme: text,
    appBarTheme: AppBarTheme(backgroundColor: const Color(0xFF111827), foregroundColor: Colors.white, titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
    cardTheme: CardThemeData(color: const Color(0xFF1F2937), surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF1F2937), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
  );
}

