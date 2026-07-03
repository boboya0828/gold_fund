import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式枚举
enum AppThemeMode {
  system('system', '跟随系统'),
  light('light', '浅色模式'),
  dark('dark', '深色模式');

  final String value;
  final String label;
  const AppThemeMode(this.value, this.label);

  static AppThemeMode fromValue(String value) {
    return AppThemeMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AppThemeMode.system,
    );
  }
}

/// 主题模式 Provider
class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.system) {
    _load();
  }

  static const _key = 'appSkinMode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key) ?? 'system';
    state = AppThemeMode.fromValue(value);
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.value);
  }

  /// 切换深色/浅色（用于快速切换按钮）
  Future<void> toggle() async {
    if (state == AppThemeMode.dark) {
      await setMode(AppThemeMode.light);
    } else {
      await setMode(AppThemeMode.dark);
    }
  }
}

/// ThemeMode provider
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// 当前是否为深色模式的便捷 provider
final isDarkModeProvider = Provider<bool>((ref) {
  final mode = ref.watch(themeModeProvider);
  if (mode == AppThemeMode.system) {
    // 系统模式下无法在 Provider 中获取，需要 Widget 层通过 MediaQuery 判断
    return false;
  }
  return mode == AppThemeMode.dark;
});
