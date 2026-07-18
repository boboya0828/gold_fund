import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/widgets/custom_nav_bar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';

/// 上传流程内的基金搜索页
/// 1:1 复刻 uni-app (zdj-v1/pages/index/fund/upload/search.vue)
/// selectMode=emit 时: pop 返回 { result, entryType:'fund', entryKey }
/// (对应 uni-app uni.$emit('manualMassUploadSelect', ...) + navigateBack)
class UploadSearchPage extends StatefulWidget {
  final String? bookId;
  final String selectMode; // 'navigate' | 'emit'
  final String entryKey;

  const UploadSearchPage({
    super.key,
    this.bookId,
    this.selectMode = 'navigate',
    this.entryKey = '',
  });

  @override
  State<UploadSearchPage> createState() => _UploadSearchPageState();
}

class _UploadSearchPageState extends State<UploadSearchPage> {
  final ApiClient _api = ApiClient();
  final TextEditingController _ctrl = TextEditingController();
  Timer? _searchTimer;

  bool _isSearching = false;
  List<_SymbolItem> _searchResultList = [];
  List<_SymbolItem> _historyList = [];
  List<_SymbolItem> _hotList = [];

  String get _keyword => _ctrl.text.trim();
  bool get _showSearchResult => _keyword.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // 对应 onShow: fetchSearchInfo
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSearchInfo());
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // ===== 数据 =====

  /// 对应 fetchSearchInfo: history + hotSearch
  Future<void> _fetchSearchInfo() async {
    try {
      final res = await _api.get(ApiEndpoints.assetSymbolSearchInfo);
      final data = _unwrapResponseData(res.data);
      List raw(dynamic v) => v is List ? v : const [];
      final history = data is Map ? raw(data['history']) : const [];
      final hot = data is Map ? raw(data['hotSearch'] ?? data['hotTop10']) : const [];
      if (!mounted) return;
      setState(() {
        _historyList = [
          for (var i = 0; i < history.length; i++) _SymbolItem.normalize(history[i], i),
        ];
        _hotList = [
          for (var i = 0; i < hot.length; i++) _SymbolItem.normalize(hot[i], i),
        ];
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _historyList = [];
          _hotList = [];
        });
      }
    }
  }

  /// 对应 unwrapResponseData
  static dynamic _unwrapResponseData(dynamic res) {
    if (res is List) return res;
    if (res is Map && res['data'] is List) return res['data'];
    if (res is Map && res['data'] is Map) return res['data'];
    return res ?? {};
  }

  /// 对应 runSearch
  Future<void> _runSearch() async {
    final kw = _keyword;
    if (kw.isEmpty) {
      setState(() => _searchResultList = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await _api.get(ApiEndpoints.assetSymbolSearch, queryParameters: {'keyword': kw});
      final data = _unwrapResponseData(res.data);
      final list = data is List ? data : const [];
      if (!mounted || kw != _keyword) return;
      setState(() {
        _searchResultList = [
          for (var i = 0; i < list.length; i++) _SymbolItem.normalize(list[i], i),
        ];
        _isSearching = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchResultList = [];
          _isSearching = false;
        });
      }
    }
  }

  /// 对应 handleKeywordInput (300ms 防抖)
  void _handleKeywordInput(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), _runSearch);
    setState(() {}); // keyword 变化驱动 showSearchResult
  }

  /// 对应 handleSearchConfirm
  void _handleSearchConfirm() {
    _searchTimer?.cancel();
    _searchTimer = null;
    if (_keyword.isEmpty) return;
    _runSearch();
  }

  /// 对应 clearKeyword
  void _clearKeyword() {
    _searchTimer?.cancel();
    _searchTimer = null;
    _ctrl.clear();
    setState(() => _searchResultList = []);
  }

  /// 对应 clearHistory
  Future<void> _clearHistory() async {
    try {
      await _api.delete(ApiEndpoints.assetSymbolSearchHistory);
    } catch (_) {}
    _fetchSearchInfo();
  }

  /// 对应 buildTargetUrl
  String _buildTargetUrl(_SymbolItem item) {
    final hasBookId = widget.bookId != null && widget.bookId!.isNotEmpty;
    final query = [
      'uniqueSymbol=${Uri.encodeComponent(item.uniqueSymbol)}',
      'shortName=${Uri.encodeComponent(item.shortName)}',
      'symbolId=${Uri.encodeComponent(item.symbolId?.toString() ?? '')}',
      if (hasBookId) 'bookId=${Uri.encodeComponent(widget.bookId!)}',
    ].join('&');
    return '/fund/upload/add-records?$query';
  }

  /// 对应 handleSelectSymbol
  void _handleSelectSymbol(_SymbolItem item) {
    if (widget.selectMode == 'emit') {
      // 对应 navigateBack + uni.$emit('manualMassUploadSelect', {...})
      context.pop({'result': item.raw, 'entryType': 'fund', 'entryKey': widget.entryKey});
      return;
    }
    context.push(_buildTargetUrl(item));
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF8F5F6);
    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        CustomNavBar(
          title: '搜索',
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBg,
          titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
        ),
        Expanded(
          child: SingleChildScrollView(
            // page-content: padding 12rpx 18rpx 24rpx
            padding: const EdgeInsets.fromLTRB(9, 6, 9, 12),
            child: Column(children: [
              _buildSearchHeader(isDark),
              _buildBody(isDark),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    final muted = isDark ? AppColors.darkTextSecondary : const Color(0xFFA7A7AB);
    return Row(children: [
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
                onChanged: _handleKeywordInput,
                onSubmitted: (_) => _handleSearchConfirm(),
                style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF4A4A4A)),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '请输入名称/代码/拼音',
                  hintStyle: AppTextStyles.cn(14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB1B1B6)),
                ),
              ),
            ),
            GestureDetector(
              onTap: _handleSearchConfirm,
              child: SizedBox(
                width: 26, // 52rpx
                height: 26,
                child: Icon(AppIcons.search, size: 22, color: muted),
              ),
            ),
          ]),
        ),
      ),
      GestureDetector(
        onTap: _clearKeyword,
        child: Padding(
          padding: const EdgeInsets.only(left: 10), // 20rpx
          child: Text('取消', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8F8F95), height: 1.0)),
        ),
      ),
    ]);
  }

  Widget _buildBody(bool isDark) {
    if (_isSearching) return _statusBox('搜索中...', isDark);
    if (_showSearchResult && _searchResultList.isEmpty) {
      return _statusBox('暂无匹配基金', isDark);
    }
    if (_showSearchResult) {
      // 搜索结果列表
      return Padding(
        padding: const EdgeInsets.only(top: 14), // section-block margin-top 28rpx
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3), // 6rpx
          child: Column(
            children: [for (final item in _searchResultList) _buildResultItem(item, isDark)],
          ),
        ),
      );
    }
    // 搜索历史 + 热搜 Top10
    return Column(children: [
      _buildSectionBlock(
        isDark,
        title: '搜索历史',
        action: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _clearHistory,
          child: Padding(
            padding: const EdgeInsets.all(4), // 8rpx
            child: Icon(Icons.delete_outline, size: 16, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFA7A7AB)),
          ),
        ),
        child: _historyList.isEmpty
            ? _emptyText('暂无搜索历史', isDark)
            : Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8, // 16rpx
                  runSpacing: 9, // 18rpx
                  children: [
                    for (final item in _historyList)
                      GestureDetector(
                        onTap: () => _handleSelectSymbol(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), // 22rpx / 12rpx
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF282828) : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.displayName,
                            style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF767676)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      _buildSectionBlock(
        isDark,
        title: '热搜基金Top10',
        child: _hotList.isEmpty
            ? _emptyText('暂无热搜数据', isDark)
            : Column(
                children: [
                  for (var i = 0; i < _hotList.length; i++) _buildHotItem(_hotList[i], i, isDark),
                ],
              ),
      ),
    ]);
  }

  Widget _buildSectionBlock(bool isDark, {required String title, Widget? action, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14), // 28rpx
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3), // 6rpx
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 11), // 22rpx
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: AppTextStyles.cn(13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF767676))),
                action ?? const SizedBox.shrink(),
              ],
            ),
          ),
          child,
        ]),
      ),
    );
  }

  Widget _statusBox(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 6), // 48rpx / 12rpx
        child: Center(
          child: Text(text, style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFAAAAB0))),
        ),
      );

  Widget _emptyText(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 6),
        child: Center(
          child: Text(text, style: AppTextStyles.cn(12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFAAAAB0))),
        ),
      );

  Widget _buildResultItem(_SymbolItem item, bool isDark) {
    final muted = isDark ? AppColors.darkTextSecondary : const Color(0xFFA7A7AB);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleSelectSymbol(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9), // 18rpx
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEDEF), width: 0.5)),
        ),
        child: Row(children: [
          Expanded(child: _nameCodeColumn(item, isDark)),
          Icon(Icons.chevron_right, size: 15, color: muted),
        ]),
      ),
    );
  }

  Widget _buildHotItem(_SymbolItem item, int index, bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleSelectSymbol(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEDEF), width: 0.5)),
        ),
        child: Row(children: [
          SizedBox(
            width: 16, // 32rpx
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: AppTextStyles.num(14,
                  weight: FontWeight.w700,
                  color: index < 3
                      ? AppColors.upColor
                      : (isDark ? AppColors.darkTextSecondary : const Color(0xFF9D9DA4))),
            ),
          ),
          const SizedBox(width: 9), // 18rpx
          Expanded(child: _nameCodeColumn(item, isDark)),
        ]),
      ),
    );
  }

  Widget _nameCodeColumn(_SymbolItem item, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        item.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF3A3A3E), height: 1.4),
      ),
      const SizedBox(height: 3), // 6rpx
      Text(
        item.displayCode,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.cn(11, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFA5A5AA)),
      ),
    ]);
  }
}

/// 搜索/历史/热搜条目 — 对应 normalizeSymbolItem
class _SymbolItem {
  final Map<String, dynamic> raw;
  final String displayName;
  final String displayCode;
  final String shortName;
  final String uniqueSymbol;
  final int? symbolId;

  const _SymbolItem({
    required this.raw,
    required this.displayName,
    required this.displayCode,
    required this.shortName,
    required this.uniqueSymbol,
    required this.symbolId,
  });

  factory _SymbolItem.normalize(dynamic item, int index) {
    final j = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    String pick(List<String> keys, String fallback) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    final displayName = pick(['symbolName', 'name', 'displayName', 'shortName', 'fundName'], '未知基金');
    final displayCode = pick(['symbolCode', 'code', 'displayCode', 'ticker', 'symbol'], '--');
    final shortName = j['shortName']?.toString().isNotEmpty == true ? j['shortName'].toString() : displayName;
    final symbolId = (j['symbolId'] as num?)?.toInt();
    final uniqueSymbol = j['uniqueSymbol']?.toString().isNotEmpty == true
        ? j['uniqueSymbol'].toString()
        : (symbolId != null ? '$symbolId' : '$displayCode-$index');
    return _SymbolItem(
      raw: j,
      displayName: displayName,
      displayCode: displayCode,
      shortName: shortName,
      uniqueSymbol: uniqueSymbol,
      symbolId: symbolId,
    );
  }
}
