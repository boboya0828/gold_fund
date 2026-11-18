import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';
import '../../../features/position/providers/position_provider.dart';
import '../../../shared/widgets/z_paging_refresh.dart';
import '../../../core/utils/stock_switch_list.dart';
import 'position_holding_row.dart';
import '../../../core/utils/screen_adapt.dart';

/// 持仓表格容器 — 1:1 复刻 .demo-table-header + .active-box（左固定列 + 右侧横滑 16 列）
///
/// 布局参数（index.vue:2542-2557 + CSS）：
/// - 左固定列 300rpx = 150px（CSS calc(284rpx + 16rpx)）
/// - 右侧每列 144rpx = 72px，表头 78rpx = 39px，行高 110rpx = 55px
/// - 分隔线 1rpx #f4f1ec（深 #2B2D33）；表头上+下线，行仅底线，末行无线
/// - 裁剪区右内边距：可横滑 32rpx / 不溢出 24rpx
/// - 横滑中固定列右缘投影；scrollLeft=0 时表头右端显示右箭头提示
class PositionHoldingTable extends ConsumerStatefulWidget {
  final PositionState state;
  final bool isDark;
  final int selectedIndex;
  final ValueChanged<int> onSelect; // 触发选中
  final void Function(int index, Offset rowOffset, double rowHeight)?
      onLongSelect; // 触发长按选中并回传行位置
  final VoidCallback onRowTap; // 普通 tap
  final VoidCallback onSortToggle; // 模式菜单切换触发
  final VoidCallback onSortManage; // 表头设置图标 → 排序管理页 (1:1 hendleSort)
  final VoidCallback onSyncTap; // 同步持仓/空态按钮 (1:1 hendleSynchronization)
  final VoidCallback onBatchTap; // 批量加减仓 (1:1 openBatchSyncPage)
  final VoidCallback? onDataSourceTap; // 估值数据源弹框（未移植时可为 null）
  final GlobalKey? modeIconKey; // 模式图标锚点（菜单定位用）

  const PositionHoldingTable({
    super.key,
    required this.state,
    required this.isDark,
    required this.selectedIndex,
    required this.onSelect,
    this.onLongSelect,
    required this.onRowTap,
    required this.onSortToggle,
    required this.onSortManage,
    required this.onSyncTap,
    required this.onBatchTap,
    this.onDataSourceTap,
    this.modeIconKey,
  });

  @override
  ConsumerState<PositionHoldingTable> createState() =>
      _PositionHoldingTableState();
}

class _PositionHoldingTableState extends ConsumerState<PositionHoldingTable> {
  static double get fixedWidth => 150.sx; // 300rpx
  static double get cellWidth => 72.sx; // 144rpx
  static double get headerHeight => 39.sx; // 78rpx
  static double get rowHeight => PositionHoldingFixedCell.rowHeight; // 110rpx

  final ScrollController _headCtrl = ScrollController();
  final ScrollController _bodyCtrl = ScrollController();
  bool _syncing = false;
  bool _scrolled = false; // scrollLeft > 0：隐藏提示箭头 + 显示交界投影

  @override
  void initState() {
    super.initState();
    _bodyCtrl.addListener(_onBodyScroll);
    _headCtrl.addListener(_onHeadScroll);
  }

  @override
  void dispose() {
    _headCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _onBodyScroll() {
    _syncFrom(_bodyCtrl, _headCtrl);
    final scrolled = _bodyCtrl.offset > 0.5;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  void _onHeadScroll() {
    _syncFrom(_headCtrl, _bodyCtrl);
  }

  /// 表头/行区横滑双向同步（防回环）
  void _syncFrom(ScrollController from, ScrollController to) {
    if (_syncing || !to.hasClients) return;
    _syncing = true;
    final target = from.offset.clamp(0.0, to.position.maxScrollExtent);
    if ((to.offset - target).abs() > 0.5) to.jumpTo(target);
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = widget.isDark;
    final items = state.sortedItems;
    final allColumns = visiblePositionColumns(state);
    final isMinimal = state.tableMode == TableShowMode.minimal;
    final columns = isMinimal
        ? allColumns
            .where((c) => kPositionMiniColumnKeys.contains(c.key))
            .toList()
        : allColumns;
    final singleLine = state.tableMode != TableShowMode.normal;

    final cardBg = isDark ? const Color(0xFF202125) : Colors.white;
    final sepColor = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC);
    final activeBoxBg =
        isDark ? const Color(0xFF111315) : const Color(0xFFF5F5F5);

    // 内容溢出可横滑时右内边距 32rpx，不溢出 24rpx
    final rightWidth = columns.length * cellWidth;
    final screenW = MediaQuery.of(context).size.width;
    final overflows = rightWidth > screenW - fixedWidth;
    final rightPad = overflows ? 16.0 : 12.0;

    // 模式切换后横滑偏移归零（1:1 uni-app watch(listMunActive)）
    final modeKey = state.tableMode;
    if (_lastModeKey != modeKey) {
      _lastModeKey = modeKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_bodyCtrl.hasClients) _bodyCtrl.jumpTo(0);
        if (_headCtrl.hasClients) _headCtrl.jumpTo(0);
      });
    }

    return Column(
      children: [
        // ===== 固定表头 .demo-table-header =====
        _buildHeader(columns, cardBg, sepColor, rightPad, overflows),
        // ===== 列表区 .active-box =====
        Expanded(
          child: ColoredBox(
            color: activeBoxBg,
            child: items.isEmpty
                ? _buildEmptyArea(context, isDark)
                : ZPagingRefresh(
                    isDark: isDark,
                    onRefresh: () =>
                        ref.read(positionProvider.notifier).refresh(),
                    child: Column(
                      children: [
                        SizedBox(
                          height: rowHeight * items.length,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 左固定列 .demo-fixed-list
                              Container(
                                width: fixedWidth,
                                decoration: BoxDecoration(
                                  boxShadow: _scrolled
                                      ? [
                                          // 8rpx 0 10rpx -6rpx rgba(31,36,48,0.08)
                                          BoxShadow(
                                            color: Color(0x141F2430),
                                            blurRadius: 5.sx,
                                            spreadRadius: -3,
                                            offset: Offset(4.sx, 0),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < items.length; i++)
                                      PositionHoldingFixedCell(
                                        item: items[i],
                                        index: i,
                                        isDark: isDark,
                                        isMinimal: isMinimal,
                                        isLast: i == items.length - 1,
                                        isSelected:
                                            widget.selectedIndex == i,
                                        hideHoldAmount: state.hideHoldAmount,
                                        hideFundName: state.hideFundName,
                                        showFundCode: state.showFundCode,
                                        showHoldingAmount:
                                            state.showHoldingAmount,
                                        fontScale: state.fontScale,
                                        onTap: () =>
                                            _handleRowTap(context, i, items[i]),
                                        onLongPress: (offset, height) {
                                          final cb = widget.onLongSelect;
                                          if (cb != null) {
                                            cb(i, offset, height);
                                          } else {
                                            widget.onSelect(i);
                                          }
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              // 右侧横滑区 .demo-right-mask
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  controller: _bodyCtrl,
                                  physics: const ClampingScrollPhysics(),
                                  child: SizedBox(
                                    width: rightWidth + rightPad,
                                    child: Column(
                                      children: [
                                        for (var i = 0; i < items.length; i++)
                                          _buildRightRow(
                                            items[i],
                                            i,
                                            columns,
                                            singleLine,
                                            cardBg,
                                            sepColor,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 底部操作行 .addbox（随列表滚动）
                        _buildAddbox(isDark),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  TableShowMode? _lastModeKey;

  // ===== 表头 =====
  Widget _buildHeader(
    List<PositionColumnDef> columns,
    Color cardBg,
    Color sepColor,
    double rightPad,
    bool overflows,
  ) {
    final isDark = widget.isDark;
    final state = widget.state;
    final mutedIconColor =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8E857E);
    final headerLabelColor =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8D8B87);
    final headerDateColor =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFFC0BAB3);
    final sortInactiveColor =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFFDDDDDD);

    return Container(
      key: const Key('position-table-header'),
      height: headerHeight,
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          top: BorderSide(color: sepColor, width: 0.5),
          bottom: BorderSide(color: sepColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 左固定图标区 .demo-fixed-head
          Container(
            width: fixedWidth,
            padding: EdgeInsets.only(left: 16.sx), // padding-left 32rpx
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onSortManage, // 1:1 hendleSort → 表头管理页
                  child: Icon(AppIcons.settings, size: 20.sx, color: mutedIconColor),
                ),
                SizedBox(width: 12.sx), // gap 24rpx
                GestureDetector(
                  key: widget.modeIconKey,
                  onTap: widget.onSortToggle, // 1:1 toggleTableModeMenu
                  child: Icon(
                    _tableModeIcon(state.tableMode),
                    key: const Key('position-header-mode-icon'),
                    size: 20.sx,
                    color: mutedIconColor,
                  ),
                ),
                SizedBox(width: 12.sx),
                GestureDetector(
                  onTap: widget.onDataSourceTap, // 估值数据源弹框（未移植时禁用）
                  child: Icon(
                    AppIcons.dataSource,
                    size: 20.sx,
                    color: mutedIconColor,
                  ),
                ),
              ],
            ),
          ),
          // 右侧列头 .demo-header-clip
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _headCtrl,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: columns.length * cellWidth + rightPad,
                    child: Row(
                      children: [
                        for (final col in columns)
                          _SortHeaderCell(
                            key: Key('position-header-${col.keySlug}'),
                            column: col,
                            dateLabel: _columnDateLabel(col, state),
                            state: state,
                            labelColor: headerLabelColor,
                            dateColor: headerDateColor,
                            inactiveColor: sortInactiveColor,
                            onTap: () => ref
                                .read(positionProvider.notifier)
                                .toggleSort(col.sortField),
                          ),
                      ],
                    ),
                  ),
                ),
                // 右端横滑提示箭头（scrollLeft=0 时显示）
                if (!_scrolled && overflows)
                  Positioned(
                    right: 2.sx, // right 4rpx
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(
                        Icons.chevron_right,
                        size: 12.sx,
                        color: Color(0xFFB3B0AA),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _columnDateLabel(PositionColumnDef col, PositionState state) {
    switch (col.dateSource) {
      case 'nav':
        return state.latestNavDateLabel;
      case 'ext':
        return state.extendedDateLabel;
      default:
        return state.headerDateLabel;
    }
  }

  // ===== 右侧数据行 =====
  Widget _buildRightRow(
    PositionItem item,
    int index,
    List<PositionColumnDef> columns,
    bool singleLine,
    Color cardBg,
    Color sepColor,
  ) {
    final isDark = widget.isDark;
    final isLast = index == widget.state.sortedItems.length - 1;
    final isSelected = widget.selectedIndex == index;
    final cells = buildHoldingCells(item, columns, widget.state, isDark);
    // 注意：必须用行自身的 context 量取位置（Builder 包住 GestureDetector）。
    // 直接用外层传入的 context 会量到整个表格组件的 RenderBox，
    // 导致长按弹框拿到错误 rowOffset/rowHeight 而"飘到页面顶部"（已踩坑修复）。
    return Builder(
      builder: (rowContext) => GestureDetector(
        onTap: () => _handleRowTap(context, index, item),
        onLongPressStart: (_) {
          final box = rowContext.findRenderObject() as RenderBox?;
          if (box != null) {
            final cb = widget.onLongSelect;
            if (cb != null) {
              cb(index, box.localToGlobal(Offset.zero), box.size.height);
            } else {
              widget.onSelect(index);
            }
          }
        },
      child: Container(
        height: rowHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2A2C31) : const Color(0xFFF1F1F1))
              : cardBg,
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: sepColor, width: 0.5)),
        ),
        child: Row(
          children: [
            for (final cell in cells)
              PositionHoldingCell(
                cell: cell,
                rowIndex: index,
                isDark: isDark,
                singleLine: singleLine,
                fontScale: widget.state.fontScale,
              ),
          ],
        ),
      ),
      ),
    );
  }

  /// 行点击 → 持仓详情 (1:1 uni-app onMetalRowClick → hendlGoMetalInfo)
  void _handleRowTap(BuildContext context, int index, PositionItem item) {
    widget.onSelect(-1);
    widget.onRowTap();
    // 全部账本 tab 下的基金传 assetId=-1
    final isAllFund =
        widget.state.tabIndex == 0 && item.assetType == 3;
    final assetId = isAllFund ? -1 : item.assetId;
    // 1:1 源码：生成详情页左右切换列表 token（当前排序后基金列表的 symbolId 序列）
    final switchToken = setStockSwitchList(
        [for (final e in widget.state.sortedItems) e.symbolId]);
    context.push(
      '/position-details?symbolId=${item.symbolId}'
      '&assetType=${item.assetType}&assetId=$assetId&switchToken=$switchToken',
    );
  }

  IconData _tableModeIcon(TableShowMode mode) {
    switch (mode) {
      case TableShowMode.normal:
        return Icons.menu; // bars
      case TableShowMode.compact:
        return Icons.format_list_bulleted; // list
      case TableShowMode.minimal:
        return Icons.more_horiz; // more-filled
    }
  }

  // ===== 底部操作 .addbox =====
  Widget _buildAddbox(bool isDark) {
    final mutedIconColor =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8E857E);
    return Padding(
      padding: EdgeInsets.only(
        left: 16.sx,
        right: 16.sx,
        top: 10.sx, // margin-top 20rpx
        bottom: 100.sx, // padding-bottom 200rpx
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _addboxEntry(
            icon: AppIcons.add,
            label: '同步持仓',
            isDark: isDark,
            iconColor: mutedIconColor,
            onTap: widget.onSyncTap,
          ),
          _addboxEntry(
            icon: AppIcons.copyPage,
            label: '批量加减仓',
            isDark: isDark,
            iconColor: mutedIconColor,
            onTap: widget.onBatchTap,
          ),
        ],
      ),
    );
  }

  /// .addbox 单个入口: 图标(12px) + 文字(22rpx #7A7A82 / 暗 #8F949D)
  Widget _addboxEntry({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sx, color: iconColor),
          SizedBox(width: 2.sx), // .addbox view margin-left 4rpx
          Text(
            label,
            style: AppTextStyles.cn(
              11.sx, // 22rpx
              color: isDark ? const Color(0xFF8F949D) : const Color(0xFF7A7A82),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 空态（含游客）：addbox 仍显示在顶部 + .ndata 覆盖层 =====
  Widget _buildEmptyArea(BuildContext context, bool isDark) {
    return Stack(
      children: [
        // addbox 在 z-paging 内顶部（空列表时也渲染）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: SizedBox(
              height: 26.sx, // margin-top 20rpx + 行高，占位避免与 ndata 重叠
              child: Stack(
                children: [
                  Positioned(
                    top: 10.sx,
                    left: 16.sx,
                    right: 16.sx,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _addboxEntry(
                          icon: AppIcons.add,
                          label: '同步持仓',
                          isDark: isDark,
                          iconColor: isDark
                              ? const Color(0xFFA7ADB8)
                              : const Color(0xFF8E857E),
                          onTap: widget.onSyncTap,
                        ),
                        _addboxEntry(
                          icon: AppIcons.copyPage,
                          label: '批量加减仓',
                          isDark: isDark,
                          iconColor: isDark
                              ? const Color(0xFFA7ADB8)
                              : const Color(0xFF8E857E),
                          onTap: widget.onBatchTap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // .ndata：absolute 铺满，padding 120rpx 60rpx 0，内容垂直居中（justify-center）
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(30.sx, 60.sx, 30.sx, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  // 游客 → /login；登录态 → hendleSynchronization 导入流程
                  onTap: () {
                    if (!widget.state.isLoggedIn) {
                      context.push('/login');
                    } else {
                      widget.onSyncTap();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxWidth: 270.sx), // 540rpx
                    height: 43.sx, // 86rpx
                    decoration: BoxDecoration(
                      color: AppColors.primary, // #E15665
                      borderRadius: BorderRadius.circular(5.sx), // 10rpx
                      boxShadow: [
                        // 0 16rpx 36rpx rgba(82,122,248,0.16)
                        BoxShadow(
                          color: Color(0x29527AF8),
                          blurRadius: 18.sx,
                          offset: Offset(0, 8.sx),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '导入我的持有基金',
                      style: AppTextStyles.cn(
                        15.sx, // 30rpx
                        color: Colors.white,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.sx), // margin-top 24rpx
                Text(
                  '已支持支付宝、天天基金、腾讯理财通、雪球基金等平台的一键导入',
                  style: AppTextStyles.cn(
                    12.sx, // 24rpx
                    color: isDark
                        ? const Color(0xFF8F949D)
                        : const Color(0xFF8D8B87),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 11.sx), // margin-top 22rpx
                Text(
                  '养基助手应用仅用于数据同步模拟，不涉及任何真实交易',
                  style: AppTextStyles.num(
                    10.sx, // 20rpx
                    color: isDark
                        ? const Color(0xFF8F949D)
                        : const Color(0xFF8D8B87),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 排序表头单元格 — 1:1 复刻 .demo-right-cell.holding-header-sort
class _SortHeaderCell extends StatelessWidget {
  final PositionColumnDef column;
  final String dateLabel;
  final PositionState state;
  final Color labelColor;
  final Color dateColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _SortHeaderCell({
    super.key,
    required this.column,
    required this.dateLabel,
    required this.state,
    required this.labelColor,
    required this.dateColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = state.sortField == column.sortField;
    const activeColor = Color(0xFFE05665); // 源码排序箭头激活色

    return GestureDetector(
      onTap: onTap, // 1:1 toggleMetalSort: desc → asc → 取消
      child: Container(
        width: _PositionHoldingTableState.cellWidth,
        height: _PositionHoldingTableState.headerHeight,
        padding: EdgeInsets.only(right: 4.sx), // 8rpx
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  column.title,
                  style: AppTextStyles.cn(11.sx, color: labelColor, height: 1.2),
                ),
                SizedBox(height: 4.sx), // margin-top 8rpx
                Text(
                  dateLabel,
                  style: AppTextStyles.num(9.sx, color: dateColor, height: 1),
                ),
              ],
            ),
            SizedBox(width: 3.sx), // gap 6rpx
            // .navimag：表头横滑列上内联布局（width 14rpx height 22rpx）
            SizedBox(
              width: 7.sx,
              height: 11.sx,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SortTriangle(
                    pointsUp: true,
                    color: isActive && state.sortOrder == 'asc'
                        ? activeColor
                        : inactiveColor,
                  ),
                  const SizedBox(height: 1),
                  _SortTriangle(
                    pointsUp: false,
                    color: isActive && state.sortOrder == 'desc'
                        ? activeColor
                        : inactiveColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortTriangle extends StatelessWidget {
  final bool pointsUp;
  final Color color;

  const _SortTriangle({required this.pointsUp, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(6.sx, 4.sx),
      painter: _SortTrianglePainter(pointsUp: pointsUp, color: color),
    );
  }
}

class _SortTrianglePainter extends CustomPainter {
  final bool pointsUp;
  final Color color;

  const _SortTrianglePainter({required this.pointsUp, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SortTrianglePainter oldDelegate) {
    return oldDelegate.pointsUp != pointsUp || oldDelegate.color != color;
  }
}
