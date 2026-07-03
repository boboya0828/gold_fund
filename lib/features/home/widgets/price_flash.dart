import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 价格闪烁动画 — 1:1 复刻 uni-app up-animation / down-animation
class PriceFlashWrapper extends StatefulWidget {
  final Widget child;
  final double price;
  final bool isDark;

  const PriceFlashWrapper({
    super.key,
    required this.child,
    required this.price,
    required this.isDark,
  });

  @override
  State<PriceFlashWrapper> createState() => _PriceFlashWrapperState();
}

class _PriceFlashWrapperState extends State<PriceFlashWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _animation;
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
    _animation = ColorTween(begin: Colors.transparent, end: Colors.transparent)
        .animate(_controller);
  }

  @override
  void didUpdateWidget(PriceFlashWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.price != _prevPrice && _initialized) {
      _triggerFlash(widget.price > _prevPrice);
    }
    _prevPrice = widget.price;
    _initialized = true;
  }

  void _triggerFlash(bool isUp) {
    final dark = widget.isDark;
    final startColor = isUp
        ? (dark ? AppColors.flashUpStartDark : AppColors.flashUpStart)
        : (dark ? AppColors.flashDownStartDark : AppColors.flashDownStart);
    final peakColor = isUp
        ? (dark ? AppColors.flashUpPeakDark : AppColors.flashUpPeak)
        : (dark ? AppColors.flashDownPeakDark : AppColors.flashDownPeak);

    _animation = ColorTween(begin: startColor, end: peakColor).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
      ),
    );

    _controller
      ..reset()
      ..forward().then((_) {
        if (mounted) {
          _animation = ColorTween(begin: peakColor, end: startColor).animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
            ),
          );
          _controller
            ..reset()
            ..forward();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _animation.value,
            borderRadius: BorderRadius.circular(14),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
