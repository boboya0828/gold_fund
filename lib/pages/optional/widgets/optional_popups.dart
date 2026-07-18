import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';

/// 长按行操作弹框 — 1:1 复刻 zdj-v1/pages/optional/index.vue 的 .popup-content
/// （深色 #383A47 浮层：标题 + 删除操作 + 小三角箭头）
///
/// 尺寸换算：rpx / 2 = px
/// popup-content: min-width 500rpx=250, radius 24rpx=12
/// popup-title:   height 82rpx=41, font 26rpx=13 w700
/// popup-actions: height 76rpx=38, font 28rpx=14 w500
/// 整体高度 158rpx=79（源码 uni.upx2px(158)）
class RowActionPopup extends StatelessWidget {
  final String title;
  final bool showAbove; // 显示在行上方时箭头朝下
  final VoidCallback onDelete;
  const RowActionPopup({
    super.key,
    required this.title,
    required this.showAbove,
    required this.onDelete,
  });

  static const double popupWidth = 250; // min-width 500rpx
  static const double popupHeight = 79; // 158rpx

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF383A47);
    return SizedBox(
      width: popupWidth,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          height: popupHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              // 0 14rpx 36rpx rgba(32, 25, 21, 0.16)
              BoxShadow(color: Color(0x29201915), blurRadius: 18, offset: Offset(0, 7)),
            ],
          ),
          child: Column(children: [
            // 标题栏
            Container(
              height: 41,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: Color(0x1FFFFFFF), width: 0.5)),
              ),
              alignment: Alignment.center,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cn(13, color: Colors.white, weight: FontWeight.w700, height: 1.0),
              ),
            ),
            // 操作区（仅"删除"）
            Container(
              height: 38,
              decoration: const BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Text('删除',
                      style: AppTextStyles.cn(14, color: Colors.white, weight: FontWeight.w500, height: 1.0)),
                ),
              ),
            ),
          ]),
        ),
        // 小三角箭头（left: 30%，向上/向下）
        Positioned(
          left: popupWidth * 0.3 - 7,
          top: showAbove ? null : -7.5,
          bottom: showAbove ? -8 : null,
          child: CustomPaint(
            size: const Size(14, 8),
            painter: _TrianglePainter(color: bg, pointUp: !showAbove),
          ),
        ),
      ]),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool pointUp;
  const _TrianglePainter({required this.color, required this.pointUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (pointUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointUp != pointUp;
}

/// 删除确认弹框 — 1:1 复刻 zdj-v1/components/delectPopup.vue
///
/// dlogbox: width 600rpx=300, 渐变 #FFFFFF→#FEF0F0, radius 20rpx=10
/// 图标 tzico.png 114rpx=57，向上溢出 50rpx=25
/// font1: 40rpx=20 bold；font2: 30rpx=15，行高 45rpx=22.5
/// 按钮: 248rpx=124 × 84rpx=42, radius 42rpx=21
class DeleteConfirmDialog extends StatelessWidget {
  final String content;
  const DeleteConfirmDialog({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const red = Color(0xFFE05665);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: 300,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            margin: const EdgeInsets.only(top: 25),
            decoration: BoxDecoration(
              gradient: isDark
                  ? null
                  : const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFFFFFFFF), Color(0xFFFEF0F0)],
                    ),
              color: isDark ? const Color(0xFF202125) : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF2B2D33) : Colors.white, width: 1),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // 图标占位（57 - 25 溢出 = 32）+ font1 margin-top 20rpx=10
              const SizedBox(height: 42),
              Text('确认删除',
                  style: AppTextStyles.cn(20,
                      color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
                      weight: FontWeight.w700)),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 21),
                child: Text(content,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cn(15,
                        color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666), height: 1.5)),
              ),
              const SizedBox(height: 23),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 21),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  // 取消（描边）
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      width: 124, height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF282828) : Colors.transparent,
                        border: Border.all(color: red, width: 0.5),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      alignment: Alignment.center,
                      child: Text('取消', style: AppTextStyles.cn(15, color: red)),
                    ),
                  ),
                  // 确认删除（实心）
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      width: 124, height: 42,
                      decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(21)),
                      alignment: Alignment.center,
                      child: Text('确认删除', style: AppTextStyles.cn(15, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
            ]),
          ),
          // 图标相对弹框上沿溢出 50rpx=25（容器已预留 margin-top 25）
          const Positioned(
            top: 0, left: 0, right: 0,
            child: Center(child: Image(image: AssetImage('assets/images/img/tzico.png'), width: 57, height: 57)),
          ),
        ]),
      ),
    );
  }
}
