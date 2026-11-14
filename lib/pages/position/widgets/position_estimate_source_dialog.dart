import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/number_format.dart' show addThousandSeparator;
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';
import 'position_profit_color.dart';

/// 估值数据源切换弹框 — 1:1 复刻 .estimate-source-mask / .estimate-source-card
/// （index.vue:239-275 模板 + ~5000-5060 样式 + 7174 深色覆盖）
///
/// 打开时并行拉取 options（各数据源当日收益/收益率）与当前模式；
/// 确定 → PUT /usercenter/api/User/estimate-source {mode, bookId?} → 关闭 → 刷新持仓
class PositionEstimateSourceDialog extends StatefulWidget {
  final bool isDark;
  final int? bookId;
  final VoidCallback onSaved;

  const PositionEstimateSourceDialog({
    super.key,
    required this.isDark,
    required this.bookId,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isDark,
    required int? bookId,
    required VoidCallback onSaved,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '切换数据源',
      barrierColor: const Color(0x80000000), // rgba(0,0,0,0.5)
      pageBuilder: (context, _, _) => Center(
        child: PositionEstimateSourceDialog(
          isDark: isDark,
          bookId: bookId,
          onSaved: onSaved,
        ),
      ),
    );
  }

  @override
  State<PositionEstimateSourceDialog> createState() =>
      _PositionEstimateSourceDialogState();
}

class _Option {
  final dynamic mode;
  final String sourceName;
  final double? dayProfit;
  final double? dayProfitRate;

  const _Option(this.mode, this.sourceName, this.dayProfit, this.dayProfitRate);

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  factory _Option.fromJson(Map<String, dynamic> j) => _Option(
        j['mode'],
        '${j['sourceName'] ?? j['name'] ?? ''}',
        _num(j['dayProfit']),
        _num(j['dayProfitRate']),
      );
}

class _PositionEstimateSourceDialogState
    extends State<PositionEstimateSourceDialog> {
  bool _loading = true;
  bool _saving = false;
  List<_Option> _options = const [];
  dynamic _currentMode;
  dynamic _draftMode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic>? get _bookQuery =>
      widget.bookId != null ? {'bookId': widget.bookId} : null;

  /// 1:1 uni-app openEstimateSourcePopup：并行拉 options + 当前模式
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiClient();
      final results = await Future.wait([
        api.get(ApiEndpoints.estimateSourceOptions,
            queryParameters: _bookQuery),
        api.get(ApiEndpoints.estimateSource, queryParameters: _bookQuery),
      ]);
      final optionsData = results[0].data;
      final list = optionsData is Map && optionsData['data'] is List
          ? optionsData['data'] as List
          : (optionsData is List ? optionsData : const []);
      final currentData = results[1].data;
      final current = currentData is Map && currentData['data'] is Map
          ? currentData['data']['mode']
          : (currentData is Map ? currentData['mode'] : null);
      if (!mounted) return;
      setState(() {
        _options = list
            .whereType<Map<String, dynamic>>()
            .map(_Option.fromJson)
            .toList();
        _currentMode = current;
        _draftMode = current;
      });
    } catch (_) {
      if (!mounted) return;
      _toast('获取数据源失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// 1:1 uni-app confirmEstimateSource
  Future<void> _confirm() async {
    final mode = _draftMode;
    if (_saving || mode == null) return;
    if (mode == _currentMode) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient().put(
        ApiEndpoints.estimateSource,
        data: {
          'mode': mode,
          if (widget.bookId != null) 'bookId': widget.bookId,
        },
      );
      if (!mounted) return;
      _currentMode = mode;
      Navigator.of(context).pop();
      _toast('已切换数据源');
      widget.onSaved(); // 刷新持仓数据（1:1 loadPositionPageData）
    } catch (_) {
      if (!mounted) return;
      _toast('切换失败，请稍后重试');
      setState(() => _saving = false);
    }
  }

  /// 1:1 uni-app $utils.formatSignedMoney（千分位 + 2 位 + 符号）
  String _signed(double value) {
    final sign = value >= 0 ? '+' : '-';
    return sign + addThousandSeparator(value.abs().toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;
    final titleColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF1F2430);
    final headColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8F8F8F);
    final headBorder =
        isDark ? const Color(0x14FFFFFF) : const Color(0xFFF0F0F0);
    final nameColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF2C2323);
    final cancelBg = isDark ? const Color(0xFF2C2E33) : const Color(0xFFF3F4F6);
    final cancelColor =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFF6B6F78);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280.sx, // 560rpx
        padding: EdgeInsets.fromLTRB(
            20.sx, 18.sx, 20.sx, 14.sx), // 36rpx 40rpx 28rpx
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10.sx), // 20rpx
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // .estimate-source-card__title
          Text(
            '切换数据源',
            style: AppTextStyles.cn(16.sx,
                color: titleColor, weight: FontWeight.w600), // 32rpx 600
          ),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.sx), // 48rpx 0
              child: Text(
                '加载中…',
                style:
                    AppTextStyles.cn(13.sx, color: const Color(0xFF8F8F8F)),
              ),
            )
          else ...[
            // 表头：数据源 | 当日收益(150rpx 右对齐) | 收益率(150rpx 右对齐)
            Container(
              margin: EdgeInsets.only(top: 14.sx), // margin-top 28rpx
              padding: EdgeInsets.only(bottom: 6.sx), // padding-bottom 12rpx
              decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: headBorder, width: 0.5)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text('数据源',
                      style: AppTextStyles.cn(12.sx, color: headColor)),
                ),
                SizedBox(
                  width: 75.sx, // 150rpx
                  child: Text('当日收益',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.cn(12.sx, color: headColor)),
                ),
                SizedBox(
                  width: 75.sx,
                  child: Text('收益率',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.cn(12.sx, color: headColor)),
                ),
              ]),
            ),
            for (final option in _options)
              _buildOption(option, nameColor, isDark),
            // 底部按钮
            Padding(
              padding: EdgeInsets.only(top: 22.sx), // margin-top 44rpx
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 36.sx, // 72rpx
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cancelBg,
                        borderRadius: BorderRadius.circular(18.sx), // 36rpx
                      ),
                      child: Text(
                        '取消',
                        style: AppTextStyles.cn(14.sx,
                            color: cancelColor, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.sx), // gap 24rpx
                Expanded(
                  child: GestureDetector(
                    onTap: _saving ? null : _confirm,
                    child: Opacity(
                      opacity: _saving ? 0.6 : 1, // --disabled
                      child: Container(
                        height: 36.sx,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE05665),
                          borderRadius: BorderRadius.circular(18.sx),
                        ),
                        child: Text(
                          _saving ? '保存中…' : '确定',
                          style: AppTextStyles.cn(14.sx,
                              color: Colors.white, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  /// .estimate-source-card__item：radio(32rpx) + 名称(1fr) + 收益/收益率(各 150rpx 右对齐)
  Widget _buildOption(_Option option, Color nameColor, bool isDark) {
    final active = option.mode == _draftMode;
    return GestureDetector(
      onTap: () => setState(() => _draftMode = option.mode),
      child: Container(
        margin: EdgeInsets.only(top: 16.sx), // margin-top 32rpx
        color: Colors.transparent,
        child: Row(children: [
          // .estimate-source-card__radio：32rpx 边框 #d8dbe0，选中内点 18rpx #E05665
          Container(
            width: 16.sx, // 32rpx
            height: 16.sx,
            margin: EdgeInsets.only(right: 9.sx), // 18rpx
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD8DBE0), width: 1),
            ),
            child: active
                ? Center(
                    child: Container(
                      width: 9.sx, // 18rpx
                      height: 9.sx,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE05665),
                      ),
                    ),
                  )
                : null,
          ),
          SizedBox(width: 8.sx), // column-gap 16rpx - 已含 radio margin 18rpx
          Expanded(
            child: Text(
              option.sourceName,
              style: AppTextStyles.cn(
                14.sx, // 28rpx
                color:
                    active ? const Color(0xFFE05665) : nameColor,
                weight: active ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 75.sx, // 150rpx
            child: Text(
              option.dayProfit == null ? '--' : _signed(option.dayProfit!),
              textAlign: TextAlign.right,
              style: AppTextStyles.num(
                13.sx, // 26rpx
                color: option.dayProfit == null
                    ? nameColor
                    : profitColor(option.dayProfit, isDark),
                weight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 75.sx,
            child: Text(
              option.dayProfitRate == null
                  ? '--'
                  : '${_signed(option.dayProfitRate!)}%',
              textAlign: TextAlign.right,
              style: AppTextStyles.num(
                13.sx,
                color: option.dayProfitRate == null
                    ? nameColor
                    : profitColor(option.dayProfitRate, isDark),
                weight: FontWeight.w600,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
