import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import '../../position/position_provider_types.dart' show FeedNoticeItem;

/// 滚动通知条 — 1:1 复刻 .feed-notice
/// （GET /asset/api/ScrollContent/current?slotCode=position_feed）
/// 高 80rpx，padding 0 24rpx，白底（深 #202125），顶部 1rpx 线 #f4f1ec（深 #2B2D33）
/// scrollType: 1=上下滚动（每 2s 逐条，0.3s）2=左右跑马灯 3=静止单行省略
///
/// 资金流通知条（.position-notice，SignalR SubscribeSectorFundFlow 驱动）本次不实现，
/// 占位注释见 position_page.dart。
class PositionFeedNotice extends StatefulWidget {
  final FeedNoticeItem item;
  final bool isDark;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  const PositionFeedNotice({
    super.key,
    required this.item,
    required this.isDark,
    required this.onClose,
    this.onTap,
  });

  @override
  State<PositionFeedNotice> createState() => _PositionFeedNoticeState();
}

class _PositionFeedNoticeState extends State<PositionFeedNotice>
    with SingleTickerProviderStateMixin {
  // 上下滚动模式：当前实现单条展示（uni-app 按轮换游标选出一条），无需定时器

  // 左右跑马灯
  AnimationController? _marqueeCtrl;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant PositionFeedNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.content != widget.item.content ||
        oldWidget.item.scrollType != widget.item.scrollType) {
      _teardownAnimation();
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    // 当前实现单条展示（uni-app 按轮换游标选出一条），上下/左右滚动对单条无实际动画
    if (widget.item.scrollType == 2) {
      _marqueeCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 10), // 10s linear infinite
      )..repeat();
    }
  }

  void _teardownAnimation() {
    _marqueeCtrl?.dispose();
    _marqueeCtrl = null;
  }

  @override
  void dispose() {
    _teardownAnimation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF1F2430);
    final mutedIconColor =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8E857E);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 40, // 80rpx
        padding: const EdgeInsets.symmetric(horizontal: 12), // 0 24rpx
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202125) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.volume_up, size: 22, color: mutedIconColor), // sound
            const SizedBox(width: 6), // gap 12rpx
            Expanded(child: _buildMessage(textColor)),
            Icon(
              Icons.keyboard_double_arrow_right, // arrow-right-double
              size: 14,
              color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF1F2430),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: widget.onClose,
              child: const SizedBox(
                width: 16, // 32rpx
                height: 16,
                child: Center(
                  child: Icon(Icons.close, size: 16, color: Color(0xFF999999)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Color textColor) {
    final style = AppTextStyles.cn(13, color: textColor, weight: FontWeight.w500);
    switch (widget.item.scrollType) {
      case 1:
        // 上下滚动：单条时等同静止（多条轮换依赖后端多任务，当前只取游标选出的一条）
        return _StaticLine(text: widget.item.content, style: style);
      case 2:
        // 左右跑马灯：内容复制一份，translateX -50% 无缝循环
        final ctrl = _marqueeCtrl;
        if (ctrl == null) {
          return _StaticLine(text: widget.item.content, style: style);
        }
        return ClipRect(
          child: AnimatedBuilder(
            animation: ctrl,
            builder: (context, child) {
              return FractionalTranslation(
                translation: Offset(-0.5 * ctrl.value, 0),
                child: child,
              );
            },
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 40), // 80rpx
                  child: Text(widget.item.content, style: style, maxLines: 1),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: Text(
                    widget.item.content,
                    style: style,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      case 3:
      default:
        return _StaticLine(text: widget.item.content, style: style);
    }
  }
}

class _StaticLine extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _StaticLine({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
