import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';

/// 交易记录页辅助组件 — 1:1 复刻 uni-app pages/positionv1/trading-record.vue
/// 的类型 Tab 栏 (.type-tabs)、记录卡片 (.record-item) 与 z-paging 底部状态。

/// 交易类型色调 (record-type--rise/fall/neutral, 明暗同色)
enum TradingRecordTone { rise, fall, neutral }

Color tradingRecordToneColor(TradingRecordTone tone) {
  switch (tone) {
    case TradingRecordTone.rise:
      return const Color(0xFFE05665);
    case TradingRecordTone.fall:
      return const Color(0xFF00B26A);
    case TradingRecordTone.neutral:
      return const Color(0xFF8F949D);
  }
}

/// 类型 Tab 栏 — .type-tabs: 全部/买入/卖出/转换/定投
class TradingRecordTypeTabs extends StatelessWidget {
  final int activeValue;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const TradingRecordTypeTabs({
    super.key,
    required this.activeValue,
    required this.isDark,
    required this.onChanged,
  });

  /// uni-app tradeTypeTabs
  static const tabs = [
    (label: '全部', value: 0),
    (label: '买入', value: 1),
    (label: '卖出', value: 2),
    (label: '转换', value: 4),
    (label: '定投', value: 5),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202125) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC),
            width: 0.5, // 1rpx
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9), // 18rpx 12rpx
      child: Row(children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 5), // gap 10rpx
          Expanded(child: _tab(tabs[i])),
        ],
      ]),
    );
  }

  Widget _tab(({String label, int value}) tab) {
    final active = activeValue == tab.value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(tab.value),
      child: Container(
        height: 26, // 52rpx
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFFE05665).withValues(alpha: 0.16) : const Color(0xFFFFECEF))
              : (isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(13), // 999rpx 胶囊
        ),
        child: Text(
          tab.label,
          style: AppTextStyles.cn(
            12, // 24rpx
            weight: active ? FontWeight.w700 : FontWeight.w400,
            color: active
                ? const Color(0xFFE05665)
                : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8D8B87)),
          ),
        ),
      ),
    );
  }
}

/// 记录卡片 — .record-item
class TradingRecordItem extends StatelessWidget {
  final String typeText;
  final TradingRecordTone tone;
  final String displayName;
  final String dateText;
  final String amountText;
  final String effectiveText; // 空串则不显示
  final bool isDark;

  const TradingRecordItem({
    super.key,
    required this.typeText,
    required this.tone,
    required this.displayName,
    required this.dateText,
    required this.amountText,
    required this.effectiveText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final toneColor = tradingRecordToneColor(tone);
    final nameColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF23283C);
    final mutedColor = isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87);

    return Container(
      margin: const EdgeInsets.only(bottom: 8), // 16rpx
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20), // 40rpx 24rpx
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202125) : Colors.white,
        borderRadius: BorderRadius.circular(8), // 16rpx
        boxShadow: isDark
            ? null
            : const [
                // 0 8rpx 18rpx rgba(69,32,8,0.04)
                BoxShadow(color: Color(0x0A452008), blurRadius: 9, offset: Offset(0, 4)),
              ],
      ),
      child: Row(children: [
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // .record-type-wrap: padding-top 2rpx, margin-right 14rpx
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 7),
              child: Text(
                typeText,
                style: AppTextStyles.cn(14, weight: FontWeight.w700, color: toneColor, height: 1.3), // 28rpx lh36rpx
              ),
            ),
            // .record-info
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cn(14, color: nameColor, height: 1.3), // 28rpx lh36rpx
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 5), // margin-top 10rpx
                  child: Text(
                    dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cn(11, color: mutedColor, height: 1.27), // 22rpx lh28rpx
                  ),
                ),
              ]),
            ),
          ]),
        ),
        // .record-right: margin-left 20rpx, 右对齐
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              amountText,
              style: AppTextStyles.cn(15, color: toneColor, height: 1.13), // 30rpx lh34rpx
            ),
            if (effectiveText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5), // margin-top 10rpx
                child: Text(
                  effectiveText,
                  maxLines: 1,
                  style: AppTextStyles.cn(11, color: mutedColor, height: 1.3), // 22rpx
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// z-paging 底部加载状态
enum TradingRecordFooterState { idle, loading, noMore, error }

/// z-paging loading-more 区: 上拉加载更多 / 加载中... / 没有更多了 / 加载失败，点击重试
class TradingRecordFooter extends StatelessWidget {
  final TradingRecordFooterState state;
  final bool isDark;
  final VoidCallback? onRetry;

  const TradingRecordFooter({super.key, required this.state, required this.isDark, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87);
    final String text;
    switch (state) {
      case TradingRecordFooterState.idle:
        text = '上拉加载更多';
        break;
      case TradingRecordFooterState.loading:
        text = '加载中...';
        break;
      case TradingRecordFooterState.noMore:
        text = '没有更多了';
        break;
      case TradingRecordFooterState.error:
        text = '加载失败，点击重试';
        break;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: state == TradingRecordFooterState.error ? onRetry : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(child: Text(text, style: AppTextStyles.cn(12, color: color))), // 24rpx
      ),
    );
  }
}
