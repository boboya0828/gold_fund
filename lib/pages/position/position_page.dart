import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/position/providers/position_provider.dart';
import 'widgets/position_nav_header.dart';
import 'widgets/position_asset_card.dart';
import 'widgets/position_holding_table.dart';
import 'widgets/position_quick_menu.dart';
import 'widgets/position_table_mode_menu.dart';
import 'widgets/position_action_popup.dart';
import 'widgets/position_delete_dialog.dart';
import 'widgets/position_asset_visible_dialog.dart';

/// 持仓页面 — 1:1 复刻 uni-app pages/positionv1/index.vue
/// 主文件只负责编排和状态管理，各 UI 区块拆入 widgets/ 目录
class PositionPage extends ConsumerStatefulWidget {
  const PositionPage({super.key});

  @override
  ConsumerState<PositionPage> createState() => _PositionPageState();
}

class _PositionPageState extends ConsumerState<PositionPage> {
  bool _showQuickMenu = false;
  bool _showTableModeMenu = false;
  bool _showPopup = false;
  int _selectedIndex = -1;

  // 表格模式菜单锚点：跟随表头模式图标定位（源码 top=rect.bottom+10, right 对齐图标右缘）
  final GlobalKey _modeIconKey = GlobalKey();
  double _modeMenuTop = 160;
  double _modeMenuRight = 16;

  // 长按行的定位数据 (用于操作弹窗跟随)
  Offset _rowOffset = Offset.zero;
  double _rowHeight = 50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(positionProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(positionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final scaffoldBg = isDark ? const Color(0xFF111315) : Colors.white;
    final maskColor = isDark ? Colors.black.withAlpha(115) : const Color(0x2E000000);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(children: [
        // 导航头背景图放在 SafeArea 外层，延伸到状态栏后面 (状态栏透明)，
        // 高度 = 状态栏高度 + 导航头自身内容高度(92 = 10+29+10+38+5)，保持底边位置不变，
        // 否则状态栏那一条会露出纯色 Scaffold 背景，跟背景图断层。
        if (!isDark)
          Positioned(top: 0, left: 0, right: 0, height: topPadding + 92,
            child: Image.asset('assets/images/img/position-bg.png', fit: BoxFit.cover, alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink())),
        SafeArea(
          // nav/资产卡/列头固定；下拉刷新只作用于列表(移入 PositionHoldingTable)，对齐 uni-app
          child: Column(children: [
            PositionNavHeader(
              state: state,
              isDark: isDark,
              topPadding: topPadding,
              onSearchTap: () => context.push('/search'),
              onMenuTap: () => setState(() {
                _showTableModeMenu = false;
                _showQuickMenu = !_showQuickMenu;
              }),
            ),
            PositionAssetCard(
              state: state,
              isDark: isDark,
              onEyeTap: () => _openAssetVisibleDialog(state),
            ),
            Expanded(
              child: PositionHoldingTable(
                state: state,
                isDark: isDark,
                selectedIndex: _selectedIndex,
                modeIconKey: _modeIconKey,
                onSelect: (idx) => setState(() {
                  _selectedIndex = idx;
                  _showPopup = idx >= 0;
                }),
                onLongSelect: (idx, rowOffset, rowHeight) => setState(() {
                  _selectedIndex = idx;
                  _showPopup = idx >= 0;
                  _rowOffset = rowOffset;
                  _rowHeight = rowHeight;
                }),
                onRowTap: () => setState(() {
                  _selectedIndex = -1;
                  _showPopup = false;
                }),
                onSortToggle: _toggleTableModeMenu,
                onSortManage: _goSortManage,
                onSyncTap: _syncHoldings,
              ),
            ),
          ]),
        ),

        // 快捷菜单蒙层
        if (_showQuickMenu) ...[
          GestureDetector(
            onTap: () => setState(() => _showQuickMenu = false),
            child: Container(color: maskColor),
          ),
          Positioned(
            right: 12,
            top: topPadding + 44,
            child: PositionQuickMenu(
              isDark: isDark,
              onSync: _syncHoldings,
              onBatchSync: () => _showToast('批量同步开发中'),
              onTradeRecord: _goTradeRecord,
              onAnalysis: _goCurve,
              onLedger: _goLedger,
            ),
          ),
        ],

        // 表格模式菜单蒙层
        if (_showTableModeMenu) ...[
          GestureDetector(
            onTap: () => setState(() => _showTableModeMenu = false),
            child: Container(color: maskColor),
          ),
          Positioned(
            right: _modeMenuRight,
            top: _modeMenuTop,
            child: PositionTableModeMenu(
              isDark: isDark,
              currentMode: state.tableMode,
              onSelect: (mode) {
                ref.read(positionProvider.notifier).setTableMode(mode);
                setState(() => _showTableModeMenu = false);
              },
            ),
          ),
        ],

        // 长按操作弹窗蒙层
        if (_showPopup)
          GestureDetector(
            onTap: () => setState(() { _showPopup = false; _selectedIndex = -1; }),
            child: Container(color: Colors.transparent),
          ),

        // 长按弹窗本体 (跟随行位置)
        if (_showPopup)
          PositionActionPopup(
            state: state,
            selectedIndex: _selectedIndex,
            rowOffset: _rowOffset,
            rowHeight: _rowHeight,
            screenWidth: MediaQuery.of(context).size.width,
            onClose: () => setState(() { _showPopup = false; _selectedIndex = -1; }),
            onEdit: () {
              final target = _getSelectedItem(state);
              setState(() { _showPopup = false; _selectedIndex = -1; });
              if (target != null) {
                // TODO(对齐): uni-app 修改持仓跳 mass-upload-maddzx / gjs-holding-edit 编辑页，
                // Flutter 端该页面尚未迁移，暂跳持仓详情（见迁移报告 REMAINING）
                context.push('/position-details?symbolId=${target.symbolId}&assetType=${target.assetType}');
              }
            },
            onBatchEdit: () {
              setState(() { _showPopup = false; _selectedIndex = -1; });
              _goSortManage();
            },
            onBatchAdjust: () {
              setState(() { _showPopup = false; _selectedIndex = -1; });
              _openBatchAdjust(state);
            },
            onPinTop: () {
              final target = _getSelectedItem(state);
              setState(() { _showPopup = false; _selectedIndex = -1; });
              if (target != null) _pinToTop(target.assetId);
            },
            onDelete: (assetName) {
              final target = _getSelectedItem(state);
              setState(() { _showPopup = false; _selectedIndex = -1; });
              if (target != null) {
                _showDeleteDialog(target);
              }
            },
          ),
      ]),
    );
  }

  PositionItem? _getSelectedItem(PositionState state) {
    final items = state.sortedItems;
    if (_selectedIndex < 0 || _selectedIndex >= items.length) return null;
    return items[_selectedIndex];
  }

  void _closeMenus() {
    setState(() { _showQuickMenu = false; _showTableModeMenu = false; });
  }

  // 模式菜单切换：按表头模式图标的实际位置锚定（源码 top=rect.bottom+10，菜单右缘对齐图标右缘）
  void _toggleTableModeMenu() {
    final box = _modeIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero);
      _modeMenuTop = pos.dy + box.size.height + 10;
      _modeMenuRight =
          MediaQuery.of(context).size.width - (pos.dx + box.size.width);
    }
    setState(() {
      _showQuickMenu = false;
      _showTableModeMenu = !_showTableModeMenu;
    });
  }

  /// 闭眼模式选择弹窗 (1:1 uni-app openAssetVisibleModePopup)
  Future<void> _openAssetVisibleDialog(PositionState state) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = await PositionAssetVisibleDialog.show(
      context,
      currentLevel: state.assetVisible,
      isDark: isDark,
    );
    if (level != null) {
      ref.read(positionProvider.notifier).setAssetVisible(level);
    }
  }

  /// 同步持仓 (1:1 uni-app hendleSynchronization)
  /// 源码: 有具体账本 → mass-upload?bookId=；全部账本 → add-accounting-records。
  /// Flutter 端导入页尚未迁移，暂用 /optional-search 承接（见迁移报告 REMAINING）。
  void _syncHoldings() {
    _closeMenus();
    final bookId = ref.read(positionProvider).currentBookId;
    context.push(bookId != null ? '/optional-search?bookId=$bookId' : '/optional-search');
  }

  /// 排序管理 (1:1 uni-app hendleSort → ./sort?bookId=)。页面未迁移，先占位提示。
  void _goSortManage() {
    _closeMenus();
    _showToast('排序管理页面建设中');
  }

  /// 交易记录 (1:1 uni-app → ./trading-record?bookId=)。页面未迁移，先占位提示。
  void _goTradeRecord() {
    _closeMenus();
    _showToast('交易记录页面建设中');
  }

  /// 批量加减仓 (1:1 uni-app openBatchAdjust)：需具体账本；页面未迁移，先占位提示。
  void _openBatchAdjust(PositionState state) {
    final bookId = state.currentBookId;
    if (bookId == null || bookId == -1) {
      _showToast('请选择具体账本后操作');
      return;
    }
    _showToast('批量加减仓页面建设中');
  }

  Future<void> _pinToTop(int assetId) async {
    final result =
        await ref.read(positionProvider.notifier).pinToTop(assetId);
    if (!mounted) return;
    switch (result) {
      case 'notFound':
        _showToast('未找到当前持仓');
      case 'alreadyTop':
        _showToast('已在顶部');
      case 'pinned':
        _showToast('已置顶');
      case 'failed':
        _showToast('置顶保存失败');
    }
  }

  void _goCurve() {
    _closeMenus();
    context.push('/user/curve');
  }

  void _goLedger() {
    _closeMenus();
    context.push('/ledger');
  }

  void _showToast(String message) {
    _closeMenus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _showDeleteDialog(PositionItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await PositionDeleteDialog.show(
      context,
      assetName: item.shortName,
      isDark: isDark,
    );
    if (confirmed == true) {
      final ok = await ref.read(positionProvider.notifier).deleteAsset(item.assetId);
      if (!mounted) return;
      if (ok) {
        _showToast('删除成功'); // 1:1 uni-app toast
        ref.read(positionProvider.notifier).loadData();
      }
    }
  }
}
