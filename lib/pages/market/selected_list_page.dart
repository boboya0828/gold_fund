import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/text_styles.dart';

/// 精选榜单页 — 1:1 复刻 zdj-v1 pages/market/selectedlist.vue
///
/// 5 个 tab：热搜榜(FundHeatTop) / 自选榜(FundPickTop) / 持有榜(FundHoldTop) /
/// 涨幅榜(FundQuoteTop) / 连涨榜(FundStreakTop)；支持按基金类型筛选
/// （全部/股票型/混合型/债券型/QDII/FOF/指数型/其它），分类规则与源码
/// FUND_TYPE_TO_FILTER + assetType 兜底一致。行点击 → /position-details?symbolId=。
class SelectedListPage extends ConsumerStatefulWidget {
  /// 初始 tab：hot / selected / holding / rise / streak（默认 selected，对齐源码）
  final String? initialTab;

  const SelectedListPage({super.key, this.initialTab});

  @override
  ConsumerState<SelectedListPage> createState() => _SelectedListPageState();
}

class _SelectedListPageState extends ConsumerState<SelectedListPage> {
  final ApiClient _api = ApiClient();

  static const _tabs = [
    ('hot', '热搜榜'),
    ('selected', '自选榜'),
    ('holding', '持有榜'),
    ('rise', '涨幅榜'),
    ('streak', '连涨榜'),
  ];
  static const _endpoints = {
    'hot': ApiEndpoints.marketFundHeatTop,
    'selected': ApiEndpoints.marketFundPickTop,
    'holding': ApiEndpoints.marketFundHoldTop,
    'rise': ApiEndpoints.marketFundQuoteTop,
    'streak': ApiEndpoints.marketFundStreakTop,
  };
  static const _titles = {
    'hot': '今日基金热搜榜',
    'selected': '今日基金自选榜',
    'holding': '今日基金持有榜',
    'rise': '今日基金涨幅榜',
    'streak': '今日基金连涨榜',
  };
  static const _filterOptions = [
    ('all', '全部'),
    ('stock', '股票型'),
    ('mixed', '混合型'),
    ('bond', '债券型'),
    ('qdii', 'QDII'),
    ('fof', 'FOF'),
    ('index', '指数型'),
    ('alt', '其它'),
  ];
  static const _boardKeys = ['all', 'stock', 'mixed', 'bond', 'qdii', 'fof', 'index', 'alt'];

  late String _activeTab = _tabs.any((t) => t.$1 == widget.initialTab) ? widget.initialTab! : 'selected';
  String _currentFilter = 'all';
  bool _showDropdown = false;

  String _updateTime = '--';
  Map<String, List<_FundItem>> _boards = {for (final k in _boardKeys) k: const []};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRankData());
  }

  // ==================== 数据 ====================

  Future<void> _fetchRankData() async {
    try {
      final res = await _api.get(_endpoints[_activeTab] ?? ApiEndpoints.marketFundPickTop);
      final parsed = _parseApiData(res.data);
      final t = _formatUpdateTime(parsed.updateTime);
      if (!mounted) return;
      setState(() {
        _updateTime = t.isEmpty ? '--' : t;
        _boards = {
          for (final k in _boardKeys) k: _buildList(parsed.rawLists[k] ?? const []),
        };
      });
    } catch (_) {}
  }

  /// parseApiData：兼容 新结构(data 直接是数组) 与 旧结构(data 按 all/stock/… 分组)
  _ParsedBoard _parseApiData(dynamic body) {
    final payload = body is Map ? (body['data'] ?? body) : body;
    final result = _ParsedBoard();
    dynamic bodyTimestamp() => body is Map ? body['timestamp'] : null;

    if (payload is List) {
      result.rawLists['all'] = payload;
      for (final item in payload) {
        if (item is Map) result.put(_resolveFilterKey(item), item);
      }
      // 更新时间优先取第一条 latestPrice.latestTime，其次 latestTime，最后 timestamp
      dynamic t;
      if (payload.isNotEmpty && payload.first is Map) {
        final first = payload.first as Map;
        final lp = first['latestPrice'];
        t = (lp is Map ? lp['latestTime'] : null) ?? first['latestTime'];
      }
      result.updateTime = t ?? bodyTimestamp() ?? '';
      return result;
    }

    if (payload is Map) {
      for (final key in _boardKeys) {
        final section = _extractBoardSection(payload[key]);
        result.rawLists[key] = section.items;
        if (_isEmptyTime(result.updateTime) && !_isEmptyTime(section.updateTime)) {
          result.updateTime = section.updateTime;
        }
      }
      if (_isEmptyTime(result.updateTime)) {
        result.updateTime =
            payload['updateTime'] ?? payload['updatedAt'] ?? payload['time'] ?? bodyTimestamp() ?? '';
      }
      // 只有 all 没有分类 → 前端按 fundTypeName 再分一次
      final hasCategory = _boardKeys
          .where((k) => k != 'all')
          .any((k) => (result.rawLists[k] ?? const []).isNotEmpty);
      final all = result.rawLists['all'] ?? const [];
      if (!hasCategory && all.isNotEmpty) {
        for (final item in all) {
          if (item is Map) result.put(_resolveFilterKey(item), item);
        }
      }
    }
    return result;
  }

  /// extractBoardSection：数组直接为 items；对象取 items/list + updateTime
  _BoardSection _extractBoardSection(dynamic section) {
    if (section is List) return _BoardSection(null, section);
    if (section is Map) {
      final items = section['items'] is List
          ? section['items'] as List
          : (section['list'] is List ? section['list'] as List : const []);
      return _BoardSection(
        section['updateTime'] ?? section['updatedAt'] ?? section['time'],
        items,
      );
    }
    return _BoardSection(null, const []);
  }

  /// resolveFilterKey：先按基金类型名称关键词归类（按规则顺序），再按 assetType 兜底
  String _resolveFilterKey(Map item) {
    final typeName = '${item['fundTypeName'] ?? item['fundType'] ?? item['typeName'] ?? ''}';
    const rules = [
      ('stock', ['股票', '普通股票', '被动指数型股票', '增强指数型股票']),
      ('mixed', ['混合', '灵活配置', '偏股混合', '偏债混合']),
      ('bond', ['债券', '纯债', '一级债', '二级债']),
      ('qdii', ['QDII']),
      ('fof', ['FOF']),
      ('index', ['指数']),
    ];
    for (final rule in rules) {
      if (rule.$2.any((k) => typeName.contains(k))) return rule.$1;
    }
    final assetType = item['assetType'] is num ? (item['assetType'] as num).toInt() : int.tryParse('${item['assetType']}');
    switch (assetType) {
      case 1:
        return 'stock';
      case 2:
        return 'bond';
      case 3:
        return 'mixed';
      case 4:
        return 'index';
      case 5:
        return 'qdii';
      case 6:
        return 'fof';
      default:
        return 'alt';
    }
  }

  /// buildList：rate = latestPrice.chgRate ?? chgRate ?? 0 → ±x.xx%
  List<_FundItem> _buildList(List<dynamic> rawList) {
    return rawList.asMap().entries.map((e) {
      final item = e.value is Map ? e.value as Map : const {};
      final lp = item['latestPrice'];
      final chg = _toNum(lp is Map ? (lp['chgRate'] ?? item['chgRate']) : item['chgRate']) ?? 0;
      return _FundItem(
        rank: e.key + 1,
        name: _firstStr(item, const ['shortName', 'name'], '--'),
        code: _firstStr(item, const ['code'], '--'),
        symbolId: '${item['symbolId'] ?? ''}',
        rate: '${chg >= 0 ? '+' : ''}${chg.toStringAsFixed(2)}%',
        trend: chg >= 0 ? 'up' : 'down',
      );
    }).toList();
  }

  /// formatUpdateTime：毫秒时间戳或可解析日期串 → MM-dd HH:mm:ss；其余原样返回
  String _formatUpdateTime(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      return _fmtDateTime(DateTime.fromMillisecondsSinceEpoch(value.toInt()));
    }
    final text = value.toString().trim();
    final d = DateTime.tryParse(text);
    if (d != null) return _fmtDateTime(d);
    return text;
  }

  String _fmtDateTime(DateTime d) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
  }

  // ==================== 事件 ====================

  void _switchTab(String tab) {
    if (_activeTab == tab) return;
    // 源码 watchEffect 仅重新拉取，加载期间保留旧榜单数据（loading 无 UI）
    setState(() {
      _activeTab = tab;
      _showDropdown = false;
    });
    _fetchRankData();
  }

  void _selectFilter(String value) {
    setState(() {
      _currentFilter = value;
      _showDropdown = false;
    });
  }

  void _handleJump(_FundItem item) {
    if (item.symbolId.isEmpty) return;
    context.push('/position-details?symbolId=${item.symbolId}');
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF8F5F2),
      body: Stack(children: [
        // .page-container 背景图 selectlist.png（100% × 474rpx=237），暗色无图
        if (!isDark)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/img/selectlist.png',
                height: 237,
                width: double.infinity,
                fit: BoxFit.fill,
                // 资源待注册进 pubspec（见迁移报告）；未注册时退回纯色背景
                errorBuilder: (_, _, _) => const SizedBox(height: 237),
              ),
            ),
          ),
        Column(children: [
          // bgState1 + darkMask：浅色透明(透出背景图)，深色 #202125
          CustomNavBar(
            title: '养基助手',
            backgroundColor: isDark ? AppColors.darkSurface : Colors.transparent,
            titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
          ),
          Expanded(
            child: Column(children: [
              _buildHero(isDark),
              Expanded(child: _buildRankPanel(isDark)),
            ]),
          ),
        ]),
      ]),
    );
  }

  /// .hero-section：标题 + 5 tab 胶囊 + 装饰线 + 更新时间/数据来源
  Widget _buildHero(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 9, 15, 13), // 18rpx 30rpx 26rpx
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _titles[_activeTab] ?? '今日基金自选榜',
          style: AppTextStyles.cn(26, // 52rpx
              color: isDark ? AppColors.darkText : const Color(0xFF452008),
              weight: FontWeight.w600,
              height: 1.16),
        ),
        // .tab-list
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10), // 20rpx
          padding: const EdgeInsets.all(3), // 6rpx
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF282828) : const Color(0x91FFFFFF),
            borderRadius: BorderRadius.circular(8), // 16rpx
          ),
          child: Row(
            children: _tabs.map((t) {
              final active = _activeTab == t.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab(t.$1),
                  child: Container(
                    height: 24, // 48rpx
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? (isDark ? const Color(0xFFE05665) : const Color(0xFFF7CD86))
                          : null,
                      borderRadius: BorderRadius.circular(7), // 14rpx
                    ),
                    child: Text(
                      t.$2,
                      style: AppTextStyles.cn(
                        14, // 28rpx
                        height: 1,
                        color: active
                            ? (isDark ? Colors.white : const Color(0xFF693717))
                            : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFF7B563E)),
                        weight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        _buildTopBgs(isDark),
        // .hero-meta
        Container(
          width: 250, // 500rpx
          padding: const EdgeInsets.symmetric(vertical: 6), // 12rpx
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text('更新时间', style: _metaStyle(isDark)),
                const SizedBox(width: 5), // hero-metagx margin-right 10rpx
                Text(_updateTime, style: _metaStyle(isDark)),
              ]),
              Text('数据来源：养基助手', style: _metaStyle(isDark)),
            ],
          ),
        ),
        _buildTopBgs(isDark),
      ]),
    );
  }

  TextStyle _metaStyle(bool isDark) =>
      AppTextStyles.cn(10, color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF956F56), height: 1);

  /// .topbgs：500rpx × 2rpx 白色渐变装饰线（暗色为 #2B2D33 实线）
  Widget _buildTopBgs(bool isDark) {
    return Container(
      width: 250,
      height: 1,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2D33) : null,
        gradient: isDark
            ? null
            : const LinearGradient(colors: [
                Color(0x00FFFFFF),
                Color(0xA3FFFFFF), // rgba(255,255,255,.64)
                Color(0x00FFFFFF),
              ]),
      ),
    );
  }

  /// .rank-panel：白底圆角面板（筛选 + 列表）
  Widget _buildRankPanel(bool isDark) {
    final visibleList = _boards[_currentFilter] ?? _boards['all'] ?? const <_FundItem>[];
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), // 36rpx
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A704C25), // rgba(112,76,37,.04)
                  offset: Offset(0, -5), // -10rpx
                  blurRadius: 15, // 30rpx
                ),
              ],
      ),
      child: Stack(children: [
        Column(children: [
          _buildPanelHead(isDark),
          Expanded(
            // 点击列表区域收起筛选下拉（源码 scroll-view @click）
            child: GestureDetector(
              onTap: () {
                if (_showDropdown) setState(() => _showDropdown = false);
              },
              behavior: HitTestBehavior.translucent,
              child: visibleList.isEmpty
                  // .empty-state：顶部横向居中（非垂直居中）
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(15, 28, 15, 36), // 56rpx 30rpx 72rpx
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('当前筛选下暂无榜单数据',
                              style: AppTextStyles.cn(12, color: const Color(0xFFB8AFAA))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: visibleList.length,
                      itemBuilder: (context, i) => _buildRankRow(visibleList[i], isDark),
                    ),
            ),
          ),
        ]),
        if (_showDropdown) _buildFilterDropdown(isDark),
      ]),
    );
  }

  /// .panel-head：左 筛选切换(金色+切换图标)，右列 涨跌幅
  Widget _buildPanelHead(bool isDark) {
    final filterLabel =
        _filterOptions.firstWhere((o) => o.$1 == _currentFilter, orElse: () => _filterOptions.first).$2;
    final filterColor = isDark ? const Color(0xFFE05665) : const Color(0xFFF2A93F);
    return Container(
      height: 36, // 72rpx
      padding: const EdgeInsets.symmetric(horizontal: 15), // 0 30rpx
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFE9E5),
            width: 0.5, // 1rpx
          ),
        ),
      ),
      child: Row(children: [
        // grid-column 1/3：筛选切换
        GestureDetector(
          onTap: () => setState(() => _showDropdown = !_showDropdown),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Text(filterLabel, style: AppTextStyles.cn(13, color: filterColor)), // 26rpx
            const SizedBox(width: 4), // gap 8rpx
            Icon(AppIcons.switch2, size: 12, color: filterColor), // icon-qiehuan 24rpx
          ]),
        ),
        const Expanded(child: SizedBox()),
        SizedBox(
          width: 90, // 180rpx
          child: Center(
            child: Text(
              '涨跌幅',
              style: AppTextStyles.cn(13,
                  color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF9D98A5)),
            ),
          ),
        ),
      ]),
    );
  }

  /// .filter-dropdown：面板头部下方的类型筛选浮层
  Widget _buildFilterDropdown(bool isDark) {
    return Positioned(
      top: 36, // 72rpx
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 10), // 20rpx 30rpx
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)), // 16rpx
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEFE9E5),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x3D000000) : const Color(0x0F000000), // .24 / .06
              offset: const Offset(0, 4), // 8rpx
              blurRadius: 10, // 20rpx
            ),
          ],
        ),
        child: Wrap(
          spacing: 8, // gap 16rpx
          runSpacing: 8,
          children: _filterOptions.map((opt) {
            final active = _currentFilter == opt.$1;
            return GestureDetector(
              onTap: () => _selectFilter(opt.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 8rpx 20rpx
                decoration: BoxDecoration(
                  color: active
                      ? (isDark ? AppColors.darkSurface : Colors.transparent)
                      : (isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5)),
                  borderRadius: BorderRadius.circular(10), // 20rpx
                ),
                child: Text(
                  opt.$2,
                  style: AppTextStyles.cn(
                    12, // 24rpx
                    height: 1.4,
                    color: active
                        ? (isDark ? const Color(0xFFE05665) : const Color(0xFFF2A93F))
                        : (isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666)),
                    weight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// .rank-row：排名 + 名称/代码 + 涨跌幅
  Widget _buildRankRow(_FundItem item, bool isDark) {
    final rateColor = item.trend == 'down' ? const Color(0xFF00ADA0) : const Color(0xFFFF5D5E);
    return GestureDetector(
      onTap: () => _handleJump(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 9), // 20rpx 30rpx 18rpx
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4EFEC),
              width: 0.5,
            ),
          ),
        ),
        child: Row(children: [
          SizedBox(
            width: 29, // 58rpx
            child: Text(
              item.rank.toString().padLeft(2, '0'), // formatRank
              style: AppTextStyles.num(14, color: _rankColor(item.rank, isDark), weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8), // column-gap 16rpx
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                item.name,
                style: AppTextStyles.cn(14,
                    color: isDark ? AppColors.darkText : const Color(0xFF333333), height: 1.3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3), // gap 6rpx
              Text(
                item.code,
                style: AppTextStyles.num(12,
                    color: isDark ? const Color(0xFFA7ADB8) : const Color(0xFF808080), height: 1.2),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90, // 180rpx
            child: Center(
              child: Text(item.rate, style: AppTextStyles.num(15, color: rateColor, height: 1.1)),
            ),
          ),
        ]),
      ),
    );
  }

  /// rankColorClass：top1 #ef9d11 / top2 #8f8f94 / top3 #d48b58 / 默认 #21203f(暗 #D7DAE0)
  Color _rankColor(int rank, bool isDark) {
    switch (rank) {
      case 1:
        return const Color(0xFFEF9D11);
      case 2:
        return const Color(0xFF8F8F94);
      case 3:
        return const Color(0xFFD48B58);
      default:
        return isDark ? AppColors.darkText : const Color(0xFF21203F);
    }
  }

  double? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// JS falsy 语义（null / '' 视为空时间）
  bool _isEmptyTime(dynamic v) => v == null || (v is String && v.isEmpty);

  String _firstStr(Map m, List<String> keys, String fallback) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return fallback;
  }
}

class _FundItem {
  final int rank;
  final String name, code, symbolId, rate, trend;
  const _FundItem({
    required this.rank,
    required this.name,
    required this.code,
    required this.symbolId,
    required this.rate,
    required this.trend,
  });
}

class _BoardSection {
  final dynamic updateTime;
  final List<dynamic> items;
  const _BoardSection(this.updateTime, this.items);
}

class _ParsedBoard {
  dynamic updateTime;
  final Map<String, List<dynamic>> rawLists = {};
  void put(String key, dynamic item) => rawLists.putIfAbsent(key, () => []).add(item);
}
