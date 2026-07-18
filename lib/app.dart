import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'features/auth/providers/theme_provider.dart';

/// 全局滚动行为 — Web/桌面端 Flutter 默认只允许触摸拖动，
/// 鼠标拖拽列表不滚动、下拉刷新（ZPagingRefresh）无法触发。
/// 把 mouse/trackpad 加入可拖拽设备，对齐 uni-app H5 的鼠标拖拽行为。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}

class YangJiApp extends ConsumerStatefulWidget {
  const YangJiApp({super.key});

  @override
  ConsumerState<YangJiApp> createState() => _YangJiAppState();
}

class _YangJiAppState extends ConsumerState<YangJiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateSystemChrome();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _updateSystemChrome();
  }

  void _updateSystemChrome() {
    final brightness = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first,
    ).platformBrightness;
    AppTheme.setSystemUIOverlay(brightness);
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.router;
    final themeMode = ref.watch(themeModeProvider);

    // 每当主题切换时更新系统 chrome
    ref.listen(themeModeProvider, (_, next) {
      final brightness = (next == AppThemeMode.dark)
          ? Brightness.dark
          : (next == AppThemeMode.light)
              ? Brightness.light
              : MediaQueryData.fromView(
                  WidgetsBinding.instance.platformDispatcher.views.first,
                ).platformBrightness;
      AppTheme.setSystemUIOverlay(brightness);
    });

    return MaterialApp.router(
      title: '养基助手',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      themeMode: _toFlutterThemeMode(themeMode),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }

  ThemeMode _toFlutterThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light: return ThemeMode.light;
      case AppThemeMode.dark: return ThemeMode.dark;
      case AppThemeMode.system: return ThemeMode.system;
    }
  }
}
