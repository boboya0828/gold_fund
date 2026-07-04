import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 盈亏颜色 — 1:1 复刻 uni-app positionv1/index.vue
/// .is-up { color: #FF4D5D }
/// .is-down { color: #00B26A } （明暗同色, index.vue:1894/2081）
/// is-neutral (default: black in light, #C9CDD4 in dark)

Color positionProfitUpColor() => const Color(0xFFFF4D5D);

Color positionProfitDownColor(bool isDark) => AppColors.positionDownColor;

Color positionProfitNeutralColor(bool isDark) => isDark ? const Color(0xFFC9CDD4) : Colors.black;

/// 根据 value 返回对应盈亏色
Color profitColor(double value, bool isDark) {
  if (value == 0) return positionProfitNeutralColor(isDark);
  return value > 0 ? positionProfitUpColor() : positionProfitDownColor(isDark);
}
