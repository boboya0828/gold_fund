import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'market_models.dart';

/// 热门指数横滑卡片条 — 1:1 复刻 zdj-v1 pages/market/index.vue 的 .card-strip
///
/// - 容器 .card-strip：白底(暗 #202125)，圆角 10rpx(=5)，padding 24/24/20rpx
/// - .quote-list gap 20rpx(=10)，卡片宽 calc((100vw - 88rpx)/3) → (屏宽-44)/3，恰显示 3 张
/// - .quote-card：padding 18/12rpx，圆角 16rpx(=8)，边框 1rpx #E9E3E5(暗 #2B2D33)
///   涨背景 #FCF6F6 / 跌背景 #F4FAFB（暗 #282828 / #24282A）
/// - .quote-price 36rpx w600，上下 padding 5rpx(=2.5)；.quote-meta 22rpx gap 10rpx，numFamily
class QuoteStrip extends StatelessWidget {
  final bool isDark;
  final List<QuoteCardData> cards;
  final ValueChanged<QuoteCardData> onTap;
  const QuoteStrip({super.key, required this.isDark, required this.cards, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW - 44) / 3; // (100vw - 88rpx) / 3
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(5), // 10rpx
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10), // 24rpx 24rpx 20rpx
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < cards.length; i++) ...[
            _QuoteCard(card: cards[i], width: cardW, isDark: isDark, onTap: onTap),
            if (i != cards.length - 1) const SizedBox(width: 10), // gap 20rpx
          ],
        ]),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final QuoteCardData card;
  final double width;
  final bool isDark;
  final ValueChanged<QuoteCardData> onTap;
  const _QuoteCard({required this.card, required this.width, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final up = card.trend == 'up';
    final tc = up ? AppColors.upColor : kMarketDownColor;
    final bg = isDark
        ? (up ? const Color(0xFF282828) : const Color(0xFF24282A))
        : (up ? AppColors.lightRollUpBg : AppColors.lightRollDownBg);
    return GestureDetector(
      // goQuoteDetails: if (!item?.symbolId) return
      onTap: card.symbolId.isEmpty ? null : () => onTap(card),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6), // 18rpx 12rpx
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFE9E3E5)),
          borderRadius: BorderRadius.circular(8), // 16rpx
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cn(13, color: isDark ? AppColors.darkText : const Color(0xFF333333))),
          const SizedBox(height: 4), // column gap 8rpx
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5), // .quote-price padding 5rpx 0
            child: Text(card.price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.num(18, color: tc, weight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
                child: Text(card.change,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.num(11, color: tc))),
            const SizedBox(width: 5), // .quote-meta gap 10rpx
            Flexible(
                child: Text(card.rate,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.num(11, color: tc))),
            const SizedBox(width: 5),
            TrendArrow(up: up, color: tc),
          ]),
        ]),
      ),
    );
  }
}

/// 涨跌趋势小三角，对齐 .trend-arrow (border-left/right 6rpx, border-top/bottom 10rpx → 6×5)。
/// 不用 Icons.arrow_drop_up/down，因其内建留白偏大，在窄卡片内会挤出溢出。
class TrendArrow extends StatelessWidget {
  final bool up;
  final Color color;
  const TrendArrow({super.key, required this.up, required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(6, 5), painter: _TrendArrowPainter(up: up, color: color));
}

class _TrendArrowPainter extends CustomPainter {
  final bool up;
  final Color color;
  const _TrendArrowPainter({required this.up, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (up) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendArrowPainter oldDelegate) =>
      oldDelegate.up != up || oldDelegate.color != color;
}
