import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 黄金/白银涨跌幅徽章 — 1:1 复刻 uni-app .cardtop-rate + up/down-animation
///
/// 动画作用在**涨跌幅徽章**(非整张卡片)：价格变动时 0.5s 背景闪烁，
/// 20% 处到达峰值再回落 (对齐 keyframes upBackgroundAnimation/downBackgroundAnimation)。
///   浅涨 base #FEF5F8 + 红叠加 2%→8%(20%)→2%；浅跌 base #F4FAFB + 绿；
///   深涨 #322329→#3B2930→#322329；深跌 #22302E→#293A37→#22302E。
/// 徽章静态底：浅涨 #fff1f4 / 浅跌 #eef8f6 / 深涨 #2A1E23 / 深跌 #1C2827。
class MetalRateBadge extends StatefulWidget {
  final bool isUp;
  final bool isDark;
  final double price; // 用于检测价格变动触发动画
  final String changeText; // 涨跌额
  final String rateText; // 涨跌幅
  final Color textColor; // 文字/图标色

  const MetalRateBadge({
    super.key,
    required this.isUp,
    required this.isDark,
    required this.price,
    required this.changeText,
    required this.rateText,
    required this.textColor,
  });

  @override
  State<MetalRateBadge> createState() => _MetalRateBadgeState();
}

class _MetalRateBadgeState extends State<MetalRateBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Color?> _bg;
  double _prevPrice = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _prevPrice = widget.price;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bg = AlwaysStoppedAnimation(_restBg);
  }

  Color get _restBg => widget.isDark
      ? (widget.isUp ? AppColors.metalUpBgDark : AppColors.metalDownBgDark)
      : (widget.isUp ? AppColors.metalUpBgLight : AppColors.metalDownBgLight);

  Color get _peakBg {
    if (widget.isDark) {
      // 深色 keyframe 峰值为实色
      return widget.isUp ? AppColors.flashUpPeakDark : AppColors.flashDownPeakDark;
    }
    // 浅色：8% 红/绿 叠加在徽章底上 (≈ base #FEF5F8/#F4FAFB)
    final overlay = widget.isUp ? AppColors.flashUpPeak : AppColors.flashDownPeak;
    return Color.alphaBlend(overlay, _restBg);
  }

  @override
  void didUpdateWidget(MetalRateBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.price != _prevPrice && _initialized) {
      _triggerFlash();
    }
    _prevPrice = widget.price;
    _initialized = true;
  }

  void _triggerFlash() {
    final rest = _restBg;
    final peak = _peakBg;
    // rest → peak(20% ease-in) → rest(80% ease-out)，总时长 500ms
    _bg = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(begin: rest, end: peak)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: peak, end: rest)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 80,
      ),
    ]).animate(_controller);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 非动画态始终用当前静态底(避免 isUp 翻转后残留旧色)
        final bg = _controller.isAnimating ? (_bg.value ?? _restBg) : _restBg;
        return Container(
          width: 110, // 220rpx
          height: 23, // 46rpx
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.changeText,
            style: AppTextStyles.cn(12, color: widget.textColor, weight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Text(
            widget.rateText,
            style: AppTextStyles.cn(12, color: widget.textColor, weight: FontWeight.w600),
          ),
          const SizedBox(width: 4), // gap 8rpx
          Image.asset(
            widget.isUp ? 'assets/images/img/upico.png' : 'assets/images/img/down.png',
            width: 8, // 16rpx
            height: 9, // 18rpx
          ),
        ],
      ),
    );
  }
}
