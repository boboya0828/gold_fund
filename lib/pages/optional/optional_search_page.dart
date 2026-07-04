import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';

/// 自选搜索/新增页 — 1:1 复刻 uni-app (zdj/pages/optional/search.vue)
/// search-and-pick: 搜索基金 → 点某行 → 带 bookId 则加入自选并返回, 否则跳详情
class OptionalSearchPage extends ConsumerStatefulWidget {
  final int bookId;
  const OptionalSearchPage({super.key, this.bookId = 0});

  @override
  ConsumerState<OptionalSearchPage> createState() => _OptionalSearchPageState();
}

class _OptionalSearchPageState extends ConsumerState<OptionalSearchPage> {
  final ApiClient _api = ApiClient();
  final TextEditingController _ctrl = TextEditingController();

  bool _isSearching = false;
  bool _isAdding = false;
  List<SymbolResult> _results = [];
  List<SymbolResult> _hotList = [];
  Timer? _debounce;

  String get _keyword => _ctrl.text.trim();
  bool get _showResult => _keyword.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchHotList());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // ===== 数据 =====
  Future<void> _fetchHotList() async {
    try {
      final res = await _api.get(ApiEndpoints.assetSymbolSearchInfo, queryParameters: {'assetType': 3});
      final data = res.data is Map ? res.data['data'] : null;
      List raw = [];
      if (data is Map) {
        raw = (data['hotSearch'] ?? data['hotTop10'] ?? data['history'] ?? []) as List;
      } else if (data is List) {
        raw = data;
      }
      if (mounted) setState(() => _hotList = raw.map((e) => SymbolResult.fromJson(e as Map<String, dynamic>)).toList());
    } catch (_) {}
  }

  void _onKeywordChanged(String _) {
    _debounce?.cancel();
    if (_keyword.isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  void _onSubmit(String _) {
    _debounce?.cancel();
    if (_keyword.isEmpty) return;
    _runSearch();
  }

  Future<void> _runSearch() async {
    final kw = _keyword;
    if (kw.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await _api.get(ApiEndpoints.assetSymbolSearch, queryParameters: {'keyword': kw, 'assetType': 3});
      final data = res.data;
      List raw = [];
      if (data is Map && data['data'] is List) {
        raw = data['data'] as List;
      } else if (data is List) {
        raw = data;
      }
      if (!mounted) return;
      // 仅当关键词未变时才更新结果, 避免竞态
      if (kw != _keyword) return;
      setState(() {
        _results = raw.map((e) => SymbolResult.fromJson(e as Map<String, dynamic>)).toList();
        _isSearching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ===== 选中 → 加自选 =====
  Future<void> _handleSelect(SymbolResult item) async {
    if (_isAdding) return;
    // 无账本 → 跳详情, 不加自选
    if (widget.bookId == 0) {
      context.push('/position-details?symbolId=${item.symbolId}&assetType=${item.assetType}');
      return;
    }
    _isAdding = true;
    try {
      await _api.post(ApiEndpoints.favorite, data: {'bookId': widget.bookId, 'symbolId': item.symbolId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('添加成功'), duration: Duration(milliseconds: 1200)),
      );
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添加失败'), duration: Duration(milliseconds: 1500)),
        );
      }
    } finally {
      _isAdding = false;
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F5F5);
    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        CustomNavBar(
          title: '搜索',
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 10, 9, 0),
            child: Column(children: [
              _buildSearchHeader(isDark),
              Expanded(child: _buildBody(isDark)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildSearchHeader(bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(
        child: Container(
          height: 40,
          padding: const EdgeInsets.only(left: 17, right: 9),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF282828) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onKeywordChanged,
                onSubmitted: _onSubmit,
                style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF4A4A4A)),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '请输入名称/代码/拼音',
                  hintStyle: AppTextStyles.cn(14, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB1B1B6)),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _onSubmit(''),
              child: SizedBox(width: 26, height: 26, child: Icon(AppIcons.search, size: 20, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA7A7AB))),
            ),
          ]),
        ),
      ),
      GestureDetector(
        onTap: () { _ctrl.clear(); _debounce?.cancel(); setState(() => _results = []); },
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text('取消', style: AppTextStyles.cn(14, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8F8F95))),
        ),
      ),
    ]),
  );

  Widget _buildBody(bool isDark) {
    if (_isSearching) return _status('搜索中...', isDark);
    if (_showResult) {
      if (_results.isEmpty) return _status('暂无匹配基金', isDark);
      return ListView(
        padding: const EdgeInsets.only(top: 14, bottom: 12),
        children: [..._results.map((e) => _row(e, isDark))],
      );
    }
    // 热搜
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(3, 0, 3, 11),
          child: Text('热搜基金', style: AppTextStyles.cn(13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF767676))),
        ),
        if (_hotList.isEmpty)
          _status('暂无热搜数据', isDark)
        else
          ..._hotList.asMap().entries.map((e) => _row(e.value, isDark, rank: e.key + 1)),
      ],
    );
  }

  Widget _status(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 6),
    child: Center(child: Text(text, style: AppTextStyles.cn(12, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFAAAAB0)))),
  );

  /// 结果行/热搜行共用 (rank!=null 时为热搜, 显示排名徽标)
  Widget _row(SymbolResult item, bool isDark, {int? rank}) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _handleSelect(item),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFEDEF))),
      ),
      child: Row(children: [
        if (rank != null)
          SizedBox(
            width: 16,
            child: Text('$rank', textAlign: TextAlign.center, style: AppTextStyles.num(14, weight: FontWeight.w700,
              color: rank <= 3 ? const Color(0xFFE05665) : const Color(0xFF9D9DA4))),
          ),
        SizedBox(width: rank != null ? 9 : 3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF3A3A3E), height: 1.4)),
            const SizedBox(height: 3),
            Text(item.displayCode, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cn(11, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA5A5AA))),
          ]),
        ),
        Icon(Icons.chevron_right, size: 18, color: isDark ? const Color(0xFF6A6E78) : const Color(0xFFC8C8CE)),
      ]),
    ),
  );
}

class SymbolResult {
  final int symbolId;
  final int assetType;
  final String displayName;
  final String displayCode;
  const SymbolResult({required this.symbolId, required this.assetType, required this.displayName, required this.displayCode});

  factory SymbolResult.fromJson(Map<String, dynamic> j) {
    String pick(List<String> keys, String fallback) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }
    return SymbolResult(
      symbolId: (j['symbolId'] as num?)?.toInt() ?? 0,
      assetType: (j['assetType'] as num?)?.toInt() ?? 3,
      displayName: pick(['shortName', 'symbolName', 'name', 'fundName', 'displayName'], '未知基金'),
      displayCode: pick(['symbolCode', 'code', 'ticker', 'symbol', 'displayCode'], '--'),
    );
  }
}
