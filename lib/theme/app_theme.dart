import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// 应用主题 - 精确匹配 uni-app 的浅色/深色模式
class AppTheme {
  AppTheme._();

  static const _fontFamily = 'siyuanheitiCNRegular';

  // ===== 浅色主题 =====
  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'siyuanheitiCNRegular', // 全局默认中文字体
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
      ),
      scaffoldBackgroundColor: AppColors.lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBg,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.black,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.tabBarBgLight,
        selectedItemColor: AppColors.tabActiveColor,
        unselectedItemColor: AppColors.tabInactiveColor,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: AppColors.cardDivider,
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.lightText),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.lightText),
        bodyLarge: TextStyle(fontSize: 14, color: AppColors.lightText),
        bodyMedium: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
        bodySmall: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
      ),
    );
  }

  // ===== 深色主题 =====
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'siyuanheitiCNRegular', // 全局默认中文字体
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
      ),
      scaffoldBackgroundColor: AppColors.darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkTabBg,
        selectedItemColor: AppColors.tabActiveColor,
        unselectedItemColor: AppColors.tabInactiveDark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: AppColors.darkBorder,
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkText),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkText),
        bodyLarge: TextStyle(fontSize: 14, color: AppColors.darkText),
        bodyMedium: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary),
        bodySmall: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
      ),
    );
  }

  /// 设置系统状态栏样式
  static void setSystemUIOverlay(Brightness brightness) {
    if (brightness == Brightness.dark) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // 浅色图标在深色背景上
        systemNavigationBarColor: AppColors.darkBg,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
    } else {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // 深色图标在浅色背景上
        systemNavigationBarColor: AppColors.lightBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ));
    }
  }
}
