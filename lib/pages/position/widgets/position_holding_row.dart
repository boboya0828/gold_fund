import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import '../position_provider_types.dart' show PositionItem;
import 'position_profit_color.dart';

/// 持仓单行 — 1:1 复刻 .holding-card-list / .holding-card__body
class PositionHoldingRow extends StatelessWidget {
  final PositionItem item;
  final int index;
  final bool isDark;
  final double nameW;
  final double dayProfitW;
  final double indicatorW;
  final double holdProfitW;
  final bool isNormal;
  final bool isCompact;
  final bool isMinimal;
  final double gapW;
  final bool isLast;
  final bool isSelected;
  final bool showMoney;
  final bool showProfit;
  final VoidCallback onTap;
  // 长按回传被按行的全局左上角 + 行高，供操作弹框跟随定位
  final void Function(Offset globalTopLeft, double height) onLongPress;

  const PositionHoldingRow({
    super.key,
    required this.item,
    required this.index,
    required this.isDark,
    required this.nameW,
    required this.dayProfitW,
    required this.indicatorW,
    required this.holdProfitW,
    required this.isNormal,
    required this.isCompact,
    required this.isMinimal,
    required this.gapW,
    required this.isLast,
    required this.isSelected,
    required this.showMoney,
    required this.showProfit,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final rowBg = isSelected
        ? (isDark ? const Color(0xFF2A2C31) : const Color(0xFFF1F1F1))
        : Colors.transparent;
    final separatorColor = isDark
        ? const Color(0xFF2B2D33)
        : const Color(0xFFF4F1EC);

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (_) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          onLongPress(box.localToGlobal(Offset.zero), box.size.height);
        }
      },
      child: Container(
        key: Key('position-holding-row-$index'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: rowBg,
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: separatorColor, width: 0.5)),
        ),
        child: SizedBox(
          height: 50, // 100rpx
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ===== 名称列 =====
              SizedBox(width: nameW, child: _buildNameColumn()),
              SizedBox(width: gapW),
              // ===== 当日收益 =====
              SizedBox(
                key: Key('position-row-day-profit-$index'),
                width: dayProfitW,
                child: _buildDayProfitColumn(),
              ),
              SizedBox(width: gapW),
              // ===== 关联板块 / 最新涨幅 =====
              SizedBox(
                key: Key('position-row-indicator-$index'),
                width: indicatorW,
                child: _buildIndicatorColumn(),
              ),
              // ===== 持有收益 (仅 normal/minimal) =====
              if (isNormal || isMinimal) ...[
                SizedBox(width: gapW),
                SizedBox(
                  key: Key('position-row-hold-profit-$index'),
                  width: holdProfitW,
                  child: _buildHoldProfitColumn(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          item.shortName,
          style: AppTextStyles.cn(
            14,
            color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF23283C),
            weight: FontWeight.w500,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // 源码：￥市值子行仅在 normal(listMunActive==0) 显示；compact/minimal 只显示名称单行
        if (isNormal) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (item.isUpdated)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 0.5,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withAlpha(140),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(2),
                    color: isDark
                        ? AppColors.primary.withAlpha(36)
                        : AppColors.primary.withAlpha(10),
                  ),
                  child: Text(
                    '已更新',
                    style: AppTextStyles.cn(
                      9,
                      color: AppColors.primary,
                      height: 1,
                    ),
                  ),
                ),
              Text(
                '￥${showMoney ? item.marketValue.toStringAsFixed(2) : '******'}',
                style: AppTextStyles.cn(
                  10.5, // 21rpx，源码 .holding-name__sub 恒定字号
                  color: isDark
                      ? const Color(0xFF9297A1)
                      : const Color(0xFF77798B),
                  height: 1,
                ),
              ),
              if (item.isYesterday) ...[
                const SizedBox(width: 4),
                Text(
                  item.latestTimeLabel,
                  style: AppTextStyles.cn(
                    10,
                    color: isDark
                        ? const Color(0xFF8F949D)
                        : const Color(0xFF77798B),
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDayProfitColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          showProfit ? _formatSigned(item.dayProfit) : '******',
          style: AppTextStyles.num(
            15,
            color: profitColor(item.dayProfit, isDark),
            weight: FontWeight.w500,
            height: 1,
          ),
        ),
        if (isNormal) ...[
          const SizedBox(height: 6),
          Text(
            showProfit ? '${_formatSigned(item.dayChangeRatio)}%' : '******',
            style: AppTextStyles.cn(
              11,
              color: profitColor(item.dayChangeRatio, isDark),
              height: 1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIndicatorColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isNormal) ...[
          if (item.firstIndicator != null) ...[
            Text(
              '${_formatSigned(item.firstIndicator!.changeRatio ?? 0)}%',
              style: AppTextStyles.num(
                15,
                color: profitColor(
                  item.firstIndicator!.changeRatio ?? 0,
                  isDark,
                ),
                weight: FontWeight.w500,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.firstIndicator!.name ??
                  item.firstIndicator!.shortName ??
                  '-',
              style: AppTextStyles.cn(
                10,
                color: isDark
                    ? const Color(0xFF8F949D)
                    : const Color(0xFF8D8B87),
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            Text(
              '-',
              style: AppTextStyles.cn(
                14,
                color: isDark
                    ? const Color(0xFF8F949D)
                    : const Color(0xFF8D8B87),
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '-',
              style: AppTextStyles.cn(
                10,
                color: isDark
                    ? const Color(0xFF8F949D)
                    : const Color(0xFF8D8B87),
                height: 1,
              ),
            ),
          ],
        ] else ...[
          // 简洁/极简: 显示最新涨幅
          Text(
            '${_formatSigned(item.latestChgRate)}%',
            style: AppTextStyles.num(
              15,
              color: profitColor(item.latestChgRate, isDark),
              weight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHoldProfitColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          showProfit ? _formatSigned(item.holdProfit) : '******',
          style: AppTextStyles.num(
            15,
            color: profitColor(item.holdProfit, isDark),
            weight: FontWeight.w500,
            height: 1,
          ),
        ),
        if (isNormal) ...[
          const SizedBox(height: 6),
          Text(
            showProfit ? '${_formatSigned(item.holdChangeRatio)}%' : '******',
            style: AppTextStyles.cn(
              11,
              color: profitColor(item.holdChangeRatio, isDark),
              height: 1,
            ),
          ),
        ],
        if (isCompact) ...[
          const SizedBox(height: 6),
          Text(
            showProfit ? '${_formatSigned(item.latestChgRate)}%' : '******',
            style: AppTextStyles.cn(
              11,
              color: profitColor(item.latestChgRate, isDark),
              height: 1,
            ),
          ),
        ],
      ],
    );
  }

  String _formatSigned(double value) {
    if (value > 0) return '+${value.toStringAsFixed(2)}';
    return value.toStringAsFixed(2);
  }
}
