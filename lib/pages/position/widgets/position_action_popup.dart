import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';
import '../../position/position_provider_types.dart'
    show PositionItem, PositionState;
import '../../../core/utils/screen_adapt.dart';

/// 长按操作弹窗 — 1:1 复刻 .popup-content（带方向箭头、跟随按下的行定位）
///
/// 规格（index.vue，单位 rpx，÷2 后过 .sx）：
/// - .popup-content 宽 620、背景 #383A47、圆角 12、padding 8；left:16px 固定
/// - top = 行 bottom + 8px 间距；下方放不下（弹窗高按 272rpx 估算、
///   底部预留 120rpx+safeArea）翻转到行上方（arrow-top）
/// - .popup-title 高 64、22rpx 700 白、底部 1rpx rgba(255,255,255,0.12)
/// - .popup-actions grid 4 列、行高 92、gap 1、容器底色 rgba(255,255,255,0.14)
/// - 操作项：基金行 8 项（含基金笔记/基金反馈），贵金属/其它行 6 项
class PositionActionPopup extends StatelessWidget {
  final PositionState state;
  final int selectedIndex;
  final Offset rowOffset; // 按下行的左上角偏移
  final double rowHeight; // 按下行的高度
  final double screenWidth;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onBatchEdit;
  final VoidCallback onBatchAdjust; // 批量加减仓 (1:1 openBatchAdjust)
  final VoidCallback onPinTop;
  final VoidCallback onMoveGroup; // 移动分组（打开移动分组弹框）
  final ValueChanged<String> onDelete; // 传入资产名

  const PositionActionPopup({
    super.key,
    required this.state,
    required this.selectedIndex,
    required this.rowOffset,
    required this.rowHeight,
    required this.screenWidth,
    required this.onClose,
    required this.onEdit,
    required this.onBatchEdit,
    required this.onBatchAdjust,
    required this.onPinTop,
    required this.onMoveGroup,
    required this.onDelete,
  });

  static double get _popupWidth => 310.sx; // 620rpx
  static double get _popupHeightEstimate => 136.sx; // 272rpx（源码估算值）
  static const double _popupGap = 8; // popupGap 8px（源码设备 px，不缩放）
  static double get _tabbarReserve => 60.sx; // 120rpx
  static double get _arrowWidth => 14.sx; // border-left/right 14rpx → 总宽 28rpx
  static double get _arrowHeight => 8.sx; // border-bottom 16rpx
  static const double _arrowCenterFraction = 0.3; // .popup-arrow left:30%

  PositionItem? _currentItem() {
    final items = state.sortedItems;
    return selectedIndex >= 0 && selectedIndex < items.length
        ? items[selectedIndex]
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final item = _currentItem();
    final title = item?.shortName ?? '资产操作';

    // 1:1 复刻源码 getRowPopupStyle：只判断下方空间(扣除底部 TabBar 预留)是否足够，
    // 不够才翻到上方；不会因为"上方空间也够"就抢先翻上去。
    final screenHeight = MediaQuery.of(context).size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomLimit =
        (screenHeight - _tabbarReserve - safeBottom - _popupGap)
            .clamp(0.0, double.infinity);
    final downTop = rowOffset.dy + rowHeight + _popupGap;
    final upTop = (rowOffset.dy - _popupHeightEstimate - _popupGap)
        .clamp(0.0, double.infinity);
    final showAbove = downTop + _popupHeightEstimate > bottomLimit;
    final top = showAbove ? upTop : downTop;

    // 源码 left:16px 固定值，不随行位置居中
    const left = 16.0;

    return Positioned(
      left: left,
      top: top,
      child: _buildPopup(context, title, showAbove, item),
    );
  }

  Widget _buildPopup(
      BuildContext context, String title, bool showAbove, PositionItem? item) {
    // 操作项 — 1:1 uni-app popupActionList
    // 基金行 8 项：置顶/修改持仓/批量编辑/批量加减仓/移动分组/基金笔记/基金反馈/删除
    // 贵金属/其它行 6 项：无 基金笔记/基金反馈
    final isFund = item?.assetType == 3;
    final actions = <_PopupAction>[
      _PopupAction('置顶', Icons.arrow_upward, onPinTop),
      _PopupAction('修改持仓', Icons.edit, onEdit),
      _PopupAction('批量编辑', Icons.settings, onBatchEdit),
      _PopupAction('批量加减仓', Icons.add, onBatchAdjust),
      // uni-icons folder-add：Flutter 无对应字体，用 Material 近似图标（同色同尺寸）
      _PopupAction('移动分组', Icons.create_new_folder_outlined, onMoveGroup),
      if (isFund)
        _PopupAction('基金笔记', AppIcons.note, () => _goFundNote(context, item)),
      // uni-icons chatboxes：Flutter 无对应字体，用 Material 近似图标（同色同尺寸）
      if (isFund)
        _PopupAction(
            '基金反馈', Icons.chat_bubble_outline, () => _goFundFeedback(context, item)),
      _PopupAction('删除', Icons.delete_outline, () {
        final target = _currentItem();
        if (target != null) onDelete(target.shortName);
      }),
    ];

    final popupBody = Container(
      width: _popupWidth,
      padding: EdgeInsets.all(4.sx), // padding 8rpx
      decoration: BoxDecoration(
        color: const Color(0xFF383A47),
        borderRadius: BorderRadius.circular(6.sx), // 12rpx
        // 0 14rpx 36rpx rgba(32,25,21,0.18)
        boxShadow: [
          BoxShadow(
              color: const Color(0x2E201915),
              blurRadius: 18.sx,
              offset: Offset(0, 7.sx)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // .popup-title：高 64rpx、22rpx 700 白、底部 1rpx rgba(255,255,255,0.12)
        Container(
          height: 32.sx,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 9.sx), // 0 18rpx
          decoration: BoxDecoration(
            color: const Color(0xFF383A47),
            borderRadius: BorderRadius.vertical(top: Radius.circular(4.sx)), // 8rpx
            border: const Border(
                bottom: BorderSide(color: Color(0x1FFFFFFF), width: 0.5)),
          ),
          child: Text(
            title,
            style:
                AppTextStyles.cn(11.sx, color: Colors.white, weight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // .popup-actions：grid 4 列、行高 92rpx、gap 1rpx、容器底色 rgba(255,255,255,0.14)
        ClipRRect(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(4.sx)), // 8rpx
          child: Container(
            color: const Color(0x24FFFFFF), // 网格细线底色
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildActionRows(actions),
            ),
          ),
        ),
      ]),
    );

    // 三角形中心对齐 popup 宽度的 30% 处 (源码 left:30%; transform:translateX(-50%))
    final arrowLeft = _popupWidth * _arrowCenterFraction - _arrowWidth / 2;
    return SizedBox(
      width: _popupWidth,
      child: Stack(clipBehavior: Clip.none, children: [
        popupBody,
        Positioned(
          left: arrowLeft,
          top: showAbove ? null : -7.5.sx, // top:-15rpx
          bottom: showAbove ? -_arrowHeight : null, // .arrow-top bottom:-16rpx
          child: CustomPaint(
            size: Size(_arrowWidth, _arrowHeight),
            painter: _ArrowPainter(up: !showAbove),
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildActionRows(List<_PopupAction> actions) {
    final rows = <Widget>[];
    for (var r = 0; r < actions.length; r += 4) {
      final slice = actions.sublist(r, math.min(r + 4, actions.length));
      rows.add(SizedBox(
        height: 46.sx, // 行高 92rpx
        child: Row(children: [
          for (var i = 0; i < slice.length; i++) ...[
            if (i > 0) const SizedBox(width: 0.5), // gap 1rpx
            Expanded(child: _actionCell(slice[i])),
          ],
        ]),
      ));
      if (r + 4 < actions.length) {
        rows.add(const SizedBox(height: 0.5)); // gap 1rpx
      }
    }
    return rows;
  }

  /// .popup-item：纵向居中、gap 10rpx、背景 #383A47、按下态 rgba(255,255,255,0.08)
  /// 图标 18px 白（uni-icons size 单位是 px，不缩放）；文字 20rpx 500 白
  Widget _actionCell(_PopupAction action) {
    return Material(
      color: const Color(0xFF383A47),
      child: InkWell(
        onTap: action.onTap,
        highlightColor: const Color(0x14FFFFFF), // rgba(255,255,255,0.08)
        splashColor: const Color(0x14FFFFFF),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(action.icon, size: 18, color: Colors.white),
          SizedBox(height: 5.sx), // gap 10rpx
          Text(
            action.label,
            style:
                AppTextStyles.cn(10.sx, color: Colors.white, weight: FontWeight.w500),
          ),
        ]),
      ),
    );
  }

  /// 基金笔记 → /fund-note（1:1 uni-app handlePopupAction('基金笔记')）
  void _goFundNote(BuildContext context, PositionItem? item) {
    if (item == null) return;
    onClose();
    final symbolCode = item.symbolCode.isNotEmpty
        ? item.symbolCode
        : item.uniqueSymbol;
    context.push(Uri(path: '/fund-note', queryParameters: {
      'symbolId': '${item.symbolId}',
      if (symbolCode.isNotEmpty) 'symbolCode': symbolCode,
      if (item.shortName.isNotEmpty) 'fundName': item.shortName,
    }).toString());
  }

  /// 基金反馈 → /user/feedback-form?type=sector（1:1 uni-app handlePopupAction('基金反馈')）
  void _goFundFeedback(BuildContext context, PositionItem? item) {
    if (item == null) return;
    onClose();
    final fundCode = item.symbolCode.isNotEmpty
        ? item.symbolCode
        : item.uniqueSymbol;
    context.push(Uri(path: '/user/feedback-form', queryParameters: {
      'type': 'sector',
      if (fundCode.isNotEmpty) 'fundCode': fundCode,
      if (item.shortName.isNotEmpty) 'fundName': item.shortName,
    }).toString());
  }
}

class _PopupAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PopupAction(this.label, this.icon, this.onTap);
}

/// 三角形箭头 CustomPainter（border 14rpx / border-bottom 16rpx 色 #383A47）
class _ArrowPainter extends CustomPainter {
  final bool up;
  const _ArrowPainter({required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF383A47);
    final path = Path();
    if (up) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
