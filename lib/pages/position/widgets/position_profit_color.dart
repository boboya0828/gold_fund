import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 盈亏颜色 — 1:1 复刻 uni-app positionv1/index.vue getProfitClass
/// .is-up { color: #FC4E50 !important }   (n >= 0，含 0)
/// .is-down { color: #07B360 !important } (n < 0) —— 明暗同色
/// is-neutral：不覆盖默认色（主行默认 #3b3b3b 浅 / #C9CDD4 深）

Color positionProfitUpColor() => AppColors.positionUpColor;

Color positionProfitDownColor(bool isDark) => AppColors.positionFallColor;

Color positionProfitNeutralColor(bool isDark) =>
    isDark ? const Color(0xFFC9CDD4) : const Color(0xFF3B3B3B);

/// 根据 value 返回对应盈亏色（1:1 getProfitClass：null/NaN → 中性色，>=0 → 红，<0 → 绿）
Color profitColor(double? value, bool isDark) {
  if (value == null || value.isNaN) return positionProfitNeutralColor(isDark);
  return value >= 0
      ? positionProfitUpColor()
      : positionProfitDownColor(isDark);
}
