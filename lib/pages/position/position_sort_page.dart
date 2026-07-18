import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/text_styles.dart';
import 'widgets/position_sort_widgets.dart';

/// 持仓排序管理页 — 1:1 复刻 uni-app pages/positionv1/sort.vue
/// 全选/单选、置顶(移到首位)、长按拖拽排序、批量删除、「完成」时保存排序
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

class _PositionSortPageState extends ConsumerState<PositionSortPage> {
  static const _accent = Color(0xFFE05665);
  final ApiClient _api = ApiClient();

  List<PositionSortItem> _list = [];
  Set<int> _selectedIds = {};

  bool get _hasBookId => widget.bookId != null;
  int get _selectedCount => _selectedIds.length;
  bool get _isAllSelected => _list.isNotEmpty && _selectedIds.length == _list.length;

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

  /// uni-app fetchPositionList: getAssetList(bookId?) → sortOrder 降序 → 归一化
  Future<void> _fetchPositionList() async {
    try {
      final res = await _api.get(
        ApiEndpoints.assetListV2,
        queryParameters: _hasBookId ? {'bookId': widget.bookId} : null,
      );
      // 数据结构: { data: { list: [...], totalCost, totalMarketValue, ... } }
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
      for (var i = 0; i < total; i++) list[i].copyWith(sortOrder: total - i, isPinned: i == 0),
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
      final res = await _api.put(ApiEndpoints.assetOrder, data: {'assetOrders': orderMap});
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
      final list = List<PositionSortItem>.from(_list);
      final item = list.removeAt(currentIndex);
      list.insert(0, item);
      _list = _refreshSortState(list);
    });
  }

  /// uni-app handleDeleteClick → uni.showModal 确认删除
  Future<void> _handleDeleteClick() async {
    if (_selectedCount == 0) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => _DeleteConfirmDialog(count: _selectedCount, isDark: isDark),
    );
    if (ok == true) _confirmDeleteSelected();
  }

  /// uni-app confirmDeleteSelected: 逐个 deleteAsset → 本地移除 → 重置排序
  Future<void> _confirmDeleteSelected() async {
    final selectedList = _list.where((e) => _selectedIds.contains(e.id) && e.assetId != null).toList();
    if (selectedList.isEmpty) return;
    _showLoading();
    try {
      await Future.wait(selectedList.map((e) => _api.delete('${ApiEndpoints.assetDeleteV2}/${e.assetId}')));
      if (!mounted) return;
      setState(() {
        _list = _refreshSortState(_list.where((e) => !_selectedIds.contains(e.id)).toList());
        _selectedIds = {};
      });
      _hideLoading();
      _toast('删除成功');
    } catch (_) {
      _hideLoading();
      _toast('删除失败');
    }
  }

  /// uni-app handleFinishClick: 保存排序 → toast → 300ms 后返回
  Future<void> _handleFinishClick() async {
    final success = await _saveOrder(_list);
    if (!success) return;
    _toast('操作成功');
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.of(context).pop();
  }

  // uni.showLoading('处理中...') 等价物
  void _showLoading() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _accent)),
    );
  }

  void _hideLoading() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF111315) : const Color(0xFFF5F5F5);
    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(children: [
        CustomNavBar(
          title: '排序',
          backgroundColor: isDark ? const Color(0xFF202125) : Colors.white,
          titleColor: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx
            child: Container(
              margin: const EdgeInsets.only(top: 9), // 18rpx
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8)), // 16rpx
              clipBehavior: Clip.antiAlias,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _buildHeader(isDark),
                if (_list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12), // 80rpx 24rpx
                    child: Center(
                      child: Text('暂无数据',
                          style: AppTextStyles.cn(13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB0A8A9))),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    proxyDecorator: _proxyDecorator,
                    itemCount: _list.length,
                    onReorderItem: _handleReorder,
                    itemBuilder: (context, index) => _buildRow(_list[index], index, isDark, key: ValueKey(_list[index].id)),
                  ),
              ]),
            ),
          ),
        ),
        PositionSortBottomBar(
          selectedCount: _selectedCount,
          isDark: isDark,
          onDelete: _handleDeleteClick,
          onFinish: _handleFinishClick,
        ),
      ]),
    );
  }

  /// settings-header: grid 62rpx 1fr 90rpx 90rpx, padding 18rpx 20rpx 14rpx
  Widget _buildHeader(bool isDark) {
    final color = isDark ? const Color(0xFFA7ADB8) : const Color(0xFFADA5A6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
      child: Row(children: [
        SizedBox(
          width: 31, // 62rpx
          child: _list.isEmpty
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: PositionSortCheckBox(checked: _isAllSelected, isDark: isDark, onTap: _toggleSelectAll),
                ),
        ),
        Expanded(child: Text('持仓名称', style: AppTextStyles.cn(12, color: color))), // 24rpx
        SizedBox(width: 45, child: Center(child: Text('置顶', style: AppTextStyles.cn(12, color: color)))), // 90rpx
        SizedBox(width: 45, child: Center(child: Text('排序', style: AppTextStyles.cn(12, color: color)))),
      ]),
    );
  }

  /// 拖拽悬浮样式 (源码 .dragging: shadow 0 12rpx 30rpx + radius 12rpx)
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        elevation: 6 * animation.value,
        shadowColor: Colors.black.withValues(alpha: 0.28),
        child: child,
      ),
      child: child,
    );
  }

  /// settings-row: padding 18rpx 20rpx, border-top 1rpx #f2efef
  Widget _buildRow(PositionSortItem item, int index, bool isDark, {required Key key}) {
    final divider = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2EFEF);
    final selected = _isSelected(item);
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202125) : Colors.white,
        border: Border(top: BorderSide(color: divider, width: 0.5)),
      ),
      child: Row(children: [
        // row-select: 62rpx
        SizedBox(
          width: 31,
          child: Align(
            alignment: Alignment.centerLeft,
            child: PositionSortCheckBox(checked: selected, isDark: isDark, onTap: () => _toggleSelectItem(item)),
          ),
        ),
        // row-name (点击同勾选)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleSelectItem(item),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                item.name.isEmpty ? '--' : item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cn(13, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333)), // 26rpx
              ),
              if (item.code.isNotEmpty) ...[
                const SizedBox(height: 1), // gap 2rpx
                Text(
                  item.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cn(10.5, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB0A8A9)), // 21rpx
                ),
              ],
            ]),
          ),
        ),
        // row-pin: 90rpx, uni-icons arrow-up
        SizedBox(
          width: 45,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _handlePin(item),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.arrow_upward, size: 22, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF333333)),
              ),
            ),
          ),
        ),
        // row-sort 拖拽手柄: 90rpx, sortico.png
        SizedBox(
          width: 45,
          child: Center(
            child: ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  'assets/images/img/sortico.png',
                  width: 15, // 30rpx
                  height: 14, // 28rpx
                  color: isDark ? Colors.white.withValues(alpha: 0.72) : null, // theme-dark: invert(1) opacity(0.72)
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// uni.showModal 风格确认框: 标题 + 内容 + 取消/删除(红)
class _DeleteConfirmDialog extends StatelessWidget {
  final int count;
  final bool isDark;
  const _DeleteConfirmDialog({required this.count, required this.isDark});

  static const _accent = Color(0xFFE05665);

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;
    final divider = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF0F0F0);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 275,
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 16),
            Text('确认删除',
                style: AppTextStyles.cn(16, weight: FontWeight.w600, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Text(
                '确定删除选中的$count个持仓吗？',
                textAlign: TextAlign.center,
                style: AppTextStyles.cn(14, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666), height: 1.5),
              ),
            ),
            Container(
              height: 44,
              decoration: BoxDecoration(border: Border(top: BorderSide(color: divider, width: 0.5))),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context, false),
                    child: Center(
                      child: Text('取消',
                          style: AppTextStyles.cn(15, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666))),
                    ),
                  ),
                ),
                Container(width: 0.5, color: divider),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context, true),
                    child: Center(child: Text('删除', style: AppTextStyles.cn(15, color: _accent))), // confirmColor #E05665
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
