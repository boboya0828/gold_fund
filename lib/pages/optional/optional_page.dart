import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/fund_group_service.dart';
import '../../shared/widgets/z_paging_refresh.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';
import 'widgets/optional_popups.dart';

/// 自选页面 - 1:1 复刻 uni-app (zdj-v1/pages/optional/index.vue)
class OptionalPage extends ConsumerStatefulWidget {
  const OptionalPage({super.key});
  @override
  ConsumerState<OptionalPage> createState() => _OptionalPageState();
}

class _OptionalPageState extends ConsumerState<OptionalPage> {
  final ApiClient _api = ApiClient();

  List<FavItem> _items = [];
  List<String> _bookNames = ['全部'];
  List<int> _bookIds = [0];
  // 源码 taberIndex 默认 1（有账本时落在第一个账本，否则回退 0=全部）
  int _tabIndex = 1;
  int _displayMode = 0; // 0=普通, 1=简洁, 2=极简
  String _sortField = '';
  String _sortOrder = 'desc';
  bool _showQuickMenu = false;
  bool _showTableMenu = false;
  double _tableMenuTop = 160;
  double _tableMenuLeft = 12;

  // 长按行操作弹框状态
  FavItem? _popupItem;
  int _popupIndex = -1;
  double _popupTop = 0;
  bool _popupShowAbove = false;

  final GlobalKey _modeTriggerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    SharedPreferences.getInstance().then((p) {
      final m = p.getInt('optionalMode') ?? 0;
      if (mounted) setState(() => _displayMode = m);
    });
  }

  /// 源码 loadPositionPageData: 先 fetchBookList 再 hendlAssetDetail（顺序执行）
  Future<void> _loadData() async {
    await _fetchBooks();
    await _fetchFavorites();
    if (mounted) setState(() {});
  }

  Future<void> _fetchBooks() async {
    try {
      final res = await _api.get(ApiEndpoints.favoriteBooks);
      final data = res.data;
      List list = [];
      if (data is List) {
        list = data;
      } else if (data?['data'] is List) {
        list = data!['data'];
      }
      final names = ['全部'];
      final ids = [0];
      for (final b in list) {
        names.add((b['bookName'] ?? b['name'] ?? '账本${b['bookId']}') as String);
        ids.add((b['bookId'] as num?)?.toInt() ?? 0);
      }
      _bookNames = names;
      _bookIds = ids;
      // 源码: taberIndex 超出账本数量时回退到 0（全部）
      if (_tabIndex > _bookNames.length - 1) _tabIndex = 0;
    } catch (_) {}
  }

  int _currentBookId() =>
      _tabIndex == 0 ? 0 : (_bookIds.length > _tabIndex ? _bookIds[_tabIndex] : 0);

  Future<void> _fetchFavorites() async {
    try {
      final bookId = _currentBookId();
      final res = await _api.get('${ApiEndpoints.favoriteByBook}/$bookId');
      final data = res.data;
      // 源码: res.data 为数组，或 data.list / data.items
      List raw = const [];
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        final d = data['data'];
        if (d is List) {
          raw = d;
        } else if (d is Map) {
          if (d['list'] is List) {
            raw = d['list'] as List;
          } else if (d['items'] is List) {
            raw = d['items'] as List;
          }
        } else if (data['list'] is List) {
          raw = data['list'] as List;
        } else if (data['items'] is List) {
          raw = data['items'] as List;
        }
      }
      final items = raw
          .whereType<Map>()
          .map((e) => _norm(e.cast<String, dynamic>()))
          .toList();
      // 源码 mergedList: 贵金属(assetType==7) 在前，基金在后（稳定分区）
      final metals = items.where((e) => e.assetType == 7).toList();
      final funds = items.where((e) => e.assetType != 7).toList();
      _items = [...metals, ...funds];
    } catch (_) {}
  }

  /// 对齐源码 normalizeFavoriteItem + getLatestChgRate/getLatestPreClose
  FavItem _norm(Map<String, dynamic> item) {
    final lp = item['latestPrice'] is Map
        ? (item['latestPrice'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final inds = (item['indicators'] is List ? item['indicators'] as List : const [])
        .whereType<Map>()
        .map((e) => IndicatorRef.fromJson(e.cast<String, dynamic>()))
        .toList();
    final firstInd = inds.isNotEmpty ? inds[0] : null;
    // increaseRatio = item.increaseRatio ?? firstIndicator.changeRatio
    final increaseRatio = _ndn(item['increaseRatio']) ?? firstInd?.changeRatio ?? 0;
    // getLatestChgRate: latestPrice.chgRate ?? latestPrice.changeRatio
    //   ?? dayProfitRate ?? dayChangeRatio ?? increaseRatio ?? null
    final dayRate = _ndn(lp['chgRate']) ??
        _ndn(lp['changeRatio']) ??
        _ndn(item['dayProfitRate']) ??
        _ndn(item['dayChangeRatio']) ??
        _ndn(item['increaseRatio']);
    final pcRaw = lp['preClose'] ?? item['preClose'];
    return FavItem(
      symbolId: (item['symbolId'] as num?)?.toInt() ?? 0,
      code: (item['code'] ?? '').toString(),
      name: (item['shortName'] ?? item['symbolName'] ?? item['name'] ?? item['displayName'] ?? '--').toString(),
      dayChangeRate: dayRate,
      increaseRatio: increaseRatio,
      preCloseText: pcRaw == null ? '--' : '$pcRaw',
      indicator: firstInd,
      favoriteId: ((item['favoriteId'] ?? item['id']) as num?)?.toInt() ?? 0,
      assetType: (item['assetType'] as num?)?.toInt() ?? 3,
      assetId: (item['assetId'] as num?)?.toInt() ?? 0,
      isHold: item['isHold'] == true || item['isHold'] == 1 || item['isHold'] == '1' || item['isHold'] == 'true',
      indicators: inds,
    );
  }

  double? _ndn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  List<FavItem> get _sorted {
    final list = List<FavItem>.from(_items);
    if (_sortField.isEmpty) return list;
    list.sort((a, b) {
      // 源码 getOptionalSortValue
      final av = _sortField == 'increaseRatio' ? a.increaseRatio : (a.dayChangeRate ?? 0);
      final bv = _sortField == 'increaseRatio' ? b.increaseRatio : (b.dayChangeRate ?? 0);
      return _sortOrder == 'asc' ? av.compareTo(bv) : bv.compareTo(av);
    });
    return list;
  }

  /// 源码 toggleMetalSort 三态循环: 无排序 → desc → asc → 取消排序
  void _toggleSort(String f) {
    setState(() {
      if (_sortField != f) {
        _sortField = f;
        _sortOrder = 'desc';
      } else if (_sortOrder == 'desc') {
        _sortOrder = 'asc';
      } else {
        _sortField = '';
        _sortOrder = 'desc';
      }
      _closeRowPopup();
    });
  }

  /// 跳转搜索/新增自选页, 携带当前账本 id(>0 才携带), 返回后刷新列表
  Future<void> _openSearch() async {
    final bookId = _currentBookId();
    final changed = await context
        .push(bookId > 0 ? '/optional-search?bookId=$bookId' : '/optional-search');
    if (changed == true && mounted) _loadData();
  }

  /// 行点击跳转持仓详情（源码 hendlGoMetalInfo）
  void _openDetails(FavItem item) {
    var q = 'symbolId=${item.symbolId}&assetType=${item.assetType}';
    if (item.assetId > 0) q += '&assetId=${item.assetId}';
    context.push('/position-details?$q');
  }

  /// 长按行 → 计算位置并弹出操作浮层（源码 onMergedRowLongPress + getRowPopupStyle）
  void _onRowLongPress(FavItem item, int index, BuildContext rowCtx) {
    final box = rowCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final mq = MediaQuery.of(context);
    const popupHeight = RowActionPopup.popupHeight; // 158rpx = 79
    const gap = 8.0;
    final tabbarReserve = 60 + mq.padding.bottom; // 120rpx + safeBottom
    final bottomLimit = math.max(0.0, mq.size.height - tabbarReserve - gap);
    final downTop = rect.bottom + gap;
    final upTop = math.max(0.0, rect.top - popupHeight - gap);
    final showAbove = downTop + popupHeight > bottomLimit;
    setState(() {
      _popupItem = item;
      _popupIndex = index;
      _popupShowAbove = showAbove;
      _popupTop = showAbove ? upTop : downTop;
    });
  }

  void _closeRowPopup() {
    if (_popupItem == null) return;
    setState(() {
      _popupItem = null;
      _popupIndex = -1;
      _popupShowAbove = false;
    });
  }

  /// 浮层点"删除" → 关闭浮层并打开 DelectPopup 风格确认框（源码 onAction('删除')）
  Future<void> _requestDelete(FavItem item) async {
    _closeRowPopup();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmDialog(content: '确定要删除「${item.name}」吗？'),
    );
    if (ok == true && mounted) _deleteItem(item);
  }

  /// 源码 deleteFavoriteRecord: favoriteId/id → removeFavorite,
  /// 否则 symbolId → removeFavoriteBySymbolId, 都没有则报错
  Future<void> _deleteItem(FavItem item) async {
    if (item.favoriteId <= 0 && item.symbolId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前记录缺少自选ID，无法删除!'), duration: Duration(seconds: 3)),
      );
      return;
    }
    try {
      if (item.favoriteId > 0) {
        await _api.delete('${ApiEndpoints.favorite}/${item.favoriteId}');
      } else {
        // uni-app: DELETE /asset/api/Favorite/remove/{symbolId}
        await _api.delete('${ApiEndpoints.favorite}/remove/${item.symbolId}');
      }
      await _fetchFavorites();
      if (mounted) {
        setState(() {});
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

  /// 源码 toggleTableModeMenu: 基于触发图标位置弹出（left 取 max(rect.right-164, 12)）
  void _toggleTableMenu() {
    if (_showTableMenu) {
      setState(() => _showTableMenu = false);
      return;
    }
    var top = 160.0;
    var left = 12.0;
    final box = _modeTriggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      top = rect.bottom + 10;
      left = math.max(rect.right - 164, 12);
    }
    setState(() {
      _showQuickMenu = false;
      _tableMenuTop = top;
      _tableMenuLeft = left;
      _showTableMenu = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF1F1F3);
    final w = MediaQuery.of(context).size.width;
    // four-cols 栅格: 2fr 0.92fr 0.92fr → ~52% / ~24% / ~24%
    final nameW = (w - 32) * 0.52;
    final colW = (w - 32) * 0.24;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        // 背景渐变图放在 SafeArea 外层，延伸到状态栏后面 (状态栏透明)，
        // 否则状态栏那一条会露出纯色 Scaffold 背景，跟渐变头部断层。
        if (!isDark)
          const Positioned(top: 0, left: 0, right: 0, child: Image(
            image: AssetImage('assets/images/img/position-bg.png'), fit: BoxFit.fitWidth, alignment: Alignment.topCenter)),
        SafeArea(
          child: ZPagingRefresh(
            isDark: isDark,
            onRefresh: _loadData,
            child: Column(children: [
              _buildNav(isDark, topPad),
              // 源码 .page-content/.active-box 区域背景 #f5f5f5（暗色 #111315）
              Container(
                color: isDark ? AppColors.darkBg : const Color(0xFFF5F5F5),
                child: Column(children: [
                  _buildTableHeader(isDark, nameW, colW),
                  _buildList(isDark, nameW, colW),
                  const SizedBox(height: 120),
                ]),
              ),
            ]),
          ),
        ),
        // ===== 快捷菜单（+号）=====
        if (_showQuickMenu)
          GestureDetector(
            onTap: () => setState(() => _showQuickMenu = false),
            child: Container(color: isDark ? Colors.black.withAlpha(115) : Colors.black.withAlpha(46)),
          ),
        if (_showQuickMenu)
          Positioned(right: 12, top: topPad + 44, child: _quickMenu(isDark)),
        // ===== 表格模式菜单 =====
        if (_showTableMenu)
          GestureDetector(
            onTap: () => setState(() => _showTableMenu = false),
            child: Container(color: isDark ? Colors.black.withAlpha(115) : Colors.black.withAlpha(46)),
          ),
        if (_showTableMenu)
          Positioned(left: _tableMenuLeft, top: _tableMenuTop, child: _tableModeMenu(isDark)),
        // ===== 长按行操作浮层（透明遮罩，点击关闭）=====
        if (_popupItem != null)
          GestureDetector(
            onTap: _closeRowPopup,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        if (_popupItem != null)
          Positioned(
            left: 16,
            top: _popupTop,
            child: RowActionPopup(
              title: _popupItem!.name,
              showAbove: _popupShowAbove,
              onDelete: () => _requestDelete(_popupItem!),
            ),
          ),
      ]),
    );
  }

  Widget _buildNav(bool isDark, double topPad) => Container(
    padding: EdgeInsets.only(top: topPad > 0 ? 0 : 8),
    // 背景图已上移至外层 Stack (延伸到状态栏后)。浅色模式下这里必须透明，
    // 否则实色会盖住下层的背景图（暗色模式无背景图，用实色兜底）。
    color: isDark ? const Color(0xFF202125) : Colors.transparent,
    child: Column(children: [
      // 源码 paddingTop = statusBarHeight + 10
      const SizedBox(height: 10),
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
      // 账本标签 — .taber-item: padding 8rpx 0 18rpx (top 4, bottom 9)
      SizedBox(height: 31, child: ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _bookNames.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () {
            // 源码 watch(taberIndex): 只重新拉自选列表，不重拉账本
            setState(() { _tabIndex = i; _closeRowPopup(); });
            _fetchFavorites().then((_) { if (mounted) setState(() {}); });
          },
          child: Padding(padding: const EdgeInsets.only(right: 24), child: Column(children: [
            const SizedBox(height: 4),
            Text(_bookNames[i], style: AppTextStyles.cn(15,
              color: _tabIndex == i ? (isDark ? Colors.white : const Color(0xFF452008)) : (isDark ? const Color(0xFF777C86) : const Color(0xFF9A7A61)),
              weight: _tabIndex == i ? FontWeight.w700 : FontWeight.w400, height: 1.2)),
            const SizedBox(height: 5),
            Container(width: 27, height: 4, decoration: BoxDecoration(
              color: _tabIndex == i ? (isDark ? AppColors.upColor : AppColors.primary) : Colors.transparent,
              borderRadius: BorderRadius.circular(999))),
          ])),
        ),
      )),
      const SizedBox(height: 5),
    ]));

  Widget _buildTableHeader(bool isDark, double nameW, double colW) {
    // 源码 .holding-card__header: padding 10rpx 1rem (v5 h16), 上下边框 1rpx
    final borderColor = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: borderColor, width: 0.5), bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(children: [
        SizedBox(width: nameW, child: Align(alignment: Alignment.centerLeft, child: GestureDetector(
          key: _modeTriggerKey,
          onTap: _toggleTableMenu,
          // 源码 mutedIconColor: 浅 #8E857E / 深 #A7ADB8
          child: Icon(_displayMode == 0 ? Icons.menu : _displayMode == 1 ? Icons.format_list_bulleted : Icons.more_horiz,
            size: 20,
            color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8E857E))))),
        SizedBox(width: colW, child: _sortBtn('关联板块', 'increaseRatio', isDark)),
        SizedBox(width: colW, child: _sortBtn('当日涨幅', 'dayProfitRate', isDark)),
      ]));
  }

  Widget _sortBtn(String title, String field, bool isDark) {
    final active = _sortField == field;
    final now = DateTime.now();
    final dl = '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final titleColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8D8B87);
    final dateColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFFC0BAB3);
    final inactiveIcon = isDark ? const Color(0xFFA7ADB8) : const Color(0xFFDDDDDD);
    return GestureDetector(onTap: () => _toggleSort(field),
      behavior: HitTestBehavior.opaque,
      child: Stack(children: [
        // 源码 .holding-header-sort: 右对齐, padding-right 18rpx=9（给箭头留位）
        Align(alignment: Alignment.centerRight, child: Padding(
          padding: const EdgeInsets.only(right: 9),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cn(11, color: titleColor, weight: isDark ? FontWeight.w500 : FontWeight.w400)),
            const SizedBox(height: 4),
            Text(dl, style: AppTextStyles.num(9, color: dateColor)),
          ]))),
        // 源码 .navimag: 钉在右缘，与标题行垂直居中对齐
        Positioned(right: 0, top: 1, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_drop_up, size: 6, color: active && _sortOrder == 'asc' ? AppColors.upColor : inactiveIcon),
          Icon(Icons.arrow_drop_down, size: 6, color: active && _sortOrder == 'desc' ? AppColors.upColor : inactiveIcon),
        ])),
      ]));
  }

  Widget _buildList(bool isDark, double nameW, double colW) {
    final sorted = _sorted;
    if (sorted.isEmpty) {
      // 源码 .optional-empty: padding 160rpx 48rpx 80rpx → top 80, h 24, bottom 40
      return Container(
        width: double.infinity,
        color: isDark ? AppColors.darkSurface : Colors.white,
        child: Padding(padding: const EdgeInsets.fromLTRB(24, 80, 24, 40), child: Column(children: [
        Text('暂无自选', style: AppTextStyles.cn(15, color: isDark ? AppColors.darkText : const Color(0xFF333333), weight: FontWeight.w600)),
        const SizedBox(height: 9),
        Text('添加基金后，可在这里查看关联板块和当日涨幅',
          style: AppTextStyles.cn(12, color: isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87))),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _openSearch,
          child: Container(
            constraints: const BoxConstraints(minWidth: 110), height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.upColor, borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.center, child: Text('新增自选', style: AppTextStyles.cn(13, color: Colors.white)))),
        ])),
      );
    }
    // 源码 .holding-card: padding 10rpx 0 8rpx → top 5, bottom 4
    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      padding: const EdgeInsets.only(top: 5, bottom: 4),
      child: Column(children: [
        ...sorted.asMap().entries.map((e) =>
          _buildRow(e.value, e.key, sorted.length - 1 == e.key, isDark, nameW, colW)),
        // 源码 .addbox: margin-left 1rem, margin-top 20rpx=10, padding-bottom 200rpx=100
        Padding(padding: const EdgeInsets.only(left: 16, top: 10, bottom: 100),
          child: Align(alignment: Alignment.centerLeft, child: GestureDetector(
            onTap: _openSearch,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(AppIcons.add, size: 12, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8E857E)),
              const SizedBox(width: 2),
              Text('新增自选', style: AppTextStyles.cn(11, color: isDark ? const Color(0xFF8F949D) : const Color(0xFF7A7A82))),
            ])))),
      ]));
  }

  Widget _buildRow(FavItem item, int index, bool isLast, bool isDark, double nameW, double colW) {
    final ind = item.indicator;
    final indRate = ind?.changeRatio ?? 0;
    final dayRate = item.dayChangeRate;
    // 源码 .textclass: 16rpx=8, #8d8b87 / 暗色 #8F949D
    final subColor = isDark ? const Color(0xFF8F949D) : const Color(0xFF8D8B87);
    // 源码 .holding-cell__rate 基色（零值/缺省时继承此色）: #3b3b3b / 暗色 #C9CDD4
    final baseRateColor = isDark ? const Color(0xFFC9CDD4) : const Color(0xFF3B3B3B);
    // 源码模板: 显示 item.symbolId || item.code
    final codeText = item.symbolId != 0 ? '${item.symbolId}' : (item.code.isNotEmpty ? item.code : '--');

    return Builder(builder: (rowCtx) => GestureDetector(
      onTap: () => _openDetails(item),
      onLongPressStart: (_) => _onRowLongPress(item, index, rowCtx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          // 源码 .row-active: 暗色 #2A2C31（浅色 #fff 无视觉变化）
          color: _popupIndex == index && isDark ? const Color(0xFF2A2C31) : null,
          // 源码最后一个 holding-card-list 的 body 无下边框
          border: isLast ? null : Border(bottom: BorderSide(
            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC), width: 0.5)),
        ),
        child: SizedBox(height: 40, child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // 名称列 (2fr)
          SizedBox(width: nameW, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(item.name, style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : Colors.black, weight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_displayMode == 0 || _displayMode == 1) ...[
              const SizedBox(height: 4),
              Row(children: [
                Flexible(child: Padding(padding: const EdgeInsets.only(top: 3),
                  child: Text(codeText, style: AppTextStyles.cn(8, color: subColor), maxLines: 1, overflow: TextOverflow.ellipsis))),
                if (item.isHold) ...[
                  const SizedBox(width: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.upColor.withAlpha(71), width: 0.5),
                      borderRadius: BorderRadius.circular(3),
                      color: AppColors.upColor.withAlpha(isDark ? 36 : 20)),
                    child: Text('持有', style: AppTextStyles.cn(9, color: AppColors.upColor))),
                ],
              ]),
            ],
          ])),
          // 关联板块列 (0.92fr) — 右对齐; 源码数值不带 % 号
          SizedBox(width: colW,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (ind != null)
                Text(_fmtSigned(indRate), style: AppTextStyles.num(13, color: _rateColor(indRate, isDark), weight: FontWeight.w500))
              else
                Text('-', style: AppTextStyles.cn(14, color: subColor)), // .nonenum 28rpx
              if (_displayMode == 0) ...[
                const SizedBox(height: 3),
                if (ind != null)
                  Text(ind.name ?? '--', style: AppTextStyles.cn(8, color: subColor), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end)
                else
                  Text('-', style: AppTextStyles.cn(11, color: subColor)), // .nonenums 22rpx
              ],
            ])),
          // 当日涨幅列 (0.92fr) — 右对齐; 带 % 号
          SizedBox(width: colW,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(dayRate == null ? '--' : '${_fmtSigned(dayRate)}%',
                style: AppTextStyles.num(13, color: dayRate == null ? baseRateColor : _rateColor(dayRate, isDark), weight: FontWeight.w500)),
              if (_displayMode == 0) ...[
                const SizedBox(height: 3),
                Text(item.preCloseText, style: AppTextStyles.num(10, color: baseRateColor, weight: FontWeight.w500)),
              ],
            ])),
        ])),
      ),
    ));
  }

  // ===== 快捷菜单（+号）— .quick-menu-panel =====
  Widget _quickMenu(bool isDark) => Container(width: 110, padding: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF282B32) : Colors.white, borderRadius: BorderRadius.circular(8),
      boxShadow: isDark ? [BoxShadow(color: Colors.black.withAlpha(87), blurRadius: 17)] : null),
    child: Column(children: [
      _menuItem(Icons.add, '添加自选', 18, isDark, () {
        setState(() => _showQuickMenu = false);
        _openSearch();
      }),
      _menuDiv(isDark), _menuItem(AppIcons.copyPage, '识别导入', 14, isDark, () {
        setState(() => _showQuickMenu = false);
        // 源码 batchAdjust: toast '批量调仓开发中'
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('批量调仓开发中'), duration: Duration(seconds: 2)),
        );
      }),
      _menuDiv(isDark), _menuItem(Icons.settings, '分组管理', 18, isDark, () async {
        setState(() => _showQuickMenu = false);
        await context.push('/ledger');
        if (mounted) _loadData();
      }),
    ]));

  Widget _menuItem(IconData icon, String label, double size, bool isDark, VoidCallback onTap) => GestureDetector(
    onTap: onTap, child: Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.transparent,
      child: Row(children: [
        Icon(icon, size: size, color: isDark ? const Color(0xFFAEB4C0) : const Color(0xFF4A5168)),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.cn(12, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF26304D))),
      ])),
  );

  Widget _menuDiv(bool isDark) => Container(height: 0.5, margin: const EdgeInsets.only(left: 36, right: 12),
    color: isDark ? const Color(0xFF3A3E48) : const Color(0xFFEEF1F5));

  // ===== 表格模式菜单 — .table-mode-menu =====
  Widget _tableModeMenu(bool isDark) => Container(width: 82, padding: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF282B32) : Colors.white, borderRadius: BorderRadius.circular(8),
      boxShadow: [BoxShadow(color: isDark ? Colors.black.withAlpha(87) : const Color(0x291A2240), blurRadius: 14, offset: const Offset(0, 6))]),
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
      color: Colors.transparent,
      child: Row(children: [
        Icon(icon, size: 18, color: active ? AppColors.primary : (isDark ? const Color(0xFF8F96A3) : const Color(0xFF888888))),
        const SizedBox(width: 7),
        Text(label, style: AppTextStyles.cn(14,
          color: active ? AppColors.primary : (isDark ? const Color(0xFFD7DAE0) : const Color(0xFF555555)),
          weight: active ? FontWeight.w600 : FontWeight.w400)),
      ])));
  }

  Widget _modeDiv(bool isDark) => Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 10),
    color: isDark ? const Color(0xFF3A3E48) : const Color(0xFFF0F0F0));

  /// 源码 $utils.formatSignedMoney: +/-符号 + 千分位 + 2位小数
  String _fmtSigned(double v) {
    final sign = v >= 0 ? '+' : '-';
    final fixed = v.abs().toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    final intPart = fixed.substring(0, dot);
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final rem = intPart.length - i;
      buf.write(intPart[i]);
      if (rem > 1 && rem % 3 == 1) buf.write(',');
    }
    return '$sign$buf${fixed.substring(dot)}';
  }

  /// 源码 getProfitClass: 0/null → 继承基色; >0 → 涨色; <0 → 跌色
  /// 涨: 浅 #E05665 / 深 #EF6672；跌: 浅 #31B87A / 深 #20B979
  Color _rateColor(double v, bool d) {
    if (v == 0) return d ? const Color(0xFFC9CDD4) : const Color(0xFF3B3B3B);
    if (v > 0) return d ? const Color(0xFFEF6672) : AppColors.upColor;
    return d ? AppColors.downColorDark : AppColors.downColor;
  }
}

class FavItem {
  final int symbolId, assetType, favoriteId, assetId;
  final String code, name, preCloseText;
  final double? dayChangeRate;
  final double increaseRatio;
  final IndicatorRef? indicator;
  final List<IndicatorRef> indicators;
  final bool isHold;
  const FavItem({
    required this.symbolId, required this.code, required this.name,
    required this.dayChangeRate, required this.increaseRatio, required this.preCloseText,
    this.indicator, required this.favoriteId, required this.assetType,
    required this.assetId, required this.isHold, this.indicators = const [],
  });
}

class IndicatorRef {
  final String? name, shortName;
  final double changeRatio;
  const IndicatorRef({this.name, this.shortName, this.changeRatio = 0});
  factory IndicatorRef.fromJson(Map<String, dynamic> j) => IndicatorRef(
    name: j['name'] as String?,
    shortName: j['shortName'] as String?,
    changeRatio: (j['changeRatio'] as num?)?.toDouble() ?? (j['chgRate'] as num?)?.toDouble() ?? 0,
  );
}
