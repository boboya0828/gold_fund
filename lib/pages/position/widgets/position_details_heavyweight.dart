import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import 'position_details_models.dart';

/// 持仓详情 — 十大重仓股
/// uni-app 对应: position-details.vue 的 .heavyweight-stocks
class PositionDetailsHeavyweight extends StatelessWidget {
  final bool isDark;
  final List<Map<String, dynamic>>? list; // null = 加载中/失败，空 = 无数据

  const PositionDetailsHeavyweight({super.key, required this.isDark, required this.list});

  String _chgRate(dynamic v) {
    final n = v is num ? v.toDouble() : null;
    if (n == null) return '--';
    return '${n >= 0 ? '+' : ''}${n.toStringAsFixed(2)}%';
  }

  String _ratio(dynamic v) {
    final n = v is num ? v.toDouble() : null;
    if (n == null) return '--';
    return '${n.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF2C2323);
    final headColor = isDark ? AppColors.darkTextSecondary : const Color(0xFFA6A6A6);
    final rowColor = isDark ? AppColors.darkText : const Color(0xFF242424);
    final subColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF999999);

    Widget headCell(String t, {bool right = false}) => Expanded(
          child: Text(t, textAlign: right ? TextAlign.right : TextAlign.center, style: AppTextStyles.cn(11, color: headColor, height: 1.4)),
        );

    return Container(
      margin: const EdgeInsets.only(top: 12), // 24rpx
      padding: const EdgeInsets.fromLTRB(9, 11, 9, 8), // 22rpx 18rpx 16rpx
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFAFFFFFF),
        borderRadius: BorderRadius.circular(11), // 22rpx
        border: Border.all(color: isDark ? const Color(0xFF2B2D33) : const Color(0xE6F5EEEE), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('十大重仓股', style: AppTextStyles.cn(15, color: titleColor, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (list != null && list!.isNotEmpty) ...[
            Row(children: [
              Expanded(flex: 3, child: Text('重仓股票', style: AppTextStyles.cn(11, color: headColor, height: 1.4))),
              headCell('涨跌幅'),
              headCell('持仓占比'),
              headCell('较上季度变化', right: true),
            ]),
            for (final item in list!)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFF0F0F0), width: 0.5)),
                ),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['stockName']?.toString() ?? '--', style: AppTextStyles.cn(12, color: rowColor)),
                      Text(item['stockCode']?.toString() ?? '', style: AppTextStyles.num(10, color: subColor)),
                    ]),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(_chgRate(item['latestPrice']?['chgRate']),
                          style: AppTextStyles.num(12, color: pdProfitColor(item['latestPrice']?['chgRate'] is num ? item['latestPrice']['chgRate'] as num : 0))),
                    ),
                  ),
                  Expanded(
                    child: Center(child: Text(_ratio(item['navRatio']), style: AppTextStyles.num(12, color: rowColor))),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(_chgRate(item['quarterlyChangeRate']),
                          style: AppTextStyles.num(12, color: pdProfitColor(item['quarterlyChangeRate'] is num ? item['quarterlyChangeRate'] as num : 0))),
                    ),
                  ),
                ]),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('暂无重仓股数据', style: AppTextStyles.cn(12, color: subColor))),
            ),
        ],
      ),
    );
  }
}
