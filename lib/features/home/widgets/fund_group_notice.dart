import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 基金群公告跑马灯 — 1:1 复刻 uni-app .fund-group-notice
class FundGroupNotice extends StatefulWidget {
  final bool isDark;
  final String text;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const FundGroupNotice({
    super.key,
    required this.isDark,
    required this.text,
    this.onTap,
    this.onClose,
  });

  @override
  State<FundGroupNotice> createState() => _FundGroupNoticeState();
}

class _FundGroupNoticeState extends State<FundGroupNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.5, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      height: 27, // 54rpx
      padding: const EdgeInsets.only(left: 6, right: 7), // 12rpx 14rpx
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.noticeBg,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2B2D33)
              : AppColors.noticeBorder,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(6), // 12rpx
      ),
      child: Row(children: [
        // 喇叭图标
        Image.asset('assets/images/img/tongzhi.png',
            width: 16, height: 16), // 32×32rpx
        const SizedBox(width: 4), // 8rpx
        // 滚动文字
        Expanded(
          child: GestureDetector(
            onTap: widget.onTap,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: double.infinity,
                child: SlideTransition(
                  position: _animation,
                  child: Row(children: [
                    Text(
                      widget.text,
                      style: TextStyle(
                        fontSize: 12, // 24rpx
                        height: 27 / 12, // 54rpx line-height
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.noticeText,
                      ),
                    ),
                    const SizedBox(width: 16), // 32rpx gap
                    Text(
                      widget.text, // 重复文字实现无缝滚动
                      style: TextStyle(
                        fontSize: 12,
                        height: 27 / 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.noticeText,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        // 右箭头
        GestureDetector(
          onTap: widget.onTap,
          child: Icon(Icons.chevron_right,
              size: 13, color: AppColors.noticeIcon), // uni-icons forward size=13
        ),
        const SizedBox(width: 2),
        // 关闭按钮
        GestureDetector(
          onTap: widget.onClose,
          child: SizedBox(
            width: 16, height: 16, // 32×32rpx
            child: Center(
              child: Icon(Icons.close, size: 10, color: AppColors.noticeClose),
            ),
          ),
        ),
      ]),
    );
  }
}
