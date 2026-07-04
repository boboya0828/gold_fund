import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/text_styles.dart';
import '../../position/position_provider_types.dart'
    show PositionState, AssetVisibleMode;
import '../../../features/position/providers/position_provider.dart'
    show positionProvider;
import '../../../core/utils/number_format.dart' show formatThousands;
import 'position_profit_color.dart';

/// 资产总览卡片 — 1:1 复刻 .asset-card
class PositionAssetCard extends ConsumerWidget {
  final PositionState state;
  final bool isDark;

  const PositionAssetCard({
    super.key,
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.isLoggedIn) return const SizedBox.shrink();

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
    final showMoney = state.visibleMode == AssetVisibleMode.showAll;
    final showProfit = state.visibleMode != AssetVisibleMode.hideProfit;

    return Container(
      key: const Key('position-asset-card'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      style: AppTextStyles.cn(11, color: labelColor, height: 1),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () =>
                          ref.read(positionProvider.notifier).toggleVisible(),
                      child: Icon(
                        state.visibleMode == AssetVisibleMode.showAll
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 15,
                        color: mutedIconColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  showMoney
                      ? formatThousands(state.totalMarketValue) // 千分位, 1:1 uni-app formatMoney
                      : '******',
                  style: AppTextStyles.num(
                    20,
                    color: isDark
                        ? const Color(0xFFA7ADB8)
                        : const Color(0xFF333333),
                    height: 1,
                  ),
                ),
              ],
            ),
            // ===== 右侧: 当日总收益 =====
            GestureDetector(
              onTap: () => context.push('/user/curve'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      if (state.showRatioTip && state.refreshTime != null)
                        Container(
                          margin: const EdgeInsets.only(right: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            // 源码 .newDate: light rgba(224,86,101,0.098) / dark rgba(224,86,101,0.16)
                            color: isDark
                                ? const Color(0x29E05665)
                                : const Color(0x19E05665),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            state.refreshTime!,
                            style: AppTextStyles.cn(
                              12,
                              // light #FF4D5D / dark #E05665
                              color: isDark
                                  ? const Color(0xFFE05665)
                                  : positionProfitUpColor(),
                              weight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ),
                      Text(
                        '当日总收益',
                        style: AppTextStyles.cn(
                          11,
                          color: labelColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.chevron_right,
                        size: 12,
                        color: subtleIconColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Text(
                        showProfit
                            ? _formatSigned(state.totalDayProfit)
                            : '******',
                        style: AppTextStyles.num(
                          17,
                          color: profitColor(state.totalDayProfit, isDark),
                          height: 1,
                        ),
                      ),
                      if (state.showRatioTip) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${_formatSigned(state.totalDayChangeRatio)}%',
                          style: AppTextStyles.cn(
                            11,
                            color: profitColor(
                              state.totalDayChangeRatio,
                              isDark,
                            ),
                            height: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
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
}
