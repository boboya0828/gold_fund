import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/number_format.dart'
    show formatThousands, addThousandSeparator;
import '../../../features/position/providers/position_provider.dart';
import '../../../shared/widgets/z_paging_refresh.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'position_profit_color.dart';

/// 账户汇总 tab 内容区 — 1:1 复刻 .overview-content
/// （资产卡由页面层渲染；本组件是 .overview-page 卡片列表 + 空态）
class PositionOverviewContent extends ConsumerWidget {
  final PositionState state;
  final bool isDark;

  /// 空态按钮：登录态走导入流程 (1:1 hendleSynchronization)，游客跳 /login
  final VoidCallback onSyncTap;

  const PositionOverviewContent({
    super.key,
    required this.state,
    required this.isDark,
    required this.onSyncTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageBg = isDark ? const Color(0xFF111315) : const Color(0xFFF4F4F5);
    final cards = state.overviewCards;

    return ColoredBox(
      color: pageBg,
      child: ZPagingRefresh(
        isDark: isDark,
        onRefresh: () => ref.read(positionProvider.notifier).refresh(),
        child: cards.isEmpty
            ? _buildEmpty(context)
            : Column(
                children: [
                  for (var i = 0; i < cards.length; i++)
                    _OverviewCard(
                      card: cards[i],
                      index: i,
                      isDark: isDark,
                      hideHoldAmount: state.hideHoldAmount,
                      hideIncomeAmount: state.hideIncomeAmount,
                      hideIncomeRate: state.hideIncomeRate,
                      onTap: () => _handleCardTap(context, ref, cards[i]),
                    ),
                  // .overview-list padding-bottom 140rpx（无指数轮播条）
                  const SizedBox(height: 70),
                ],
              ),
      ),
    );
  }

  void _handleCardTap(BuildContext context, WidgetRef ref, OverviewCard card) {
    final ok =
        ref.read(positionProvider.notifier).selectBookTabById(card.bookId);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('对应账户不存在，请刷新后重试'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 空态（含游客）— 1:1 .overview-state--empty（ndata 系列样式，按钮 margin-top 32rpx）
  Widget _buildEmpty(BuildContext context) {
    final tipColor = isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5, // min-height 50vh
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (!state.isLoggedIn) {
                context.push('/login');
              } else {
                onSyncTap();
              }
            },
            child: Container(
              margin: const EdgeInsets.only(top: 16), // overview-empty-action 32rpx
              width: 270, // max-width 540rpx
              height: 43, // 86rpx
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x29527AF8),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '导入我的持有基金',
                style: AppTextStyles.cn(
                  15,
                  color: Colors.white,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12), // ndata-tip margin-top 24rpx
          Text(
            '已支持支付宝、天天基金、腾讯理财通、雪球基金等平台的一键导入',
            style: AppTextStyles.cn(12, color: tipColor, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 11), // ndata-tip1 margin-top 22rpx
          Text(
            '养基助手应用仅用于数据同步模拟，不涉及任何真实交易',
            style: AppTextStyles.num(10, color: tipColor, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 单个汇总卡片 — 1:1 .overview-card
class _OverviewCard extends StatelessWidget {
  final OverviewCard card;
  final int index;
  final bool isDark;
  final bool hideHoldAmount;
  final bool hideIncomeAmount;
  final bool hideIncomeRate;
  final VoidCallback onTap;

  const _OverviewCard({
    required this.card,
    required this.index,
    required this.isDark,
    required this.hideHoldAmount,
    required this.hideIncomeAmount,
    required this.hideIncomeRate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEFF1);
    final bottomBorderColor =
        isDark ? const Color(0xFF2B2D33) : const Color(0xFFE7E7E9);
    final nameColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF3A3D48);
    final labelColor = isDark ? const Color(0xFF8F949D) : const Color(0xFF999BA4);
    final assetValueColor =
        isDark ? const Color(0xFFD7DAE0) : const Color(0xFF4D5878);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: Key('position-overview-card-$index'),
        margin: const EdgeInsets.only(bottom: 8), // margin-bottom 16rpx
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(
            top: BorderSide(color: borderColor, width: 0.5),
            bottom: BorderSide(color: bottomBorderColor, width: 0.5),
          ),
        ),
        child: Column(
          children: [
            // ===== 头部：图标 + 账本名 + 涨/跌家数 =====
            Container(
              height: 38, // 76rpx
              padding: const EdgeInsets.symmetric(horizontal: 15), // 0 30rpx
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Image.asset(
                          _bookIcon(card),
                          width: 20, // 40rpx
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(width: 20, height: 20),
                        ),
                        const SizedBox(width: 6), // margin-right 12rpx
                        Flexible(
                          child: Text(
                            card.bookName.isNotEmpty
                                ? card.bookName
                                : '账户${index + 1}',
                            style: AppTextStyles.cn(
                              14, // 28rpx
                              color: nameColor,
                              height: 1.4, // line-height 40rpx
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _countBadge(
                        Icons.arrow_upward,
                        const Color(0xFFFF4D5D),
                        card.riseCount,
                        positionProfitUpColor(),
                      ),
                      const SizedBox(width: 15), // gap 30rpx
                      _countBadge(
                        Icons.arrow_downward,
                        const Color(0xFF00B26A),
                        card.fallCount,
                        positionProfitDownColor(isDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ===== 中部：账户资产 + 迷你走势 =====
            Container(
              height: 71, // 142rpx
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 6), // 26rpx 30rpx 12rpx
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '账户资产',
                          style: AppTextStyles.cn(
                            12, // 24rpx
                            color: labelColor,
                            height: 1.33, // line-height 32rpx
                          ),
                        ),
                        const SizedBox(height: 4), // margin-top 8rpx
                        Text(
                          hideHoldAmount
                              ? '******'
                              : formatThousands(card.assetAmount),
                          style: AppTextStyles.num(
                            15, // 30rpx
                            color: assetValueColor,
                            weight: FontWeight.w600,
                            height: 1.33,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12), // column-gap 24rpx
                  SizedBox(
                    width: 165, // 330rpx
                    height: 46, // 92rpx
                    child: CustomPaint(
                      painter: _TrendPainter(
                        points: _trendPoints(card.trend),
                        color: card.dayProfit < 0
                            ? const Color(0xFF00B26A)
                            : const Color(0xFFFF5A67),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ===== 底部：持有收益 / 当日收益 =====
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 13), // 0 30rpx 26rpx
              child: Row(
                children: [
                  Expanded(
                    child: _profitBlock(
                      label: '持有收益',
                      value: card.holdingProfit,
                      rate: card.holdingProfitRate,
                      labelColor: labelColor,
                    ),
                  ),
                  const SizedBox(width: 25), // column-gap 50rpx
                  Expanded(
                    child: _profitBlock(
                      label: '当日收益',
                      value: card.dayProfit,
                      rate: card.dayProfitRate,
                      labelColor: labelColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 涨/跌家数 — 箭头 size 16 + 26rpx 500 数字（is-up/is-down 色）
  Widget _countBadge(IconData icon, Color iconColor, int count, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 1), // gap 2rpx
        Text(
          '$count',
          style: AppTextStyles.num(13, color: textColor, weight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _profitBlock({
    required String label,
    required double value,
    required double rate,
    required Color labelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.cn(12, color: labelColor, height: 1.33),
        ),
        const SizedBox(height: 4), // margin-top 8rpx
        Row(
          children: [
            Text(
              hideIncomeAmount ? '******' : _formatSignedMoney(value),
              style: AppTextStyles.num(
                14.5, // 29rpx
                color: profitColor(value, isDark),
                weight: FontWeight.w600,
                height: 1.38, // line-height 40rpx
              ),
            ),
            const SizedBox(width: 7), // gap 14rpx
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4, // 8rpx
                vertical: 1.5, // 3rpx
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3), // 6rpx
                color: rate >= 0
                    ? const Color(0x1AFF4D5D) // rgba(255,77,93,0.1)
                    : const Color(0x1A00B26A), // rgba(0,178,106,0.1)
              ),
              child: Text(
                hideIncomeRate ? '******' : '${_formatSignedMoney(rate)}%',
                style: AppTextStyles.num(
                  11, // 22rpx
                  color: profitColor(rate, isDark),
                  height: 1.36, // line-height 30rpx
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 账本图标（1:1 uni-app getOverviewBookIcon）
  String _bookIcon(OverviewCard card) {
    final key = '${card.iconKey} ${card.bookName}'.toLowerCase();
    if (key.contains('支付宝') ||
        key.contains('alipay') ||
        key.contains('zhifubao') ||
        key.contains('zfb')) {
      return 'assets/images/img/zfb.png';
    }
    if (key.contains('腾讯') ||
        key.contains('理财通') ||
        key.contains('tencent') ||
        key.contains('txlc')) {
      return 'assets/images/img/txlc.png';
    }
    if (key.contains('天天') || key.contains('tiantian') || key.contains('ttjj')) {
      return 'assets/images/img/ttjj.png';
    }
    return 'assets/images/img/zbmr.png';
  }

  String _formatSignedMoney(double value) {
    final sign = value >= 0 ? '+' : '-';
    return sign + addThousandSeparator(value.abs().toStringAsFixed(2));
  }

  /// 走势点归一化 — 1:1 uni-app getOverviewTrendPoints
  /// x: 9:30→0 … 15:00→240（剔除午休 11:30-13:00）；y: dayProfitRate 或 assetAmount
  List<Offset> _trendPoints(List<OverviewTrendPoint> trend) {
    if (trend.isEmpty) return const [];
    final useRate = trend.any((p) => p.dayProfitRate != null);
    const morningStart = 9 * 60 + 30;
    const lunchStart = 11 * 60 + 30;
    const lunchEnd = 13 * 60;
    const marketEnd = 15 * 60;
    const lunchDuration = lunchEnd - lunchStart;
    final points = <Offset>[];
    for (final p in trend) {
      int? minutes;
      final match = RegExp(r'T(\d{2}):(\d{2})').firstMatch(p.time);
      if (match != null) {
        minutes = int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
      } else if (p.timestamp > 0) {
        final date =
            DateTime.fromMillisecondsSinceEpoch(p.timestamp * 1000);
        minutes = date.hour * 60 + date.minute;
      }
      if (minutes == null) continue;
      if (minutes < morningStart || minutes > marketEnd) continue;
      if (minutes >= lunchStart && minutes < lunchEnd) continue;
      final value = useRate ? p.dayProfitRate : p.assetAmount;
      if (value == null) continue;
      final x = (minutes < lunchEnd
              ? minutes - morningStart
              : minutes - morningStart - lunchDuration)
          .toDouble();
      points.add(Offset(x, value));
    }
    return points;
  }
}

/// 迷你走势图 — 1:1 uni-app drawOverviewTrend 的 echarts 折线（无坐标轴）
class _TrendPainter extends CustomPainter {
  final List<Offset> points; // x: 0..240, y: 原始值
  final Color color;

  const _TrendPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const inset = 2.0; // echarts grid 4px@2x
    final values = points.map((p) => p.dy);
    var min = values.reduce((a, b) => a < b ? a : b);
    var max = values.reduce((a, b) => a > b ? a : b);
    if (min > 0) min = 0;
    if (max < 0) max = 0;
    final padding = (max - min) * 0.08;
    final pad = padding == 0 ? 0.1 : padding;
    min -= pad;
    max += pad;

    final drawW = size.width - inset * 2;
    final drawH = size.height - inset * 2;
    double px(double x) => inset + (x / 240) * drawW;
    double py(double y) => inset + (1 - (y - min) / (max - min)) * drawH;

    final path = Path()
      ..moveTo(px(points.first.dx), py(points.first.dy));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(px(points[i].dx), py(points[i].dy));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 0.75 // echarts lineStyle width 1.5@2x
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
