import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';
import '../position_provider_types.dart'
    show PositionFontScale, PositionItem, PositionState, TableShowMode;
import 'position_profit_color.dart';

/// 持仓表格列定义 — 1:1 复刻 uni-app demoAllTableColumns（16 列）
class PositionColumnDef {
  final String key;
  final String title;
  final String sortField;

  /// 副标题日期来源：trade=curTradeDate / nav=latestNavDate / ext=扩展列日期
  final String dateSource;

  /// 测试/定位用 key 后缀
  final String keySlug;

  const PositionColumnDef(
    this.key,
    this.title,
    this.sortField, {
    this.dateSource = 'trade',
    required this.keySlug,
  });
}

/// 默认全列（顺序 1:1 uni-app baseColumns）
const kPositionAllColumns = <PositionColumnDef>[
  PositionColumnDef('dayProfit', '当日收益', 'dayProfit', keySlug: 'day-profit'),
  PositionColumnDef('indicator', '关联板块', 'increaseRatio', keySlug: 'indicator'),
  PositionColumnDef('holdProfit', '持有收益', 'holdProfit', keySlug: 'hold-profit'),
  PositionColumnDef('latestNav', '最新净值', 'latestPrice.latestPrice',
      dateSource: 'nav', keySlug: 'latest-nav'),
  PositionColumnDef('dayChangeRatio', '当日涨幅', 'dayChangeRatio',
      keySlug: 'day-change-ratio'),
  PositionColumnDef('topHoldingsAvgChangeRate', '重仓均涨幅',
      'topHoldingsAvgChangeRate', dateSource: 'ext', keySlug: 'top-holdings'),
  PositionColumnDef('weekProfit', '本周收益', 'weekProfit',
      dateSource: 'ext', keySlug: 'week-profit'),
  PositionColumnDef('monthProfit', '本月收益', 'monthProfit',
      dateSource: 'ext', keySlug: 'month-profit'),
  PositionColumnDef('yearProfitRate', '今年涨幅', 'yearProfitRate',
      dateSource: 'ext', keySlug: 'year-profit-rate'),
  PositionColumnDef('marketValue', '持有金额', 'marketValue', keySlug: 'market-value'),
  PositionColumnDef('holdingRatio', '持仓占比', 'holdingRatio', keySlug: 'holding-ratio'),
  PositionColumnDef('holdQuantity', '持有份额', 'holdQuantity', keySlug: 'hold-quantity'),
  PositionColumnDef('holdCostAmount', '持有成本', 'holdCostAmount',
      keySlug: 'hold-cost-amount'),
  PositionColumnDef('holdDay', '持有天数', 'holdDay', keySlug: 'hold-day'),
  PositionColumnDef('breakEvenRate', '回本涨幅', 'breakEvenRate',
      keySlug: 'break-even-rate'),
];

/// 极简模式只保留的三列（1:1 uni-app DEMO_MINI_COLUMN_KEYS）
const kPositionMiniColumnKeys = ['dayProfit', 'indicator', 'holdProfit'];

/// 按表头管理配置过滤+排序可见列（无配置用默认全列）
List<PositionColumnDef> visiblePositionColumns(PositionState state) {
  final keys = state.columnKeys;
  if (keys == null || keys.isEmpty) return kPositionAllColumns;
  final result = <PositionColumnDef>[];
  for (final key in keys) {
    final col = kPositionAllColumns.where((c) => c.key == key).firstOrNull;
    if (col != null) result.add(col);
  }
  return result.isEmpty ? kPositionAllColumns : result;
}

/// 单元格数据 — 1:1 uni-app createDemoCell 产物
class HoldingCellData {
  final String key;
  final String keySlug;
  final String text; // 空串 → 渲染占位符 --
  final String subText;
  final String subPrefix; // QDII 净值日期前缀
  final bool showEmptySub;
  final Color? textColor; // null → 中性色
  final Color? subColor;
  final bool oversize; // 持有收益 |值|≥100000 字号降档 32→28rpx
  final bool subIsIndicatorName; // 板块名副行（18rpx，≥8 字降 16rpx）
  final bool subIsNavSub; // 净值副行（灰色不带涨跌色）

  const HoldingCellData({
    required this.key,
    required this.keySlug,
    this.text = '',
    this.subText = '',
    this.subPrefix = '',
    this.showEmptySub = false,
    this.textColor,
    this.subColor,
    this.oversize = false,
    this.subIsIndicatorName = false,
    this.subIsNavSub = false,
  });
}

// ===== 数值格式化（1:1 uni-app truncateNumber/formatPlainMoney 系列：截断不四舍五入）=====

double? _truncate(num? value, [int digits = 2]) {
  if (value == null) return null;
  final num = value.toDouble();
  if (num.isNaN || num.isInfinite) return null;
  final factor = math.pow(10, digits).toDouble();
  final abs = num.abs();
  // 1:1 uni-app：absoluteValue + Number.EPSILON * max(1, abs)
  const eps = 2.220446049250313e-16;
  final adjusted = abs + eps * math.max(1, abs);
  return num.sign * ((adjusted * factor).truncate() / factor);
}

String _plain(num? value, [int digits = 2]) {
  final t = _truncate(value, digits);
  if (t == null) return '0.00';
  return t.toStringAsFixed(digits);
}

String _plainSigned(num? value, [int digits = 2]) {
  final t = _truncate(value, digits);
  if (t == null) return '0.00';
  return '${t > 0 ? '+' : ''}${t.toStringAsFixed(digits)}';
}

String? _nullablePlain(num? value, [int digits = 2]) {
  final t = _truncate(value, digits);
  return t?.toStringAsFixed(digits);
}

String? _nullableSigned(num? value, [int digits = 2]) {
  final t = _truncate(value, digits);
  if (t == null) return null;
  return '${t > 0 ? '+' : ''}${t.toStringAsFixed(digits)}';
}

/// 构建一行所有可见单元格 — 1:1 uni-app demoDisplayRows 的 cells 组装
/// [singleLine] 简洁/极简模式只渲染主行（副行置空）
List<HoldingCellData> buildHoldingCells(
  PositionItem item,
  List<PositionColumnDef> columns,
  PositionState state,
  bool isDark,
) {
  final hideHoldAmount = state.hideHoldAmount;
  final hideIncomeAmount = state.hideIncomeAmount;
  final hideIncomeRate = state.hideIncomeRate;
  final cells = <String, HoldingCellData>{};

  HoldingCellData make(
    PositionColumnDef col,
    String text,
    String subText, {
    Color? textColor,
    Color? subColor,
    String subPrefix = '',
    bool showEmptySub = false,
    bool oversize = false,
    bool subIsIndicatorName = false,
    bool subIsNavSub = false,
  }) {
    return HoldingCellData(
      key: col.key,
      keySlug: col.keySlug,
      text: text,
      subText: subText,
      subPrefix: subPrefix,
      showEmptySub: showEmptySub,
      textColor: textColor,
      subColor: subColor,
      oversize: oversize,
      subIsIndicatorName: subIsIndicatorName,
      subIsNavSub: subIsNavSub,
    );
  }

  for (final col in columns) {
    switch (col.key) {
      case 'dayProfit':
        // TODO(lock): 当日收益解锁（dayProfitLocked）未移植，锁定态整列锁图标+「解锁」入口待补
        cells[col.key] = make(
          col,
          hideIncomeAmount ? '******' : _plainSigned(item.dayProfit),
          hideIncomeRate ? '******' : '${_plainSigned(item.dayChangeRatio)}%',
          textColor: profitColor(item.dayProfit, isDark),
          subColor: profitColor(item.dayChangeRatio, isDark),
        );
      case 'indicator':
        final indicator = item.firstIndicator;
        final ratio = indicator?.changeRatio;
        cells[col.key] = make(
          col,
          ratio == null ? '' : '${_plainSigned(ratio)}%',
          indicator == null ? '' : item.firstIndicatorName,
          textColor: ratio == null ? null : profitColor(ratio, isDark),
          subColor: isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87),
          showEmptySub: indicator == null,
          subIsIndicatorName: true,
        );
      case 'holdProfit':
        cells[col.key] = make(
          col,
          hideIncomeAmount ? '******' : _plainSigned(item.holdProfit),
          hideIncomeRate ? '******' : '${_plainSigned(item.holdChangeRatio)}%',
          textColor: profitColor(item.holdProfit, isDark),
          subColor: profitColor(item.holdChangeRatio, isDark),
          oversize: item.holdProfit.abs() >= 100000,
        );
      case 'latestNav':
        final rate = item.latestChgRateOrNull;
        final nav = _nullablePlain(item.latestPrice?.latestPrice, 4);
        final prefix = item.isQdii ? item.navDateLabel : '';
        cells[col.key] = make(
          col,
          rate == null
              ? ''
              : (hideIncomeRate ? '******' : '${_plainSigned(rate)}%'),
          nav ?? '',
          textColor: rate == null ? null : profitColor(rate, isDark),
          subColor: isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87),
          subPrefix: prefix,
          showEmptySub: nav == null && prefix.isEmpty,
          subIsNavSub: true,
        );
      case 'dayChangeRatio':
        cells[col.key] = make(
          col,
          '${_plainSigned(item.dayChangeRatio)}%',
          '',
          textColor: profitColor(item.dayChangeRatio, isDark),
        );
      case 'topHoldingsAvgChangeRate':
        final rate = item.topHoldingsAvgChangeRate;
        final text = _nullableSigned(rate);
        cells[col.key] = make(
          col,
          text == null ? '' : '$text%',
          '',
          textColor: rate == null ? null : profitColor(rate, isDark),
        );
      case 'weekProfit':
      case 'monthProfit':
        final profit = col.key == 'weekProfit' ? item.weekProfit : item.monthProfit;
        final rate =
            col.key == 'weekProfit' ? item.weekProfitRate : item.monthProfitRate;
        if (profit == null && rate == null) {
          cells[col.key] = make(col, '', '');
        } else {
          cells[col.key] = make(
            col,
            profit == null
                ? ''
                : (hideIncomeAmount ? '******' : _plainSigned(profit)),
            rate == null
                ? ''
                : (hideIncomeRate ? '******' : '${_nullableSigned(rate)}%'),
            textColor: profitColor(profit ?? rate, isDark),
            subColor: profitColor(rate ?? profit, isDark),
            showEmptySub: rate == null,
          );
        }
      case 'yearProfitRate':
        final rate = item.yearProfitRate;
        final profit = item.yearProfit;
        if (rate == null && profit == null) {
          cells[col.key] = make(col, '', '');
        } else {
          final rateText = _nullableSigned(rate);
          cells[col.key] = make(
            col,
            rate == null
                ? ''
                : (hideIncomeRate ? '******' : '$rateText%'),
            profit == null
                ? ''
                : (hideIncomeAmount ? '******' : _plainSigned(profit)),
            textColor: profitColor(rate ?? profit, isDark),
            subColor: profitColor(profit ?? rate, isDark),
            showEmptySub: profit == null,
          );
        }
      case 'marketValue':
        cells[col.key] = make(
          col,
          hideHoldAmount ? '******' : _plain(item.marketValue),
          '',
        );
      case 'holdingRatio':
        final ratio = item.holdingRatio;
        cells[col.key] = make(
          col,
          ratio == null ? '' : '${_plain(ratio)}%',
          '',
        );
      case 'holdQuantity':
        final quantity = item.holdQuantityNum;
        cells[col.key] = make(
          col,
          quantity == null
              ? ''
              : (hideHoldAmount ? '******' : _plain(quantity)),
          '',
        );
      case 'holdCostAmount':
        final cost = item.holdCostAmountNum;
        cells[col.key] = make(
          col,
          cost == null ? '' : (hideHoldAmount ? '******' : _plain(cost)),
          '',
        );
      case 'holdDay':
        final days = item.holdDay;
        cells[col.key] = make(col, days == null ? '' : '$days天', '');
      case 'breakEvenRate':
        final rate = item.breakEvenRate;
        cells[col.key] = make(
          col,
          rate == null ? '' : '+${_plain(rate)}%',
          '',
          textColor: (rate == null || rate == 0)
              ? null
              : profitColor(rate, isDark),
        );
    }
  }
  // 按列顺序输出；简洁/极简模式副行置空（模板自然不渲染）
  final singleLine = state.tableMode != TableShowMode.normal;
  return columns.map((col) {
    final cell = cells[col.key]!;
    if (!singleLine) return cell;
    return HoldingCellData(
      key: cell.key,
      keySlug: cell.keySlug,
      text: cell.text,
      textColor: cell.textColor,
      oversize: cell.oversize,
    );
  }).toList();
}

/// 左固定列单元格 — 1:1 复刻 .demo-fixed-row（名称 + 副信息行）
class PositionHoldingFixedCell extends StatelessWidget {
  final PositionItem item;
  final int index;
  final bool isDark;
  final bool isMinimal; // 极简模式只显示名称一行
  final bool isLast;
  final bool isSelected;
  final bool hideHoldAmount;
  final bool hideFundName;
  final bool showFundCode;
  final bool showHoldingAmount;
  final PositionFontScale fontScale; // 列表字体档位（大号/标准）
  final VoidCallback onTap;
  final void Function(Offset globalTopLeft, double height) onLongPress;

  static const double rowHeight = 55; // 110rpx

  const PositionHoldingFixedCell({
    super.key,
    required this.item,
    required this.index,
    required this.isDark,
    required this.isMinimal,
    required this.isLast,
    required this.isSelected,
    required this.hideHoldAmount,
    required this.hideFundName,
    required this.showFundCode,
    required this.showHoldingAmount,
    this.fontScale = PositionFontScale.large,
    required this.onTap,
    required this.onLongPress,
  });

  /// 从 PositionState 派生隐私标志的便捷构造参数组
  static ({bool hold, bool income, bool rate, bool name}) hideFlagsOf(
    PositionState state,
  ) => (
    hold: state.hideHoldAmount,
    income: state.hideIncomeAmount,
    rate: state.hideIncomeRate,
    name: state.hideFundName,
  );

  @override
  Widget build(BuildContext context) {
    final rowBg = isSelected
        ? (isDark ? const Color(0xFF2A2C31) : const Color(0xFFF1F1F1))
        : (isDark ? const Color(0xFF202125) : Colors.white);
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
        height: rowHeight,
        padding: const EdgeInsets.only(left: 16, right: 5), // 32rpx / 10rpx
        decoration: BoxDecoration(
          color: rowBg,
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: separatorColor, width: 0.5)),
        ),
        child: isMinimal ? _buildNameOnly() : _buildNameWithSub(),
      ),
    );
  }

  /// 极简模式：名称单行
  Widget _buildNameOnly() {
    return Align(
      alignment: Alignment.centerLeft,
      child: _nameText(),
    );
  }

  Widget _buildNameWithSub() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _nameText(),
        const SizedBox(height: 6), // margin-top 12rpx
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // 「已更新」徽章（1:1 uni-app isLatestNavItem）
            if (item.isLatestNav)
              Container(
                margin: const EdgeInsets.only(right: 4), // gap 8rpx
                padding: const EdgeInsets.symmetric(
                  horizontal: 3, // 6rpx
                  vertical: 0.5, // 1rpx
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2), // 4rpx
                  color: isDark
                      ? const Color(0x24E05665) // rgba(224,86,101,0.14)
                      : const Color(0x0AE05665), // rgba(224,86,101,0.04)
                ),
                child: Text(
                  '已更新',
                  style: AppTextStyles.cn(
                    fontScale.badge, // 18rpx（标准档 14rpx）
                    color: const Color(0xFFE05665),
                    height: 1,
                  ),
                ),
              ),
            // 表头管理：showFundCode → 基金代码；否则 showHoldingAmount → 持有金额
            if (showFundCode)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  hideFundName
                      ? '******'
                      : (item.symbolCode.isNotEmpty ? item.symbolCode : '--'),
                  style: AppTextStyles.num(
                    fontScale.nameSub, // 21rpx（标准档 19rpx）
                    color: isDark
                        ? const Color(0xFF9297A1)
                        : const Color(0xFF77798B),
                    height: 1,
                  ),
                ),
              )
            else if (showHoldingAmount)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '￥${hideHoldAmount ? '******' : _plain(item.marketValue)}',
                  style: AppTextStyles.num(
                    fontScale.nameSub, // 21rpx（标准档 19rpx）
                    color: isDark
                        ? const Color(0xFF9297A1)
                        : const Color(0xFF77798B),
                    height: 1,
                  ),
                ),
              ),
            // 昨日净值日期
            if (item.isYesterday) ...[
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  item.latestTimeLabel,
                  style: AppTextStyles.num(
                    fontScale.yesterday, // 20rpx（标准档 16rpx）
                    color: isDark
                        ? const Color(0xFF8F949D)
                        : const Color(0xFF77798B),
                    height: 1,
                  ),
                ),
              ),
            ],
            // 定投徽章
            if (item.hasDcaPlan)
              Container(
                margin: const EdgeInsets.only(right: 4),
                constraints: const BoxConstraints(minWidth: 14), // 28rpx
                height: 14,
                padding: const EdgeInsets.symmetric(horizontal: 2.5), // 5rpx
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.5), // 5rpx
                  color: isDark
                      ? const Color(0x2E4A90FF) // rgba(74,144,255,0.18)
                      : const Color(0x1F347CFF), // rgba(52,124,255,0.12)
                ),
                alignment: Alignment.center,
                child: Text(
                  '定',
                  style: AppTextStyles.cn(
                    fontScale.badge, // 18rpx（标准档 14rpx）
                    color: isDark
                        ? const Color(0xFF6EA8FF)
                        : const Color(0xFF347CFF),
                    weight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
            // 笔记图标
            if (item.hasNote)
              const Icon(AppIcons.note, size: 11, color: Color(0xFFE15665)),
          ],
        ),
      ],
    );
  }

  Widget _nameText() {
    return Text(
      hideFundName ? '******' : item.shortName,
      style: AppTextStyles.cn(
        fontScale.nameMain, // 28rpx（标准档 26rpx）
        color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF23283C),
        weight: FontWeight.w500,
        height: 1.2,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 右侧横滑区单元格 — 1:1 复刻 .demo-right-cell
class PositionHoldingCell extends StatelessWidget {
  final HoldingCellData cell;
  final int rowIndex;
  final bool isDark;
  final bool singleLine;
  final PositionFontScale fontScale;

  const PositionHoldingCell({
    super.key,
    required this.cell,
    required this.rowIndex,
    required this.isDark,
    required this.singleLine,
    this.fontScale = PositionFontScale.large,
  });

  @override
  Widget build(BuildContext context) {
    final placeholderColor = const Color(0xFFC3C8D1); // hsw-placeholder
    return Container(
      key: Key('position-row-${cell.keySlug}-$rowIndex'),
      width: 72, // 144rpx
      height: PositionHoldingFixedCell.rowHeight,
      padding: const EdgeInsets.only(right: 4), // padding-right 8rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (cell.text.isNotEmpty)
            Text(
              cell.text,
              style: AppTextStyles.num(
                // 32rpx → 超档 28rpx（标准档 30rpx → 26rpx）
                cell.oversize ? fontScale.cellMainSmall : fontScale.cellMain,
                color: cell.textColor ?? positionProfitNeutralColor(isDark),
                weight: FontWeight.w500,
                height: 1,
              ),
              maxLines: 1,
            )
          else
            Text(
              '--',
              style: AppTextStyles.num(
                fontScale.placeholder, // 28rpx（标准档 24rpx）
                color: placeholderColor,
                height: 1,
              ),
            ),
          if (!singleLine) ...[
            if (cell.subText.isNotEmpty || cell.subPrefix.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6), // margin-top 12rpx
                child: _buildSub(),
              )
            else if (cell.showEmptySub)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '--',
                  style: AppTextStyles.num(
                    fontScale.placeholderSub, // 20rpx（标准档 16rpx）
                    color: placeholderColor,
                    height: 1,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSub() {
    if (cell.subIsIndicatorName) {
      // 板块名：18rpx，≥8 字降 16rpx（列宽 144rpx 下 18rpx 只能放 7 字；两档相同）
      final name = cell.subText;
      return Text(
        name,
        style: AppTextStyles.cn(
          name.length >= 8 ? fontScale.indicatorNameXl : fontScale.indicatorName,
          color: cell.subColor,
          height: 1,
        ),
        maxLines: 1,
        textAlign: TextAlign.right,
      );
    }
    if (cell.subIsNavSub) {
      // 净值副行：[QDII 日期前缀 18rpx] 净值 4 位小数
      return Text.rich(
        TextSpan(children: [
          if (cell.subPrefix.isNotEmpty)
            TextSpan(
              text: cell.subPrefix,
              style: AppTextStyles.num(
                fontScale.navDate, // 18rpx（标准档 14rpx）
                color: cell.subColor,
                height: 1,
              ),
            ),
          if (cell.subPrefix.isNotEmpty) const TextSpan(text: ' '), // margin-right 6rpx
          TextSpan(
            text: cell.subText,
            style: AppTextStyles.num(fontScale.cellSub, color: cell.subColor, height: 1),
          ),
        ]),
        maxLines: 1,
        textAlign: TextAlign.right,
      );
    }
    return Text(
      cell.subText,
      style: AppTextStyles.num(
        fontScale.cellSub, // 22rpx（标准档 20rpx）
        color: cell.subColor ?? positionProfitNeutralColor(isDark),
        height: 1,
      ),
      maxLines: 1,
      textAlign: TextAlign.right,
    );
  }
}
