import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 流入流出人数对比 — 1:1 复刻 uni-app pages/member/contrast.vue
///
/// 数据：GET /asset/api/Vip/flow-data/latest-summary（getVipLatestFlowDataSummary）。
///
/// 说明：uni-app 模板中的 ECharts 走势区块（.page-echarts）在源码里处于注释状态，
/// 本次 1:1 迁移同样不渲染；如后续源码放开注释，可用 fl_chart 复刻，见报告 REMAINING。
class ContrastPage extends ConsumerStatefulWidget {
  const ContrastPage({super.key});

  @override
  ConsumerState<ContrastPage> createState() => _ContrastPageState();
}

class _ContrastPageState extends ConsumerState<ContrastPage> {
  static const _endpoint = ApiEndpoints.vipFlowDataLatestSummary;

  final ApiClient _api = ApiClient();

  _FlowInfo _flowInfo = const _FlowInfo();

  @override
  void initState() {
    super.initState();
    // uni-app onMounted: loadLatestFlow()
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLatestFlow());
  }

  Future<void> _loadLatestFlow() async {
    try {
      final res = await _api.get(_endpoint);
      // unwrapApiData: res?.data ?? res ?? {}
      dynamic data = res.data;
      if (data is Map && data['data'] != null) data = data['data'];
      final map =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      if (mounted) setState(() => _flowInfo = _normalizeFlowInfo(map));
    } catch (_) {
      // uni-app: console.error + showToast('获取对比数据失败')
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取对比数据失败')),
        );
      }
    }
  }

  /// normalizeFlowInfo
  static _FlowInfo _normalizeFlowInfo(Map<String, dynamic> data) {
    final sourceRaw = _firstNonNull([
      data['latest'],
      data['summary'],
      data['latestSummary'],
      data['flowSummary'],
    ]);
    final source = sourceRaw is Map
        ? Map<String, dynamic>.from(sourceRaw)
        : data;
    final rawTime = _firstNonNull([
      source['recordDate'],
      source['recordTime'],
      source['time'],
      source['updateTime'],
      source['statTime'],
      source['createdTime'],
      source['publishTime'],
    ]);
    final inflow = _toNumber(_firstNonNull([
      source['inflowCount'],
      source['inCount'],
      source['inflowPeople'],
      source['inflowUsers'],
      source['inflow'],
    ]));
    final outflow = _toNumber(_firstNonNull([
      source['outflowCount'],
      source['outCount'],
      source['outflowPeople'],
      source['outflowUsers'],
      source['outflow'],
    ]));
    final total = inflow + outflow;
    final risePercent =
        total > 0 ? (inflow / total * 100).clamp(4.0, 96.0) : 50.0;
    return _FlowInfo(
      timeText: _formatDateTime(rawTime),
      inflowText: inflow.round().toString(),
      outflowText: outflow.round().toString(),
      risePercent: risePercent,
      fallPercent: 100 - risePercent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // .page-container: #F1F1F3 / .theme-dark #111315
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF1F1F3);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        // bgState:false → 纯色导航栏：浅 #ffffff / 深 #202125
        CustomNavBar(
          title: '流入流出人数对比',
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
        ),
        Expanded(
          // .page-content .ml-4.mr-4
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _buildTitleRow(isDark),
              _buildGridCard(isDark),
            ]),
          ),
        ),
      ]),
    );
  }

  /// .page-title（margin 30rpx 0）
  Widget _buildTitleRow(bool isDark) {
    final metaColor =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFF7F8088);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15), // 30rpx
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '流入流出人数对比',
            style: AppTextStyles.cn(19, // 38rpx
                weight: FontWeight.w600,
                height: 1,
                color:
                    isDark ? AppColors.darkText : const Color(0xFF303030)),
          ),
          // .page-title__meta（源码 font-size:14px，非 rpx）
          Row(children: [
            Text('更新时间', style: AppTextStyles.cn(14, color: metaColor, height: 1)),
            Text(_flowInfo.timeText,
                style: AppTextStyles.cn(14, color: metaColor, height: 1)),
          ]),
        ],
      ),
    );
  }

  /// .page-grid
  Widget _buildGridCard(bool isDark) {
    return Container(
      height: 116, // 232rpx
      margin: const EdgeInsets.only(top: 10), // 20rpx
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 0), // 30rpx 28rpx 0
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10), // 20rpx
        boxShadow: isDark
            ? null // .theme-dark .page-grid { box-shadow: none }
            : const [
                BoxShadow(
                  color: Color(0x14B7B7B7), // rgba(183,183,183,0.08)
                  blurRadius: 6, // 12rpx
                  spreadRadius: 1, // 2rpx
                  offset: Offset(0, 3), // 6rpx
                ),
              ],
      ),
      child: Column(children: [
        // .page-grid__title
        Text(
          '- 当日流入流出 -',
          style: AppTextStyles.cn(15, // 30rpx
              weight: FontWeight.w500,
              height: 1,
              color: isDark ? AppColors.darkText : const Color(0xFF333333)),
        ),
        // .page-grid__row（margin-top 48rpx）
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Row(children: [
            Expanded(
              child: Row(children: [
                Text('流入人数',
                    style: AppTextStyles.cn(14, // 28rpx
                        height: 1,
                        color: isDark
                            ? AppColors.darkText
                            : const Color(0xFF333333))),
                const SizedBox(width: 5), // margin-left 10rpx
                Text(
                  _flowInfo.inflowText,
                  style: AppTextStyles.num(17, // 34rpx
                      weight: FontWeight.w500,
                      color: const Color(0xFFFF6679)), // --rise 明暗同色
                ),
              ]),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _flowInfo.outflowText,
                    style: AppTextStyles.num(17,
                        weight: FontWeight.w500,
                        color: const Color(0xFF1AC0AD)), // --fall 明暗同色
                  ),
                  const SizedBox(width: 5), // margin-left 10rpx
                  Text('流出人数',
                      style: AppTextStyles.cn(14,
                          height: 1,
                          color: isDark
                              ? AppColors.darkText
                              : const Color(0xFF333333))),
                ],
              ),
            ),
          ]),
        ),
        // .page-grid__progress（margin-top 22rpx，height 22rpx，圆角 999rpx）
        Padding(
          padding: const EdgeInsets.only(top: 11),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 11,
              child: Row(children: [
                // .page-grid__progress-rise：clip-path 右上斜切 6rpx，margin-right 2rpx
                Expanded(
                  flex: _flowInfo.risePercent.round(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 1),
                    child: ClipPath(
                      clipper: const _SlantClip(rightTop: true),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Color(0xFFFF7E8D),
                            Color(0xFFFF5868),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                // .page-grid__progress-fall：clip-path 左下斜切 6rpx，margin-left 2rpx
                Expanded(
                  flex: _flowInfo.fallPercent.round(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 1),
                    child: ClipPath(
                      clipper: const _SlantClip(rightTop: false),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Color(0xFF16C0AD),
                            Color(0xFF99DFD8),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ===================== 格式化工具（逐项对齐 uni-app helpers） =====================

  static dynamic _firstNonNull(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      if (v is String && v.trim().isEmpty) continue;
      return v;
    }
    return null;
  }

  static String _pickText(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static double _toNumber(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// formatDateTime：MM-dd HH:mm，解析失败取 raw.slice(5,16)，空值 '--'
  static String _formatDateTime(dynamic value) {
    final raw = _pickText([value]);
    if (raw.isEmpty) return '--';
    final date = DateTime.tryParse(raw.replaceAll('/', '-'));
    if (date == null) {
      final s = raw.length > 16 ? raw.substring(5, 16) : raw;
      return s.replaceFirst('T', ' ');
    }
    String pad2(int v) => v.toString().padLeft(2, '0');
    return '${pad2(date.month)}-${pad2(date.day)} '
        '${pad2(date.hour)}:${pad2(date.minute)}';
  }
}

/// normalizeFlowInfo 输出
class _FlowInfo {
  final String timeText;
  final String inflowText;
  final String outflowText;
  final double risePercent;
  final double fallPercent;

  const _FlowInfo({
    this.timeText = '--',
    this.inflowText = '--',
    this.outflowText = '--',
    this.risePercent = 50,
    this.fallPercent = 50,
  });
}

/// 进度条斜切 —— 1:1 还原 uni-app clip-path（斜切量 6rpx=3）
/// rightTop=true：polygon(0 0, calc(100%-6rpx) 0, 100% 100%, 0 100%)
/// rightTop=false：polygon(0 0, 100% 0, 100% 100%, 6rpx 100%)
class _SlantClip extends CustomClipper<Path> {
  final bool rightTop;

  const _SlantClip({required this.rightTop});

  @override
  Path getClip(Size size) {
    const slant = 3.0; // 6rpx
    final path = Path();
    if (rightTop) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width - slant, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(slant, size.height)
        ..close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _SlantClip oldClipper) =>
      oldClipper.rightTop != rightTop;
}
