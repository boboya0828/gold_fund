import 'package:flutter/material.dart';

/// 深色模式图标反色滤镜
///
/// 1:1 复刻 uni-app pages/user/index.vue 深色样式中的 CSS 滤镜：
///   .theme-dark .navto image,
///   .theme-dark .navto1 image { filter: invert(1) opacity(0.62); }
/// invert(1) => RGB 取反 (255 - c)；opacity(0.62) => alpha × 0.62。
class DarkModeIconFilter extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const DarkModeIconFilter({super.key, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isDark) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -1, 0, 0, 0, 255, //
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 0.62, 0,
      ]),
      child: child,
    );
  }
}
