import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';
import '../../position/position_provider_types.dart' show PositionState;
import '../../../features/position/providers/position_provider.dart'
    show positionProvider;
import '../../../core/utils/number_format.dart'
    show formatThousands, addThousandSeparator;
import 'position_profit_color.dart';

/// 资产总览卡片 — 1:1 复刻 .asset-card
/// 普通 tab 与账户汇总 tab 共用（数据源不同由调用方传入）
class PositionAssetCard extends ConsumerWidget {
  final PositionState state;
  final bool isDark;

  /// 点击眼睛图标 → 打开「闭眼模式选择」弹窗 (1:1 uni-app openAssetVisibleModePopup)
  final VoidCallback onEyeTap;

  /// 汇总 tab 模式：数据源取 overviewStats，且收益数值受闭眼模式隐藏
  /// (1:1 uni-app .overview-summary-card)
  final bool overviewMode;

  const PositionAssetCard({
    super.key,
    required this.state,
    required this.isDark,
    required this.onEyeTap,
    this.overviewMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 游客也显示（0.00 / +0.00），1:1 uni-app asset-card 无 hasToken 条件
    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;
    final labelColor = isDark
        ? const Color(0xFFA7ADB8)
        : const Color(0xFF8D8B87);
    final mutedIconColor = isDark
        ? const Color(0xFFA7ADB8)
        : const Color(0xFF8E857E);
    final subtleIconColor = isDark
        ? const Color(0xFF777E8B)
        : const Color(0xFFc9c2bb);

    final totalMarketAmount = overviewMode
        ? state.overviewTotalMarketValue
        : state.totalMarketValue;
    final totalDayProfit =
        overviewMode ? state.overviewTotalDayProfit : state.totalDayProfit;
    final totalDayChangeRatio = overviewMode
        ? state.overviewTotalDayChangeRatio
        : state.totalDayChangeRatio;

    // 1:1 uni-app：主显 金额/收益率 由 showProfitRatio 决定；刷新后的 3 秒内
    // (isShowRatio) 在旁边小号显示另一项。
    // 普通 tab 收益不受闭眼模式隐藏；汇总 tab 收益归 hideIncomeAmount/hideIncomeRate。
    final mainIsRatio = state.showProfitRatio;
    final mainValue = mainIsRatio ? totalDayChangeRatio : totalDayProfit;
    final subValue = mainIsRatio ? totalDayProfit : totalDayChangeRatio;
    final mainHidden =
        overviewMode && (mainIsRatio ? state.hideIncomeRate : state.hideIncomeAmount);
    final subHidden =
        overviewMode && (mainIsRatio ? state.hideIncomeAmount : state.hideIncomeRate);
    final mainText = mainHidden
        ? '******'
        : mainIsRatio
            ? '${_formatSigned(totalDayChangeRatio)}%'
            : _formatSignedMoney(totalDayProfit);
    final subText = subHidden
        ? '******'
        : mainIsRatio
            ? _formatSignedMoney(totalDayProfit)
            : '${_formatSigned(totalDayChangeRatio)}%';

    return Container(
      key: const Key('position-asset-card'),
      padding: const EdgeInsets.symmetric(horizontal: 16), // 页面级 pr-4 pl-4 (1rem)
      decoration: BoxDecoration(color: cardBg),
      child: SizedBox(
        height: 65, // 130rpx
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ===== 左侧: 账户资产(元) =====
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(
                      '账户资产(元)',
                      // .asset-card__label 也是 numFamily（DIN 数字字体）
                      style: AppTextStyles.num(11, color: labelColor, height: 1),
                    ),
                    const SizedBox(width: 5), // gap 10rpx
                    GestureDetector(
                      onTap: onEyeTap,
                      child: Icon(
                        state.assetVisible == 0
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 15,
                        color: mutedIconColor,
                      ),
                    ),
                    // 市场魔方胶囊（公告 position=3 开启，汇总 tab 不显示）
                    if (state.marketCubeEnabled && !overviewMode) ...[
                      const SizedBox(width: 4), // margin-left 8rpx
                      GestureDetector(
                        onTap: () {
                          // 1:1 uni-app openPreMarketValuation → /pages/market/sub/cube
                          // Flutter 端尚无市场魔方页面，待移植后接入
                        },
                        child: Container(
                          key: const Key('position-market-cube-pill'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, // 16rpx
                            vertical: 2, // 4rpx
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE15665), // dark-market-toggle--on
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '市场魔方',
                            style: AppTextStyles.cn(
                              10, // 20rpx
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8), // margin-top 16rpx
                Text(
                  state.hideHoldAmount
                      ? '******'
                      : formatThousands(totalMarketAmount), // 千分位, 1:1 uni-app formatMoney
                  style: AppTextStyles.num(
                    20, // 40rpx
                    color: isDark
                        ? const Color(0xFFA7ADB8)
                        : const Color(0xFF333333),
                    height: 1,
                  ),
                ),
              ],
            ),
            // ===== 右侧: 当日总收益 + 统计箭头 =====
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // meta 行: [刷新时间/尚未开盘] [切换图标] [当日总收益]
                    Row(
                      children: [
                        if (state.showRatioTip && state.refreshTime != null)
                          Container(
                            margin: const EdgeInsets.only(right: 3), // gap 6rpx
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9, // 18rpx
                              vertical: 3, // 6rpx
                            ),
                            decoration: BoxDecoration(
                              // 源码 .newDate-item: light rgba(224,86,101,0.1) / dark rgba(224,86,101,0.16)
                              // --tip 变体(尚未开盘): light #FFF1F3 / dark rgba(224,86,101,0.16)
                              color: isDark
                                  ? const Color(0x29E05665)
                                  : (state.showNotOpened
                                      ? const Color(0xFFFFF1F3)
                                      : const Color(0x1AE05665)),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              state.showNotOpened
                                  ? '尚未开盘'
                                  : state.refreshTime!,
                              style: AppTextStyles.cn(
                                12, // 24rpx
                                // light #FF4D5D / tip #E05665 / dark #E05665(tip #EF6672)
                                color: state.showNotOpened
                                    ? (isDark
                                        ? const Color(0xFFEF6672)
                                        : const Color(0xFFE05665))
                                    : (isDark
                                        ? const Color(0xFFE05665)
                                        : const Color(0xFFFF4D5D)),
                                weight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                          ),
                        // 切换 金额/收益率 (icon-qiehuan2, 12px, 源码固定 #8d8b87)
                        GestureDetector(
                          onTap: () => ref
                              .read(positionProvider.notifier)
                              .toggleProfitDisplay(),
                          child: const Icon(
                            AppIcons.qiehuan2,
                            size: 12,
                            color: Color(0xFF8D8B87),
                          ),
                        ),
                        const SizedBox(width: 3), // gap 6rpx
                        GestureDetector(
                          onTap: () => ref
                              .read(positionProvider.notifier)
                              .toggleProfitDisplay(),
                          child: Text(
                            '当日总收益',
                            style: AppTextStyles.cn(
                              11,
                              color: labelColor,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9), // margin-top 18rpx
                    // 主收益 + (刷新后 3 秒内的) 副收益
                    Row(
                      children: [
                        Text(
                          mainText,
                          style: AppTextStyles.num(
                            18, // 36rpx (FIX-20260917-005)
                            color: profitColor(mainValue, isDark),
                            height: 1,
                          ),
                        ),
                        if (state.showRatioTip) ...[
                          const SizedBox(width: 6), // padding-left 12rpx
                          Text(
                            subText,
                            style: AppTextStyles.num(
                              12, // 24rpx (FIX-20260917-005)
                              color: profitColor(subValue, isDark),
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 4), // day-profit mr-2 (8rpx)
                // 统计箭头 → 收益曲线页 (1:1 uni-app hendlestatistics, size 16)
                GestureDetector(
                  onTap: () {
                    final bookId = state.currentBookId;
                    context.push(bookId != null
                        ? '/user/curve?bookId=$bookId'
                        : '/user/curve');
                  },
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: subtleIconColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSigned(double value) {
    if (value > 0) return '+${value.toStringAsFixed(2)}';
    return value.toStringAsFixed(2);
  }

  /// 1:1 uni-app formatSignedMoney: 千分位 + 2 位小数 + +/- 符号
  String _formatSignedMoney(double value) {
    final sign = value >= 0 ? '+' : '-';
    return sign + addThousandSeparator(value.abs().toStringAsFixed(2));
  }
}
