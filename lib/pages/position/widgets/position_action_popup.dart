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

  @override
  Widget build(BuildContext context) {
    final items = state.sortedItems;
    final item = selectedIndex >= 0 && selectedIndex < items.length ? items[selectedIndex] : null;
    final title = item?.shortName ?? '资产操作';

    // 计算弹窗位置：优先放在行上方，否则放下方
    final spaceAbove = rowOffset.dy;
    final spaceBelow = MediaQuery.of(context).size.height - rowOffset.dy - rowHeight;
    final showAbove = spaceAbove > _popupMaxHeight || spaceBelow < _popupMaxHeight;

    final double top;
    if (showAbove) {
      top = rowOffset.dy - _popupMaxHeight - 8;
    } else {
      top = rowOffset.dy + rowHeight + 8;
    }
    // 水平居中于行，左边界约束 16
    double left = rowOffset.dx + (rowHeight > 0 ? 0 : 0) - (_popupWidth / 2) + (rowHeight > 0 ? 8 : 0);
    left = left.clamp(16.0, screenWidth - _popupWidth - 16);

    return Positioned(
      left: left,
      top: top.clamp(80.0, MediaQuery.of(context).size.height - _popupMaxHeight - 16),
      child: _buildPopup(title, showAbove),
    );
  }

  Widget _buildPopup(String title, bool showAbove) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!showAbove) _arrowUp(),
        Container(
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
        ),
        if (showAbove) _arrowDown(),
      ],
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

  Widget _arrowUp() {
    // 朝上的三角形 (popup 在行下方时)，源码 .popup-arrow left:30%
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: _popupWidth * 0.3),
        child: CustomPaint(size: const Size(12, 6), painter: _ArrowPainter(up: true)),
      ),
    );
  }

  Widget _arrowDown() {
    // 朝下的三角形 (popup 在行上方时)，源码 .popup-arrow left:30%
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: _popupWidth * 0.3),
        child: CustomPaint(size: const Size(12, 6), painter: _ArrowPainter(up: false)),
      ),
    );
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
