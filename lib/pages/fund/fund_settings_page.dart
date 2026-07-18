import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/fund_settings_book_modal.dart';
import 'widgets/fund_settings_segmented_control.dart';

/// 基金设置页（账户设置 / 表头设置） — uni-app 对应: pages/index/fund/settings.vue
///
/// 账户设置：固定「全部」默认账户 + 可拖拽排序的持仓账本列表（u-dragsort），
/// 显示开关/改名/删除/清空/排序保存走 /asset/api/Asset/books 系列接口（均为 ApiEndpoints 现有常量）。
/// 表头设置：static/config.json table_config.simple 的静态表头，开关仅本地生效（源码如此，无持久化）。
///
/// 差异说明：
/// - 源码 settings.vue 无深色模式样式，深色配色为适配补全（页面骨架/卡片/图标着色）。
/// - 源码两个底部按钮（新增账户/保持设置）均打开同一个 create-book-modal，保持 1:1。
/// - 本页面未使用 umeng 埋点（源码即无）。
class FundSettingsPage extends StatefulWidget {
  /// 路由预留参数（源码未读取 query 参数，保持签名兼容）
  final String? symbolId;
  final String? assetId;

  const FundSettingsPage({super.key, this.symbolId, this.assetId});

  @override
  State<FundSettingsPage> createState() => _FundSettingsPageState();
}

/// 账户行（源码 accountList 项）
class _AccountItem {
  final String id; // 默认账户为 'all'，否则为 bookId 字符串
  String name;
  bool visible;
  final bool canEdit;
  final int? bookId;
  int sortOrder;
  final bool isDefault;

  _AccountItem({
    required this.id,
    required this.name,
    required this.visible,
    required this.canEdit,
    required this.bookId,
    required this.sortOrder,
    required this.isDefault,
  });
}

/// 表头行（源码 headerList 项）
class _HeaderItem {
  final String keyId;
  final String name;
  bool visible;
  final bool canEdit;

  _HeaderItem({required this.keyId, required this.name, required this.visible, required this.canEdit});
}

class _FundSettingsPageState extends State<FundSettingsPage> {
  final ApiClient _api = ApiClient();

  int _activeTab = 0;
  List<_AccountItem> _accounts = [];
  final Set<int> _visibleSaving = {}; // 源码 visibleSavingMap

  /// 表头配置 — 1:1 zdj-v1 static/config.json（default_mode=simple 的 table_config）
  static const _headerConfig = [
    (key: 'curr_earn', label: '单日收益', show: true),
    (key: 'earn', label: '总收益', show: true),
    (key: 'day_increase', label: '日涨幅', show: true),
    (key: 'week_increase', label: '周涨幅', show: true),
    (key: 'month_increase', label: '月涨幅', show: true),
    (key: 'year_increase', label: '年涨幅', show: true),
  ];

  late final List<_HeaderItem> _headers = [
    for (var i = 0; i < _headerConfig.length; i++)
      _HeaderItem(
        keyId: _headerConfig[i].key,
        name: _headerConfig[i].label,
        visible: _headerConfig[i].show,
        canEdit: true,
      ),
  ];

  _AccountItem? get _defaultAccount {
    for (final item in _accounts) {
      if (item.isDefault) return item;
    }
    return null;
  }

  List<_AccountItem> get _draggableAccounts => [for (final item in _accounts) if (!item.isDefault) item];

  @override
  void initState() {
    super.initState();
    _fetchBookList();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static int? _toIntOrNull(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// 源码 fetchBookList：获取账本列表并按 sortOrder 升序，前置默认「全部」账户
  Future<void> _fetchBookList() async {
    try {
      final res = await _api.get(ApiEndpoints.assetBooks);
      final body = res.data;
      final list = body is List
          ? body
          : (body is Map && body['data'] is List ? body['data'] as List : const []);
      final books = list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        ..sort((a, b) => _toInt(a['sortOrder'], 9999).compareTo(_toInt(b['sortOrder'], 9999)));
      final accounts = <_AccountItem>[
        _AccountItem(id: 'all', name: '全部', visible: true, canEdit: false, bookId: null, sortOrder: -1, isDefault: true),
        for (var i = 0; i < books.length; i++)
          _AccountItem(
            id: '${books[i]['bookId'] ?? i}',
            name: (books[i]['name'] ?? books[i]['bookName'] ?? '账本${books[i]['bookId']}').toString(),
            visible: books[i]['isVisible'] != false,
            canEdit: true,
            bookId: _toIntOrNull(books[i]['bookId']),
            sortOrder: _toInt(books[i]['sortOrder'], i),
            isDefault: false,
          ),
      ];
      if (mounted) setState(() => _accounts = accounts);
    } catch (_) {
      // 源码: console.error('获取账本列表失败') + accountList = []
      if (mounted) setState(() => _accounts = []);
    }
  }

  /// 源码 toggleVisible（账户 Tab）：先本地切换，有 bookId 时调 renameAssetBook；失败回滚
  Future<void> _toggleAccountVisible(_AccountItem item, bool value) async {
    final prev = item.visible;
    setState(() => item.visible = value);
    final bookId = item.bookId;
    if (bookId == null) return;
    setState(() => _visibleSaving.add(bookId));
    try {
      await _api.put(ApiEndpoints.assetBooks, data: {'bookId': bookId, 'newName': item.name});
    } catch (_) {
      // 源码: 更新失败 → 回滚 visible + toast
      if (mounted) setState(() => item.visible = prev);
      _toast('更新失败');
    } finally {
      if (mounted) setState(() => _visibleSaving.remove(bookId));
    }
  }

  /// 表头 Tab 开关：源码仅本地切换（activeTab!==0 时不走接口）
  void _toggleHeaderVisible(_HeaderItem item, bool value) {
    setState(() => item.visible = value);
  }

  /// 源码 handleAccountDragEnd：先本地落序，再 PUT books/order {bookOrders:{bookId:index}}
  /// （onReorderItem 的 newIndex 已按移除项自动修正，无需手动 -1）
  void _onReorderItem(int oldIndex, int newIndex) {
    final defaultAcc = _defaultAccount;
    final draggable = _draggableAccounts;
    setState(() {
      final item = draggable.removeAt(oldIndex);
      draggable.insert(newIndex, item);
      _accounts = [?defaultAcc, ...draggable];
    });
    _saveOrder(draggable);
  }

  Future<void> _saveOrder(List<_AccountItem> draggable) async {
    final orders = <int, int>{};
    for (var i = 0; i < draggable.length; i++) {
      final id = draggable[i].bookId;
      if (id != null) orders[id] = i;
    }
    try {
      await _api.put(ApiEndpoints.assetBooksOrder, data: {'bookOrders': orders});
      _toast('排序已保存');
    } catch (_) {
      _toast('排序保存失败');
      _fetchBookList();
    }
  }

  /// 源码：底部按钮（两个 Tab 均打开 create-book-modal）
  Future<void> _openCreateModal() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await FundSettingsBookModal.show(context, isDark: isDark);
    if (ok == true) _fetchBookList();
  }

  /// 源码 openEditModal：默认账户不可编辑
  Future<void> _openEditModal(_AccountItem item) async {
    if (item.isDefault) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await FundSettingsBookModal.show(
      context,
      isDark: isDark,
      editMode: true,
      bookId: item.bookId,
      initialName: item.name,
    );
    if (ok == true) _fetchBookList();
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFFAF7F7),
      body: Container(
        decoration: isDark
            ? null
            : const BoxDecoration(
                // 源码 .page-container: linear-gradient(180deg,#faf7f7 0%,#f3f1f3 38%,#f6f6f8 100%)
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFAF7F7), Color(0xFFF3F1F3), Color(0xFFF6F6F8)],
                  stops: [0.0, 0.38, 1.0],
                ),
              ),
        child: Column(
          children: [
            CustomNavBar(
              title: '基金设置',
              backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFFAF7F7),
              titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
            ),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 15), // 30rpx
                    child: Column(
                      children: [
                        FundSettingsSegmentedControl(
                          tabs: const ['账户设置', '表头设置'],
                          activeIndex: _activeTab,
                          onChanged: (i) => setState(() => _activeTab = i),
                          isDark: isDark,
                        ),
                        _buildSettingsCard(isDark),
                      ],
                    ),
                  ),
                  // 源码 .bottom-area: fixed bottom 80rpx，居中
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 40, // 80rpx
                    child: Center(child: _buildBottomButton()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 源码 .logout-btn：574x90rpx，#E05665，圆角 45rpx
  Widget _buildBottomButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openCreateModal,
      child: Container(
        width: 287, // 574rpx
        height: 45, // 90rpx
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.upColor, // #E05665
          borderRadius: BorderRadius.circular(22.5), // 45rpx
        ),
        child: Text(
          _activeTab == 0 ? '新增账户' : '保持设置',
          style: AppTextStyles.cn(16, color: Colors.white), // 32rpx
        ),
      ),
    );
  }

  /// 源码 .settings-card：margin-top 22rpx，圆角 18rpx，边框+投影
  Widget _buildSettingsCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 11), // 22rpx
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF5202125) : const Color(0xF5FFFFFF), // rgba(*,0.96)
        borderRadius: BorderRadius.circular(9), // 18rpx
        border: Border.all(
          color: isDark ? const Color(0x0FFFFFFF) : const Color(0xF2F1ECEC), // 1rpx rgba(241,236,236,.95)
          width: 0.5,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0F6B5E57), // rgba(107,94,87,0.06)
                  offset: Offset(0, 6), // 12rpx
                  blurRadius: 20, // 40rpx
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCardHeader(isDark),
          if (_activeTab == 0) ..._buildAccountSection(isDark) else ..._buildHeaderSection(isDark),
        ],
      ),
    );
  }

  /// 源码 .settings-header：grid 1.5fr 0.7fr 1fr 0.45fr，padding 22rpx 24rpx 18rpx，22rpx
  Widget _buildCardHeader(bool isDark) {
    final style = AppTextStyles.cn(
      11, // 22rpx
      color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFADA5A6),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 9), // 22rpx 24rpx 18rpx
      color: isDark ? AppColors.darkSurface : const Color(0xEBFFFFFF), // rgba(255,255,255,0.92)
      child: Row(
        children: [
          Expanded(flex: 150, child: Text(_activeTab == 0 ? '账户名称' : '表头名称', style: style)),
          Expanded(
            flex: 70,
            child: Center(child: Text(_activeTab == 0 ? '编辑' : '置顶', style: style)),
          ),
          Expanded(flex: 100, child: Center(child: Text('是否显示', style: style))),
          Expanded(flex: 45, child: Center(child: Text('排序', style: style))),
        ],
      ),
    );
  }

  List<Widget> _buildAccountSection(bool isDark) {
    if (_accounts.isEmpty) return [_buildEmptyState(isDark)];
    final defaultAcc = _defaultAccount;
    final draggable = _draggableAccounts;
    return [
      if (defaultAcc != null) _buildDefaultRow(defaultAcc, isDark),
      if (draggable.isNotEmpty)
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          proxyDecorator: _proxyDecorator,
          itemCount: draggable.length,
          onReorderItem: _onReorderItem,
          itemBuilder: (context, index) => _buildDraggableRow(draggable[index], index, isDark),
        ),
    ];
  }

  List<Widget> _buildHeaderSection(bool isDark) {
    if (_headers.isEmpty) return [_buildEmptyState(isDark)];
    return [for (final item in _headers) _buildHeaderRow(item, isDark)];
  }

  /// 源码 .empty-state：padding 40rpx 24rpx，26rpx #b0a8a9
  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20), // 40rpx 24rpx
      color: isDark ? const Color(0xFF282828) : Colors.white,
      child: Text(
        '暂无数据',
        textAlign: TextAlign.center,
        style: AppTextStyles.cn(13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB0A8A9)), // 26rpx
      ),
    );
  }

  /// 行容器：padding 22rpx 24rpx，border-top 1rpx #f2efef，背景 #fff（深 #282828）
  BoxDecoration _rowDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF282828) : Colors.white,
      border: Border(
        top: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2EFEF), width: 0.5),
      ),
    );
  }

  Widget _rowName(String name, bool isDark) {
    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.cn(
        15, // 30rpx
        color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF463936),
        weight: FontWeight.w600,
      ),
    );
  }

  /// uni-app switch：scale(0.72)，选中色 #5A84FF
  Widget _buildSwitch(bool value, bool disabled, ValueChanged<bool> onChanged) {
    return Transform.scale(
      scale: 0.72,
      child: Switch(
        value: value,
        onChanged: disabled ? null : onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFF5A84FF),
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFDFDFDF),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  /// 源码默认「全部」账户行：三列均为占位符
  Widget _buildDefaultRow(_AccountItem item, bool isDark) {
    return Container(
      decoration: _rowDecoration(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), // 22rpx 24rpx
      child: Row(
        children: [
          Expanded(flex: 150, child: _rowName(item.name, isDark)),
          const Expanded(flex: 70, child: Center(child: SizedBox(width: 17, height: 17))), // edit-placeholder 34rpx
          const Expanded(flex: 100, child: Center(child: SizedBox(width: 36, height: 22))), // switch-placeholder 72x44rpx
          const Expanded(flex: 45, child: Center(child: SizedBox(width: 17, height: 16))), // sort-placeholder 34x32rpx
        ],
      ),
    );
  }

  /// 可拖拽账户行：编辑图标 + 开关 + 绝对定位拖拽手柄（源码 :deep(.ui-dragSort-item-handler) right 24rpx）
  Widget _buildDraggableRow(_AccountItem item, int index, bool isDark) {
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.72) : null;
    return Container(
      key: ValueKey('acc-${item.id}'),
      decoration: _rowDecoration(isDark),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), // 22rpx 24rpx
            child: Row(
              children: [
                Expanded(flex: 150, child: _rowName(item.name, isDark)),
                Expanded(
                  flex: 70,
                  child: Center(
                    child: item.canEdit
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openEditModal(item),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Image.asset(
                                'assets/images/img/editico.png',
                                width: 16.5, // 33rpx
                                height: 16.5,
                                color: iconColor,
                              ),
                            ),
                          )
                        : const SizedBox(width: 17, height: 17),
                  ),
                ),
                Expanded(
                  flex: 100,
                  child: Center(
                    child: _buildSwitch(
                      item.visible,
                      _visibleSaving.contains(item.bookId),
                      (v) => _toggleAccountVisible(item, v),
                    ),
                  ),
                ),
                // sort 列占位（拖拽手柄绝对定位覆盖）
                const Expanded(flex: 45, child: Center(child: SizedBox(width: 17, height: 16))),
              ],
            ),
          ),
          Positioned(
            right: 12, // 24rpx
            top: 0,
            bottom: 0,
            child: Center(
              child: ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(6), // 12rpx
                  child: Image.asset(
                    'assets/images/img/sortico.png',
                    width: 17, // 34rpx
                    height: 16, // 32rpx
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 表头行：编辑/排序图标静态展示（源码未绑定点击事件），开关仅本地切换
  Widget _buildHeaderRow(_HeaderItem item, bool isDark) {
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.72) : null;
    return Container(
      decoration: _rowDecoration(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), // 22rpx 24rpx
      child: Row(
        children: [
          Expanded(flex: 150, child: _rowName(item.name, isDark)),
          Expanded(
            flex: 70,
            child: Center(
              child: item.canEdit
                  ? Image.asset('assets/images/img/editico.png', width: 16.5, height: 16.5, color: iconColor)
                  : const SizedBox(width: 17, height: 17),
            ),
          ),
          Expanded(
            flex: 100,
            child: Center(
              child: _buildSwitch(item.visible, false, (v) => _toggleHeaderVisible(item, v)),
            ),
          ),
          Expanded(
            flex: 45,
            child: Center(
              child: Image.asset('assets/images/img/sortico.png', width: 17, height: 16, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 拖拽悬浮样式（源码 .u-dragsort-item.dragging：shadow 0 12rpx 30rpx + radius 12rpx）
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6), // 12rpx
        elevation: 6 * animation.value,
        shadowColor: Colors.black.withValues(alpha: 0.28),
        child: child,
      ),
      child: child,
    );
  }
}
