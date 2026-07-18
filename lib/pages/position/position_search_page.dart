import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';
import 'widgets/position_search_widgets.dart';

/// 持仓搜索页 — 1:1 复刻 uni-app pages/positionv1/search.vue
/// 搜索历史 + 热搜基金 + 模糊搜索(assetType=3); 选中记录搜索历史后:
///   - from=trading-record: 携带 {fundCode, fundName} pop 返回 (源码写 storage + navigateBack)
///   - 否则: 跳转持仓详情 /position-details
/// query: from, bookId
class PositionSearchPage extends ConsumerStatefulWidget {
  final String from;
  final String bookId;
  const PositionSearchPage({super.key, this.from = '', this.bookId = ''});

  @override
  ConsumerState<PositionSearchPage> createState() => _PositionSearchPageState();
}

/// 搜索结果/历史/热搜通用条目 (uni-app normalizeSymbolItem)
class PositionSymbolItem {
  final int symbolId;
  final int assetType;
  final String displayName;
  final String displayCode;
  final String code;
  final String uniqueSymbol;
  final String relatedIndexSymbolIds;

  const PositionSymbolItem({
    required this.symbolId,
    required this.assetType,
    required this.displayName,
    required this.displayCode,
    required this.code,
    required this.uniqueSymbol,
    required this.relatedIndexSymbolIds,
  });

  factory PositionSymbolItem.fromJson(Map<String, dynamic> j, int index) {
    String pick(List<String> keys, String fallback) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    final displayName = pick(['symbolName', 'name', 'displayName', 'shortName', 'fundName'], '未知基金');
    final displayCode = pick(['symbolCode', 'code', 'displayCode', 'ticker', 'symbol'], '--');
    final symbolId = (j['symbolId'] as num?)?.toInt() ?? 0;
    return PositionSymbolItem(
      symbolId: symbolId,
      assetType: (j['assetType'] as num?)?.toInt() ?? 3,
      displayName: displayName,
      displayCode: displayCode,
      code: pick(['code', 'symbolCode', 'fundCode'], ''),
      uniqueSymbol: pick(['uniqueSymbol'], symbolId > 0 ? '$symbolId' : '$displayCode-$index'),
      relatedIndexSymbolIds: j['relatedIndexSymbolIds']?.toString() ?? '',
    );
  }
}

class _PositionSearchPageState extends ConsumerState<PositionSearchPage> {
  final ApiClient _api = ApiClient();
  final TextEditingController _ctrl = TextEditingController();

  bool _isSearching = false;
  bool _hasLogin = false;
  List<PositionSymbolItem> _results = [];
  List<PositionSymbolItem> _history = [];
  List<PositionSymbolItem> _hot = [];
  Timer? _debounce;

  String get _keyword => _ctrl.text.trim();
  bool get _showResult => _keyword.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // uni-app onShow: 未登录 → 跳转登录; 已登录 → 拉取搜索信息
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await _checkLogin()) {
        if (mounted) context.replace('/login');
        return;
      }
      _fetchSearchInfo();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// uni-app checkLogin: token + userInfo 均存在
  Future<bool> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userInfo = prefs.getString('userInfo');
    final ok = token != null && token.isNotEmpty && userInfo != null && userInfo.isNotEmpty;
    if (mounted) setState(() => _hasLogin = ok);
    return ok;
  }

  /// uni-app unwrapResponseData: 数组直返 / {data:[...]} / {data:{...}}
  dynamic _unwrap(dynamic res) {
    if (res is List) return res;
    if (res is Map) {
      final d = res['data'];
      if (d is List || d is Map) return d;
    }
    return res ?? {};
  }

  /// uni-app fetchSearchInfo: assetGetSearchInfo(3) → history / hotSearch
  Future<void> _fetchSearchInfo() async {
    if (!_hasLogin) return;
    try {
      final res = await _api.get(ApiEndpoints.assetSymbolSearchInfo, queryParameters: {'assetType': 3});
      final data = _unwrap(res.data);
      final history = data is Map ? (data['history'] as List? ?? const []) : const [];
      final hot = data is Map
          ? ((data['hotSearch'] ?? data['hotTop10']) as List? ?? const [])
          : const [];
      if (!mounted) return;
      setState(() {
        _history = [
          for (var i = 0; i < history.length; i++)
            if (history[i] is Map) PositionSymbolItem.fromJson((history[i] as Map).cast<String, dynamic>(), i),
        ];
        _hot = [
          for (var i = 0; i < hot.length; i++)
            if (hot[i] is Map) PositionSymbolItem.fromJson((hot[i] as Map).cast<String, dynamic>(), i),
        ];
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _history = [];
          _hot = [];
        });
      }
    }
  }

  /// uni-app runSearch: assetSearchSymbol(keyword, 3)
  Future<void> _runSearch() async {
    if (!_hasLogin) return;
    final kw = _keyword;
    if (kw.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await _api.get(ApiEndpoints.assetSymbolSearch, queryParameters: {'keyword': kw, 'assetType': 3});
      final data = _unwrap(res.data);
      final list = data is List ? data : const [];
      if (!mounted || kw != _keyword) return; // 关键词已变化, 丢弃旧结果
      setState(() {
        _results = [
          for (var i = 0; i < list.length; i++)
            if (list[i] is Map) PositionSymbolItem.fromJson((list[i] as Map).cast<String, dynamic>(), i),
        ];
        _isSearching = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
    }
  }

  void _onKeywordChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch); // 300ms 防抖
  }

  void _onSearchConfirm() {
    _debounce?.cancel();
    if (_keyword.isEmpty) return;
    _runSearch();
  }

  /// uni-app clearKeyword: 仅清空关键词与结果 (「取消」按钮)
  void _clearKeyword() {
    _debounce?.cancel();
    _ctrl.clear();
    setState(() => _results = []);
  }

  /// uni-app clearHistory: assetDeleteSearchHistory → 重新拉取
  Future<void> _clearHistory() async {
    if (!_hasLogin) return;
    try {
      await _api.delete(ApiEndpoints.assetSymbolSearchHistory);
    } catch (_) {/* 源码未处理失败, 仍刷新 */}
    _fetchSearchInfo();
  }

  /// uni-app recordSearchHistory: assetRecordSearch(symbolId) → 刷新历史
  Future<void> _recordSearchHistory(PositionSymbolItem item) async {
    if (!_hasLogin || item.symbolId <= 0) return;
    try {
      await _api.post('${ApiEndpoints.assetSymbolSearchOperate}?symbolId=${item.symbolId}');
      _fetchSearchInfo();
    } catch (_) {/* 源码仅 console.error */}
  }

  /// uni-app handleSelectSymbol
  Future<void> _handleSelectSymbol(PositionSymbolItem item) async {
    if (!await _checkLogin()) return;
    _recordSearchHistory(item);
    if (!mounted) return;
    if (widget.from == 'trading-record') {
      // backToTradeRecord: 源码写 storage(positionTradeRecordSearchFund) + navigateBack
      // Flutter 等价: 携带结果 pop, 由调用方 await 接收
      context.pop({
        'source': 'trading-record',
        'fundCode': item.code.isNotEmpty ? item.code : item.displayCode,
        'fundName': item.displayName,
        if (widget.bookId.isNotEmpty) 'bookId': widget.bookId,
      });
      return;
    }
    // 跳转持仓详情 (返回时对齐 uni-app onShow 刷新搜索信息)
    context
        .push('/position-details?symbolId=${item.symbolId}&assetType=${item.assetType}')
        .then((_) => _fetchSearchInfo());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF111315) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(children: [
        CustomNavBar(
          title: '搜索',
          backgroundColor: isDark ? const Color(0xFF202125) : Colors.white,
          titleColor: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9), // 18rpx
            child: Column(children: [
              _buildSearchHeader(isDark),
              Expanded(child: _buildBody(isDark)),
            ]),
          ),
        ),
      ]),
    );
  }

  /// search-header: 搜索栏(80rpx 圆角白底) + 取消按钮
  Widget _buildSearchHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8), // padding-top 20rpx / bottom 16rpx
      child: Row(children: [
        Expanded(
          child: Container(
            height: 40, // 80rpx
            padding: const EdgeInsets.only(left: 17, right: 9), // 34rpx / 18rpx
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF282828) : Colors.white,
              borderRadius: BorderRadius.circular(24), // 48rpx
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.search,
                  onChanged: _onKeywordChanged,
                  onSubmitted: (_) => _onSearchConfirm(),
                  style: AppTextStyles.cn(14, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF4A4A4A)), // 28rpx
                  cursorColor: const Color(0xFFE05665),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '请输入名称/代码/拼音',
                    hintStyle:
                        AppTextStyles.cn(14, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB1B1B6)),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _onSearchConfirm,
                child: SizedBox(
                  width: 26, // 52rpx
                  height: 26,
                  child: Icon(AppIcons.search,
                      size: 22, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA7A7AB)),
                ),
              ),
            ]),
          ),
        ),
        GestureDetector(
          onTap: _clearKeyword,
          child: Padding(
            padding: const EdgeInsets.only(left: 10), // margin-left 20rpx
            child: Text('取消',
                style: AppTextStyles.cn(14, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8F8F95))),
          ),
        ),
      ]),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isSearching) {
      return ListView(children: [_statusBox('搜索中...', isDark)]);
    }
    if (_showResult) {
      if (_results.isEmpty) {
        return ListView(children: [_statusBox('暂无匹配基金', isDark)]);
      }
      // 搜索结果
      return ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14), // section-block margin-top 28rpx
            child: Column(children: [for (final item in _results) _resultItem(item, isDark)]),
          ),
        ],
      );
    }
    // 搜索历史 + 热搜基金
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        if (_history.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PositionSearchSectionHeader(
                title: '搜索历史',
                isDark: isDark,
                action: GestureDetector(
                  onTap: _clearHistory,
                  child: Padding(
                    padding: const EdgeInsets.all(4), // 8rpx
                    child: Icon(Icons.delete_outline,
                        size: 16, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA7A7AB)), // up-icon trash
                  ),
                ),
              ),
              Wrap(
                spacing: 8, // 16rpx
                runSpacing: 9, // 18rpx
                children: [
                  for (final item in _history)
                    PositionSearchHistoryTag(
                      text: item.displayName,
                      isDark: isDark,
                      onTap: () => _handleSelectSymbol(item),
                    ),
                ],
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PositionSearchSectionHeader(title: '热搜基金', isDark: isDark),
            if (_hot.isEmpty)
              _statusBox('暂无热搜数据', isDark)
            else
              for (var i = 0; i < _hot.length; i++) _hotItem(_hot[i], i, isDark),
          ]),
        ),
      ],
    );
  }

  /// status-box / empty-text: padding 48rpx 0 12rpx, 24rpx #aaaab0
  Widget _statusBox(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 6),
      child: Center(
        child: Text(text, style: AppTextStyles.cn(12, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFAAAAB0))),
      ),
    );
  }

  /// result-item: 名称+代码 + 右箭头, border-bottom 1rpx
  Widget _resultItem(PositionSymbolItem item, bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleSelectSymbol(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9), // 18rpx
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEDEF), width: 0.5),
          ),
        ),
        child: Row(children: [
          Expanded(child: _nameCodeColumn(item, isDark)),
          Icon(Icons.chevron_right, size: 15, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA7A7AB)), // uni-icons right
        ]),
      ),
    );
  }

  /// hot-item: 排名徽标(前3红) + 名称代码
  Widget _hotItem(PositionSymbolItem item, int index, bool isDark) {
    final rank = index + 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleSelectSymbol(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEDEF), width: 0.5),
          ),
        ),
        child: Row(children: [
          SizedBox(
            width: 16, // 32rpx
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: AppTextStyles.num(
                14, // 28rpx
                weight: FontWeight.w700,
                color: rank <= 3 ? const Color(0xFFE05665) : const Color(0xFF9D9DA4), // hot-rank-top
              ),
            ),
          ),
          const SizedBox(width: 9), // margin-left 18rpx
          Expanded(child: _nameCodeColumn(item, isDark)),
        ]),
      ),
    );
  }

  /// hot-main / result-main: 名称(28rpx) + 代码(22rpx)
  Widget _nameCodeColumn(PositionSymbolItem item, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        item.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.cn(14, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF3A3A3E), height: 1.4),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 3), // margin-top 6rpx
        child: Text(
          item.displayCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.cn(11, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA5A5AA)),
        ),
      ),
    ]);
  }
}
