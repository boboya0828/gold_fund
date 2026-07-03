import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/position/providers/position_provider.dart';
import '../../theme/app_colors.dart';
import 'widgets/position_nav_header.dart';
import 'widgets/position_asset_card.dart';
import 'widgets/position_holding_table.dart';
import 'widgets/position_quick_menu.dart';
import 'widgets/position_table_mode_menu.dart';
import 'widgets/position_action_popup.dart';
import 'widgets/position_delete_dialog.dart';

/// 持仓页面 — 1:1 复刻 uni-app pages/positionv1/index.uvue
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

  // 长按行的定位数据 (用于操作弹窗跟随)
  final Offset _rowOffset = Offset.zero;
  final double _rowHeight = 50;

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
        SafeArea(
          child: RefreshIndicator(
            color: AppColors.upColor,
            onRefresh: () => ref.read(positionProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                PositionAssetCard(state: state, isDark: isDark),
                PositionHoldingTable(
                  state: state,
                  isDark: isDark,
                  selectedIndex: _selectedIndex,
                  onSelect: (idx) => setState(() {
                    _selectedIndex = idx;
                    _showPopup = idx >= 0;
                  }),
                  onRowTap: () => setState(() {
                    _selectedIndex = -1;
                    _showPopup = false;
                  }),
                  onSortToggle: () => setState(() {
                    _showQuickMenu = false;
                    _showTableModeMenu = !_showTableModeMenu;
                  }),
                ),
              ]),
            ),
          ),
        ),

        // 快捷菜单蒙层
        if (_showQuickMenu) ...[
          GestureDetector(
            onTap: () => setState(() => _showQuickMenu = false),
            child: Container(color: maskColor),
          ),
          Positioned(
            right: 12,
            top: topPadding + 34,
            child: PositionQuickMenu(
              isDark: isDark,
              onSync: () => _goOptionalSearch(),
              onBatchSync: () => _showDevelopingSnackBar(),
              onAnalysis: () => _goCurve(),
              onLedger: () => _goLedger(),
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
            right: 16,
            top: 160,
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
                context.push('/position-details?symbolId=${target.symbolId}&assetType=${target.assetType}');
              }
            },
            onBatchEdit: () {
              setState(() { _showPopup = false; _selectedIndex = -1; });
              context.push('/optional-search');
            },
            onPinTop: () {
              final target = _getSelectedItem(state);
              if (target != null) {
                ref.read(positionProvider.notifier).pinToTop(target.assetId);
              }
              setState(() { _showPopup = false; _selectedIndex = -1; });
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

  void _goOptionalSearch() {
    _closeMenus();
    context.push('/optional-search');
  }

  void _goCurve() {
    _closeMenus();
    context.push('/user/curve');
  }

  void _goLedger() {
    _closeMenus();
    context.push('/ledger');
  }

  void _showDevelopingSnackBar() {
    _closeMenus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('批量调仓开发中'), duration: Duration(seconds: 2)),
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
      if (ok) ref.read(positionProvider.notifier).loadData();
    }
  }
}
