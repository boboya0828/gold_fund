import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';

/// 基金收益排行卡（债/货基金）— 1:1 复刻 position-details.vue heavyweight-stocks 的排行分支
/// 标题「基金收益排行」+ period tabs + 表格 + 查看更多 + 行点击跳该基金详情
class PositionDetailsRanking extends StatelessWidget {
  final bool isDark;
  final List<Map<String, String>> periodTabs; // [{label, value}]
  final String activePeriod;
  final ValueChanged<String> onPeriodChange;
  final List<Map<String, dynamic>>? items; // null=未加载/失败
  final bool loading;
  final bool loadError;
  final VoidCallback onRetry;
  final String valueLabel; // 当前 period 列名
  final String dataDateText; // 「数据截至 MM-DD」
  final VoidCallback onMore;
  final ValueChanged<Map<String, dynamic>>? onRowTap;

  const PositionDetailsRanking({
    super.key,
    required this.isDark,
    required this.periodTabs,
    required this.activePeriod,
    required this.onPeriodChange,
    required this.items,
    required this.loading,
    required this.loadError,
    required this.onRetry,
    required this.valueLabel,
    required this.dataDateText,
    required this.onMore,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF202125) : const Color(0xFAFFFFFF);
    final titleColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF2C2323);
    final headColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8F8F8F);
    final nameColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF1A1A1A);
    final divider = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0ECE8);

    return Container(
      margin: EdgeInsets.only(top: 12.sx), // margin-top 24rpx
      padding: EdgeInsets.fromLTRB(9.sx, 11.sx, 9.sx, 8.sx), // 22rpx 18rpx 16rpx
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(11.sx), // 22rpx
        border: Border.all(color: const Color(0xE6F5EEEE), width: 0.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0x0F645856),
              blurRadius: 20.sx,
              offset: Offset(0, 8.sx)), // 0 16rpx 40rpx rgba(100,88,86,0.06)
        ],
      ),
      child: Column(children: [
        // 头部：标题 + 查看更多
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('基金收益排行',
              style: AppTextStyles.cn(15.sx,
                  color: titleColor, weight: FontWeight.w500)), // 30rpx
          GestureDetector(
            onTap: onMore,
            child: Row(children: [
              Text('查看更多',
                  style: AppTextStyles.cn(12.sx,
                      color: isDark
                          ? const Color(0xFFA7ADB8)
                          : const Color(0xFF777777))),
              Icon(Icons.chevron_right,
                  size: 12,
                  color: isDark
                      ? const Color(0xFFA7ADB8)
                      : const Color(0xFF777777)),
            ]),
          ),
        ]),
        // period tabs
        Padding(
          padding: EdgeInsets.only(top: 8.sx),
          child: Row(children: [
            for (final tab in periodTabs)
              GestureDetector(
                onTap: () => onPeriodChange(tab['value']!),
                child: Container(
                  margin: EdgeInsets.only(right: 6.sx),
                  height: 27.sx, // 54rpx
                  padding: EdgeInsets.symmetric(horizontal: 10.sx),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activePeriod == tab['value']
                        ? const Color(0xFFE85F6F)
                        : (isDark
                            ? const Color(0xFF282828)
                            : const Color(0xFFF6F6F8)),
                    borderRadius: BorderRadius.circular(25.sx),
                  ),
                  child: Text(
                    tab['label']!,
                    style: AppTextStyles.cn(
                      12.sx,
                      color: activePeriod == tab['value']
                          ? Colors.white
                          : (isDark
                              ? const Color(0xFFA7ADB8)
                              : const Color(0xFFA3A8B5)),
                      weight: activePeriod == tab['value']
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            if (dataDateText.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 4.sx),
                child: Text(dataDateText,
                    style: AppTextStyles.cn(10.sx, color: headColor)),
              ),
          ]),
        ),
        SizedBox(height: 4.sx),
        // 表头：排名 | 基金 | 当前口径值
        Container(
          padding: EdgeInsets.only(bottom: 4.sx),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider, width: 0.5)),
          ),
          child: Row(children: [
            SizedBox(
                width: 28.sx,
                child: Text('排名', style: AppTextStyles.cn(12.sx, color: headColor))),
            Expanded(
                child: Text('基金', style: AppTextStyles.cn(12.sx, color: headColor))),
            Text(valueLabel, style: AppTextStyles.cn(12.sx, color: headColor)),
          ]),
        ),
        if (loading)
          _state('加载中...', headColor)
        else if (loadError || items == null)
          GestureDetector(
            onTap: onRetry,
            child: _state('获取失败，点击重试', const Color(0xFFE05665)),
          )
        else if (items!.isEmpty)
          GestureDetector(
            onTap: onRetry,
            child: _state('暂无数据，请稍后重试', headColor),
          )
        else
          for (var i = 0; i < items!.length; i++) _row(items![i], i, nameColor, headColor, divider),
      ]),
    );
  }

  Widget _state(String text, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.sx),
      child: Center(child: Text(text, style: AppTextStyles.cn(13.sx, color: color))),
    );
  }

  /// 行：排名（前三红）| 名称+代码 | 数值 30rpx
  Widget _row(Map<String, dynamic> item, int index, Color nameColor,
      Color headColor, Color divider) {
    final rank = index + 1;
    final rankColor =
        rank <= 3 ? const Color(0xFFE05665) : headColor;
    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRowTap == null ? null : () => onRowTap!(item),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.sx), // padding 24rpx 0
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF5F3F0),
                  width: 0.5)),
        ),
        child: Row(children: [
          SizedBox(
            width: 28.sx,
            child: Text('$rank',
                style: AppTextStyles.num(15.sx,
                    color: rankColor, weight: FontWeight.w600)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['shortName'] ?? item['name'] ?? '--'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cn(14.sx,
                      color: nameColor, weight: FontWeight.w500)), // 28rpx
              Text('${item['code'] ?? item['symbolCode'] ?? ''}',
                  style: AppTextStyles.num(11.sx, color: headColor)), // 22rpx
            ]),
          ),
          Text('${item['_displayValue'] ?? '--'}',
              style: AppTextStyles.num(15.sx, color: nameColor)), // 30rpx
        ]),
      ),
    );
    return row;
  }
}
