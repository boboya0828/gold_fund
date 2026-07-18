import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';
import '../../../features/position/providers/position_provider.dart';
import '../../../shared/widgets/z_paging_refresh.dart';
import 'position_holding_row.dart';

/// 持仓表格容器 — 1:1 复刻 .holding-card (含 header + 列表)
class PositionHoldingTable extends ConsumerWidget {
  final PositionState state;
  final bool isDark;
  final int selectedIndex;
  final ValueChanged<int> onSelect; // 触发选中
  final void Function(int index, Offset rowOffset, double rowHeight)?
      onLongSelect; // 触发长按选中并回传行位置
  final VoidCallback onRowTap; // 普通 tap
  final VoidCallback onSortToggle; // 模式菜单切换触发
  final VoidCallback onSortManage; // 表头设置图标 → 排序管理页 (1:1 hendleSort)
  final VoidCallback onSyncTap; // 同步持仓/批量加减仓/空态按钮 (1:1 hendleSynchronization)
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
    this.modeIconKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.isLoggedIn) return _buildEmptyState(context, isDark);

    final items = state.sortedItems;
    final isNormal = state.tableMode == TableShowMode.normal;
    final isCompact = state.tableMode == TableShowMode.compact;
    final isMinimal = state.tableMode == TableShowMode.minimal;
    final hideFlags = PositionHoldingRow.hideFlagsOf(state);
    final mutedIconColor = isDark
        ? const Color(0xFFA7ADB8)
        : const Color(0xFF8E857E);
    final sortInactiveColor = isDark
        ? const Color(0xFFA7ADB8)
        : const Color(0xFFdddddd);
    final headerLabelColor = isDark
        ? const Color(0xFFA7ADB8)
        : const Color(0xFF8D8B87);
    final headerDateColor = isDark
        ? const Color(0xFFA7ADB8)
        : const Color(0xFFC0BAB3);

    // 1:1 uni-app headerDateLabel: 接口 curTradeDate，缺省回退最近交易日
    final dateLabel = state.headerDateLabel;

    final screenW = MediaQuery.of(context).size.width;
    final contentW = screenW - 32; // 减去左右 1rem padding

    // Column widths matching CSS grid fractions exactly
    final double nameW, dayProfitW, indicatorW, holdProfitW, gapW;
    if (isCompact) {
      gapW = 4; // 8rpx
      final availW = contentW - 2 * gapW;
      nameW = availW * 2 / 3.84;
      dayProfitW = availW * 0.92 / 3.84;
      indicatorW = availW * 0.92 / 3.84;
      holdProfitW = availW * 0.92 / 3.84;
    } else {
      gapW = 8; // 16rpx
      final availW = contentW - 3 * gapW;
      nameW = availW * 1.40 / 4.1;
      dayProfitW = availW * 0.9 / 4.1;
      indicatorW = availW * 0.9 / 4.1;
      holdProfitW = availW * 0.9 / 4.1;
    }

    // 表头固定；下拉刷新 + 列表滚动区在下方 (对齐 uni-app: 列头在 z-paging 外, 刷新头在列头下方)
    return Column(
      children: [
        // 固定表头
        _buildHeader(
          isDark,
          isNormal,
          isCompact,
          isMinimal,
          nameW,
          dayProfitW,
          indicatorW,
          holdProfitW,
          gapW,
          mutedIconColor,
          sortInactiveColor,
          headerLabelColor,
          headerDateColor,
          dateLabel,
          state,
          context,
          ref,
        ),
        // 列表区 (仅此处可下拉刷新)；整块灰底 = uni-app .active-box #f5f5f5/#111315
        Expanded(
          child: ColoredBox(
            color: isDark ? const Color(0xFF111315) : const Color(0xFFF5F5F5),
            child: items.isEmpty
              ? _buildEmptyState(context, isDark)
              : ZPagingRefresh(
                  isDark: isDark,
                  onRefresh: () =>
                      ref.read(positionProvider.notifier).refresh(),
                  child: Column(
                    children: [
                      Container(
                        // 列表行容器白底 = uni-app .holding-card #ffffff/#202125
                        color: isDark
                            ? const Color(0xFF202125)
                            : Colors.white,
                        // 性能优化：使用 ListView.builder 替代 Column+map
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (ctx, i) {
                            final item = items[i];
                            return PositionHoldingRow(
                              item: item,
                              index: i,
                              isDark: isDark,
                              nameW: nameW,
                              dayProfitW: dayProfitW,
                              indicatorW: indicatorW,
                              holdProfitW: holdProfitW,
                              isNormal: isNormal,
                              isCompact: isCompact,
                              isMinimal: isMinimal,
                              gapW: gapW,
                              isLast: i == items.length - 1,
                              isSelected: selectedIndex == i,
                              hideHoldAmount: hideFlags.hold,
                              hideIncomeAmount: hideFlags.income,
                              hideIncomeRate: hideFlags.rate,
                              hideFundName: hideFlags.name,
                              onTap: () {
                                onSelect(-1);
                                onRowTap();
                                // 1:1 uni-app hendlGoMetalInfo: 全部账本tab下的基金传 assetId=-1
                                final isAllFund =
                                    state.tabIndex == 0 && item.assetType == 3;
                                final assetId =
                                    isAllFund ? -1 : item.assetId;
                                context.push(
                                  '/position-details?symbolId=${item.symbolId}'
                                  '&assetType=${item.assetType}&assetId=$assetId',
                                );
                              },
                              onLongPress: (offset, height) {
                                if (onLongSelect != null) {
                                  onLongSelect!(i, offset, height);
                                } else {
                                  onSelect(i);
                                }
                              },
                            );
                          },
                        ),
                      ),
                      // 底部操作行 (随列表滚动, 对齐 uni-app .addbox 在 z-paging 内)
                      // 1:1 源码: 左「同步持仓」(icon-tianjia) 右「批量加减仓」(icon-fuzhiyemian)，
                      // 两者都触发 hendleSynchronization
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 10, // margin-top 20rpx
                          bottom: 100, // padding-bottom 200rpx
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _addboxEntry(
                              icon: AppIcons.add,
                              label: '同步持仓',
                              isDark: isDark,
                              iconColor: mutedIconColor,
                              onTap: onSyncTap,
                            ),
                            _addboxEntry(
                              icon: AppIcons.copyPage,
                              label: '批量加减仓',
                              isDark: isDark,
                              iconColor: mutedIconColor,
                              onTap: onSyncTap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    bool isDark,
    bool isNormal,
    bool isCompact,
    bool isMinimal,
    double nameW,
    double dayProfitW,
    double indicatorW,
    double holdProfitW,
    double gapW,
    Color mutedIconColor,
    Color sortInactiveColor,
    Color headerLabelColor,
    Color headerDateColor,
    String dateLabel,
    PositionState state,
    BuildContext context,
    WidgetRef ref,
  ) {
    return Container(
      key: const Key('position-table-header'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202125) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F1EC),
            width: 0.5,
          ),
        ),
      ),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            SizedBox(
              width: nameW,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onSortManage, // 1:1 uni-app hendleSort → 排序管理页
                    child: Icon(
                      AppIcons.settings,
                      size: 20,
                      color: mutedIconColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    key: modeIconKey,
                    onTap: () => _toggleTableModeMenu(context),
                    child: Icon(
                      _tableModeIcon(state.tableMode),
                      key: const Key('position-header-mode-icon'),
                      size: 20,
                      color: mutedIconColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: gapW),
            SizedBox(
              key: const Key('position-header-day-profit'),
              width: dayProfitW,
              child: _SortHeader(
                title: '当日收益',
                field: 'dayProfit',
                dateLabel: dateLabel,
                state: state,
                labelColor: headerLabelColor,
                dateColor: headerDateColor,
                inactiveColor: sortInactiveColor,
                onTap: () =>
                    ref.read(positionProvider.notifier).toggleSort('dayProfit'),
              ),
            ),
            SizedBox(width: gapW),
            SizedBox(
              key: const Key('position-header-indicator'),
              width: indicatorW,
              child: isNormal
                  ? _SortHeader(
                      title: '关联板块',
                      field: 'increaseRatio',
                      dateLabel: dateLabel,
                      state: state,
                      labelColor: headerLabelColor,
                      dateColor: headerDateColor,
                      inactiveColor: sortInactiveColor,
                      onTap: () => ref
                          .read(positionProvider.notifier)
                          .toggleSort('increaseRatio'),
                    )
                  : _SortHeader(
                      title: '最新涨幅',
                      field: isMinimal
                          ? 'increaseRatio'
                          : 'latestPrice.chgRate',
                      dateLabel: dateLabel,
                      state: state,
                      labelColor: headerLabelColor,
                      dateColor: headerDateColor,
                      inactiveColor: sortInactiveColor,
                      onTap: () => ref
                          .read(positionProvider.notifier)
                          .toggleSort(
                            isMinimal ? 'increaseRatio' : 'latestPrice.chgRate',
                          ),
                    ),
            ),
            if (isNormal || isMinimal) ...[
              SizedBox(width: gapW),
              SizedBox(
                key: const Key('position-header-hold-profit'),
                width: holdProfitW,
                child: _SortHeader(
                  title: '持有收益',
                  field: 'holdProfit',
                  dateLabel: dateLabel,
                  state: state,
                  labelColor: headerLabelColor,
                  dateColor: headerDateColor,
                  inactiveColor: sortInactiveColor,
                  onTap: () => ref
                      .read(positionProvider.notifier)
                      .toggleSort('holdProfit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleTableModeMenu(BuildContext context) {
    // 委托回主页面层切换菜单显隐（onSortToggle 内部 toggle）
    onSortToggle();
  }

  IconData _tableModeIcon(TableShowMode mode) {
    switch (mode) {
      case TableShowMode.normal:
        return Icons.menu;
      case TableShowMode.compact:
        return Icons.format_list_bulleted;
      case TableShowMode.minimal:
        return Icons.more_horiz;
    }
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
          Icon(icon, size: 12, color: iconColor), // 源码 mutedIconColor
          const SizedBox(width: 2), // .addbox view margin-left 4rpx
          Text(
            label,
            style: AppTextStyles.cn(
              11, // 22rpx
              color: isDark ? const Color(0xFF8F949D) : const Color(0xFF7A7A82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 60, 30, 0),
        child: Column(
          children: [
            GestureDetector(
              // 1:1 uni-app .ndata-action → hendleSynchronization (导入持仓, 非登录页)
              onTap: onSyncTap,
              child: Container(
                width: 270,
                height: 43,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '导入我的持有基金',
                  style: AppTextStyles.cn(
                    15,
                    color: Colors.white,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '已支持支付宝、天天基金、腾讯理财通、雪球基金等平台的一键导入',
              style: AppTextStyles.cn(
                12,
                color: isDark
                    ? const Color(0xFF8F949D)
                    : const Color(0xFF8D8B87),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 11),
            Text(
              '养基助手应用仅用于数据同步模拟，不涉及任何真实交易',
              style: AppTextStyles.cn(
                10,
                color: isDark
                    ? const Color(0xFF8F949D)
                    : const Color(0xFF8D8B87),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 排序表头 — 1:1 复刻 .holding-header-sort
class _SortHeader extends StatelessWidget {
  final String title;
  final String field;
  final String dateLabel;
  final PositionState state;
  final Color labelColor;
  final Color dateColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _SortHeader({
    required this.title,
    required this.field,
    required this.dateLabel,
    required this.state,
    required this.labelColor,
    required this.dateColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = state.sortField == field;
    const activeColor = Color(0xFFE05665); // 源码排序箭头激活色

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // 标题/日期文字：右侧留 9px (对齐源码 padding-right:18rpx)，给排序箭头留空间
          Padding(
            padding: const EdgeInsets.only(right: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: AppTextStyles.cn(11, color: labelColor, height: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel,
                  style: AppTextStyles.num(9, color: dateColor, height: 1),
                ),
              ],
            ),
          ),
          // 排序箭头：贴列真实右边缘 (对齐源码 .navimag { position:absolute; right:0 },
          // 不受父级 padding 影响，与下方数据列的右边缘对齐)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
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
      size: const Size(6, 4),
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
