import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';

/// 自定义数字键盘 — 1:1 复刻 uni-app components/CustomNumberKeyboard.vue
/// 固定在页面底部: 左侧 3x4 数字网格 + 右侧 ⌫/清空/确认 动作列
class MaddNumberKeyboard extends StatelessWidget {
  final bool visible;
  final String value;
  final bool allowNegative;
  final ValueChanged<String> onChanged;
  final VoidCallback onConfirm;

  const MaddNumberKeyboard({
    super.key,
    required this.visible,
    required this.value,
    this.allowNegative = false,
    required this.onChanged,
    required this.onConfirm,
  });

  static const _digitKeys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '-'];

  // uni-app normalizeNumberText: 去非法字符 + 只保留第一个小数点 + 负号仅允许在开头
  String _normalize(String text) {
    final isNegative = allowNegative && text.trimLeft().startsWith('-');
    final numeric = text.replaceAll(RegExp(r'[^\d.]'), '');
    final parts = numeric.split('.');
    final intPart = parts.first;
    final decPart = parts.sublist(1).join();
    return '${isNegative ? '-' : ''}$intPart${parts.length > 1 ? '.$decPart' : ''}';
  }

  void _emit(String next) => onChanged(_normalize(next));

  void _onKey(String key) {
    final current = value;
    if (key == 'confirm') {
      onConfirm();
      return;
    }
    if (key == 'clear') {
      _emit('');
      return;
    }
    if (key == 'delete') {
      _emit(current.isEmpty ? '' : current.substring(0, current.length - 1));
      return;
    }
    if (key == '-') {
      if (!allowNegative) return;
      _emit(current.startsWith('-') ? current.substring(1) : '-$current');
      return;
    }
    if (key == '.' && current.contains('.')) return;
    _emit('$current$key');
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // 颜色 (rpx÷2 已在尺寸处换算)
    final panelBg = isDark ? const Color(0xFF252628) : const Color(0xFFD8DCE4);
    final keyBg = isDark ? const Color(0xFF6E6E6C) : Colors.white;
    final keyColor = isDark ? Colors.white : const Color(0xFF050505);
    final actionColor = isDark ? Colors.white : const Color(0xFF101529);
    final minusColor = isDark ? const Color(0xFF24D184) : const Color(0xFF11A96F);
    final minusDisabledBg = isDark ? const Color(0xFF5B5B59) : const Color(0xFFF7F8FA);
    final minusDisabledColor = isDark ? const Color(0xFF8C8C8A) : const Color(0xFFC2C6D0);
    final keyShadow = isDark
        ? const BoxShadow(color: Color(0x59000000), offset: Offset(0, 1.5))
        : const BoxShadow(color: Color(0x47434853), offset: Offset(0, 1.5)); // rgba(67,72,83,0.28)

    Widget buildKey({
      required String label,
      String? keyValue,
      Color? bg,
      Color? color,
      double fontSize = 21, // 42rpx
      FontWeight weight = FontWeight.w400,
      double? height,
      bool expand = false,
    }) {
      final child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onKey(keyValue ?? label),
        child: Container(
          height: expand ? null : (height ?? 52), // 104rpx
          decoration: BoxDecoration(
            color: bg ?? keyBg,
            borderRadius: BorderRadius.circular(5), // 10rpx
            boxShadow: [keyShadow],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: RegExp(r'^[0-9.\-⌫]$').hasMatch(label)
                ? AppTextStyles.num(fontSize, color: color ?? keyColor, weight: weight, height: 1.0)
                : AppTextStyles.cn(fontSize, color: color ?? keyColor, weight: weight, height: 1.0),
          ),
        ),
      );
      return expand ? Expanded(child: child) : child;
    }

    // 数字网格: 3 列 x 4 行, 行高 104rpx=52, 间距 12rpx=6
    final digitRows = <Widget>[];
    for (var r = 0; r < 4; r++) {
      if (r > 0) digitRows.add(const SizedBox(height: 6));
      final rowKeys = _digitKeys.sublist(r * 3, r * 3 + 3);
      digitRows.add(SizedBox(
        height: 52,
        child: Row(
          children: [
            for (var i = 0; i < rowKeys.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Builder(builder: (context) {
                  final k = rowKeys[i];
                  if (k == '-') {
                    final disabled = !allowNegative;
                    return buildKey(
                      label: '-',
                      fontSize: isDark ? 25 : 24, // 50rpx / 48rpx
                      weight: FontWeight.w700,
                      bg: disabled ? minusDisabledBg : keyBg,
                      color: disabled ? minusDisabledColor : minusColor,
                    );
                  }
                  return buildKey(label: k);
                }),
              ),
            ],
          ],
        ),
      ));
    }

    return Container(
      color: panelBg,
      padding: EdgeInsets.only(left: 6, right: 6, top: 9, bottom: 6 + bottomInset), // 18rpx 12rpx
      child: GestureDetector(
        onTap: () {}, // 拦截点击, 不冒泡到页面(关闭键盘)
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: Column(children: digitRows)),
            const SizedBox(width: 6),
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 4 * 52 + 3 * 6, // 与数字网格等高
                child: Column(
                  children: [
                    buildKey(label: '⌫', keyValue: 'delete', fontSize: 17, color: actionColor), // 34rpx
                    const SizedBox(height: 6),
                    buildKey(label: '清空', keyValue: 'clear', fontSize: 17, color: actionColor),
                    const SizedBox(height: 6),
                    buildKey(
                      label: '确认',
                      keyValue: 'confirm',
                      fontSize: 18, // 36rpx
                      bg: const Color(0xFFE05665),
                      color: Colors.white,
                      expand: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
