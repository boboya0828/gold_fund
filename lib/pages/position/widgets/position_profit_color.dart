import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 盈亏颜色 — 1:1 复刻 uni-app
/// .is-up { color: #FF4D5D }
/// .is-down { color: #31B87A (light) / #20B979 (dark) }
/// is-neutral (default: black in light, #C9CDD4 in dark)

Color positionProfitUpColor() => const Color(0xFFFF4D5D);

Color positionProfitDownColor(bool isDark) => isDark ? AppColors.downColorDark : AppColors.downColor;

Color positionProfitNeutralColor(bool isDark) => isDark ? const Color(0xFFC9CDD4) : Colors.black;

/// 根据 value 返回对应盈亏色
Color profitColor(double value, bool isDark) {
  if (value == 0) return positionProfitNeutralColor(isDark);
  return value > 0 ? positionProfitUpColor() : positionProfitDownColor(isDark);
}
