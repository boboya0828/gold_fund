import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 早/晚报列表条目 — 对齐 morningnews.vue / closingnews.vue formatReportItem 输出
class MemberReportItem {
  final String id;
  final String title; // 【M月D日】 周X早报/尾盘
  final String summary;
  final String timeText; // HH:mm
  final String cover;

  const MemberReportItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.timeText,
    required this.cover,
  });
}

/// 分页响应 — 对齐 uni-app unwrapApiData/unwrapList/unwrapTotal
class MemberReportPageData {
  final List<dynamic> rows;
  final int? total;

  const MemberReportPageData(this.rows, this.total);

  factory MemberReportPageData.fromBody(dynamic body) {
    // unwrapApiData: res?.data ?? res ?? {}
    dynamic data = body;
    if (data is Map && data['data'] != null) data = data['data'];

    // unwrapList
    List<dynamic> rows = const [];
    if (data is List) {
      rows = data;
    } else if (data is Map) {
      final inner = data['data'];
      rows = _firstList([
        data['items'],
        data['records'],
        data['list'],
        data['rows'],
        inner is Map ? inner['items'] : null,
        inner is Map ? inner['records'] : null,
        inner is Map ? inner['list'] : null,
        inner is Map ? inner['rows'] : null,
      ]);
    }

    // unwrapTotal: pageData = data?.data ?? data
    final pageData = (data is Map && data['data'] is Map) ? data['data'] : data;
    int? total;
    if (pageData is Map) {
      for (final key in const ['total', 'totalCount', 'count']) {
        final v = pageData[key];
        final n = v is num ? v : num.tryParse('${v ?? ''}');
        if (n != null) {
          total = n.toInt();
          break;
        }
      }
    }
    return MemberReportPageData(rows, total);
  }

  static List<dynamic> _firstList(List<dynamic> values) {
    for (final v in values) {
      if (v is List) return v;
    }
    return const [];
  }
}

/// 早/晚报分页列表 — 1:1 复刻 morningnews.vue / closingnews.vue 的
/// 列表结构、分页加载（pageNum/pageSize=20）、空/加载态与上拉加载更多。
///
/// 页面差异（标题规则、摘要文案、空态文案、接口）通过参数注入。
class MemberReportListView extends StatefulWidget {
  /// 拉取一页数据（pageNum 从 1 开始，pageSize 固定 20）
  final Future<MemberReportPageData> Function(int pageNum, int pageSize)
      fetchPage;

  /// formatDateTitle 的 reportName：早报页按 item.type 取 早报/报告；尾盘页固定 尾盘
  final String Function(String? itemType) reportNameFor;

  /// formatReportItem 的固定摘要文案
  final String summaryText;

  /// 空列表文案（暂无早报 / 暂无尾盘）
  final String emptyText;

  /// 加载失败 toast 文案
  final String errorText;

  /// 点击条目（对齐 openReport；id 为空时由调用方提示"暂无详情"）
  final ValueChanged<MemberReportItem> onOpen;

  final bool isDark;

  const MemberReportListView({
    super.key,
    required this.fetchPage,
    required this.reportNameFor,
    required this.summaryText,
    required this.emptyText,
    required this.errorText,
    required this.onOpen,
    required this.isDark,
  });

  @override
  State<MemberReportListView> createState() => _MemberReportListViewState();
}

class _MemberReportListViewState extends State<MemberReportListView> {
  static const int _pageSize = 20;

  int _pageIndex = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  List<MemberReportItem> _items = const [];

  @override
  void initState() {
    super.initState();
    // uni-app onLoad: loadReports(true)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReports(true));
  }

  /// loadReports(reset)：loading/loadingMore 互斥；reset 时清空并回到第 1 页
  Future<void> _loadReports(bool reset) async {
    if (_loading || _loadingMore) return;
    if (reset) {
      _pageIndex = 1;
      _hasMore = true;
      _items = const [];
      _loading = true;
    } else {
      if (!_hasMore) return;
      _loadingMore = true;
    }
    if (mounted) setState(() {});
    try {
      final res = await widget.fetchPage(_pageIndex, _pageSize);
      final next = <MemberReportItem>[
        for (var i = 0; i < res.rows.length; i++)
          _formatReportItem(res.rows[i], i),
      ];
      if (!mounted) return;
      setState(() {
        _items = reset ? next : [..._items, ...next];
        final total = res.total;
        _hasMore =
            total != null ? _items.length < total : res.rows.length >= _pageSize;
        if (_hasMore) _pageIndex += 1;
      });
    } catch (_) {
      // uni-app: console.error + uni.showToast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.errorText)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  /// scroll-view @scrolltolower → loadMore
  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 40) {
      _loadReports(false);
    }
    return false;
  }

  /// formatReportItem：publishTime 取 item.time；id 取 id/reportId/morningReportId/closingReportId
  MemberReportItem _formatReportItem(dynamic raw, int index) {
    final item =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final publishTime = item['time'];
    final reportId = _pickText([
      item['id'],
      item['reportId'],
      item['morningReportId'],
      item['closingReportId'],
    ]);
    return MemberReportItem(
      id: reportId,
      title: _formatDateTitle(publishTime, widget.reportNameFor(
          item['type']?.toString())),
      summary: widget.summaryText,
      timeText: _formatTimeOnly(publishTime),
      cover: _pickText(
          [item['coverImage'], item['image'], item['thumbnail'], item['banner']]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted =
        widget.isDark ? const Color(0xFFA7ADB8) : const Color(0xFF7D7D85);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView(
        // .page-content: padding-top 20rpx
        padding: const EdgeInsets.only(top: 10),
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        children: [
          if (_loading && _items.isEmpty)
            _stateBox('加载中...', muted)
          else if (_items.isEmpty)
            _stateBox(widget.emptyText, muted)
          else ...[
            for (var i = 0; i < _items.length; i++) _buildCard(_items[i], i),
            // .load-more-text
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 15), // 8rpx 0 30rpx
              child: Center(
                child: Text(
                  _hasMore
                      ? (_loadingMore ? '加载中...' : '上拉加载更多')
                      : '没有更多了',
                  style: AppTextStyles.cn(12, color: muted), // 24rpx
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// .state-box
  Widget _stateBox(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60), // 120rpx
      child: Center(child: Text(text, style: AppTextStyles.cn(12, color: color))),
    );
  }

  /// .newList（index==0 时 .newList--featured 渐变）
  Widget _buildCard(MemberReportItem item, int index) {
    final isDark = widget.isDark;
    final featured = index == 0;
    final textColor =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFF333333);
    final muted =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFF7D7D85);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onOpen(item),
      child: Container(
        height: 99, // 198rpx
        margin: const EdgeInsets.only(bottom: 10), // 20rpx
        padding: const EdgeInsets.symmetric(horizontal: 15), // 30rpx
        decoration: BoxDecoration(
          color: featured ? null : (isDark ? AppColors.darkSurface : Colors.white),
          gradient: featured
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? const [Color(0xFF292420), Color(0xFF202125)]
                      : const [Color(0xFFFFF6F1), Color(0xFFFFFFFF)],
                )
              : null,
          borderRadius: BorderRadius.circular(10), // 20rpx
        ),
        child: Row(children: [
          // .newList-l
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // .newList-head（gap 16rpx）
                Row(children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: AppTextStyles.cn(15, // 30rpx
                          weight: FontWeight.w700,
                          height: 1.2,
                          color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8), // gap 16rpx
                  // .newList-time numFamily（margin-right 26rpx 由卡片右区承担一半，按源码 26rpx）
                  Padding(
                    padding: const EdgeInsets.only(right: 13), // 26rpx
                    child: Text(
                      item.timeText,
                      style: AppTextStyles.num(15, color: muted), // 30rpx
                    ),
                  ),
                ]),
                // .newList-line
                Container(
                  height: 0.5, // 1rpx
                  margin: const EdgeInsets.only(top: 12), // 24rpx
                  color: isDark
                      ? const Color(0xFF2B2D33)
                      : const Color(0xFFEDEDED),
                ),
                // .newList-desc
                Padding(
                  padding: const EdgeInsets.only(top: 14), // 28rpx
                  child: Text(
                    item.summary,
                    style: AppTextStyles.cn(13, // 26rpx
                        height: 1.4,
                        color: isDark
                            ? const Color(0xFFA7ADB8)
                            : const Color(0xFF666666)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // .newList-r：前进箭头居中靠右 + 封面/dayico 绝对定位右上
          SizedBox(
            width: 40, // 80rpx
            height: double.infinity,
            child: Stack(children: [
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right, // uni-icons type="forward" size 22
                  size: 22,
                  color: isDark
                      ? const Color(0xFFA7ADB8)
                      : const Color(0xFF7B7C81), // mutedIconColor
                ),
              ),
              if (item.cover.isNotEmpty || featured)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _buildCover(item, featured),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  /// .newList-r image（36rpx×40rpx）：网络封面 aspectFill；无封面且首条用 dayico 占位
  Widget _buildCover(MemberReportItem item, bool featured) {
    if (item.cover.isNotEmpty) {
      return Image.network(
        item.cover,
        width: 18,
        height: 20,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => featured
            ? _dayico()
            : const SizedBox(width: 18, height: 20),
      );
    }
    return _dayico();
  }

  /// /static/image/img/dayico.png
  Widget _dayico() {
    return Image.asset(
      'assets/images/img/dayico.png',
      width: 18,
      height: 20,
      errorBuilder: (_, _, _) => const SizedBox(width: 18, height: 20),
    );
  }

  // ===================== 格式化工具（逐项对齐 uni-app helpers） =====================

  static String _pickText(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceAll('/', '-'));
  }

  /// formatDateTitle：【M月D日】 周X早报/尾盘；无日期回退 VIP早报/VIP尾盘
  static String _formatDateTitle(dynamic value, String reportName) {
    final date = _parseDate(value);
    if (date == null) return 'VIP$reportName';
    const weeks = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return '【${date.month}月${date.day}日】 ${weeks[date.weekday % 7]}$reportName';
  }

  /// formatTimeOnly：提取 HH:mm
  static String _formatTimeOnly(dynamic value) {
    final raw = _pickText([value]);
    final match = RegExp(r'(?:T|\s)(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) return '';
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
  }
}
