import 'package:flutter/material.dart';
import '../../../core/utils/screen_adapt.dart';

/// hero 区骨架屏 — 1:1 复刻 position-details.vue .hero-skeleton
/// 骨架只包 hero 卡（头 + 3 格 + 9 格），下方区块各有自己的加载/空态
class PositionDetailsHeroSkeleton extends StatefulWidget {
  final bool isDark;

  const PositionDetailsHeroSkeleton({super.key, required this.isDark});

  @override
  State<PositionDetailsHeroSkeleton> createState() =>
      _PositionDetailsHeroSkeletonState();
}

class _PositionDetailsHeroSkeletonState
    extends State<PositionDetailsHeroSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final base = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0EFF1);
    final highlight = isDark ? const Color(0xFF373A41) : const Color(0xFFF8F7F8);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final color = Color.lerp(base, highlight, _ctrl.value)!;
        return Container(
          padding: EdgeInsets.fromLTRB(15.sx, 14.sx, 15.sx, 13.sx), // 28rpx 30rpx 26rpx
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202125) : Colors.white,
            borderRadius: BorderRadius.circular(7.sx), // 14rpx
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _box(color, 160.sx, 16.sx),
            SizedBox(height: 6.sx),
            _box(color, 110.sx, 10.sx),
            SizedBox(height: 10.sx),
            Row(children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: 6.sx),
                Expanded(child: _box(color, double.infinity, 30.sx)),
              ],
            ]),
            SizedBox(height: 7.sx),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 7,
              crossAxisSpacing: 6,
              childAspectRatio: 1.9,
              children: [for (var i = 0; i < 9; i++) _box(color, double.infinity, double.infinity)],
            ),
          ]),
        );
      },
    );
  }

  Widget _box(Color color, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.sx), // 16rpx
      ),
    );
  }
}
