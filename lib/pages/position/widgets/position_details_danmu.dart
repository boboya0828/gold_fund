import 'dart:async';

import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import 'position_details_models.dart';

/// 持仓详情 — 弹幕层（覆盖在关联涨跌图上）
/// uni-app 对应: position-details.vue 的 .danmu-layer / .danmu-item / .danmu-report
class PositionDetailsDanmuLayer extends StatefulWidget {
  final List<PdDanmuItem> items;
  final bool isDark;
  final int renderKey;
  final ValueChanged<PdDanmuItem> onReport;

  const PositionDetailsDanmuLayer({
    super.key,
    required this.items,
    required this.isDark,
    required this.renderKey,
    required this.onReport,
  });

  @override
  State<PositionDetailsDanmuLayer> createState() => _PositionDetailsDanmuLayerState();
}

class _PositionDetailsDanmuLayerState extends State<PositionDetailsDanmuLayer> {
  static const _tops = <double>[13, 40, 67, 94, 121, 148]; // 26~296rpx / 2
  String? _activeId;
  Timer? _reportTimer;

  @override
  void dispose() {
    _reportTimer?.cancel();
    super.dispose();
  }

  void _handleTap(PdDanmuItem item) {
    if (_activeId == item.id) {
      _closeReport();
      return;
    }
    _reportTimer?.cancel();
    setState(() => _activeId = item.id);
    _reportTimer = Timer(const Duration(seconds: 3), _closeReport);
  }

  void _closeReport() {
    _reportTimer?.cancel();
    if (mounted) setState(() => _activeId = null);
  }

  Color _toneColor(String tone) {
    if (widget.isDark) {
      switch (tone) {
        case 'red':
          return const Color(0xFFFF8D96);
        case 'green':
          return const Color(0xFF60D6B3);
        case 'blue':
          return const Color(0xFF7FA6F9);
        case 'orange':
          return const Color(0xFFFFB86B);
        default:
          return const Color(0xFFB8BEC8);
      }
    }
    switch (tone) {
      case 'red':
        return const Color(0xFFF15A65);
      case 'green':
        return const Color(0xFF23A982);
      case 'blue':
        return const Color(0xFF3478F6);
      case 'orange':
        return const Color(0xFFFF9F43);
      default:
        return const Color(0xFF8A909C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xE632343A) : const Color(0xE0F7F7F7);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final children = <Widget>[];
      for (final item in widget.items) {
        final top = _tops[item.topIndex % _tops.length];
        children.add(_DanmuRunner(
          key: ValueKey('${widget.renderKey}-${item.id}'),
          item: item,
          top: top,
          laneWidth: width,
          bg: bg,
          color: _toneColor(item.tone),
          active: _activeId == item.id,
          onTap: () => _handleTap(item),
        ));
      }
      // 举报气泡（简化定位：固定在被点中弹幕所在行的上方）
      if (_activeId != null) {
        PdDanmuItem? item;
        for (final e in widget.items) {
          if (e.id == _activeId) {
            item = e;
            break;
          }
        }
        if (item != null) {
          final target = item;
          final top = (_tops[target.topIndex % _tops.length] - 28).clamp(2.0, 200.0);
          children.add(Positioned(
            left: 16,
            top: top,
            child: GestureDetector(
              onTap: () {
                widget.onReport(target);
                _closeReport();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), // 92x54rpx 近似
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF3A3E48) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)],
                ),
                child: Text('举报', style: AppTextStyles.cn(11, color: widget.isDark ? Colors.white : const Color(0xFF333333))),
              ),
            ),
          ));
        }
      }
      return Stack(fit: StackFit.expand, children: children);
    });
  }
}

class _DanmuRunner extends StatefulWidget {
  final PdDanmuItem item;
  final double top;
  final double laneWidth;
  final Color bg;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _DanmuRunner({
    super.key,
    required this.item,
    required this.top,
    required this.laneWidth,
    required this.bg,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  State<_DanmuRunner> createState() => _DanmuRunnerState();
}

class _DanmuRunnerState extends State<_DanmuRunner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.item.durationSec * 1000).round()),
    );
    if (widget.item.delaySec <= 0) {
      _controller.forward();
    } else {
      _delayTimer = Timer(Duration(milliseconds: (widget.item.delaySec * 1000).round()), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 估算文本宽度用于移出屏幕
    final estWidth = widget.item.text.length * 11.0 + 40;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final left = widget.laneWidth - (widget.laneWidth + estWidth) * t;
        return Positioned(
          left: left,
          top: widget.top,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              height: 19, // 38rpx
              constraints: const BoxConstraints(maxWidth: 210), // 420rpx
              padding: const EdgeInsets.symmetric(horizontal: 9), // 18rpx
              decoration: BoxDecoration(
                color: widget.bg,
                borderRadius: BorderRadius.circular(999),
                border: widget.active || widget.item.isOwn
                    ? Border.all(color: widget.color.withValues(alpha: 0.6), width: 0.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                widget.item.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cn(11, color: widget.color, height: 1.0),
              ),
            ),
          ),
        );
      },
    );
  }
}
