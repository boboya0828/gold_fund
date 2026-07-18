import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 盈亏分析统计卡 — 1:1 复刻 uni-app curve.vue `.statistics`
/// 总资产/本金 | 总持仓收益/收益率 + 今日收益/累计收益 mini 卡
class CurveStatsCard extends StatelessWidget {
  final bool isDark;
  final bool amountHidden;
  final double totalMarketValue;
  final double principal;
  final double totalProfit;
  final double totalProfitRatio;
  final double todayProfit;
  final double todayProfitRatio;
  final VoidCallback onToggleHidden;

  const CurveStatsCard({
    super.key,
    required this.isDark,
    required this.amountHidden,
    required this.totalMarketValue,
    required this.principal,
    required this.totalProfit,
    required this.totalProfitRatio,
    required this.todayProfit,
    required this.todayProfitRatio,
    required this.onToggleHidden,
  });

  static const _hiddenText = '******';

  Color _riseFallColor(double value) {
    final rise = isDark ? AppColors.upColor : const Color(0xFFE45A6F);
    final fall = isDark ? const Color(0xFF10B4A1) : const Color(0xFF16B85F);
    return value >= 0 ? rise : fall;
  }

  String _fmtAmount(double v) => amountHidden ? _hiddenText : v.toStringAsFixed(2);

  String _fmtSigned(double v) {
    if (amountHidden) return _hiddenText;
    return '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}';
  }

  String _fmtPercent(double v) {
    if (amountHidden) return _hiddenText;
    return '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFB7AEAB);
    final subColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF8F7E76);
    final primaryText = isDark ? AppColors.darkText : const Color(0xFF4C250C);

    return Container(
      height: 216, // 432rpx
      margin: const EdgeInsets.symmetric(horizontal: 16), // mr-4 ml-4
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 40rpx 20rpx
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF9F7), Color(0xFFFFFFFF)],
              ),
        color: isDark ? AppColors.darkSurface : null,
        borderRadius: BorderRadius.circular(10), // 20rpx
      ),
      child: Column(
        children: [
          // ===== statistics-top =====
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 15), // 30rpx
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 总资产
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text('总资产(元)', style: AppTextStyles.cn(11, color: labelColor)),
                            const SizedBox(width: 4), // 8rpx
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onToggleHidden,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  amountHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 16,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C644D),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9), // 18rpx
                        Text(
                          _fmtAmount(totalMarketValue),
                          style: AppTextStyles.num(23, color: primaryText, weight: FontWeight.w700, height: 1.1),
                        ),
                        const SizedBox(height: 9), // 18rpx
                        Text('本金 ${_fmtAmount(principal)}', style: AppTextStyles.cn(10, color: subColor)),
                      ],
                    ),
                  ),
                  // 分割线
                  Container(
                    width: 1,
                    margin: const EdgeInsets.fromLTRB(4, 15, 4, 10), // 30rpx 8rpx 20rpx 8rpx
                    color: isDark ? const Color(0xFF464749) : const Color(0xFFEEE4E1),
                  ),
                  // 总持仓收益
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 19), // text-indent 38rpx
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('总持仓收益(元)', style: AppTextStyles.cn(11, color: labelColor)),
                          const SizedBox(height: 9),
                          Text(
                            _fmtSigned(totalProfit),
                            style: AppTextStyles.num(23, color: _riseFallColor(totalProfit), weight: FontWeight.w700, height: 1.1),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            _fmtPercent(totalProfitRatio),
                            style: AppTextStyles.num(10, color: _riseFallColor(totalProfitRatio)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ===== statistics-bottom =====
          Padding(
            padding: const EdgeInsets.only(top: 20), // 40rpx
            child: SizedBox(
              height: 78, // 156rpx
              child: Row(
                children: [
                  Expanded(
                    child: _MiniCard(
                      isDark: isDark,
                      title: '今日收益',
                      value: _fmtSigned(todayProfit),
                      rate: _fmtPercent(todayProfitRatio),
                      valueColor: _riseFallColor(todayProfit),
                      rateColor: _riseFallColor(todayProfitRatio),
                    ),
                  ),
                  const SizedBox(width: 20), // gap 40rpx
                  Expanded(
                    child: _MiniCard(
                      isDark: isDark,
                      title: '累计收益',
                      value: _fmtSigned(totalProfit),
                      rate: _fmtPercent(totalProfitRatio),
                      valueColor: _riseFallColor(totalProfit),
                      rateColor: _riseFallColor(totalProfitRatio),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String value;
  final String rate;
  final Color valueColor;
  final Color rateColor;

  const _MiniCard({
    required this.isDark,
    required this.title,
    required this.value,
    required this.rate,
    required this.valueColor,
    required this.rateColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 13, 11, 12), // 26rpx 22rpx 24rpx
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : const Color(0xFFFCF6F6),
        borderRadius: BorderRadius.circular(5), // 10rpx
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.cn(11, color: isDark ? AppColors.darkText : const Color(0xFF2C2321), weight: FontWeight.w600),
          ),
          const SizedBox(height: 10), // 20rpx
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.num(17, color: valueColor, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4), // 8rpx
              Text(rate, style: AppTextStyles.num(10, color: rateColor, weight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
