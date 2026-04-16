import 'package:flutter/material.dart';
import 'app_colors.dart';

enum AppThemeType { light, dark }

class AppTheme {
  static ThemeData getTheme(AppThemeType type, Color accentColor) {
    switch (type) {
      case AppThemeType.light:
        return _lightTheme(accentColor);
      case AppThemeType.dark:
        return _darkTheme(accentColor);
    }
  }

  static ThemeData _lightTheme(Color accent) {
    const appBarBg = Color(0xFFECEDF5);       // светло-лавандовый фон AppBar (как на скрине)
    const navAccent = Color(0xFF7878CC);      // фиолетово-синий акцент нижней навигации
    const iconDark  = Color(0xFF333333);
    const textDark  = Color(0xFF1A1A1A);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: navAccent,
      scaffoldBackgroundColor: Colors.white,     // Вернул белый фон
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,   // Чтобы AppBar не менял цвет при прокрутке
        foregroundColor: iconDark,
        elevation: 0,
        iconTheme: IconThemeData(color: iconDark),
        actionsIconTheme: IconThemeData(color: iconDark),
      ),
      iconTheme: const IconThemeData(color: iconDark),
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconColor: iconDark,
        iconSize: 22,
        textStyle: TextStyle(color: textDark, fontSize: 15),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: iconDark,
        textColor: textDark,
        tileColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,        // нижнее меню — белый фон
        indicatorColor: navAccent.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: navAccent);
          }
          return const IconThemeData(color: Color(0xFF888888));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: navAccent);
          }
          return const TextStyle(fontSize: 12, color: Color(0xFF888888));
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: navAccent,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
    );
  }

  static ThemeData _darkTheme(Color accent) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: accent,
      scaffoldBackgroundColor: AppColors.darkBg,
      cardColor: AppColors.darkCard,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      popupMenuTheme: const PopupMenuThemeData(
        iconColor: Colors.white70,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: accent.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent);
          }
          return const IconThemeData(color: Colors.white54);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent);
          }
          return const TextStyle(fontSize: 12, color: Colors.white54);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.darkCard,
      ),
    );
  }
}
