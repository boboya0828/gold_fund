import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';

/// 资金流向面板 — 1:1 复刻 position-details.vue .fund-flow-panel
/// view-tabs：实时流向(round) / 流向明细(daily) / 资金详情(跳转独立页)
/// round：默认 2 条可展开；daily：默认 6 条可展开
class PositionDetailsFundFlowPanel extends StatelessWidget {
  final bool isDark;
  final String view; // 'round' | 'daily'
  final bool loading;
  final List<Map<String, dynamic>> rounds; // 已过滤排序的轮次
  final String roundDate;
  final bool roundsExpanded;
  final bool canExpandRounds;
  final VoidCallback onToggleRounds;
  final List<Map<String, dynamic>> dailyItems; // 已过滤
  final bool dailyExpanded;
  final bool canExpandDaily;
  final VoidCallback onToggleDaily;
  final ValueChanged<String> onViewChange;
  final VoidCallback onOpenDetails;

  const PositionDetailsFundFlowPanel({
    super.key,
    required this.isDark,
    required this.view,
    required this.loading,
    required this.rounds,
    required this.roundDate,
    required this.roundsExpanded,
    required this.canExpandRounds,
    required this.onToggleRounds,
    required this.dailyItems,
    required this.dailyExpanded,
    required this.canExpandDaily,
    required this.onToggleDaily,
    required this.onViewChange,
    required this.onOpenDetails,
  });

  // ===== 金额/颜色（1:1 uni-app formatFundFlowAmount/getFundFlowClass）=====
  static const _riseColor = Color(0xFFF04D5D); // 流入红
  static const _fallColor = Color(0xFF12A874); // 流出绿
  static const _neutralColor = Color(0xFF737985);

  static Color flowColor(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    if (amount == null || amount == 0) return _neutralColor;
    return amount > 0 ? _riseColor : _fallColor;
  }

  /// 1:1 formatFundFlowAmount：|v|≥1e8→亿，≥1e4→万，/unit 2 位，+/- 号
  static ({String text, String unit}) splitAmount(dynamic value) {
    if (value == null || value == '') return (text: '--', unit: '');
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    if (amount == null) return (text: '--', unit: '');
    final unit = amount.abs() >= 100000000 ? 100000000.0 : 10000.0;
    final suffix = unit == 100000000 ? '亿' : '万';
    final formatted = (amount.abs() / unit).toStringAsFixed(2);
    final sign = amount > 0 ? '+' : (amount < 0 ? '-' : '');
    return (text: '$sign$formatted ', unit: suffix);
  }

  static String _formatDate(dynamic raw) {
    final text = '$raw';
    final m = RegExp(r'(\d{2})[-/](\d{2})').firstMatch(text);
    if (m != null) return '${m.group(1)}-${m.group(2)}';
    return text.length > 5 ? text.substring(0, 5) : text;
  }

  static String _formatTime(dynamic raw) {
    final text = '$raw';
    final m = RegExp(r'(\d{2}:\d{2})').firstMatch(text);
    return m?.group(1) ?? text;
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8F8F8F);
    final titleColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF30343B);

    return Container(
      padding: EdgeInsets.fromLTRB(15.sx, 12.sx, 15.sx, 14.sx), // 24rpx 30rpx 28rpx
      constraints: BoxConstraints(minHeight: 200.sx), // min-h 400rpx
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // .fund-flow-view-tabs：h52 padding 0 18 圆角 4 底 #f8f9fa 描边 #e2e5e9 23rpx #6e7580
        Row(children: [
          _viewTab('实时流向', view == 'round', () => onViewChange('round'), isDark),
          SizedBox(width: 4.sx),
          _viewTab('流向明细', view == 'daily', () => onViewChange('daily'), isDark),
          SizedBox(width: 4.sx),
          GestureDetector(
            onTap: onOpenDetails,
            child: Container(
              height: 26.sx, // 52rpx
              padding: EdgeInsets.symmetric(horizontal: 9.sx), // 0 18rpx
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282828) : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(2.sx),
                border: Border.all(
                    color: isDark ? const Color(0xFF3A3D45) : const Color(0xFFE2E5E9),
                    width: 0.5),
              ),
              child: Text('资金详情',
                  style: AppTextStyles.cn(11.5.sx,
                      color: isDark
                          ? const Color(0xFFA7ADB8)
                          : const Color(0xFF6E7580))), // 23rpx
            ),
          ),
        ]),
        SizedBox(height: 6.sx),
        if (loading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 30.sx),
            child: Center(
              child: Text('资金流向加载中...',
                  style: AppTextStyles.cn(13.sx, color: labelColor)),
            ),
          )
        else if (view == 'round' && rounds.isEmpty)
          _empty('暂未获取到该基金持仓股票资金流数据', labelColor)
        else if (view == 'daily' && dailyItems.isEmpty)
          _empty('暂未获取到该基金持仓股票资金流数据', labelColor)
        else if (view == 'round')
          _buildRounds(labelColor, titleColor)
        else
          _buildDaily(labelColor, titleColor),
      ]),
    );
  }

  Widget _empty(String text, Color labelColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 30.sx),
      child: Center(child: Text(text, style: AppTextStyles.cn(13.sx, color: labelColor))),
    );
  }

  Widget _viewTab(String label, bool active, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26.sx, // 52rpx
        padding: EdgeInsets.symmetric(horizontal: 9.sx), // 0 18rpx
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFF5465C)
              : (isDark ? const Color(0xFF282828) : const Color(0xFFF8F9FA)),
          borderRadius: BorderRadius.circular(2.sx), // 4rpx
          border: Border.all(
            color: active
                ? const Color(0xFFF5465C)
                : (isDark ? const Color(0xFF3A3D45) : const Color(0xFFE2E5E9)),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.cn(
            11.5.sx, // 23rpx
            color: active
                ? Colors.white
                : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFF6E7580)),
            weight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// round 实时轮次列表
  Widget _buildRounds(Color labelColor, Color titleColor) {
    final visible = roundsExpanded ? rounds : rounds.take(2).toList();
    final mainNet = rounds.isNotEmpty ? _num(rounds.first['mainNetInflowAmount']) : null;
    final headBg = mainNet == null
        ? (isDark ? const Color(0xFF282828) : const Color(0xFFF7FAF9))
        : (mainNet >= 0
            ? (isDark ? const Color(0xFF322329) : const Color(0xFFFFF8F8))
            : (isDark ? const Color(0xFF22302E) : const Color(0xFFF3FAF8)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 日期头
      Padding(
        padding: EdgeInsets.only(top: 6.sx, bottom: 6.sx), // margin-top 12rpx
        child: Text(
          _formatDate(roundDate),
          style: AppTextStyles.num(13.sx, color: titleColor, weight: FontWeight.w600),
        ),
      ),
      for (final item in visible)
        Container(
          constraints: BoxConstraints(minHeight: 58.sx), // min-h 116rpx
          margin: EdgeInsets.only(bottom: 6.sx),
          padding: EdgeInsets.symmetric(horizontal: 12.sx, vertical: 9.sx), // 18rpx 24rpx
          decoration: BoxDecoration(
            color: headBg,
            borderRadius: BorderRadius.circular(4.sx),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('持仓股票资金流',
                    style: AppTextStyles.cn(13.5.sx,
                        color: titleColor, weight: FontWeight.w500)), // 27rpx
                SizedBox(height: 2.sx),
                Text(_formatTime(item['roundTime']),
                    style: AppTextStyles.num(11.sx, color: labelColor)), // 22rpx
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (item['mainNetInflowAmount'] != null)
                  _amountLine('主力', item['mainNetInflowAmount'], labelColor),
                if (item['retailNetInflowAmount'] != null)
                  _amountLine('散户', item['retailNetInflowAmount'], labelColor),
              ]),
            ],
          ),
        ),
      if (canExpandRounds)
        GestureDetector(
          onTap: onToggleRounds,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6.sx),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(roundsExpanded ? '收起' : '展开显示',
                  style: AppTextStyles.cn(12.sx,
                      color: isDark
                          ? const Color(0xFFA7ADB8)
                          : const Color(0xFF7B818C))),
              Icon(roundsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 13,
                  color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF7B818C)),
            ]),
          ),
        ),
    ]);
  }

  /// 主力/散户金额行：label 21rpx + 金额 30rpx 700（单位字重 400）
  Widget _amountLine(String label, dynamic value, Color labelColor) {
    final split = splitAmount(value);
    return Row(crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label,
              style: AppTextStyles.cn(10.5.sx, color: labelColor)), // 21rpx
          SizedBox(width: 3.sx),
          Text(split.text,
              style: AppTextStyles.num(15.sx,
                  color: flowColor(value), weight: FontWeight.w700)), // 30rpx
          if (split.unit.isNotEmpty)
            Text(split.unit,
                style: AppTextStyles.cn(11.sx, color: flowColor(value))),
        ]);
  }

  /// daily 明细表：3 列 grid 1.15fr 1.15fr 0.7fr
  Widget _buildDaily(Color labelColor, Color titleColor) {
    final visible = dailyExpanded ? dailyItems : dailyItems.take(6).toList();
    return Column(children: [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 8.sx), // head h88rpx
        child: Row(children: [
          Expanded(
              flex: 115,
              child: Text('日期', style: AppTextStyles.cn(12.sx, color: labelColor))),
          Expanded(
              flex: 115,
              child: Text('净流向(亿元)',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cn(12.sx, color: labelColor))),
          Expanded(
              flex: 70,
              child: Text('涨跌幅',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.cn(12.sx, color: labelColor))),
        ]),
      ),
      for (final item in visible)
        Container(
          constraints: BoxConstraints(minHeight: 50.sx), // min-h 100rpx
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(
                    color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0F1F4),
                    width: 0.5)),
          ),
          child: Row(children: [
            Expanded(
                flex: 115,
                child: Text(_formatDate(item['tradeDate']),
                    style: AppTextStyles.num(13.5.sx,
                        color: titleColor, weight: FontWeight.w500))), // 27rpx
            Expanded(
              flex: 115,
              child: Text(_dailyAmount(item),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.num(13.5.sx,
                      color: flowColor(_dailyAmountRaw(item)),
                      weight: FontWeight.w500)),
            ),
            Expanded(
              flex: 70,
              child: Text(_formatRate(item['fundChangeRate']),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.num(13.5.sx,
                      color: flowColor(item['fundChangeRate']),
                      weight: FontWeight.w500)),
            ),
          ]),
        ),
      if (canExpandDaily)
        GestureDetector(
          onTap: onToggleDaily,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6.sx),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(dailyExpanded ? '收起' : '展开显示',
                  style: AppTextStyles.cn(12.sx,
                      color: isDark
                          ? const Color(0xFFA7ADB8)
                          : const Color(0xFF7B818C))),
              Icon(dailyExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 13,
                  color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF7B818C)),
            ]),
          ),
        ),
    ]);
  }

  static double? _dailyAmountRaw(Map<String, dynamic> item) {
    final yi = _num(item['netInflowAmountYi']);
    if (yi != null && yi != 0) return yi;
    final raw = _num(item['netInflowAmount']);
    if (raw != null && raw != 0) return raw / 100000000;
    return null;
  }

  static String _dailyAmount(Map<String, dynamic> item) {
    final v = _dailyAmountRaw(item);
    if (v == null) return '--';
    return '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}';
  }

  static String _formatRate(dynamic value) {
    final v = _num(value);
    if (v == null) return '--';
    return '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
  }
}
