import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

/// 下拉刷新 — 对外统一入口（类名与参数保持不变，调用页面零改动）
///
/// 内部实现：easy_refresh 的 [EasyRefresh] + [BezierCircleHeader]（气球弹动风格），
/// 替换原自研 CupertinoSliverRefreshControl 方案（箭头+文字样式）。
///
/// 行为对齐原 z-paging refresher-only：
/// - 触发阈值 100rpx = 50px（triggerOffset）
/// - 刷新成功以 success 态的对勾弹动动画表示（BezierCircle 无文字态）
/// - 完成后头部随 kBezierCircleDisappearDuration(800ms) 动画自然收起，
///   由 easy_refresh 的 IndicatorNotifier 状态机管理，不会卡在半截
///   （原自研版需要手动回弹修复的问题在 easy_refresh 内建流程中不存在）
/// - 无 footer（refresher-only，上拉不加载）
class ZPagingRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final bool isDark;

  /// 滚动内容（会包进 SliverToBoxAdapter）。与 [slivers] 二选一。
  final Widget? child;

  /// 直接提供 sliver 列表（高级用法）。与 [child] 二选一。
  final List<Widget>? slivers;

  final ScrollController? controller;

  /// 原自研刷新头的文字颜色参数（easy_refresh 版刷新头无文字，保留仅为 API 兼容）。
  final Color? titleColor;

  const ZPagingRefresh({
    super.key,
    required this.onRefresh,
    required this.isDark,
    this.child,
    this.slivers,
    this.controller,
    this.titleColor,
  }) : assert(child != null || slivers != null,
            'ZPagingRefresh 需要 child 或 slivers 之一');

  /// 触发阈值 100rpx = 50px（对齐 z-paging refresher-threshold=100）
  static const double triggerOffset = 50;

  @override
  State<ZPagingRefresh> createState() => _ZPagingRefreshState();
}

class _ZPagingRefreshState extends State<ZPagingRefresh> {
  // 外部没传 controller 时用内部的（滚动位置由 easy_refresh 管理，此 controller
  // 仅供调用方读取位置/主动滚动）。
  ScrollController? _internalController;
  ScrollController get _controller =>
      widget.controller ?? (_internalController ??= ScrollController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  Future<IndicatorResult> _handleRefresh() async {
    await widget.onRefresh();
    return IndicatorResult.success;
  }

  @override
  Widget build(BuildContext context) {
    return EasyRefresh(
      header: BezierCircleHeader(
        triggerOffset: ZPagingRefresh.triggerOffset,
        // 气球（前景）用品牌红；背景条透明，融入列表底色
        foregroundColor:
            widget.isDark ? const Color(0xFFE05665) : const Color(0xFFE15665),
        backgroundColor: Colors.transparent,
      ),
      onRefresh: _handleRefresh,
      // 不传 physics：easy_refresh 通过 ScrollConfiguration 注入
      // _ERScrollPhysics（parent=AlwaysScrollableScrollPhysics），
      // 短列表也可下拉；显式设置 physics 会使注入失效
      child: CustomScrollView(
        controller: _controller,
        slivers: [
          if (widget.slivers != null)
            ...widget.slivers!
          else
            SliverToBoxAdapter(child: widget.child),
        ],
      ),
    );
  }
}
