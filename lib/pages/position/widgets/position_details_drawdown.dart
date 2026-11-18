import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';

/// 回撤修复面板 — 1:1 复刻 position-details.vue .drawdown-panel
/// stats（最大回撤/修复天数）+ loading/失败重试/空态(status 驱动)/折线图 + 区间 tab
class PositionDetailsDrawdownPanel extends StatelessWidget {
  final bool isDark;
  final bool loading;
  final bool loadError;
  final VoidCallback onRetry;

  /// status: 'ok' | 'recovering' | 'noData' | 'insufficientData'
  final String status;
  final double? maxDrawdownRate; // 最大回撤率（%）
  final int? recoveryDays;
  final List<double> series; // 相对区间首点涨跌幅（%）
  final int peakIndex;
  final int troughIndex;
  final int recoveryIndex; // recovering 时取 series 末点

  final List<Map<String, String>> periodTabs;
  final String activePeriod;
  final ValueChanged<String> onPeriodChange;

  const PositionDetailsDrawdownPanel({
    super.key,
    required this.isDark,
    required this.loading,
    required this.loadError,
    required this.onRetry,
    required this.status,
    required this.maxDrawdownRate,
    required this.recoveryDays,
    required this.series,
    required this.peakIndex,
    required this.troughIndex,
    required this.recoveryIndex,
    required this.periodTabs,
    required this.activePeriod,
    required this.onPeriodChange,
  });

  static const _riseColor = Color(0xFFF5465C);
  static const _fallColor = Color(0xFF20B083);

  bool get _hasChart =>
      series.length > 1 && status != 'noData' && status != 'insufficientData';
  bool get _recovering => status == 'recovering';

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8F8F8F);
    final titleColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF242424);

    return Container(
      padding: EdgeInsets.fromLTRB(15.sx, 12.sx, 15.sx, 14.sx),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // .drawdown-stats：gap 60rpx，dot 12rpx，value 30rpx/600
        Row(children: [
          _statItem(
            dotColor: _riseColor,
            label: '最大回撤',
            value: maxDrawdownRate == null
                ? '--'
                : '${maxDrawdownRate!.toStringAsFixed(2)}%',
            valueColor: titleColor,
            labelColor: labelColor,
          ),
          SizedBox(width: 30.sx), // gap 60rpx
          _statItem(
            dotColor: _fallColor,
            label: '修复天数',
            value: _recovering
                ? '修复中'
                : (recoveryDays == null ? '--' : '$recoveryDays天'),
            valueColor: titleColor,
            labelColor: labelColor,
          ),
        ]),
        SizedBox(height: 8.sx),
        if (loading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40.sx),
            child: Center(
              child: Text('加载中...', style: AppTextStyles.cn(13.sx, color: labelColor)),
            ),
          )
        else if (loadError)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 30.sx),
            child: Center(
              child: Column(children: [
                Text('回撤数据加载失败', style: AppTextStyles.cn(13.sx, color: labelColor)),
                SizedBox(height: 8.sx),
                GestureDetector(
                  onTap: onRetry,
                  child: Icon(Icons.refresh,
                      size: 14.sx,
                      color: isDark ? const Color(0xFFE05665) : const Color(0xFFE85F6F)),
                ),
              ]),
            ),
          )
        else if (_hasChart) ...[
          SizedBox(
            height: 200.sx, // 400rpx
            child: CustomPaint(
              painter: _DrawdownPainter(
                series: series,
                peakIndex: peakIndex,
                troughIndex: troughIndex,
                recoveryIndex: recoveryIndex,
                recovering: _recovering,
                lineColor: isDark ? const Color(0xFF7F8EA3) : const Color(0xFFA9BCD0),
                labelColor: labelColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          // .drawdownPeriodTabs：5 档
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final tab in periodTabs) _periodTab(tab, isDark),
          ]),
        ] else
          Padding(
            padding: EdgeInsets.symmetric(vertical: 30.sx),
            child: Center(
              child: Text(
                status == 'insufficientData' ? '数据不足，暂不计算回撤' : '暂无回撤数据',
                style: AppTextStyles.cn(13.sx, color: labelColor),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _statItem({
    required Color dotColor,
    required String label,
    required String value,
    required Color valueColor,
    required Color labelColor,
  }) {
    return Row(children: [
      Container(
        width: 6.sx, // 12rpx
        height: 6.sx,
        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
      ),
      SizedBox(width: 4.sx),
      Text(label, style: AppTextStyles.cn(11.sx, color: labelColor)),
      SizedBox(width: 5.sx),
      Text(value,
          style: AppTextStyles.num(15.sx,
              color: valueColor, weight: FontWeight.w600)), // 30rpx
    ]);
  }

  Widget _periodTab(Map<String, String> tab, bool isDark) {
    final active = activePeriod == tab['value'];
    return GestureDetector(
      onTap: () => onPeriodChange(tab['value']!),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 3.sx),
        height: 28.sx, // 56rpx
        padding: EdgeInsets.symmetric(horizontal: 10.sx),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFE85F6F)
              : (isDark ? const Color(0xFF282828) : Colors.transparent),
          borderRadius: BorderRadius.circular(25.sx), // 50rpx
        ),
        child: Text(
          tab['label']!,
          style: AppTextStyles.cn(
            12.sx, // 24rpx
            color: active
                ? Colors.white
                : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA3A8B5)),
            weight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 回撤折线（自绘，替代 echarts）：浅蓝灰主线 + peak/trough 绿点 + 修复段红区
class _DrawdownPainter extends CustomPainter {
  final List<double> series;
  final int peakIndex;
  final int troughIndex;
  final int recoveryIndex;
  final bool recovering;
  final Color lineColor;
  final Color labelColor;

  const _DrawdownPainter({
    required this.series,
    required this.peakIndex,
    required this.troughIndex,
    required this.recoveryIndex,
    required this.recovering,
    required this.lineColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;
    const top = 6.0;
    const bottom = 24.0;
    final minV = series.reduce((a, b) => a < b ? a : b);
    final maxV = series.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;
    double px(int i) => i / (series.length - 1) * size.width;
    double py(double v) => top + (1 - (v - minV) / span) * (size.height - top - bottom);

    // 修复段（trough → recovery/末点）红色半透明区域 + 红线
    final endIdx = recovering ? series.length - 1 : recoveryIndex;
    if (endIdx > troughIndex && troughIndex >= 0 && troughIndex < series.length) {
      final area = Path()..moveTo(px(troughIndex), size.height - bottom);
      for (var i = troughIndex; i <= endIdx; i++) {
        area.lineTo(px(i), py(series[i]));
      }
      area.lineTo(px(endIdx), size.height - bottom);
      area.close();
      canvas.drawPath(area, Paint()..color = const Color(0x1AF5465C));
      final recoverLine = Path()..moveTo(px(troughIndex), py(series[troughIndex]));
      for (var i = troughIndex + 1; i <= endIdx; i++) {
        recoverLine.lineTo(px(i), py(series[i]));
      }
      canvas.drawPath(
          recoverLine,
          Paint()
            ..color = const Color(0xFFF5465C)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }

    // 主线
    final line = Path()..moveTo(px(0), py(series[0]));
    for (var i = 1; i < series.length; i++) {
      line.lineTo(px(i), py(series[i]));
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = lineColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);

    // peak/trough 绿点
    final dotPaint = Paint()..color = const Color(0xFF20B083);
    if (peakIndex >= 0 && peakIndex < series.length) {
      canvas.drawCircle(Offset(px(peakIndex), py(series[peakIndex])), 3, dotPaint);
    }
    if (troughIndex >= 0 && troughIndex < series.length) {
      canvas.drawCircle(Offset(px(troughIndex), py(series[troughIndex])), 3, dotPaint);
      // 「最大回撤 x%」标签
      _drawLabel(canvas, '最大回撤 ${series[troughIndex].toStringAsFixed(2)}%',
          Offset(px(troughIndex), py(series[troughIndex]) - 14), size);
    }
    // 修复点标签
    if (recovering && series.isNotEmpty) {
      _drawLabel(canvas, '正在修复中',
          Offset(px(series.length - 1) - 60, py(series.last) - 14), size);
    } else if (recoveryIndex > troughIndex && recoveryIndex < series.length) {
      _drawLabel(canvas, '已修复',
          Offset(px(recoveryIndex) - 30, py(series[recoveryIndex]) - 14), size);
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset at, Size size) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(color: labelColor, fontSize: 10, fontFamily: 'DIN')),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = at.dx.clamp(0.0, size.width - tp.width);
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(covariant _DrawdownPainter oldDelegate) =>
      oldDelegate.series != series ||
      oldDelegate.troughIndex != troughIndex ||
      oldDelegate.recoveryIndex != recoveryIndex ||
      oldDelegate.recovering != recovering ||
      oldDelegate.lineColor != lineColor;
}
