import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const seed = Color(0xFF1F4D43);
    const surface = Color(0xFFF4F3EF);
    const card = Colors.white;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      cardColor: card,
      dividerColor: const Color(0xFFE7E5E4),
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          color: const Color(0xFFE9F1EE),
          borderRadius: BorderRadius.circular(14),
        ),
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF0F172A),
        unselectedLabelColor: const Color(0xFF6B7280),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFEBE8E2)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE7E5E4)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: const Color(0xFFE9F1EE),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color:
                isSelected ? const Color(0xFF0F172A) : const Color(0xFF6B7280),
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F172A),
          side: const BorderSide(color: Color(0xFFD6D3D1)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seed,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD6D3D1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD6D3D1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: seed, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
