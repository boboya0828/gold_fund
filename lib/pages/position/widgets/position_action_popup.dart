import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import '../../position/position_provider_types.dart' show PositionState;

/// 长按操作弹窗 — 1:1 复刻 .popup-content (带方向箭头、跟随按下的行定位)
class PositionActionPopup extends StatelessWidget {
  final PositionState state;
  final int selectedIndex;
  final Offset rowOffset;       // 按下行的左上角偏移
  final double rowHeight;       // 按下行的高度
  final double screenWidth;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onBatchEdit;
  final VoidCallback onPinTop;
  final ValueChanged<String> onDelete;  // 传入资产名

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
    required this.onPinTop,
    required this.onDelete,
  });

  static const double _popupWidth = 260;
  static const double _popupMaxHeight = 83; // 33 + 50
  static const double _popupGap = 8; // 源码 popupGap
  static const double _tabbarReserve = 60; // 源码 uni.upx2px(120)
  static const double _arrowWidth = 14; // 源码 border-left/right 14rpx
  static const double _arrowHeight = 8; // 源码 border-bottom 16rpx
  static const double _arrowCenterFraction = 0.3; // 源码 .popup-arrow left:30%

  @override
  Widget build(BuildContext context) {
    final items = state.sortedItems;
    final item = selectedIndex >= 0 && selectedIndex < items.length ? items[selectedIndex] : null;
    final title = item?.shortName ?? '资产操作';

    // 1:1 复刻源码 getRowPopupStyle：只判断下方空间(扣除底部 TabBar 预留)是否足够，
    // 不够才翻到上方；不会因为"上方空间也够"就抢先翻上去。
    final screenHeight = MediaQuery.of(context).size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomLimit = screenHeight - _tabbarReserve - safeBottom - _popupGap;
    final downTop = rowOffset.dy + rowHeight + _popupGap;
    final upTop = (rowOffset.dy - _popupMaxHeight - _popupGap).clamp(0.0, double.infinity);
    final showAbove = downTop + _popupMaxHeight > bottomLimit;
    final top = showAbove ? upTop : downTop;

    // 源码 left:16px 固定值，不随行位置居中
    const left = 16.0;

    return Positioned(
      left: left,
      top: top,
      child: _buildPopup(title, showAbove),
    );
  }

  Widget _buildPopup(String title, bool showAbove) {
    final popupBody = Container(
      width: _popupWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF383A47),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Color(0x2E201915), blurRadius: 18, offset: Offset(0, 7))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // popup-title
        Container(
          height: 33,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x1FFFFFFF), width: 0.5)),
          ),
          child: Text(title,
            style: AppTextStyles.cn(12, color: Colors.white, weight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        // popup-actions
        SizedBox(
          height: 50,
          child: Row(children: [
            _action('置顶', Icons.arrow_upward, onPinTop),
            _divider(),
            _action('修改持仓', Icons.edit, () {
              onEdit();
            }),
            _divider(),
            _action('批量编辑', Icons.settings, onBatchEdit),
            _divider(),
            _action('删除', Icons.delete_outline, () {
              final items = state.sortedItems;
              final selItem = selectedIndex >= 0 && selectedIndex < items.length ? items[selectedIndex] : null;
              if (selItem != null) onDelete(selItem.shortName);
            }),
          ]),
        ),
      ]),
    );

    // 三角形中心对齐 popup 宽度的 30% 处 (源码 left:30%; transform:translateX(-50%))，
    // 用 Stack + 负偏移绝对定位，避免依赖 Column 的隐式宽度传导。
    final arrowLeft = _popupWidth * _arrowCenterFraction - _arrowWidth / 2;
    return SizedBox(
      width: _popupWidth,
      child: Stack(clipBehavior: Clip.none, children: [
        popupBody,
        Positioned(
          left: arrowLeft,
          top: showAbove ? null : -_arrowHeight,
          bottom: showAbove ? -_arrowHeight : null,
          child: CustomPaint(size: const Size(_arrowWidth, _arrowHeight), painter: _ArrowPainter(up: !showAbove)),
        ),
      ]),
    );
  }

  Widget _action(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        onTapUp: (_) {}, // 防止点击穿透
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 21, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.cn(10, color: Colors.white, weight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _divider() {
    // 源码 .popup-item::before top:0;bottom:0 → 满行高分隔线, rgba(255,255,255,0.14)
    return Container(width: 0.5, height: 50, color: const Color(0x24FFFFFF));
  }
}

/// 三角形箭头 CustomPainter
class _ArrowPainter extends CustomPainter {
  final bool up;
  _ArrowPainter({required this.up});

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
