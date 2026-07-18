import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/text_styles.dart';

/// 下拉刷新 — 1:1 复刻 uni-app z-paging 默认刷新头
///
/// z-paging 默认刷新头（z-paging-refresh.vue）：水平居中一行
///   左侧图标：默认箭头朝下 → 超阈值箭头朝上(0.2s 旋转) → 刷新中转圈 → 完成对勾 (17px)
///   右侧文案：继续下拉刷新 / 松开立即刷新 / 正在刷新... / 刷新成功 (15px)
///   主题色：文字 浅 #555555 / 深 #efefef；指示器 浅 #777777 / 深 #eeeeee
///   触发阈值 refresher-threshold=100rpx = 50px
///
/// 用 CupertinoSliverRefreshControl 实现（drag/armed/refresh/done 四态 1:1 对应 z-paging）。
/// 强制 BouncingScrollPhysics，保证 Android/Web 也能下拉（否则 Clamping 不产生 overscroll）。
class ZPagingRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final bool isDark;

  /// 滚动内容（会包进 SliverToBoxAdapter）。与 [slivers] 二选一。
  final Widget? child;

  /// 直接提供 sliver 列表（高级用法）。与 [child] 二选一。
  final List<Widget>? slivers;

  final ScrollController? controller;

  const ZPagingRefresh({
    super.key,
    required this.onRefresh,
    required this.isDark,
    this.child,
    this.slivers,
    this.controller,
  }) : assert(child != null || slivers != null,
            'ZPagingRefresh 需要 child 或 slivers 之一');

  static const double _threshold = 50; // 100rpx

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          refreshTriggerPullDistance: _threshold,
          refreshIndicatorExtent: _threshold,
          onRefresh: onRefresh,
          builder: (context, mode, pulled, trigger, extent) =>
              _ZpRefreshHeader(mode: mode, isDark: isDark),
        ),
        if (slivers != null)
          ...slivers!
        else
          SliverToBoxAdapter(child: child),
      ],
    );
  }
}

class _ZpRefreshHeader extends StatefulWidget {
  final RefreshIndicatorMode mode;
  final bool isDark;

  const _ZpRefreshHeader({required this.mode, required this.isDark});

  @override
  State<_ZpRefreshHeader> createState() => _ZpRefreshHeaderState();
}

class _ZpRefreshHeaderState extends State<_ZpRefreshHeader> {
  // 刷新成功后 CupertinoSliverRefreshControl 会把 extent 收缩回 0，
  // 收缩过程中一旦 extent 低于阈值，框架会把 mode 又报回 drag/armed，
  // 导致"刷新成功"的对勾一闪就变回箭头。这里锁定：一旦见过 done，
  // 在真正 inactive（收起动画结束）之前都继续展示 done 的样式。
  bool _justCompleted = false;

  @override
  void didUpdateWidget(covariant _ZpRefreshHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode == RefreshIndicatorMode.done) {
      _justCompleted = true;
    } else if (widget.mode == RefreshIndicatorMode.inactive) {
      _justCompleted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _justCompleted ? RefreshIndicatorMode.done : widget.mode;
    final isDark = widget.isDark;

    if (mode == RefreshIndicatorMode.inactive) {
      return const SizedBox.shrink();
    }

    final titleColor =
        isDark ? const Color(0xFFEFEFEF) : const Color(0xFF555555);
    final indicatorColor =
        isDark ? const Color(0xFFEEEEEE) : const Color(0xFF777777);

    final String text;
    switch (mode) {
      case RefreshIndicatorMode.armed:
        text = '松开立即刷新';
        break;
      case RefreshIndicatorMode.refresh:
        text = '正在刷新...';
        break;
      case RefreshIndicatorMode.done:
        text = '刷新成功';
        break;
      case RefreshIndicatorMode.drag:
      default:
        text = '继续下拉刷新';
        break;
    }

    // RepaintBoundary 隔离刷新头自身的图层：CupertinoSliverRefreshControl 在
    // drag/armed/refresh/done 间快速切换子树类型时，若不单独成层，
    // 偶尔会在合成时把图标残留的图层画到其他内容之上（"显示在最顶层"）。
    return RepaintBoundary(
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 17,
              height: 17,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _buildIcon(mode, indicatorColor),
                ),
              ),
            ),
            const SizedBox(width: 6), // 9rpx≈4.5，取 6 视觉更稳
            Text(text, style: AppTextStyles.cn(15, color: titleColor, height: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(RefreshIndicatorMode mode, Color color) {
    switch (mode) {
      case RefreshIndicatorMode.refresh:
        return CupertinoActivityIndicator(key: const ValueKey('refresh'), color: color, radius: 8);
      case RefreshIndicatorMode.done:
        return Icon(Icons.check, key: const ValueKey('done'), size: 17, color: color);
      case RefreshIndicatorMode.armed:
      case RefreshIndicatorMode.drag:
      default:
        // 箭头：drag 朝下(turns .5)、armed 朝上(turns 0)，0.2s 平滑旋转（对齐 z-paging）
        return AnimatedRotation(
          key: const ValueKey('arrow'),
          turns: mode == RefreshIndicatorMode.armed ? 0.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: Icon(Icons.arrow_upward, size: 15, color: color),
        );
    }
  }
}
