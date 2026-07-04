import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/fund_group_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';

/// 自选页面 - 1:1 复刻 uni-app (wxapp-yjzs/pages/optional/index.vue)
class OptionalPage extends ConsumerStatefulWidget {
  const OptionalPage({super.key});
  @override
  ConsumerState<OptionalPage> createState() => _OptionalPageState();
}

class _OptionalPageState extends ConsumerState<OptionalPage> {
  final ApiClient _api = ApiClient();

  List<FavItem> _items = [];
  List<String> _bookNames = ['全部'];
  List<int> _bookIds = [];
  int _tabIndex = 0;
  int _displayMode = 0; // 0=normal, 1=compact, 2=minimal
  String _sortField = '';
  String _sortOrder = 'desc';
  bool _showQuickMenu = false;
  bool _showTableMenu = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    SharedPreferences.getInstance().then((p) {
      final m = p.getInt('optionalMode') ?? 0;
      if (mounted) setState(() => _displayMode = m);
    });
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchBooks(), _fetchFavorites()]);
    if (mounted) setState(() {});
  }

  Future<void> _fetchBooks() async {
    try {
      final res = await _api.get(ApiEndpoints.favoriteBooks);
      final data = res.data;
      List list = [];
      if (data is List) { list = data; }
      else if (data?['data'] is List) { list = data!['data']; }
      final names = ['全部']; final ids = [0];
      for (final b in list) {
        names.add((b['bookName'] ?? b['name'] ?? '账本') as String);
        ids.add(b['bookId'] as int? ?? 0);
      }
      _bookNames = names; _bookIds = ids;
    } catch (_) {}
  }

  Future<void> _fetchFavorites() async {
    try {
      final bookId = _tabIndex == 0 ? 0 : (_bookIds.length > _tabIndex ? _bookIds[_tabIndex] : 0);
      final res = await _api.get('${ApiEndpoints.favoriteByBook}/$bookId');
      final data = res.data;
      List raw = [];
      if (data?['data'] is List) { raw = data!['data'] as List; }
      else if (data is List) { raw = data; }
      _items = raw.cast<Map<String, dynamic>>().map((e) => _norm(e)).toList();
    } catch (_) {}
  }

  FavItem _norm(Map<String, dynamic> item) {
    final lp = item['latestPrice'] as Map<String, dynamic>? ?? {};
    final indicators = (item['indicators'] ?? item['indicatorList'] ?? lp['indicatorList']) as List?;
    final firstInd = indicators != null && indicators.isNotEmpty ? IndicatorRef.fromJson(indicators[0] as Map<String, dynamic>) : null;
    return FavItem(
      symbolId: item['symbolId'] as int? ?? 0,
      code: (item['symbolCode'] ?? item['code'] ?? '--') as String,
      name: (item['shortName'] ?? item['name'] ?? '--') as String,
      dayChangeRate: _nd(lp['chgRate'] ?? item['dayChangeRatio']),
      preClose: _nd(lp['preClose'] ?? item['preClose']),
      indicator: firstInd,
      favoriteId: item['favoriteId'] as int? ?? item['id'] as int? ?? 0,
      assetType: item['assetType'] as int? ?? 3,
      assetId: item['assetId'] as int? ?? 0,
      isHold: item['isHold'] == true || item['isHold'] == 1 || item['isHold'] == 'true',
      indicators: indicators?.cast<Map<String, dynamic>>().map((e) => IndicatorRef.fromJson(e)).toList() ?? [],
    );
  }

  double _nd(dynamic v) { if (v == null) return 0; if (v is num) return v.toDouble(); return double.tryParse(v.toString()) ?? 0; }

  List<FavItem> get _sorted {
    final list = List<FavItem>.from(_items);
    if (_sortField.isEmpty) return list;
    list.sort((a, b) {
      double av, bv;
      if (_sortField == 'increaseRatio') { av = a.indicator?.changeRatio ?? 0; bv = b.indicator?.changeRatio ?? 0; }
      else { av = a.dayChangeRate; bv = b.dayChangeRate; }
      return _sortOrder == 'asc' ? av.compareTo(bv) : bv.compareTo(av);
    });
    return list;
  }

  void _toggleSort(String f) {
    setState(() { if (_sortField == f) { _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc'; } else { _sortField = f; _sortOrder = 'desc'; } });
  }

  /// 跳转搜索/新增自选页, 携带当前账本 id, 返回后刷新列表
  Future<void> _openSearch() async {
    final bookId = _tabIndex == 0 ? 0 : (_bookIds.length > _tabIndex ? _bookIds[_tabIndex] : 0);
    final changed = await context.push('/optional-search?bookId=$bookId');
    if (changed == true && mounted) _loadData();
  }

  Future<void> _deleteItem(FavItem item) async {
    // 3 条回退路径，对齐 uni-app
    try {
      if (item.favoriteId > 0) {
        await _api.delete('${ApiEndpoints.favorite}/${item.favoriteId}');
      } else if (item.symbolId > 0) {
        await _api.delete('${ApiEndpoints.favorite}/symbol/${item.symbolId}');
      } else if (item.assetId > 0) {
        await _api.delete('${ApiEndpoints.assetDetail}/${item.assetId}');
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: ${e.toString()}'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF1F1F3);
    final w = MediaQuery.of(context).size.width;
    // Column widths matching uni-app grid: 2fr 0.92fr 0.92fr (name ~52%, indicator ~24%, change ~24%)
    final nameW = (w - 32) * 0.52;
    final colW = (w - 32) * 0.24;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        // 背景渐变图放在 SafeArea 外层，延伸到状态栏后面 (状态栏透明)，
        // 否则状态栏那一条会露出纯色 Scaffold 背景，跟渐变头部断层。
        if (!isDark)
          const Positioned(top: 0, left: 0, right: 0, child: Image(
            image: AssetImage('assets/images/img/position-bg1.png'), fit: BoxFit.fitWidth, alignment: Alignment.topCenter)),
        SafeArea(
          child: RefreshIndicator(
            color: AppColors.upColor,
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(children: [
                _buildNav(isDark, topPad),
                _buildTableHeader(isDark, nameW, colW),
                _buildList(isDark, nameW, colW),
                const SizedBox(height: 120),
              ]),
            ),
          ),
        ),
        if (_showQuickMenu)
          GestureDetector(onTap: () => setState(() => _showQuickMenu = false), child: Container(color: isDark ? Colors.black.withAlpha(115) : Colors.black.withAlpha(46))),
        if (_showQuickMenu) Positioned(right: 12, top: topPad + 44, child: _quickMenu(isDark)),
        if (_showTableMenu)
          GestureDetector(onTap: () => setState(() => _showTableMenu = false), child: Container(color: isDark ? Colors.black.withAlpha(115) : Colors.black.withAlpha(46))),
        if (_showTableMenu) Positioned(right: 16, top: 160, child: _tableModeMenu(isDark)),
      ]),
    );
  }

  Widget _buildNav(bool isDark, double topPad) => Container(
    padding: EdgeInsets.only(top: topPad > 0 ? 0 : 8),
    // 背景渐变图已上移至外层 Stack (延伸到状态栏后)，这里只保留纯色兜底
    color: isDark ? const Color(0xFF202125) : const Color(0xFFF1F1F3),
    child: Column(children: [
      const SizedBox(height: 5),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(height: 29, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(onTap: () => FundGroupService.open(context), child: Container(width: 80, height: 29, decoration: BoxDecoration(
            color: isDark ? Colors.transparent : Colors.white, borderRadius: BorderRadius.circular(25)),
            alignment: Alignment.center, child: Image.asset('assets/images/img/fundqun.png', width: 65, height: 12.5))),
          Text('养基助手', style: AppTextStyles.cn(16, color: isDark ? const Color(0xFFD6D8DE) : const Color(0xFF452008), weight: FontWeight.w700)),
          Container(width: 80, height: 29, decoration: BoxDecoration(
            color: isDark ? Colors.transparent : Colors.white, borderRadius: BorderRadius.circular(25)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(onTap: _openSearch, child: Icon(AppIcons.search, size: 20, color: isDark ? const Color(0xFFB7BBC4) : const Color(0xFF452008))),
              const SizedBox(width: 16),
              GestureDetector(onTap: () => setState(() { _showTableMenu = false; _showQuickMenu = !_showQuickMenu; }),
                child: Icon(AppIcons.add, size: 20, color: isDark ? const Color(0xFFB7BBC4) : const Color(0xFF452008))),
            ])),
        ])),
      ),
      const SizedBox(height: 10),
      SizedBox(height: 34, child: ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _bookNames.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () { setState(() => _tabIndex = i); _loadData(); },
          child: Padding(padding: const EdgeInsets.only(right: 24), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(_bookNames[i], style: AppTextStyles.cn(15,
              color: _tabIndex == i ? (isDark ? Colors.white : const Color(0xFF452008)) : (isDark ? const Color(0xFF777C86) : const Color(0xFF9A7A61)),
              weight: _tabIndex == i ? FontWeight.w700 : FontWeight.w400)),
            const SizedBox(height: 4),
            Container(width: 27, height: 4, decoration: BoxDecoration(
              color: _tabIndex == i ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(999))),
          ])),
        ),
      )),
      const SizedBox(height: 5),
    ]));

  Widget _buildTableHeader(bool isDark, double nameW, double colW) {
    final hc = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8D8B87);
    final now = DateTime.now();
    final dl = '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC))),
      ),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC)))),
        child: Row(children: [
          SizedBox(width: nameW, child: Align(alignment: Alignment.centerLeft, child: GestureDetector(
            onTap: () => setState(() { _showQuickMenu = false; _showTableMenu = !_showTableMenu; }),
            child: Icon(_displayMode == 0 ? Icons.menu : _displayMode == 1 ? Icons.format_list_bulleted : Icons.more_horiz, size: 20, color: hc)))),
          SizedBox(width: colW, child: _sortBtn('关联板块', 'increaseRatio', dl, isDark)),
          SizedBox(width: colW, child: _sortBtn('当日涨幅', 'dayProfitRate', dl, isDark)),
        ])));
  }

  Widget _sortBtn(String title, String field, String dl, bool isDark) {
    final active = _sortField == field;
    final ac = AppColors.primary;
    final ic = isDark ? const Color(0xFFA7ADB8) : const Color(0xFFdddddd);
    return GestureDetector(onTap: () => _toggleSort(field),
      behavior: HitTestBehavior.opaque,
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Flexible(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.cn(11, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8D8B87))),
          Text(dl, style: AppTextStyles.num(9, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFC0BAB3))),
        ])),
        const SizedBox(width: 1),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_drop_up, size: 7, color: active && _sortOrder == 'asc' ? ac : ic),
          Icon(Icons.arrow_drop_down, size: 7, color: active && _sortOrder == 'desc' ? ac : ic),
        ]),
      ]));
  }

  Widget _buildList(bool isDark, double nameW, double colW) {
    final sorted = _sorted;
    if (sorted.isEmpty) {
      return Padding(padding: const EdgeInsets.only(top: 80), child: Column(children: [
        Text('暂无自选', style: AppTextStyles.cn(15, color: isDark ? AppColors.darkText : const Color(0xFF333333), weight: FontWeight.w600)),
        const SizedBox(height: 9),
        Text('添加基金后，可在这里查看关联板块和当日涨幅', style: AppTextStyles.cn(12, color: const Color(0xFF8d8b87))),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _openSearch,
          child: Container(width: 110, height: 36, decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.center, child: Text('新增自选', style: AppTextStyles.cn(13, color: Colors.white)))),
      ]));
    }
    return Container(color: isDark ? AppColors.darkSurface : Colors.white,
      child: Column(children: [
        ...sorted.asMap().entries.map((e) => _buildRow(e.value, isDark, nameW, colW)),
        Padding(padding: const EdgeInsets.only(left: 16, top: 10, bottom: 100),
          child: Align(alignment: Alignment.centerLeft, child: GestureDetector(
            onTap: _openSearch,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(AppIcons.add, size: 12, color: const Color(0xFF7A7A82)),
              const SizedBox(width: 2), Text('新增自选', style: AppTextStyles.cn(11, color: const Color(0xFF7A7A82))),
            ])))),
      ]));
  }

  Widget _buildRow(FavItem item, bool isDark, double nameW, double colW) {
    final ind = item.indicator;
    final indRate = ind?.changeRatio ?? 0;
    final dayRate = item.dayChangeRate;
    final showIndicator = _displayMode == 0 || _displayMode == 1; // normal/compact show indicator
    final showPreClose = _displayMode == 0; // only normal shows preClose

    return GestureDetector(
      onTap: () {
        context.push('/position-details?symbolId=${item.symbolId}&assetType=${item.assetType}');
      },
      onLongPress: () => _showDeleteConfirm(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC), width: 0.5))),
        child: SizedBox(height: 40, child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Name column (52%)
          SizedBox(width: nameW, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(item.name, style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : Colors.black, weight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_displayMode == 0 || _displayMode == 1) ...[
              const SizedBox(height: 4),
              Row(children: [
                Text(item.code, style: AppTextStyles.cn(11, color: isDark ? const Color(0xFF9297A1) : const Color(0xFFA49A92))),
                if (item.isHold) ...[
                  const SizedBox(width: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.primary.withAlpha(71)), borderRadius: BorderRadius.circular(3),
                      color: AppColors.primary.withAlpha(20)),
                    child: Text('持有', style: AppTextStyles.cn(9, color: AppColors.primary))),
                ],
              ]),
            ],
          ])),
          // Indicator column (24%) — 右对齐 (源码 .holding-cell align-items:end)
          SizedBox(width: colW,
            child: showIndicator
                ? Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (ind != null) ...[
                    Text('${_fs(indRate)}%', style: AppTextStyles.num(13, color: _pc(indRate, isDark), weight: FontWeight.w500)),
                    if (_displayMode == 0)
                      Text(ind.name ?? ind.shortName ?? '--', style: AppTextStyles.cn(11, color: const Color(0xFF8D8B87)), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                  ] else ...[
                    Text('-', style: AppTextStyles.cn(14, color: const Color(0xFF8D8B87)), textAlign: TextAlign.end),
                    if (_displayMode == 0) Text('-', style: AppTextStyles.cn(11, color: const Color(0xFF8D8B87)), textAlign: TextAlign.end),
                  ],
                ]) : Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${_fs(indRate)}%', style: AppTextStyles.num(13, color: _pc(indRate, isDark), weight: FontWeight.w500)),
                ])),
          // Change column (24%) — 右对齐
          SizedBox(width: colW,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_fs(dayRate)}%', style: AppTextStyles.num(13, color: _pc(dayRate, isDark), weight: FontWeight.w500)),
              if (showPreClose)
                Text(item.preClose.toStringAsFixed(2), style: AppTextStyles.num(10, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFA49A92))),
            ])),
        ])),
      ),
    );
  }

  void _showDeleteConfirm(FavItem item) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定要删除「${item.name}」吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () { Navigator.pop(ctx); _deleteItem(item); },
          child: const Text('确认删除', style: TextStyle(color: AppColors.primary))),
      ],
    ));
  }

  Widget _quickMenu(bool isDark) => Container(width: 110, decoration: BoxDecoration(
    color: isDark ? const Color(0xFF282B32) : Colors.white, borderRadius: BorderRadius.circular(8),
    boxShadow: isDark ? [BoxShadow(color: Colors.black.withAlpha(87), blurRadius: 17)] : null),
    child: Column(children: [
      _menuItem(AppIcons.add, '添加自选', isDark, () {
        setState(() => _showQuickMenu = false);
        _openSearch();
      }),
      _menuDiv(isDark), _menuItem(AppIcons.copyPage, '识别导入', isDark, () {
        setState(() => _showQuickMenu = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('识别导入开发中'), duration: Duration(seconds: 2)),
        );
      }),
      _menuDiv(isDark), _menuItem(AppIcons.settings, '分组管理', isDark, () {
        setState(() => _showQuickMenu = false);
        context.push('/ledger');
      }),
    ]));

  Widget _menuItem(IconData icon, String label, bool isDark, VoidCallback onTap) => GestureDetector(
    onTap: onTap, child: Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: isDark ? null : const BoxDecoration(),
      child: Row(children: [Icon(icon, size: 18, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF4A5168)),
        const SizedBox(width: 7), Text(label, style: AppTextStyles.cn(12, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF26304D)))])),
  );

  Widget _menuDiv(bool isDark) => Container(height: 0.5, margin: const EdgeInsets.only(left: 36, right: 12),
    color: isDark ? const Color(0xFF3A3E48) : const Color(0xFFEEF1F5));

  Widget _tableModeMenu(bool isDark) => Container(width: 82, decoration: BoxDecoration(
    color: isDark ? const Color(0xFF282B32) : Colors.white, borderRadius: BorderRadius.circular(8),
    boxShadow: [BoxShadow(color: isDark ? Colors.black.withAlpha(87) : const Color(0x291A2240), blurRadius: 14)]),
    child: Column(children: [
      _modeItem(Icons.menu, '普通', 0, isDark), _modeDiv(isDark),
      _modeItem(Icons.format_list_bulleted, '简洁', 1, isDark), _modeDiv(isDark),
      _modeItem(Icons.more_horiz, '极简', 2, isDark),
    ]));

  Widget _modeItem(IconData icon, String label, int mode, bool isDark) {
    final active = _displayMode == mode;
    return GestureDetector(onTap: () {
      setState(() { _displayMode = mode; _showTableMenu = false; });
      SharedPreferences.getInstance().then((p) => p.setInt('optionalMode', mode));
    }, child: Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 10),
      color: active ? (isDark ? const Color(0xFF2A2024) : const Color(0xFFFFF5F6)) : null,
      child: Row(children: [
        Icon(icon, size: 18, color: active ? AppColors.primary : (isDark ? const Color(0xFF8F96A3) : const Color(0xFF888888))),
        const SizedBox(width: 7), Text(label, style: AppTextStyles.cn(14, color: active ? AppColors.primary : (isDark ? const Color(0xFFD7DAE0) : const Color(0xFF555555)), weight: active ? FontWeight.w600 : FontWeight.w400)),
      ])));
  }

  Widget _modeDiv(bool isDark) => Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 10),
    color: isDark ? const Color(0xFF3A3E48) : const Color(0xFFF0F0F0));

  String _fs(double v) => '${v >= 0 ? "+" : ""}${v.toStringAsFixed(2)}';
  Color _pc(double v, bool d) => v == 0 ? (d ? const Color(0xFFA7ADB8) : Colors.black) : v > 0 ? AppColors.upColor : (d ? const Color(0xFF20B979) : AppColors.downColor);
}

class FavItem {
  final int symbolId, assetType, favoriteId, assetId;
  final String code, name;
  final double dayChangeRate, preClose;
  final IndicatorRef? indicator;
  final List<IndicatorRef> indicators;
  final bool isHold;
  const FavItem({required this.symbolId, required this.code, required this.name, required this.dayChangeRate, required this.preClose, this.indicator, required this.favoriteId, required this.assetType, required this.assetId, required this.isHold, this.indicators = const []});
}

class IndicatorRef {
  final String? name, shortName;
  final double changeRatio;
  const IndicatorRef({this.name, this.shortName, this.changeRatio = 0});
  factory IndicatorRef.fromJson(Map<String, dynamic> j) => IndicatorRef(name: j['name'] as String?, shortName: j['shortName'] as String?, changeRatio: (j['changeRatio'] as num?)?.toDouble() ?? (j['chgRate'] as num?)?.toDouble() ?? 0);
}
