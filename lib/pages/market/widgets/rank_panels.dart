import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'market_models.dart';

/// 板块收益排行 / 基金自选榜表面板 — 1:1 复刻 zdj-v1 pages/market/index.vue 的
/// .sector-panel / .sector-panel.fund-panel
///
/// - .sector-panel：高 660rpx(=330)，padding 36/40/0rpx，圆角 10rpx(=5)，白底(暗 #202125)
/// - .fund-panel：height auto、min-height 660rpx(=330)、padding-bottom 18rpx(=9)
/// - 表头 .sector-table-head：margin-top 34rpx(=17)，padding-bottom 16rpx(=8)，
///   24rpx(=12) #808080(暗 #A7ADB8)，下边框 #F2F2F2(暗 #2B2D33)
/// - 行 .sector-row 高 82rpx(=41) / .fund-row 高 98rpx(=49)，下边框 #ebe6e1(暗 #2B2D33)，
///   最后一行无边框（:last-child border-bottom: 0）

class SectorRankPanel extends StatelessWidget {
  final bool isDark;
  final List<SectorRankItem> items;
  final VoidCallback onMore;
  final ValueChanged<SectorRankItem> onItemTap;
  const SectorRankPanel({
    super.key,
    required this.isDark,
    required this.items,
    required this.onMore,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? const Color(0xFF2B2D33) : const Color(0xFFEBE6E1);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), // 36rpx 40rpx 0
      child: SizedBox(
        height: 330, // 660rpx
        child: Column(children: [
          _PanelTitle(title: '板块收益排行', isDark: isDark, onMore: onMore),
          const SizedBox(height: 17), // 34rpx
          _TableHead(isDark: isDark, columns: const ['排名', '板块名称', '涨跌幅'], fund: false),
          for (var i = 0; i < items.length; i++)
            _SectorRow(item: items[i], isDark: isDark, isLast: i == items.length - 1,
                borderColor: borderColor, onTap: onItemTap),
        ]),
      ),
    );
  }
}

class FundRankPanel extends StatelessWidget {
  final bool isDark;
  final List<FundRankItemData> items;
  final VoidCallback onMore;
  final ValueChanged<FundRankItemData> onItemTap;
  const FundRankPanel({
    super.key,
    required this.isDark,
    required this.items,
    required this.onMore,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? const Color(0xFF2B2D33) : const Color(0xFFEBE6E1);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 9), // 36rpx 40rpx 18rpx
      // .fund-panel: height auto; min-height 660rpx
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 330),
        child: Column(children: [
          _PanelTitle(title: '基金自选榜单', isDark: isDark, onMore: onMore),
          const SizedBox(height: 17),
          _TableHead(isDark: isDark, columns: const ['排名', '基金名称', '净值', '涨跌幅'], fund: true),
          for (var i = 0; i < items.length; i++)
            _FundRow(item: items[i], isDark: isDark, isLast: i == items.length - 1,
                borderColor: borderColor, onTap: onItemTap),
        ]),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  final VoidCallback onMore;
  const _PanelTitle({required this.title, required this.isDark, required this.onMore});

  @override
  Widget build(BuildContext context) {
    // 更多文字 #A6A6A6(暗 #A7ADB8)；箭头图标用 useAppTheme mutedIconColor #7B7C81(暗 #A7ADB8)
    final moreText = isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA6A6A6);
    final moreIcon = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF7B7C81);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : Colors.black)),
      GestureDetector(
        onTap: onMore,
        child: Row(children: [
          Text('更多', style: AppTextStyles.cn(13, color: moreText, height: 1)),
          const SizedBox(width: 2), // gap 4rpx
          Icon(Icons.chevron_right, size: 14, color: moreIcon),
        ]),
      ),
    ]);
  }
}

class _TableHead extends StatelessWidget {
  final bool isDark;
  final List<String> columns;
  final bool fund;
  const _TableHead({required this.isDark, required this.columns, required this.fund});

  @override
  Widget build(BuildContext context) {
    final hc = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF808080);
    TextStyle s() => AppTextStyles.cn(12, color: hc);
    return Container(
      padding: const EdgeInsets.only(bottom: 8), // 16rpx
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2F2F2))),
      ),
      child: Row(children: [
        SizedBox(width: 32, child: Text(columns[0], style: s(), textAlign: TextAlign.center)), // 64rpx
        Expanded(child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(columns[1], style: s()))), // 24rpx
        if (fund)
          SizedBox(width: 68, child: Text(columns[2], style: s(), textAlign: TextAlign.right)), // 136rpx
        SizedBox(
            width: fund ? 68 : 78, // fund 136rpx / sector 156rpx
            child: Text(columns[fund ? 3 : 2], style: s(), textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _SectorRow extends StatelessWidget {
  final SectorRankItem item;
  final bool isDark, isLast;
  final Color borderColor;
  final ValueChanged<SectorRankItem> onTap;
  const _SectorRow({required this.item, required this.isDark, required this.isLast,
      required this.borderColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final up = item.trend == 'up';
    final tc = up ? AppColors.upColor : kMarketDownColor;
    return GestureDetector(
      onTap: () => onTap(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 41, // 82rpx
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(children: [
          SizedBox(
            width: 32,
            child: Text(formatRankNo(item.rank),
                style: AppTextStyles.num(14, color: marketRankColor(item.rank, isDark), weight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(item.name,
                  style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF1E1917), height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
          SizedBox(
            width: 78, // 156rpx
            child: Text(item.rate, style: AppTextStyles.num(15, color: tc), textAlign: TextAlign.right),
          ),
        ]),
      ),
    );
  }
}

class _FundRow extends StatelessWidget {
  final FundRankItemData item;
  final bool isDark, isLast;
  final Color borderColor;
  final ValueChanged<FundRankItemData> onTap;
  const _FundRow({required this.item, required this.isDark, required this.isLast,
      required this.borderColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final up = item.trend == 'up';
    final tc = up ? AppColors.upColor : kMarketDownColor;
    return GestureDetector(
      onTap: () => onTap(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 49, // 98rpx
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(children: [
          SizedBox(
            width: 32,
            child: Text(formatRankNo(item.rank),
                style: AppTextStyles.num(14, color: marketRankColor(item.rank, isDark), weight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(item.name,
                    style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF1E1917), height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4), // .fund-code margin-top 8rpx
                Text(item.code,
                    style: AppTextStyles.num(12, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF9B9B9B))),
              ]),
            ),
          ),
          // .fund-net 固定带 .is-up（红色 #E05665，源码暗色无覆盖，明暗同色）
          SizedBox(
            width: 68,
            child: Text(item.netValue, style: AppTextStyles.num(15, color: AppColors.upColor), textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 68,
            child: Text(item.rate, style: AppTextStyles.num(15, color: tc), textAlign: TextAlign.right),
          ),
        ]),
      ),
    );
  }
}
