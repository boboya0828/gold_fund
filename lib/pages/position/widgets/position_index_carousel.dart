import 'dart:async';

import 'package:flutter/material.dart';
import '../../../features/position/providers/position_provider.dart'
    show IndexCarouselItem;
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';

/// 指数轮播条 — 1:1 复刻 components/index-carousel-bar.vue
/// fixed 悬浮在 tabbar 上方（本页 Stack 内 bottom:0），高 80rpx，白底，
/// 顶部 1rpx #F0F1F4（深 #2B2D33），圆角 24rpx（顶部），横向轮播指数行情条目。
/// mode=2 且多条时上下滚动（8s 间隔，0.6s 动画，末尾复制首条无缝循环）。
class PositionIndexCarousel extends StatefulWidget {
  final List<IndexCarouselItem> items;
  final int mode; // 1=静态首条 2=多条上下滚动
  final bool isDark;
  final ValueChanged<IndexCarouselItem> onSelect;

  /// 轮播间隔（源码默认 8000ms，宿主未传 interval 时的值）
  final Duration interval;

  const PositionIndexCarousel({
    super.key,
    required this.items,
    required this.mode,
    required this.isDark,
    required this.onSelect,
    this.interval = const Duration(seconds: 8),
  });

  @override
  State<PositionIndexCarousel> createState() => _PositionIndexCarouselState();
}

class _PositionIndexCarouselState extends State<PositionIndexCarousel> {
  PageController? _pageCtrl;
  Timer? _rollTimer;

  // 无有效 name 的条目直接丢弃（1:1 displayItems）
  List<IndexCarouselItem> get _displayItems =>
      widget.items.where((e) => e.name.trim().isNotEmpty).toList();

  bool get _isRolling => widget.mode == 2 && _displayItems.length > 1;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant PositionIndexCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.items != widget.items ||
        oldWidget.interval != widget.interval) {
      _setup();
    }
  }

  void _setup() {
    _rollTimer?.cancel();
    _rollTimer = null;
    if (_isRolling) {
      _pageCtrl ??= PageController();
      final interval = widget.interval < const Duration(seconds: 1)
          ? const Duration(seconds: 8)
          : widget.interval;
      _rollTimer = Timer.periodic(interval, (_) {
        if (!mounted || !(_pageCtrl?.hasClients ?? false)) return;
        final current = (_pageCtrl!.page ?? 0).round();
        if (current < _displayItems.length) {
          _pageCtrl!.animateToPage(current + 1,
              duration: const Duration(milliseconds: 600), curve: Curves.ease);
          // 滚到复制条后无动画跳回 0，无缝循环（对齐源码 650ms resetTimer）
          if (current + 1 == _displayItems.length) {
            Future.delayed(const Duration(milliseconds: 650), () {
              final ctrl = _pageCtrl;
              if (mounted && ctrl != null && ctrl.hasClients) ctrl.jumpToPage(0);
            });
          }
        }
      });
    } else {
      _pageCtrl?.dispose();
      _pageCtrl = null;
    }
  }

  @override
  void dispose() {
    _rollTimer?.cancel();
    _pageCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _displayItems;
    if (items.isEmpty) return const SizedBox.shrink();
    final isDark = widget.isDark;

    return Container(
      height: 40.sx, // 80rpx
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202125) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.sx)), // 24rpx
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0F1F4),
            width: 0.5,
          ),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, -1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _isRolling
          ? PageView.builder(
              controller: _pageCtrl,
              scrollDirection: Axis.vertical,
              physics: const NeverScrollableScrollPhysics(), // 源码仅自动轮播
              itemCount: items.length + 1, // 末尾复制首条
              itemBuilder: (_, i) =>
                  _Row(item: items[i < items.length ? i : 0], isDark: isDark, onTap: widget.onSelect),
            )
          : _Row(item: items.first, isDark: isDark, onTap: widget.onSelect),
    );
  }
}

/// 单条行情行：名称 + 价格 + 涨跌额 + 涨跌幅 + 方向箭头（或停牌状态文案）
class _Row extends StatelessWidget {
  final IndexCarouselItem item;
  final bool isDark;
  final ValueChanged<IndexCarouselItem> onTap;

  const _Row({required this.item, required this.isDark, required this.onTap});

  static const _upLight = Color(0xFFE15665);
  static const _downLight = Color(0xFF20B083);
  static const _upDark = Color(0xFFFF6B74);
  static const _downDark = Color(0xFF2ECF9A);

  int? get _trend {
    if (item.isSuspended || item.chgRate == null) return null;
    return item.chgRate! >= 0 ? 1 : -1;
  }

  Color? get _trendColor => switch (_trend) {
        1 => isDark ? _upDark : _upLight,
        -1 => isDark ? _downDark : _downLight,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final nameColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF1F2430);
    final subColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF5A5F6A);
    final arrowColor = isDark ? const Color(0xFF777E89) : const Color(0xFFB0B4BD);
    final trend = _trend;
    final trendColor = _trendColor;

    return GestureDetector(
      onTap: () => onTap(item),
      child: Container(
        height: 40.sx, // 80rpx
        padding: EdgeInsets.symmetric(horizontal: 12.sx), // 0 24rpx
        decoration: BoxDecoration(
          // 右侧渐变只服务涨跌区域：涨红跌绿，停牌/缺涨跌幅不显示
          gradient: trend == null
              ? null
              : LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: trend > 0
                      ? (isDark
                          ? const [Color(0x00FF6B74), Color(0x24FF6B74)]
                          : const [Color(0x00E15665), Color(0x14E15665)])
                      : (isDark
                          ? const [Color(0x002ECF9A), Color(0x242ECF9A)]
                          : const [Color(0x0020B083), Color(0x1720B083)]),
                  stops: const [0.52, 1.0],
                ),
        ),
        child: Row(children: [
          // 名称：max-width 36%，26rpx 500
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: (MediaQuery.of(context).size.width - 24.sx) * 0.36),
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cn(13.sx, color: nameColor, weight: FontWeight.w500),
            ),
          ),
          if (item.isSuspended) ...[
            Expanded(
              child: Text(
                _formatPrice(item.latestPrice),
                textAlign: TextAlign.right,
                style: AppTextStyles.num(13.sx, color: nameColor, weight: FontWeight.w500),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 6.sx), // padding-left 12rpx
              child: Text(item.statusText,
                  style: AppTextStyles.cn(12.sx, color: const Color(0xFF8A8F99))),
            ),
          ] else ...[
            // 价格（flex 右对齐，26rpx 500，涨跌色）
            Expanded(
              child: Text(
                _formatPrice(item.latestPrice),
                textAlign: TextAlign.right,
                style: AppTextStyles.num(13.sx,
                    color: trendColor ?? nameColor, weight: FontWeight.w500),
              ),
            ),
            // 涨跌额（108rpx 右对齐）
            SizedBox(
              width: 54.sx,
              child: Padding(
                padding: EdgeInsets.only(left: 4.sx), // margin-left 8rpx
                child: Text(
                  _formatChange(item.changeAmount),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.num(13.sx, color: trendColor ?? subColor),
                ),
              ),
            ),
            // 涨跌幅（90rpx 右对齐）
            SizedBox(
              width: 45.sx,
              child: Padding(
                padding: EdgeInsets.only(left: 4.sx),
                child: Text(
                  _formatRate(item.chgRate),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.num(13.sx, color: trendColor ?? subColor),
                ),
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.only(left: 6.sx), // margin-left 12rpx
            child: Icon(Icons.keyboard_arrow_up, size: 12, color: arrowColor),
          ),
        ]),
      ),
    );
  }

  static String _formatPrice(double? v) => v == null ? '--' : v.toStringAsFixed(2);
  static String _formatChange(double? v) =>
      v == null ? '--' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}';
  static String _formatRate(double? v) =>
      v == null ? '--' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
}
