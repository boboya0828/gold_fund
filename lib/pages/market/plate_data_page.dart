import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 板块数据页 — 1:1 复刻 zdj-v1 pages/market/plate-data.vue
///
/// 双列卡片网格：emoji 图标 + 板块名 + 涨跌箭头/涨跌幅。
/// 注意：源码 plateList 为前端硬编码静态数据（无接口）；条目无 symbolId，
/// goToDetails 被 `if (!item?.symbolId) return` 拦截，点击恒为无操作，1:1 保留。
class PlateDataPage extends ConsumerWidget {
  const PlateDataPage({super.key});

  // 源码 plateList 静态数据（icon, name, rate, trend）
  static const _plates = [
    ('🧠', 'AI算力', '-3.19%', 'down'),
    ('💡', 'CPO', '-9.00%', 'down'),
    ('🖥', '半导体', '-2.32%', 'down'),
    ('💾', '存储', '-7.85%', 'down'),
    ('🏢', '数据中心', '-4.04%', 'down'),
    ('☁', '云计算', '-0.16%', 'down'),
    ('🚀', '商业航天', '-0.65%', 'down'),
    ('🛰', '卫星', '-0.46%', 'down'),
    ('🤖', '机器人', '-4.51%', 'down'),
    ('🚗', '自动驾驶', '-7.20%', 'down'),
    ('⚛', '核电', '-1.29%', 'down'),
    ('⚡', '电网', '-3.11%', 'down'),
    ('🛡', '军工', '+3.35%', 'up'),
    ('🔋', '新能源', '-3.94%', 'down'),
    ('☀', '光伏', '-2.83%', 'down'),
    ('🔋', '锂电池', '-3.10%', 'down'),
    ('🛢', '石油', '+0.79%', 'up'),
    ('🔥', '天然气', '+0.58%', 'up'),
    ('🔶', '铜/有色', '+1.63%', 'up'),
    ('🥇', '黄金', '+2.98%', 'up'),
    ('🏦', '银行金融', '+0.24%', 'up'),
    ('🧬', '生物医药', '+2.51%', 'up'),
    ('🛒', '消费', '+2.99%', 'up'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF1F1F3),
      body: Column(children: [
        CustomNavBar(
          title: '板块数据',
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12), // 24rpx
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10, // 20rpx
              mainAxisSpacing: 10,
              mainAxisExtent: 46, // 卡片 padding 26rpx*2 + 内容 40rpx = 92rpx
            ),
            itemCount: _plates.length,
            itemBuilder: (context, i) => _buildCard(_plates[i], isDark),
          ),
        ),
      ]),
    );
  }

  Widget _buildCard((String, String, String, String) item, bool isDark) {
    final (icon, name, rate, trend) = item;
    final up = trend == 'up';
    final color = up ? AppColors.upColor : kPlateDownColor;
    return GestureDetector(
      // goToDetails：item 无 symbolId → return（1:1 无操作）
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13), // 26rpx 22rpx
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(8), // 16rpx
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x1F000000) : const Color(0x0A000000), // .12 / .04
              offset: const Offset(0, 2), // 4rpx
              blurRadius: 8, // 16rpx
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(children: [
                Text(icon, style: const TextStyle(fontSize: 20, height: 1)), // 40rpx
                const SizedBox(width: 8), // gap 16rpx
                Expanded(
                  child: Text(
                    name,
                    style: AppTextStyles.cn(14,
                        color: isDark ? AppColors.darkText : const Color(0xFF1E1917), height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 4),
            // ▲/▼ 20rpx=10，颜色同涨跌
            Text(up ? '▲' : '▼', style: TextStyle(fontSize: 10, height: 1, color: color)),
            const SizedBox(width: 3), // gap 6rpx
            Text(rate, style: AppTextStyles.num(14, color: color, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// 本页跌/绿 #00ADA0（源码 is-down/arrow-down，明暗同色，与 market_models.kMarketDownColor 一致）
const Color kPlateDownColor = Color(0xFF00ADA0);
