import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 关注飙升榜 — 1:1 复刻 uni-app pages/member/risingchart.vue
///
/// 数据：
///   GET /asset/api/Vip/attention-rise-ranks/{period}（getVipAttentionRiseRankByPeriod，period=today/week/month）
///   GET /asset/api/Vip/attention-rise-ranks/{id}（getVipAttentionRiseRankDetail，会员主页带 id 进入）
///
/// 入参对齐 uni-app onLoad(options)：period + id。
class RisingChartPage extends ConsumerStatefulWidget {
  /// today | week | month（非法值回退 today）
  final String period;

  /// 榜单详情 id；非空时按 id 拉取并隐藏期榜切换语义（对齐 detailId 逻辑）
  final String detailId;

  const RisingChartPage({super.key, this.period = 'today', this.detailId = ''});

  @override
  ConsumerState<RisingChartPage> createState() => _RisingChartPageState();
}

class _RisingChartPageState extends ConsumerState<RisingChartPage> {
  static const _rankBase = ApiEndpoints.vipAttentionRiseRanks;

  /// periodOptions
  static const _periodOptions = [
    (label: '日榜', value: 'today', title: '今日关注飙升榜'),
    (label: '周榜', value: 'week', title: '本周关注飙升榜'),
    (label: '月榜', value: 'month', title: '本月关注飙升榜'),
  ];

  final ApiClient _api = ApiClient();

  bool _showFilterPopup = false;
  bool _loading = false;
  String _activePeriod = 'today';
  String _detailId = '';
  Map<String, dynamic> _rankInfo = const {};
  List<_RankItem> _rankList = const [];

  @override
  void initState() {
    super.initState();
    // uni-app onLoad: period 校验 + id
    _activePeriod =
        _periodOptions.any((o) => o.value == widget.period) ? widget.period : 'today';
    _detailId = widget.detailId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRank());
  }

  ({String label, String value, String title}) get _activeOption =>
      _periodOptions.firstWhere((o) => o.value == _activePeriod,
          orElse: () => _periodOptions.first);

  /// pageTitle：rankInfo.title/name → 期榜默认标题
  String get _pageTitle => _pickText(
      [_rankInfo['title'], _rankInfo['name'], _activeOption.title]);

  /// dateRangeText
  String get _dateRangeText => _formatDateRange(_rankInfo);

  Future<void> _loadRank() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await _api.get(_detailId.isNotEmpty
          ? '$_rankBase/$_detailId'
          : '$_rankBase/$_activePeriod');
      // unwrapApiData: res?.data ?? res ?? {}
      dynamic data = res.data;
      if (data is Map && data['data'] != null) data = data['data'];
      // rankInfo = data?.data ?? data ?? {}
      if (data is Map && data['data'] is Map) data = data['data'];
      final info =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final rows = _unwrapRankItems(info);
      if (!mounted) return;
      setState(() {
        _rankInfo = info;
        _rankList = [
          for (var i = 0; i < rows.length; i++) _formatRankItem(rows[i], i),
        ];
      });
    } catch (_) {
      // uni-app: console.error + 置空 + toast 获取榜单失败
      if (mounted) {
        setState(() {
          _rankInfo = const {};
          _rankList = const [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取榜单失败')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// handlePeriodChange：先关弹层；同期且无 detailId 直接返回；否则清 detailId 重载
  void _handlePeriodChange(String value) {
    setState(() => _showFilterPopup = false);
    if (_activePeriod == value && _detailId.isEmpty) return;
    _detailId = '';
    _activePeriod = value;
    _loadRank();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // .theme-dark: 无背景图，#111315；浅色仅顶部 474rpx 背景图，其余为白
    final bg = isDark ? AppColors.darkBg : Colors.white;
    final muted =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8F7D69);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        // .page-container 背景图 selectlist.png（100% × 474rpx，顶部）
        if (!isDark)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 237, // 474rpx
            child: Image.asset(
              'assets/images/img/selectlist.png',
              fit: BoxFit.fill,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Column(children: [
          // bgState:false + lightNavBackground:transparent → 浅色透明导航栏
          CustomNavBar(
            title: '养基助手',
            backgroundColor:
                isDark ? AppColors.darkBg : Colors.transparent,
            titleColor:
                isDark ? AppColors.darkText : const Color(0xFF333333),
          ),
          Expanded(
            // .page-content .ml-4.mr-4
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                _buildHero(isDark, muted),
                _buildRankPanel(isDark),
              ]),
            ),
          ),
        ]),
        // .filter-popup-mask + .filter-popup（top:172rpx right:28rpx）
        if (_showFilterPopup) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showFilterPopup = false),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 86, // 172rpx
            right: 14, // 28rpx
            child: _buildFilterPopup(isDark),
          ),
        ],
      ]),
    );
  }

  /// .hero-section
  Widget _buildHero(bool isDark, Color muted) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // .hero-title（margin-top 20rpx）
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          _pageTitle,
          style: AppTextStyles.cn(28, // 56rpx
              weight: FontWeight.w700,
              height: 1.16,
              color:
                  isDark ? AppColors.darkText : const Color(0xFF4A2308)),
        ),
      ),
      // .hero-meta-row（margin 16rpx 0）
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // .hero-meta：统计区间：MM.DD-MM.DD（numFamily）
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '统计区间：',
                    style: AppTextStyles.cn(11, color: muted, height: 1)),
                TextSpan(
                    text: _dateRangeText,
                    style: AppTextStyles.num(11, color: muted)),
              ]),
            ),
            // .hero-filter
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showFilterPopup = true),
              child: Row(children: [
                Text(
                  _activeOption.label,
                  style: AppTextStyles.cn(12, // 24rpx
                      height: 1,
                      color: isDark
                          ? const Color(0xFFA7ADB8)
                          : const Color(0xFF8D7B68)),
                ),
                const SizedBox(width: 4), // gap 8rpx
                Icon(
                  Icons.keyboard_arrow_down, // uni-icons type="bottom" size 12
                  size: 12,
                  color: isDark
                      ? const Color(0xFFA7ADB8)
                      : const Color(0xFF7B7C81), // mutedIconColor
                ),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }

  /// .rank-panel
  Widget _buildRankPanel(bool isDark) {
    final borderColor =
        isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEFEF);
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(9)), // 18rpx 18rpx 0 0
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          _buildHead(isDark, borderColor),
          Expanded(child: _buildList(isDark)),
        ]),
      ),
    );
  }

  /// .rank-head：grid 58rpx | 1fr | 126rpx | 158rpx，column-gap 8rpx
  Widget _buildHead(bool isDark, Color borderColor) {
    final style = AppTextStyles.cn(12, // 24rpx
        height: 1,
        color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF989898));
    return Container(
      height: 38, // 76rpx
      padding: const EdgeInsets.symmetric(horizontal: 10), // 20rpx
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)), // 1rpx
      ),
      child: Row(children: [
        SizedBox(width: 29, child: Text('排名', style: style)), // 58rpx
        const SizedBox(width: 4), // column-gap 8rpx
        Expanded(child: Text('基金名称', style: style)),
        const SizedBox(width: 4),
        SizedBox(
            width: 63, // 126rpx
            child: Text('基金代码', style: style, textAlign: TextAlign.center)),
        const SizedBox(width: 4),
        SizedBox(
            width: 79, // 158rpx
            child: Text('飙升幅度', style: style, textAlign: TextAlign.center)),
      ]),
    );
  }

  /// .rank-list
  Widget _buildList(bool isDark) {
    if (_loading) return _stateRow('加载中...', isDark);
    if (_rankList.isEmpty) return _stateRow('暂无榜单数据', isDark);
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      itemCount: _rankList.length,
      itemBuilder: (_, i) => _buildRow(_rankList[i], isDark),
    );
  }

  /// .state-row
  Widget _stateRow(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60), // 120rpx
      child: Center(
        child: Text(
          text,
          style: AppTextStyles.cn(13, // 26rpx
              color: isDark
                  ? const Color(0xFFA7ADB8)
                  : const Color(0xFF8F7D69)),
        ),
      ),
    );
  }

  /// .rank-row
  Widget _buildRow(_RankItem item, bool isDark) {
    final top3 = item.rank >= 1 && item.rank <= 3;
    final indexColor = top3
        ? const Color(0xFFEFA53E) // is-top1/2/3（明暗同色）
        : (isDark ? AppColors.darkText : const Color(0xFF3B3B3B));
    final textColor =
        isDark ? AppColors.darkText : const Color(0xFF3D3D3D);

    return Container(
      height: 45, // 90rpx
      padding: const EdgeInsets.symmetric(horizontal: 10), // 20rpx
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF1F1F1),
            width: 0.5, // 1rpx
          ),
        ),
      ),
      child: Row(children: [
        // .rank-row__index numFamily（formatRank 补零）
        SizedBox(
          width: 29,
          child: Text(
            item.rank.toString().padLeft(2, '0'),
            style: AppTextStyles.num(15, color: indexColor), // 30rpx
          ),
        ),
        const SizedBox(width: 4),
        // .rank-row__name
        Expanded(
          child: Text(
            item.name,
            style: AppTextStyles.cn(14, height: 1.2, color: textColor), // 28rpx
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        // .rank-row__code numFamily
        SizedBox(
          width: 63,
          child: Text(
            item.code,
            style: AppTextStyles.num(14, // 28rpx
                color: isDark
                    ? const Color(0xFFA7ADB8)
                    : const Color(0xFF4E4E4E)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        // .rank-row__rate numFamily + upico.png
        SizedBox(
          width: 79,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  item.rate,
                  style: AppTextStyles.num(15, color: textColor), // 30rpx
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4), // 8rpx
                child: Image.asset(
                  'assets/images/img/upico.png',
                  width: 8, // 16rpx
                  height: 9, // 18rpx
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 8, height: 9),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  /// .filter-popup
  Widget _buildFilterPopup(bool isDark) {
    return Container(
      width: 82, // 164rpx
      padding: const EdgeInsets.symmetric(vertical: 5), // 10rpx 0
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8), // 16rpx
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0x47000000) // rgba(0,0,0,0.28)
                : const Color(0x1F4C3510), // rgba(76,53,16,0.12)
            blurRadius: 14, // 28rpx
            offset: const Offset(0, 4), // 8rpx
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final option in _periodOptions)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _handlePeriodChange(option.value),
            child: Container(
              height: 34, // 68rpx
              alignment: Alignment.center,
              color: _activePeriod == option.value
                  ? (isDark
                      ? const Color(0xFF282828)
                      : const Color(0xFFFFF6E8))
                  : null,
              child: Text(
                option.label,
                style: AppTextStyles.cn(13, // 26rpx
                    height: 1,
                    weight: _activePeriod == option.value
                        ? FontWeight.w600
                        : null,
                    color: _activePeriod == option.value
                        ? (isDark
                            ? const Color(0xFFE0B46C)
                            : const Color(0xFFC5862C))
                        : (isDark
                            ? const Color(0xFFA7ADB8)
                            : const Color(0xFF6F6252))),
              ),
            ),
          ),
      ]),
    );
  }

  // ===================== 数据归一化（逐项对齐 uni-app script） =====================

  /// unwrapRankItems
  static List<dynamic> _unwrapRankItems(Map<String, dynamic> data) {
    final inner = data['data'];
    final candidates = <dynamic>[
      data['items'],
      data['records'],
      data['list'],
      data['rows'],
      data['ranks'],
      data['details'],
      data['rankItems'],
      inner is Map ? inner['items'] : null,
      inner is Map ? inner['records'] : null,
      inner is Map ? inner['list'] : null,
      inner is Map ? inner['ranks'] : null,
      inner is Map ? inner['details'] : null,
    ];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return const [];
  }

  /// formatRankItem
  static _RankItem _formatRankItem(dynamic raw, int index) {
    final item =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final rank = _toFiniteNumber(
        _firstNonNull(
            [item['rank'], item['rankNo'], item['sort'], item['order']]),
        fallback: (index + 1).toDouble());
    final rateValue = _firstNonNull([
      item['riseRate'],
      item['riseRatio'],
      item['increaseRate'],
      item['increaseRatio'],
      item['changeRate'],
      item['changeRatio'],
      item['value'],
    ]);
    final rateText =
        _pickText([item['riseText'], item['rateText'], item['valueText']]);
    return _RankItem(
      rank: rank?.round() ?? (index + 1),
      name: _pickText([
        item['shortName'],
        item['symbolName'],
        item['fundName'],
        item['name'],
        item['title'],
      ]),
      code: _pickText([
        item['symbolCode'],
        item['code'],
        item['fundCode'],
        item['symbol'],
      ]),
      rate: rateText.isNotEmpty ? rateText : _formatRate(rateValue),
    );
  }

  /// formatDateRange：显式区间 → start/end（MM.DD）→ '--'
  static String _formatDateRange(Map<String, dynamic> data) {
    final explicit = _pickText([
      data['statRange'],
      data['dateRange'],
      data['periodRange'],
      data['rangeText'],
    ]);
    if (explicit.isNotEmpty) return explicit;
    final start = _formatMonthDay(_firstNonNull([
      data['startTime'],
      data['startDate'],
      data['beginTime'],
      data['beginDate'],
    ]));
    final end = _formatMonthDay(_firstNonNull([
      data['endTime'],
      data['endDate'],
      data['finishTime'],
      data['finishDate'],
    ]));
    if (start.isNotEmpty && end.isNotEmpty) return '$start-$end';
    return '--';
  }

  /// formatMonthDay：MM.DD
  static String _formatMonthDay(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '';
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m.$d';
  }

  /// formatRate：Number → xx.xx%，否则 '--'
  static String _formatRate(dynamic value) {
    final num = _toFiniteNumber(value);
    if (num == null) return '--';
    return '${num.toStringAsFixed(2)}%';
  }

  static double? _toFiniteNumber(dynamic value, {double? fallback}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

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

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceAll('/', '-'));
  }
}

/// formatRankItem 输出
class _RankItem {
  final int rank;
  final String name;
  final String code;
  final String rate;

  const _RankItem({
    required this.rank,
    required this.name,
    required this.code,
    required this.rate,
  });
}
