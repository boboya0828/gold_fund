import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/providers/theme_provider.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/text_styles.dart';

/// 皮肤设置页 — 1:1 复刻 uni-app pages/user/center/skin.vue
/// 白色皮肤 / 深色皮肤 单选列表
///
/// 存储语义对齐 uni-app：
///   appSkinMode          — 用户选择的模式（light/dark），由 themeModeProvider 持久化
///   appSkinResolvedMode  — 解析后的实际模式（本页与 appSkinMode 一致）
///
/// 平台专有能力（umeng 埋点、原生导航栏/TabBar 换肤）未迁移。
class SkinPage extends ConsumerStatefulWidget {
  const SkinPage({super.key});

  @override
  ConsumerState<SkinPage> createState() => _SkinPageState();
}

class _SkinPageState extends ConsumerState<SkinPage> {
  /// uni-app RESOLVED_SKIN_STORAGE_KEY
  static const _resolvedSkinStorageKey = 'appSkinResolvedMode';

  /// uni-app skinOptions: [白色皮肤 light, 深色皮肤 dark]
  static const _options = [
    (label: '白色皮肤', mode: AppThemeMode.light),
    (label: '深色皮肤', mode: AppThemeMode.dark),
  ];

  // 页面专有背景色（与全局 darkBg 不同，对齐 skin.vue）
  static const _lightPageBg = Color(0xFFF6F8FC);
  static const _darkPageBg = Color(0xFF10131A);

  @override
  void initState() {
    super.initState();
    // uni-app refreshSkinMode + persistSkinMode：非法/缺失值归一化为 light 并回写
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mode = ref.read(themeModeProvider);
      if (mode != AppThemeMode.light && mode != AppThemeMode.dark) {
        _applyMode(AppThemeMode.light);
      } else {
        _persistResolved(mode);
      }
    });
  }

  /// uni-app persistSkinMode 中的 appSkinResolvedMode 回写
  Future<void> _persistResolved(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resolvedSkinStorageKey, mode.value);
  }

  Future<void> _applyMode(AppThemeMode mode) async {
    await ref.read(themeModeProvider.notifier).setMode(mode); // 持久化 appSkinMode
    await _persistResolved(mode);
  }

  /// uni-app handleSelectSkin：相同模式直接返回
  void _onSelect(AppThemeMode mode) {
    if (ref.read(themeModeProvider) == mode) return;
    _applyMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: isDark ? _darkPageBg : _lightPageBg,
      appBar: CustomNavBar(
        title: '皮肤切换',
        backgroundColor: isDark ? _darkPageBg : const Color(0xFFFAF7F7),
        titleColor: isDark ? const Color(0xFFF7F8FA) : const Color(0xFF333333),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // light: #FFFFFF 0% → #F6F8FC 28%；dark: #10131A 0% → #151922 100%
            colors: isDark
                ? const [Color(0xFF10131A), Color(0xFF151922)]
                : const [Colors.white, _lightPageBg],
            stops: isDark ? const [0, 1] : const [0, 0.28],
          ),
        ),
        child: Container(
          color: isDark ? const Color(0xFF171C26) : Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _options.length; i++)
                _skinItem(
                  label: _options[i].label,
                  selected: current == _options[i].mode,
                  isDark: isDark,
                  showBorder: i != _options.length - 1,
                  onTap: () => _onSelect(_options[i].mode),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skinItem({
    required String label,
    required bool selected,
    required bool isDark,
    required bool showBorder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56, // 112rpx
        padding: const EdgeInsets.symmetric(horizontal: 20), // 40rpx
        decoration: BoxDecoration(
          border: showBorder
              ? Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF262D3A) : const Color(0xFFF0F1F4),
                    width: 0.5, // 1rpx
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.cn(
                17, // 34rpx
                color: isDark ? const Color(0xFFF7F8FA) : const Color(0xFF151A2D),
                weight: FontWeight.w500,
              ),
            ),
            // 单选圈
            Container(
              width: 23, // 46rpx
              height: 23,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 2, // 4rpx
                  color: selected
                      ? const Color(0xFFE05665)
                      : (isDark ? const Color(0xFF606A78) : const Color(0xFFC5CBD4)),
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 11, // 22rpx
                        height: 11,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE05665),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
