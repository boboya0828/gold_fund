import 'package:flutter/material.dart';
import '../../../core/models/symbol.dart';
import '../../../features/home/home_format.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 首页横向滚动指数项 — 1:1 复刻 uni-app .rollitem + up/down-animation
///
/// 价格变动时整项背景 500ms 闪烁 (20% 处达峰再回落):
///   浅涨 base #FEF5F8 + 红叠加 2%→8%→2%；浅跌 base #F4FAFB + 绿；
///   深涨 #322329→#3B2930→#322329；深跌 #22302E→#293A37→#22302E。
class MarketRollItem extends StatefulWidget {
  final SymbolInfo item;
  final bool isDark;
  final bool? flashUp; // 非 null 时触发一次闪烁 (值 = 方向)
  final VoidCallback? onTap;

  const MarketRollItem({
    super.key,
    required this.item,
    required this.isDark,
    this.flashUp,
    this.onTap,
  });

  @override
  State<MarketRollItem> createState() => _MarketRollItemState();
}

class _MarketRollItemState extends State<MarketRollItem>
    with SingleTickerProviderStateMixin {
  // zdj .uptext_color / .downtext_color (明暗同色)
  static const _upColor = Color(0xFFEA5D70);
  static const _downColor = Color(0xFF10B4A1);

  late final AnimationController _controller;
  Animation<Color?> _bg = const AlwaysStoppedAnimation(null);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant MarketRollItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // null → 非 null: 新一次闪烁; 方向翻转: 重新触发
    if (widget.flashUp != null &&
        (oldWidget.flashUp == null || oldWidget.flashUp != widget.flashUp)) {
      _triggerFlash(widget.flashUp!);
    }
  }

  void _triggerFlash(bool up) {
    final Animation<Color?> seq;
    if (widget.isDark) {
      final c0 = up ? AppColors.flashUpStartDark : AppColors.flashDownStartDark;
      final c1 = up ? AppColors.flashUpPeakDark : AppColors.flashDownPeakDark;
      seq = TweenSequence<Color?>([
        TweenSequenceItem(
          tween: ColorTween(begin: c0, end: c1)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 20,
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: c1, end: c0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 80,
        ),
      ]).animate(_controller);
    } else {
      // keyframes 浅色基底与条目自身底色无关: 涨 #FEF5F8 / 跌 #F4FAFB
      final base = up ? const Color(0xFFFEF5F8) : const Color(0xFFF4FAFB);
      final overlayStart =
          up ? AppColors.flashUpStart : AppColors.flashDownStart;
      final overlayPeak = up ? AppColors.flashUpPeak : AppColors.flashDownPeak;
      final start = Color.alphaBlend(overlayStart, base);
      final peak = Color.alphaBlend(overlayPeak, base);
      seq = TweenSequence<Color?>([
        TweenSequenceItem(
          tween: ColorTween(begin: start, end: peak)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 20,
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: peak, end: start)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 80,
        ),
      ]).animate(_controller);
    }
    _bg = seq;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    // trend = (rate ?? change ?? 0) < 0 ? 'down' : 'up' (flat 归 up)
    final trendDown = (item.changeRate ?? item.change ?? 0) < 0;
    final color = trendDown ? _downColor : _upColor;
    final restBg = isDark
        ? AppColors.darkSurface
        : (trendDown ? AppColors.lightRollDownBg : AppColors.lightRollUpBg);
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32) / 3; // uni-app: calc((100vw - 2rem) / 3)

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final bg = _controller.isAnimating ? (_bg.value ?? restBg) : restBg;
          return Container(
            width: itemWidth,
            decoration: BoxDecoration(color: bg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.name,
                    style: AppTextStyles.cn(12,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                        height: 1.0),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10), // 20rpx
                Text(homeFmtDecimal(item.latestPrice, 2, '--'),
                    style: AppTextStyles.num(18,
                        color: color, weight: FontWeight.w700)),
                const SizedBox(height: 5), // 10rpx
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(homeFmtSignedAmount(item.change ?? 0),
                      style: AppTextStyles.num(12,
                          color: color, weight: FontWeight.w500)),
                  const SizedBox(width: 3), // text padding 0 3rpx 双侧
                  Text(homeFmtSignedPercent(item.changeRate ?? 0),
                      style: AppTextStyles.num(12,
                          color: color, weight: FontWeight.w500)),
                  const SizedBox(width: 4.5), // padding 3rpx + icon margin-left 6rpx
                  Image.asset(
                      trendDown
                          ? 'assets/images/img/down.png'
                          : 'assets/images/img/upico.png',
                      width: 8.5, // 17rpx
                      height: 8.5),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
