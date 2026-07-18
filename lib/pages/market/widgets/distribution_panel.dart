import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'market_models.dart';

/// 今日涨跌分布面板 — 1:1 复刻 zdj-v1 pages/market/index.vue 的 .distribution-panel
///
/// - 面板：白底(暗 #202125)，圆角 10rpx(=5)，padding 36/24/26rpx，标题下间距 20rpx(=10)
/// - 柱状图 .distribution-chart：高 206rpx(=103)，左右 padding 8rpx(=4)，item 宽 60rpx(=30)
///   条宽 28rpx(=14)，圆角 4rpx(=2) 仅上方；颜色 跌#16b85f / 平#9ea7bc / 涨#ff4d57
/// - 汇总条 .distribution-summary__bar：高 24rpx(=12)，两端圆角 999，斜切角 14rpx(=7)，
///   中间斜杠分隔块 24rpx(=12) 宽 #aab1c1 skewX(-32deg)，上下各叠 -4rpx(=-2) 边距
class DistributionPanel extends StatelessWidget {
  final bool isDark;
  final List<DistItem> items;
  const DistributionPanel({super.key, required this.isDark, required this.items});

  @override
  Widget build(BuildContext context) {
    final downTotal = items.where((d) => d.type == 'down').fold<int>(0, (s, d) => s + d.value);
    final upTotal = items.where((d) => d.type == 'up').fold<int>(0, (s, d) => s + d.value);
    final flatTotal = items.where((d) => d.type == 'flat').fold<int>(0, (s, d) => s + d.value);
    // distTotalCount 含平盘；distDownPercent = Math.round(down/total*100)，空数据默认 50
    final total = downTotal + upTotal + flatTotal;
    final downPct = total == 0 ? 50 : (downTotal / total * 100).round();

    final valColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF515B76);
    final lblColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8B8B8B);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(5), // 10rpx
      ),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 13), // 36rpx 24rpx 26rpx
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('今日涨跌分布',
            style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : Colors.black, height: 1.2)),
        const SizedBox(height: 10), // .distribution-panel__header margin-bottom 20rpx
        SizedBox(
          height: 103, // 206rpx
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4), // 8rpx
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.map((d) => _DistBar(item: d, valColor: valColor, lblColor: lblColor)).toList(),
            ),
          ),
        ),
        const SizedBox(height: 13), // .distribution-summary margin-top 26rpx
        Row(children: [
          Text('下跌', style: AppTextStyles.cn(11, color: lblColor)),
          const SizedBox(width: 3), // value margin 0 6rpx
          Text('$downTotal',
              style: AppTextStyles.num(11, color: const Color(0xFF16B85F), weight: FontWeight.w600)),
          const SizedBox(width: 7), // gap 14rpx
          Expanded(child: _SummaryBar(downPct: downPct)),
          const SizedBox(width: 7),
          Text('$upTotal',
              style: AppTextStyles.num(11, color: const Color(0xFFFF4D57), weight: FontWeight.w600)),
          const SizedBox(width: 3),
          Text('上涨', style: AppTextStyles.cn(11, color: lblColor)),
        ]),
      ]),
    );
  }
}

class _DistBar extends StatelessWidget {
  final DistItem item;
  final Color valColor, lblColor;
  const _DistBar({required this.item, required this.valColor, required this.lblColor});

  @override
  Widget build(BuildContext context) {
    final bc = item.type == 'down'
        ? const Color(0xFF16B85F)
        : (item.type == 'flat' ? const Color(0xFF9EA7BC) : const Color(0xFFFF4D57));
    return SizedBox(
      width: 30, // 60rpx
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('${item.value}',
            maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: AppTextStyles.num(11, color: valColor)),
        const SizedBox(height: 4), // value margin-bottom 8rpx
        Container(
          height: item.height.toDouble(),
          width: 14, // 28rpx
          decoration: BoxDecoration(
            color: bc,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)), // 4rpx
          ),
        ),
        const SizedBox(height: 5), // label margin-top 10rpx
        Text(item.label,
            maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: AppTextStyles.num(9, color: lblColor)),
      ]),
    );
  }
}

/// 涨跌对比汇总条：左绿(跌) + 斜杠分隔 + 右红(涨)，两端圆角、内侧斜切。
class _SummaryBar extends StatelessWidget {
  final int downPct;
  const _SummaryBar({required this.downPct});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 12, // 24rpx
        child: Row(children: [
          Flexible(
            flex: downPct,
            child: ClipPath(
              clipper: _SlantClipper(down: true),
              child: Container(color: const Color(0xFF16B85F)),
            ),
          ),
          // .distribution-summary__bar-divider：24rpx 宽 #aab1c1，skewX(-32deg)，margin 0 -4rpx
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: -2),
            decoration: BoxDecoration(color: const Color(0xFFAAB1C1), borderRadius: BorderRadius.circular(2)),
            transform: Matrix4.skewX(-32 * math.pi / 180),
          ),
          Flexible(
            flex: 100 - downPct,
            child: ClipPath(
              clipper: _SlantClipper(down: false),
              child: Container(color: const Color(0xFFFF4D57)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 斜切 clip-path，对齐源码 14rpx(=7px) 斜边：
/// 跌条 polygon(0 0, 100% 0, calc(100% - 14rpx) 100%, 0 100%)
/// 涨条 polygon(14rpx 0, 100% 0, 100% 100%, 0 100%)
class _SlantClipper extends CustomClipper<Path> {
  final bool down;
  const _SlantClipper({required this.down});

  @override
  Path getClip(Size size) {
    const slant = 7.0; // 14rpx
    final path = Path();
    if (down) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width - slant, size.height)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(slant, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _SlantClipper oldClipper) => oldClipper.down != down;
}
