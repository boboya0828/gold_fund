import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../features/position/providers/position_provider.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/text_styles.dart';
import 'widgets/position_delete_dialog.dart';
import 'widgets/position_move_group_dialog.dart';
import 'widgets/position_sort_widgets.dart';
import '../../core/utils/screen_adapt.dart';

/// 账本设置页（排序 / 表头管理）— 1:1 复刻 uni-app pages/positionv1/sub/sort.vue
///
/// 排序 tab：全选/单选、置顶(移到首位)、长按拖拽排序、批量移动分组、批量删除、
///           「完成」时 PUT /asset/api/Asset/order 保存排序并返回
/// 表头管理 tab：显示开关(互斥)、表头显隐(眼睛)/置顶/拖拽排序，
///           「完成」时 PUT /usercenter/api/User/holding-columns 保存并停留本页
/// query: bookId (可选, 指定账本; 不传则全部账本)
class PositionSortPage extends ConsumerStatefulWidget {
  final int? bookId;
  const PositionSortPage({super.key, this.bookId});

  @override
  ConsumerState<PositionSortPage> createState() => _PositionSortPageState();
}

/// 排序行模型 (uni-app fetchPositionList map 后的结构)
class PositionSortItem {
  final int id; // assetId || id || index
  final String name;
  final String code;
  final int? assetId;
  final int sortOrder;
  final bool isPinned;
  final int? bookId;

  const PositionSortItem({
    required this.id,
    required this.name,
    required this.code,
    required this.assetId,
    required this.sortOrder,
    required this.isPinned,
    this.bookId,
  });

  PositionSortItem copyWith({int? sortOrder, bool? isPinned}) => PositionSortItem(
        id: id,
        name: name,
        code: code,
        assetId: assetId,
        sortOrder: sortOrder ?? this.sortOrder,
        isPinned: isPinned ?? this.isPinned,
        bookId: bookId,
      );
}

/// 表头配置行（columns tab）
class _ColumnItem {
  final String key;
  final String title;
  bool visible;
  _ColumnItem({required this.key, required this.title, required this.visible});
}

class _PositionSortPageState extends ConsumerState<PositionSortPage> {
  static const _accent = Color(0xFFE05665);
  final ApiClient _api = ApiClient();

  String _tab = 'sort'; // sort | columns（1:1 activeTab）

  // ===== 排序 tab =====
  List<PositionSortItem> _list = [];
  Set<int> _selectedIds = {};
  bool _deleting = false;
  bool _sortDirty = false; // 有未保存改动时「完成」为正常红（1:1 sortDirty）

  // ===== 表头管理 tab =====
  bool _showHoldingAmount = false;
  bool _showFundCode = false;
  List<_ColumnItem> _columnList = [];
  bool _columnsLoading = false;
  bool _columnsSaving = false;
  bool _columnsDirty = false;
  bool _columnsLoaded = false;

  bool get _hasBookId => widget.bookId != null;
  int get _selectedCount => _selectedIds.length;
  bool get _isAllSelected =>
      _list.isNotEmpty && _selectedIds.length == _list.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchPositionList());
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  // ==================== 排序 tab ====================

  /// uni-app fetchPositionList: getAssetList(bookId?) → sortOrder 降序 → 归一化
  Future<void> _fetchPositionList() async {
    try {
      final res = await _api.get(
        ApiEndpoints.assetListV2,
        queryParameters: _hasBookId ? {'bookId': widget.bookId} : null,
      );
      final data = res.data;
      dynamic payload = data;
      if (data is Map && data['data'] != null) payload = data['data'];
      final List list = payload is Map
          ? (payload['list'] is List ? payload['list'] as List : const [])
          : (payload is List ? payload : const []);
      final items = <PositionSortItem>[];
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        if (e is! Map) continue;
        final assetId = (e['assetId'] as num?)?.toInt();
        final sortVal = (e['sortOrder'] as num?)?.toInt() ?? 0;
        final rawBookId = (e['bookId'] as num?)?.toInt();
        items.add(PositionSortItem(
          id: assetId ?? (e['id'] as num?)?.toInt() ?? i,
          name: (e['shortName'] ?? e['name'] ?? '--').toString(),
          code: (e['code'] ?? e['symbolCode'] ?? '').toString(),
          assetId: assetId,
          sortOrder: sortVal,
          isPinned: false, // 排序后统一计算
          bookId: rawBookId ?? (_hasBookId ? widget.bookId : null),
        ));
      }
      // (b.sortOrder ?? -1) - (a.sortOrder ?? -1) 降序, 首行为置顶
      items.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
      final pinned = _refreshSortState(items);
      if (!mounted) return;
      setState(() {
        _list = pinned;
        // 剔除已不存在的选中项
        final ids = pinned.map((e) => e.id).toSet();
        _selectedIds = _selectedIds.where(ids.contains).toSet();
      });
    } catch (_) {
      if (mounted) setState(() => _list = []);
    }
  }

  /// uni-app refreshSortState: sortOrder = total - index, isPinned = index === 0
  List<PositionSortItem> _refreshSortState(List<PositionSortItem> list) {
    final total = list.length;
    return [
      for (var i = 0; i < total; i++)
        list[i].copyWith(sortOrder: total - i, isPinned: i == 0),
    ];
  }

  bool _isSelected(PositionSortItem item) => _selectedIds.contains(item.id);

  void _toggleSelectItem(PositionSortItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedIds = {};
      } else {
        _selectedIds = _list.map((e) => e.id).toSet();
      }
    });
  }

  /// uni-app saveOrder: PUT /asset/api/Asset/order {assetOrders:{assetId: total-index}}
  Future<bool> _saveOrder(List<PositionSortItem> list) async {
    final orderMap = <int, int>{};
    final total = list.length;
    for (var i = 0; i < total; i++) {
      final assetId = list[i].assetId;
      if (assetId != null) orderMap[assetId] = total - i;
    }
    if (orderMap.isEmpty) return true;
    try {
      final res =
          await _api.put(ApiEndpoints.assetOrder, data: {'assetOrders': orderMap});
      final data = res.data;
      // uni-app: result?.code && Number(result.code) !== 200 → 仅 truthy 且非 200 视为失败
      final code = data is Map ? (data['code'] as num?)?.toInt() : null;
      if (code != null && code != 0 && code != 200) {
        throw Exception((data as Map)['message']?.toString() ?? '排序保存失败');
      }
      return true;
    } catch (_) {
      _toast('排序保存失败');
      return false;
    }
  }

  /// uni-app handleDragEnd: 仅更新本地顺序, 「完成」时才保存
  void _handleReorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    setState(() {
      _sortDirty = true;
      final list = List<PositionSortItem>.from(_list);
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _list = _refreshSortState(list);
    });
  }

  /// uni-app handlePin: 移到首位 (已在顶部则忽略)
  void _handlePin(PositionSortItem target) {
    final currentIndex = _list.indexWhere((e) => e.id == target.id);
    if (currentIndex <= 0) return;
    setState(() {
      _sortDirty = true;
      final list = List<PositionSortItem>.from(_list);
      final item = list.removeAt(currentIndex);
      list.insert(0, item);
      _list = _refreshSortState(list);
    });
  }

  /// uni-app handleDeleteClick → DelectPopup「确定删除选中的N个持仓吗？」
  Future<void> _handleDeleteClick() async {
    if (_selectedCount == 0 || _deleting) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await PositionDeleteDialog.show(
      context,
      assetName: '',
      isDark: isDark,
      content: '确定删除选中的$_selectedCount个持仓吗？',
    );
    if (ok == true) _confirmDeleteSelected();
  }

  /// uni-app confirmDeleteSelected: batchDeleteAsset {assetIds} → 本地移除 → 重置排序
  Future<void> _confirmDeleteSelected() async {
    if (_deleting) return;
    final assetIds = _list
        .where((e) => _selectedIds.contains(e.id))
        .map((e) => e.assetId)
        .whereType<int>()
        .where((id) => id > 0)
        .toSet()
        .toList();
    if (assetIds.isEmpty) return;
    setState(() => _deleting = true);
    try {
      final res = await _api.post(
        ApiEndpoints.assetBatchDelete,
        data: {'assetIds': assetIds},
      );
      final data = res.data;
      final code = data is Map ? (data['code'] as num?)?.toInt() : null;
      if (code != null && code != 200) {
        throw Exception((data as Map)['message']?.toString() ?? '删除失败');
      }
      if (!mounted) return;
      final deleted = assetIds.toSet();
      setState(() {
        _list = _refreshSortState(
            _list.where((e) => !deleted.contains(e.assetId)).toList());
        _selectedIds = {};
      });
      _toast('删除成功');
      // 删除后同步刷新持仓页缓存（1:1 持仓页 onShow 重新拉取）
      unawaited(ref.read(positionProvider.notifier).loadData());
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  /// uni-app handleFinishClick: 保存排序 → toast「操作成功」→ 300ms 后返回
  Future<void> _handleFinishClick() async {
    final success = await _saveOrder(_list);
    if (!success) return;
    _toast('操作成功');
    unawaited(ref.read(positionProvider.notifier).loadData());
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.of(context).pop();
  }

  // ==================== 移动分组 ====================

  /// uni-app resolveMoveSourceBookId: 优先页面 bookId，其次选中项的唯一共同账本
  int? _resolveMoveSourceBookId(List<PositionSortItem> selectedList) {
    if (_hasBookId) return widget.bookId;
    final bookIds = selectedList
        .map((e) => e.bookId)
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();
    return bookIds.length == 1 ? bookIds.first : null;
  }

  /// uni-app openMoveGroupModal
  Future<void> _openMoveGroupModal() async {
    if (_selectedCount == 0) return;
    final selectedList =
        _list.where((e) => _selectedIds.contains(e.id)).toList();
    final sourceBookId = _resolveMoveSourceBookId(selectedList);
    if (sourceBookId == null) {
      _toast('请选择具体账本后操作');
      return;
    }
    final assetIds = selectedList
        .map((e) => e.assetId)
        .whereType<int>()
        .where((id) => id > 0)
        .toSet()
        .toList();
    if (assetIds.isEmpty) return;
    List<BookItem> bookList;
    try {
      final res = await _api.get(ApiEndpoints.assetBooks);
      final data = res.data;
      final List list = data is List
          ? data
          : (data is Map && data['data'] is List ? data['data'] as List : const []);
      bookList = list
          .whereType<Map<String, dynamic>>()
          .map(BookItem.fromJson)
          .toList();
    } catch (_) {
      _toast('获取账户列表失败');
      return;
    }
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await PositionMoveGroupDialog.show(
      context,
      isDark: isDark,
      assetIds: assetIds,
      sourceBookId: sourceBookId,
      books:
          bookList.where((b) => b.bookId != sourceBookId).toList(),
    );
    if (result == null || !mounted) return;
    // 不保留源账本时本地移除已移动项（1:1 confirmMoveGroup）
    if (!result.keepSource) {
      final moved = assetIds.toSet();
      setState(() {
        _list = _refreshSortState(
            _list.where((e) => !moved.contains(e.assetId)).toList());
      });
    }
    setState(() => _selectedIds = {});
    unawaited(ref.read(positionProvider.notifier).loadData());
  }

  // ==================== 表头管理 tab ====================

  /// uni-app switchTab: 首次切到表头管理时加载配置
  void _switchTab(String tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    if (tab == 'columns' && !_columnsLoaded) _loadHoldingColumns();
  }

  /// uni-app loadHoldingColumns
  Future<void> _loadHoldingColumns() async {
    if (_columnsLoading) return;
    setState(() => _columnsLoading = true);
    try {
      final res = await _api.get(ApiEndpoints.holdingColumns);
      final data = res.data;
      final payload = (data is Map && data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : (data as Map<String, dynamic>? ?? {});
      if (!mounted) return;
      setState(() {
        _showHoldingAmount = payload['showHoldingAmount'] == true;
        _showFundCode = payload['showFundCode'] == true;
        final cols = (payload['columns'] as List?) ?? const [];
        _columnList = cols.whereType<Map<String, dynamic>>().map((e) {
          return _ColumnItem(
            key: '${e['key'] ?? ''}',
            title: '${e['title'] ?? e['key'] ?? '--'}',
            visible: e['visible'] != false,
          );
        }).toList();
        _columnsLoaded = true;
      });
    } catch (_) {
      _toast('表头配置加载失败');
    } finally {
      if (mounted) setState(() => _columnsLoading = false);
    }
  }

  /// uni-app toggleColumnVisible（本地修改，完成时统一保存）
  void _toggleColumnVisible(_ColumnItem item) {
    setState(() {
      _columnsDirty = true;
      item.visible = !item.visible;
    });
  }

  /// uni-app pinColumn: 移到 columns 首位
  void _pinColumn(_ColumnItem target) {
    final index = _columnList.indexWhere((e) => e.key == target.key);
    if (index <= 0) return;
    setState(() {
      _columnsDirty = true;
      final moved = _columnList.removeAt(index);
      _columnList.insert(0, moved);
    });
  }

  /// uni-app toggleColumnSwitch: 两个开关互斥（打开一个自动关掉另一个）
  void _toggleColumnSwitch(bool isAmount) {
    setState(() {
      _columnsDirty = true;
      if (isAmount) {
        _showHoldingAmount = !_showHoldingAmount;
        if (_showHoldingAmount) _showFundCode = false;
      } else {
        _showFundCode = !_showFundCode;
        if (_showFundCode) _showHoldingAmount = false;
      }
    });
  }

  /// uni-app handleColumnDragEnd
  void _handleColumnReorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    setState(() {
      _columnsDirty = true;
      final moved = _columnList.removeAt(oldIndex);
      _columnList.insert(newIndex, moved);
    });
  }

  /// uni-app saveHoldingColumns: PUT {showHoldingAmount, showFundCode, columns}
  /// 保存成功停留本页（不返回），复位未保存标记
  Future<void> _saveHoldingColumns() async {
    if (_columnsSaving) return;
    setState(() => _columnsSaving = true);
    try {
      await _api.put(
        ApiEndpoints.holdingColumnsSave,
        data: {
          'showHoldingAmount': _showHoldingAmount,
          'showFundCode': _showFundCode,
          'columns': _columnList
              .map((e) => {'key': e.key, 'visible': e.visible})
              .toList(),
        },
      );
      _toast('操作成功');
      setState(() => _columnsDirty = false);
      // 保存后刷新持仓页的表头配置（1:1 持仓页 onShow loadHoldingColumnSettings）
      unawaited(ref.read(positionProvider.notifier).refreshHoldingColumns());
    } catch (_) {
      _toast('保存失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _columnsSaving = false);
    }
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF111315) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(children: [
        // 源码 CustomNavbar title="账本设置"（bgState=false 白底/深色 #202125）
        CustomNavBar(
          title: '账本设置',
          backgroundColor: isDark ? const Color(0xFF202125) : Colors.white,
          titleColor: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
        ),
        // 排序 / 表头管理 切换（白色通栏）
        _buildTabs(isDark),
        Expanded(
          child: _tab == 'sort' ? _buildSortContent(isDark) : _buildColumnsContent(isDark),
        ),
        // 底部按钮：排序 tab 三枚 / 表头管理 tab 单枚完成
        if (_tab == 'sort')
          PositionSortBottomBar(
            selectedCount: _selectedCount,
            sortDirty: _sortDirty,
            deleting: _deleting,
            isDark: isDark,
            onMove: _openMoveGroupModal,
            onDelete: _handleDeleteClick,
            onFinish: _handleFinishClick,
          )
        else
          PositionColumnsFinishBar(
            dirty: _columnsDirty,
            saving: _columnsSaving,
            isDark: isDark,
            onFinish: _saveHoldingColumns,
          ),
      ]),
    );
  }

  /// .sort-tabs：高 86rpx、padding 16rpx 0 10rpx、gap 96rpx、白底、底部 1rpx 线
  Widget _buildTabs(bool isDark) {
    final inactiveColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666);
    final borderColor = isDark ? const Color(0xFF2A2D34) : const Color(0xFFF2EFEF);
    return Container(
      height: 43.sx, // 86rpx
      padding: EdgeInsets.only(top: 8.sx, bottom: 5.sx), // 16rpx 0 10rpx
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202125) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _tabItem('排序', _tab == 'sort', inactiveColor, () => _switchTab('sort')),
        SizedBox(width: 48.sx), // gap 96rpx
        _tabItem('表头管理', _tab == 'columns', inactiveColor,
            () => _switchTab('columns')),
      ]),
    );
  }

  /// .sort-tab：30rpx 500 #666（深 #A7ADB8）；active #E05665 700 +
  /// 44rpx×6rpx 圆角 3rpx 指示条（居中 bottom:0，padding-bottom 10rpx）
  Widget _tabItem(
      String label, bool active, Color inactiveColor, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(
          label,
          style: AppTextStyles.cn(
            15.sx, // 30rpx
            color: active ? _accent : inactiveColor,
            weight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        SizedBox(height: 5.sx), // padding-bottom 10rpx
        Container(
          width: 22.sx, // 44rpx
          height: 3.sx, // 6rpx
          decoration: BoxDecoration(
            color: active ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(1.5.sx), // 3rpx
          ),
        ),
      ]),
    );
  }

  // ==================== 排序 tab 内容 ====================

  Widget _buildSortContent(bool isDark) {
    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;
    return Column(children: [
      _buildHeader(isDark),
      Expanded(
        child: _list.isEmpty
            ? Container(
                width: double.infinity,
                color: cardBg,
                padding: EdgeInsets.symmetric(vertical: 40.sx, horizontal: 12.sx), // 80rpx 24rpx
                child: Text(
                  '暂无数据',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cn(13.sx,
                      color: isDark
                          ? const Color(0xFFA7ADB8)
                          : const Color(0xFFB0A8A9)),
                ),
              )
            : ReorderableListView.builder(
                padding: EdgeInsets.only(bottom: 100.sx), // padding-bottom 200rpx
                buildDefaultDragHandles: false,
                proxyDecorator: _proxyDecorator,
                itemCount: _list.length,
                onReorderItem: _handleReorder,
                itemBuilder: (context, index) =>
                    _buildRow(_list[index], index, isDark,
                        key: ValueKey(_list[index].id)),
              ),
      ),
    ]);
  }

  /// settings-header: grid 62rpx 1fr 90rpx 90rpx, padding 18rpx 20rpx 14rpx, 24rpx #ada5a6
  Widget _buildHeader(bool isDark) {
    final color = isDark ? const Color(0xFFA7ADB8) : const Color(0xFFADA5A6);
    return Container(
      color: isDark ? const Color(0xFF202125) : Colors.white,
      padding: EdgeInsets.fromLTRB(10.sx, 9.sx, 10.sx, 7.sx),
      child: Row(children: [
        SizedBox(
          width: 31.sx, // 62rpx
          child: _list.isEmpty
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: PositionSortCheckBox(
                      checked: _isAllSelected,
                      isDark: isDark,
                      onTap: _toggleSelectAll),
                ),
        ),
        Expanded(
            child:
                Text('持仓名称', style: AppTextStyles.cn(12.sx, color: color))),
        SizedBox(
            width: 45.sx,
            child: Center(
                child:
                    Text('置顶', style: AppTextStyles.cn(12.sx, color: color)))),
        SizedBox(
            width: 45.sx,
            child: Center(
                child:
                    Text('排序', style: AppTextStyles.cn(12.sx, color: color)))),
      ]),
    );
  }

  /// 拖拽悬浮样式 (源码 .dragging: shadow 0 12rpx 30rpx + radius 12rpx；深色 #282828 底)
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Material(
        color: isDark ? const Color(0xFF282828) : Colors.white,
        borderRadius: BorderRadius.circular(6.sx),
        elevation: 6 * animation.value,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
        child: child,
      ),
      child: child,
    );
  }

  /// settings-row: grid 62rpx 1fr 90rpx 90rpx, padding 18rpx 20rpx, border-top 1rpx #f2efef
  /// （:first-child 无 border-top）
  Widget _buildRow(PositionSortItem item, int index, bool isDark,
      {required Key key}) {
    final divider = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2EFEF);
    final selected = _isSelected(item);
    return Container(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: 10.sx, vertical: 9.sx),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202125) : Colors.white,
        border: index == 0
            ? null
            : Border(top: BorderSide(color: divider, width: 0.5)),
      ),
      child: Row(children: [
        // row-select: 62rpx
        SizedBox(
          width: 31.sx,
          child: Align(
            alignment: Alignment.centerLeft,
            child: PositionSortCheckBox(
                checked: selected,
                isDark: isDark,
                onTap: () => _toggleSelectItem(item)),
          ),
        ),
        // row-name (点击同勾选)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleSelectItem(item),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                item.name.isEmpty ? '--' : item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cn(13.sx,
                    color: isDark
                        ? const Color(0xFFD7DAE0)
                        : const Color(0xFF333333)), // 26rpx
              ),
              if (item.code.isNotEmpty) ...[
                const SizedBox(height: 1), // gap 2rpx
                Text(
                  item.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.num(10.5.sx,
                      color: isDark
                          ? const Color(0xFFA7ADB8)
                          : const Color(0xFFB0A8A9)), // 21rpx
                ),
              ],
            ]),
          ),
        ),
        // row-pin: 90rpx, uni-icons arrow-up size 22(px)
        SizedBox(
          width: 45.sx,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _handlePin(item),
              child: Padding(
                padding: EdgeInsets.all(4.sx),
                child: Icon(Icons.arrow_upward,
                    size: 22,
                    color: isDark
                        ? const Color(0xFFA7ADB8)
                        : const Color(0xFF333333)),
              ),
            ),
          ),
        ),
        // row-sort 拖拽手柄区: 90rpx（u-dragsort handler right:20rpx width:90rpx）
        SizedBox(
          width: 45.sx,
          child: ReorderableDragStartListener(
            index: index,
            child: Container(
              color: Colors.transparent,
              alignment: Alignment.center,
              padding: EdgeInsets.all(6.sx),
              child: Image.asset(
                'assets/images/img/sortico.png',
                width: 15.sx, // 30rpx
                height: 14.sx, // 28rpx
                color: isDark
                    ? Colors.white.withValues(alpha: 0.72)
                    : null, // theme-dark: invert(1) opacity(0.72)
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ==================== 表头管理 tab 内容 ====================

  Widget _buildColumnsContent(bool isDark) {
    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;
    final divider = isDark ? const Color(0xFF2A2D34) : const Color(0xFFF2EFEF);
    return Container(
      color: cardBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 100.sx), // padding-bottom 200rpx
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 顶部两个互斥开关
          _switchRow('显示 基金名称 + 持有金额', _showHoldingAmount, isDark,
              divider, () => _toggleColumnSwitch(true)),
          _switchRow('显示 基金名称 + 基金代码', _showFundCode, isDark, divider,
              () => _toggleColumnSwitch(false)),
          // .columns-table: margin-top 12rpx padding-top 6rpx
          Padding(
            padding: EdgeInsets.only(top: 3.sx),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // .columns-table__head: grid 1fr 100rpx×3, padding 24rpx 24rpx 20rpx, 24rpx #8F8F8F
              Container(
                margin: EdgeInsets.only(top: 3.sx), // margin-top 12rpx(共 6+6)
                padding: EdgeInsets.fromLTRB(12.sx, 12.sx, 12.sx, 10.sx),
                child: Row(children: [
                  Expanded(
                    child: Text('表头名称',
                        style: AppTextStyles.cn(12.sx,
                            color: isDark
                                ? const Color(0xFF8F96A3)
                                : const Color(0xFF8F8F8F))),
                  ),
                  _columnsHeadCell('显示', isDark),
                  _columnsHeadCell('置顶', isDark),
                  _columnsHeadCell('排序', isDark),
                ]),
              ),
              if (_columnsLoading)
                _columnsEmpty('加载中…', isDark)
              else if (_columnList.isEmpty)
                _columnsEmpty('暂无表头配置', isDark)
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: _proxyDecorator,
                  itemCount: _columnList.length,
                  onReorderItem: _handleColumnReorder,
                  itemBuilder: (context, index) => _buildColumnRow(
                      _columnList[index], index, isDark,
                      key: ValueKey(_columnList[index].key)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _columnsHeadCell(String label, bool isDark) {
    return SizedBox(
      width: 50.sx, // 100rpx
      child: Center(
        child: Text(
          label,
          style: AppTextStyles.cn(12.sx,
              color: isDark ? const Color(0xFF8F96A3) : const Color(0xFF8F8F8F)),
        ),
      ),
    );
  }

  /// .columns-empty: padding 60rpx 0, 26rpx #9AA0AB
  Widget _columnsEmpty(String text, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 30.sx),
      child: Center(
        child: Text(text,
            style: AppTextStyles.cn(13.sx, color: const Color(0xFF9AA0AB))),
      ),
    );
  }

  /// .column-switch-row: padding 28rpx 32rpx, border-bottom 1rpx, label 28rpx #333
  Widget _switchRow(String label, bool enabled, bool isDark, Color divider,
      VoidCallback onTap) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.sx, vertical: 14.sx),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.cn(14.sx,
                color: isDark
                    ? const Color(0xFFD7DAE0)
                    : const Color(0xFF333333)), // 28rpx
          ),
          // .column-switch: 88×48rpx, radius 24rpx, #E5E7EB(开 #E05665), dot 40rpx 白
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44.sx, // 88rpx
              height: 24.sx, // 48rpx
              padding: EdgeInsets.all(2.sx), // 4rpx
              decoration: BoxDecoration(
                color: enabled ? _accent : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(12.sx), // 24rpx
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    enabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20.sx, // 40rpx
                  height: 20.sx,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 3.sx,
                          offset: Offset(0, 1.sx)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 表头管理数据行: grid 1fr 100rpx×3, padding 26rpx 24rpx, min-height 96rpx
  Widget _buildColumnRow(_ColumnItem item, int index, bool isDark,
      {required Key key}) {
    final divider = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2EFEF);
    final eyeColor = item.visible
        ? (isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333))
        : const Color(0xFFB3B7C0);
    return Container(
      key: key,
      constraints: BoxConstraints(minHeight: 48.sx), // 96rpx
      padding: EdgeInsets.symmetric(horizontal: 12.sx, vertical: 13.sx),
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : Border(top: BorderSide(color: divider, width: 0.5)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            item.title.isEmpty ? '--' : item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.cn(13.sx,
                color: isDark
                    ? const Color(0xFFD7DAE0)
                    : const Color(0xFF333333)), // 26rpx
          ),
        ),
        // row-eye: 显隐切换（uni-icons eye/eye-slash size 20）
        SizedBox(
          width: 50.sx,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleColumnVisible(item),
              child: Padding(
                padding: EdgeInsets.all(4.sx),
                child: Icon(
                  item.visible ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                  color: eyeColor,
                ),
              ),
            ),
          ),
        ),
        // row-pin: 置顶（移到首位）
        SizedBox(
          width: 50.sx,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _pinColumn(item),
              child: Padding(
                padding: EdgeInsets.all(4.sx),
                child: Icon(Icons.arrow_upward,
                    size: 22,
                    color: isDark
                        ? const Color(0xFFA7ADB8)
                        : const Color(0xFF333333)),
              ),
            ),
          ),
        ),
        // row-sort 拖拽手柄
        SizedBox(
          width: 50.sx,
          child: ReorderableDragStartListener(
            index: index,
            child: Container(
              color: Colors.transparent,
              alignment: Alignment.center,
              padding: EdgeInsets.all(6.sx),
              child: Image.asset(
                'assets/images/img/sortico.png',
                width: 15.sx,
                height: 14.sx,
                color: isDark ? Colors.white.withValues(alpha: 0.72) : null,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
