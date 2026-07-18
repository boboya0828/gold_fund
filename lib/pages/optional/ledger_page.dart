import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/text_styles.dart';
import 'widgets/ledger_account_sheet.dart';
import 'widgets/ledger_book_api.dart';
import 'widgets/ledger_book_modal.dart';
import 'widgets/ledger_confirm_dialog.dart';

/// 账本管理页 — 1:1 复刻 uni-app pages/optional/ledger.vue + pages/position/ledger.vue
/// 两个源码页面结构完全一致, 仅接口族(自选 favorite / 持仓 asset)与「清空」文案不同,
/// 故通过 [bookType] 参数化复用:
///   - 自选分组: LedgerPage() / bookType: LedgerBookType.favorite → getFavoriteBooks 系列
///   - 持仓账本: bookType: LedgerBookType.asset → getAssetBooks 系列
/// 注: 源码模板中「账户设置/表头设置」分段控件已不渲染(activeTab 恒为 0, 表头设置为死代码), 故不迁移。
class LedgerPage extends ConsumerStatefulWidget {
  final LedgerBookType bookType;
  const LedgerPage({super.key, this.bookType = LedgerBookType.favorite});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

/// 账本行模型 (uni-app fetchBookList map 后的结构)
class LedgerAccount {
  final int id;
  final String name;
  final int bookId; // 默认账本归一化为 0
  final int sortOrder;
  final bool isDefault;
  final bool canEdit;

  const LedgerAccount({
    required this.id,
    required this.name,
    required this.bookId,
    required this.sortOrder,
    required this.isDefault,
    this.canEdit = true,
  });

  LedgerAccount copyWith({int? sortOrder}) => LedgerAccount(
        id: id,
        name: name,
        bookId: bookId,
        sortOrder: sortOrder ?? this.sortOrder,
        isDefault: isDefault,
        canEdit: canEdit,
      );
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  static const _accent = Color(0xFFE05665);
  List<LedgerAccount> _accountList = [];
  bool _rowActionLoading = false;

  LedgerBookApi get _api => LedgerBookApi(widget.bookType);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBookList());
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  /// uni-app fetchBookList: 拉取账本 → 归一化默认账本(bookId=0) → sortOrder 降序
  Future<void> _fetchBookList() async {
    try {
      final res = await _api.fetchBooks();
      final data = res.data;
      final List list = data is List ? data : (data is Map && data['data'] is List ? data['data'] as List : const []);
      final books = <LedgerAccount>[];
      for (var i = 0; i < list.length; i++) {
        final book = list[i];
        if (book is! Map) continue;
        final rawId = book['bookId'];
        final parsedId = rawId == null ? null : int.tryParse(rawId.toString());
        // isDefaultBook: isDefault 标记或 bookId 解析为 0
        final isDefault = book['isDefault'] == true || (rawId != null && rawId != '' && parsedId == 0);
        final bookId = isDefault ? 0 : (parsedId ?? i);
        books.add(LedgerAccount(
          id: parsedId ?? i,
          name: (book['name'] ?? book['bookName'] ?? '账本$bookId').toString(),
          bookId: bookId,
          sortOrder: (book['sortOrder'] as num?)?.toInt() ?? -(i + 1),
          isDefault: isDefault,
        ));
      }
      books.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
      if (mounted) setState(() => _accountList = books);
    } catch (_) {
      if (mounted) setState(() => _accountList = []);
    }
  }

  /// uni-app handleAccountDragEnd: 顺序变化才保存 {bookOrders:{bookId:sort}}
  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final list = List<LedgerAccount>.from(_accountList);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    // sortOrder = 总数 - 下标; 默认账本 key 归一化为 0
    final total = list.length;
    final sortDict = <int, int>{};
    final normalized = <LedgerAccount>[];
    for (var i = 0; i < total; i++) {
      final acc = list[i].copyWith(sortOrder: total - i);
      normalized.add(acc);
      sortDict[acc.isDefault ? 0 : acc.bookId] = acc.sortOrder;
    }
    setState(() => _accountList = normalized);
    try {
      await _api.updateBookOrder(sortDict);
      _toast('排序已保存');
    } catch (_) {
      _toast('排序保存失败');
      _fetchBookList(); // 失败回滚
    }
  }

  Future<void> _openEditModal(LedgerAccount item) async {
    final saved = await LedgerBookModal.show(
      context,
      isDark: Theme.of(context).brightness == Brightness.dark,
      bookType: widget.bookType,
      editMode: true,
      bookId: item.isDefault ? 0 : item.bookId,
      initialName: item.name,
      isDefault: item.isDefault,
    );
    if (saved == true) _fetchBookList();
  }

  Future<void> _openDeleteBookPopup(LedgerAccount item) async {
    if (item.isDefault || _rowActionLoading) return;
    final ok = await LedgerConfirmDialog.show(
      context,
      title: '删除账户',
      content: '删除后不可恢复，确定删除当前账户吗？',
      confirmText: '确认删除',
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
    if (ok == true) _confirmDeleteBook(item);
  }

  Future<void> _confirmDeleteBook(LedgerAccount item) async {
    if (item.isDefault || _rowActionLoading) return;
    setState(() => _rowActionLoading = true);
    try {
      await _api.deleteBook(item.bookId);
      _toast('删除成功');
      await _fetchBookList();
    } catch (_) {
      _toast('删除失败');
    } finally {
      if (mounted) setState(() => _rowActionLoading = false);
    }
  }

  Future<void> _openClearBookPopup(LedgerAccount item) async {
    if (_rowActionLoading) return;
    final ok = await LedgerConfirmDialog.show(
      context,
      title: _api.clearTitle,
      content: _api.clearContent,
      confirmText: '确认清空',
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
    if (ok == true) _confirmClearBook(item);
  }

  Future<void> _confirmClearBook(LedgerAccount item) async {
    if (_rowActionLoading) return;
    setState(() => _rowActionLoading = true);
    try {
      await _api.clearBook(item.bookId);
      _toast('清空成功');
      await _fetchBookList();
    } catch (_) {
      _toast('清空失败');
    } finally {
      if (mounted) setState(() => _rowActionLoading = false);
    }
  }

  Future<void> _openCreateModal() async {
    final saved = await LedgerBookModal.show(
      context,
      isDark: Theme.of(context).brightness == Brightness.dark,
      bookType: widget.bookType,
    );
    if (saved == true) _fetchBookList();
  }

  Future<void> _openCreateAccountSheet() async {
    final saved = await LedgerAccountSheet.show(
      context,
      isDark: Theme.of(context).brightness == Brightness.dark,
      bookType: widget.bookType,
      existingNames: _accountList.map((e) => e.name).toList(),
    );
    if (saved == true) _fetchBookList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF111315) : const Color(0xFFF5F5F5);
    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(children: [
        Column(children: [
          CustomNavBar(
            title: '账本管理',
            backgroundColor: isDark ? const Color(0xFF202125) : Colors.white,
            titleColor: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 15), // 30rpx
              child: Padding(
                // 为底部固定按钮预留空间 (两枚按钮高约 102 + bottom 40)
                padding: const EdgeInsets.only(bottom: 150),
                child: _buildSettingsCard(isDark, cardBg),
              ),
            ),
          ),
        ]),
        // bottom-area: fixed bottom 80rpx, 居中两枚按钮
        Positioned(
          left: 0,
          right: 0,
          bottom: 40 + bottomInset,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _bottomButton(
              text: '新增账户',
              filled: true,
              isDark: isDark,
              onTap: _openCreateModal,
            ),
            const SizedBox(height: 12), // 24rpx
            _bottomButton(
              text: '快捷创建',
              filled: false,
              isDark: isDark,
              onTap: _openCreateAccountSheet,
            ),
          ]),
        ),
      ]),
    );
  }

  /// settings-card: margin-top 22rpx, radius 18rpx
  Widget _buildSettingsCard(bool isDark, Color cardBg) {
    return Container(
      margin: const EdgeInsets.only(top: 11),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(9)),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 表头: 账户名称 | 编辑 删除账户 清空xx 排序
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 7), // 22rpx 18rpx 14rpx
          child: Row(children: [
            Expanded(
              child: Text('账户名称',
                  style: AppTextStyles.cn(11, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFADA5A6))), // 22rpx
            ),
            for (final label in ['编辑', '删除账户', _api.clearTitle, '排序'])
              SizedBox(
                width: label == '编辑'
                    ? 25 // 50rpx
                    : label == '排序'
                        ? 32 // 64rpx
                        : 57, // 114rpx
                child: Center(
                  child: Text(label,
                      maxLines: 1,
                      style: AppTextStyles.cn(11, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFADA5A6))),
                ),
              ),
          ]),
        ),
        if (_accountList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12), // 40rpx 24rpx
            child: Center(
              child: Text('暂无数据',
                  style: AppTextStyles.cn(13, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFFB0A8A9))), // 26rpx
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: _proxyDecorator,
            itemCount: _accountList.length,
            onReorderItem: _handleReorder,
            itemBuilder: (context, index) {
              final item = _accountList[index];
              return _buildAccountRow(item, index, isDark, key: ValueKey(item.id));
            },
          ),
      ]),
    );
  }

  /// 拖拽中的悬浮样式 (源码 .dragging: shadow + radius 12rpx)
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

  /// settings-row: min-height 86rpx, padding 14rpx 22rpx, border-top 1rpx
  /// 长按 350ms 触发拖拽 (uni-app long-press-drag) → ReorderableDelayedDragStartListener
  Widget _buildAccountRow(LedgerAccount item, int index, bool isDark, {required Key key}) {
    final divider = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2EFEF);
    return ReorderableDelayedDragStartListener(
      key: key,
      index: index,
      child: Container(
        constraints: const BoxConstraints(minHeight: 43),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202125) : Colors.white,
          border: Border(top: BorderSide(color: divider, width: 0.5)),
        ),
        child: Row(children: [
          // row-name
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cn(14, color: isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333)), // 28rpx
            ),
          ),
          // row-edit: 50rpx
          SizedBox(
            width: 25,
            child: Center(
              child: item.canEdit
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openEditModal(item),
                      child: Image.asset(
                        'assets/images/img/editico.png',
                        width: 15, // 30rpx
                        height: 15,
                        color: isDark ? Colors.white.withValues(alpha: 0.62) : null, // theme-dark: invert(1) opacity(0.62)
                      ),
                    )
                  : const SizedBox(width: 15, height: 15),
            ),
          ),
          const SizedBox(width: 6), // column-gap 12rpx
          // row-action 删除: 114rpx (默认账户无此操作, 占位)
          SizedBox(
            width: 57,
            child: Center(
              child: item.isDefault
                  ? const SizedBox(width: 28, height: 18)
                  : _actionText(
                      text: '删除',
                      danger: true,
                      isDark: isDark,
                      onTap: () => _openDeleteBookPopup(item),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          // row-action 清空: 114rpx
          SizedBox(
            width: 57,
            child: Center(
              child: _actionText(text: '清空', danger: false, isDark: isDark, onTap: () => _openClearBookPopup(item)),
            ),
          ),
          const SizedBox(width: 6),
          // 拖拽手柄图标: 64rpx
          SizedBox(
            width: 32,
            child: Center(
              child: Image.asset(
                'assets/images/img/sortico.png',
                width: 15, // 30rpx
                height: 14, // 28rpx
                color: isDark ? Colors.white.withValues(alpha: 0.62) : null,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// row-action-text: 22rpx, min-width 56rpx, height 36rpx, radius 18rpx
  /// danger(删除): 透明底 #333 文字; 普通(清空): 红字 + 8% 红底
  Widget _actionText({required String text, required bool danger, required bool isDark, required VoidCallback onTap}) {
    return Opacity(
      opacity: _rowActionLoading ? 0.45 : 1, // row-action-text--disabled
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _rowActionLoading ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 28),
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 4), // 8rpx
          decoration: BoxDecoration(
            color: danger ? Colors.transparent : _accent.withValues(alpha: isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            maxLines: 1,
            style: AppTextStyles.cn(
              11,
              color: danger ? (isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333)) : _accent,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// logout-btn: 574x90rpx, radius 45rpx, 32rpx
  Widget _bottomButton({required String text, required bool filled, required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 287, // 574rpx
        height: 45, // 90rpx
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _accent : (isDark ? const Color(0xFF282828) : Colors.white),
          borderRadius: BorderRadius.circular(22.5),
          border: filled ? null : Border.all(color: _accent, width: 1), // 2rpx
        ),
        child: Text(
          text,
          style: AppTextStyles.cn(16, color: filled ? Colors.white : _accent), // 32rpx
        ),
      ),
    );
  }
}
