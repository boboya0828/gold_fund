import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/text_styles.dart';

/// 持仓分布条目
class DistributionDatum {
  final String name;
  final double value; // 百分比数值（接口已返回百分数）
  final Color color;

  const DistributionDatum({required this.name, required this.value, required this.color});

  /// uni-app: Number(item.ratio || 0).toFixed(2)
  String get ratioText => value.toStringAsFixed(2);
}

/// 持仓分布环形图 — 1:1 复刻 uni-app pages/user/distribution.vue 的 ECharts pie
/// radius ['55%', '75%']，中心 50%/50%，中心文案 '{n}个' + 类型标签
class DistributionDonut extends StatelessWidget {
  /// uni-app distribution.vue PIE_COLORS（与 curve.vue 顺序不同，勿混用）
  static const pieColors = [
    0xFFE05665, 0xFF3D73EB, 0xFFFF9C1C, 0xFF4EB2F0, 0xFF9033F0,
    0xFFFF5B69, 0xFF07B361, 0xFFFFBE37, 0xFF5D7EF6, 0xFFE85F6F,
    0xFF00B8D9, 0xFFFF6B35, 0xFF8E6FF7, 0xFF2ECC71, 0xFFE74C3C,
    0xFF3498DB, 0xFFF39C12, 0xFF1ABC9C, 0xFF9B59B6, 0xFFE67E22,
    0xFF2980B9, 0xFF27AE60, 0xFFC0392B, 0xFF16A085, 0xFFD35400,
    0xFF8E44AD, 0xFF2C3E50, 0xFFF1C40F, 0xFF7F8C8D, 0xFFE91E63,
  ];

  final bool isDark;
  final List<DistributionDatum> data;
  final String centerCount; // '5个'
  final String centerLabel; // '基金' / '板块' / '类型'

  const DistributionDonut({
    super.key,
    required this.isDark,
    required this.data,
    required this.centerCount,
    required this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final labelColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF999999);

    return Stack(
      alignment: Alignment.center,
      children: [
        // 环形图 200×200，radius 55%~75% → 内径 55 / 环厚 20
        if (data.isNotEmpty)
          Positioned.fill(
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 55, // ECharts 55% of 100
                startDegreeOffset: 270, // ECharts 默认从 12 点方向开始
                borderData: FlBorderData(show: false),
                pieTouchData: PieTouchData(enabled: false), // silent: true
                sections: [
                  for (final d in data)
                    PieChartSectionData(
                      value: d.value,
                      color: d.color,
                      radius: 20, // 外径 75(75%) - 内径 55(55%)
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
        // 中心文案
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(centerCount, style: AppTextStyles.cn(24, color: textColor, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(centerLabel, style: AppTextStyles.cn(14, color: labelColor)),
          ],
        ),
      ],
    );
  }
}
