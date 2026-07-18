import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/z_paging_refresh.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/member_models.dart';
import 'widgets/member_timeline.dart';
import 'widgets/member_vip_header.dart';

/// 会员页面 - 1:1 复刻 uni-app pages/member/index.vue (zdj-v1)
///
/// 数据：GET /asset/api/Vip/home（uni-app getVipHome），
/// 归一化逻辑逐项对齐 index.vue 的 computed（displayGroups 等）。
class MemberPage extends ConsumerStatefulWidget {
  const MemberPage({super.key});
  @override
  ConsumerState<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends ConsumerState<MemberPage> {
  final ApiClient _api = ApiClient();

  String _avatar = '';
  String _nickname = '未登录';
  bool _vipHomeLoaded = false;
  List<VipTimelineGroup> _groups = const [];

  @override
  void initState() {
    super.initState();
    // 对齐 uni-app onLoad/onReady：读取本地用户信息 + 触发 z-paging reload
    _loadUser();
    _loadVipHome();
  }

  // ===================== 用户信息（对齐 loadUserInfo/normalizeUserInfo） =====================

  void _loadUser() {
    SharedPreferences.getInstance().then((p) {
      final raw = p.getString('userInfo');
      if (raw == null || raw.isEmpty || !raw.startsWith('{')) {
        if (mounted) {
          setState(() {
            _nickname = '未登录';
            _avatar = '';
          });
        }
        return;
      }
      try {
        final data = Map<String, dynamic>.from(
            const JsonDecoder().convert(raw) as Map);
        // normalizeUserInfo: avatarUrl || avatar；nickname || userName || username
        final avatar =
            _pickText([data['avatarUrl'], data['avatar']]);
        final nickname = _pickText(
            [data['nickname'], data['userName'], data['username']]);
        if (mounted) {
          setState(() {
            _avatar = avatar;
            _nickname = nickname.isEmpty ? '未登录' : nickname;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _nickname = '未登录');
      }
    });
  }

  // ===================== VIP 首页数据（对齐 loadVipHome/displayGroups） =====================

  Future<void> _loadVipHome() async {
    try {
      final res = await _api.get(ApiEndpoints.vipHome);
      // unwrapApiData: res?.data ?? res ?? {}
      final body = res.data;
      dynamic data = body;
      if (body is Map && body['data'] != null) data = body['data'];
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      if (mounted) {
        setState(() {
          _groups = _buildDisplayGroups(map);
          _vipHomeLoaded = true;
        });
      }
    } catch (_) {
      // uni-app: console.error + showToast('获取VIP数据失败')，数据置空
      if (mounted) {
        setState(() {
          _groups = const [];
          _vipHomeLoaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取VIP数据失败')),
        );
      }
    }
  }

  /// displayGroups：优先 groups/groupList/data.groups，否则 items/records/list
  /// 合成单分组；空 items 的分组被过滤。
  List<VipTimelineGroup> _buildDisplayGroups(Map<String, dynamic> home) {
    final groupsRaw = _pickFirstArray([
      home['groups'],
      home['groupList'],
      home['data'] is Map ? (home['data'] as Map)['groups'] : null,
    ]);

    if (groupsRaw.isNotEmpty) {
      final out = <VipTimelineGroup>[];
      for (var gi = 0; gi < groupsRaw.length; gi++) {
        final g = groupsRaw[gi] is Map
            ? Map<String, dynamic>.from(groupsRaw[gi] as Map)
            : <String, dynamic>{};
        final itemsRaw =
            _pickFirstArray([g['items'], g['list'], g['records']]);
        final items = <VipTimelineItem>[
          for (var ii = 0; ii < itemsRaw.length; ii++)
            _normalizeTimelineItem(itemsRaw[ii],
                groupDate: g['date'], index: ii),
        ];
        if (items.isEmpty) continue;
        // formatChineseDate(group.date || items[0]?.time)
        final firstTime = itemsRaw.isNotEmpty && itemsRaw[0] is Map
            ? (itemsRaw[0] as Map)['time']
            : null;
        out.add(VipTimelineGroup(
          dateText: _formatChineseDate(g['date'] ?? firstTime),
          items: items,
        ));
      }
      return out;
    }

    final directRaw =
        _pickFirstArray([home['items'], home['records'], home['list']]);
    final items = <VipTimelineItem>[
      for (var i = 0; i < directRaw.length; i++)
        _normalizeTimelineItem(directRaw[i], index: i),
    ];
    if (items.isEmpty) return const [];
    // formatChineseDate(fallbackItems[0]?.time || fallbackItems[0]?.groupDate)
    final firstRaw = directRaw.first is Map
        ? Map<String, dynamic>.from(directRaw.first as Map)
        : <String, dynamic>{};
    return [
      VipTimelineGroup(
        dateText:
            _formatChineseDate(firstRaw['time'] ?? firstRaw['groupDate']),
        items: items,
      ),
    ];
  }

  /// normalizeTimelineItem + getReportTitle + getReportDesc
  VipTimelineItem _normalizeTimelineItem(dynamic raw,
      {dynamic groupDate, required int index}) {
    final item = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final type = (item['type'] ?? '').toString();
    final gDate = _pickText([groupDate, item['groupDate']]);

    // getReportTitle
    final String title;
    if (type == 'attention_rise_rank') {
      title = _pickText([item['title']], fallback: '今日关注度飙升');
    } else {
      const fallbackMap = {
        'morning_report': 'VIP早报',
        'closing_report': '指数集体翻红，哪些是机会？',
      };
      title = _pickText(
          [item['title'], item['name'], item['typeName'], fallbackMap[type]],
          fallback: '--');
    }

    // getReportDesc
    final String desc;
    if (type == 'morning_report') {
      desc = _pickText(
          [item['summary'], item['desc'], item['description']],
          fallback: '点击查看VIP早报吧～');
    } else if (type == 'closing_report') {
      desc = _pickText(
          [item['summary'], item['desc'], item['description']],
          fallback: '赶紧点击查看尾盘参考吧～');
    } else {
      desc = _pickText([item['summary'], item['desc'], item['description']]);
    }

    final timeText = _formatTimeOnly(_firstNonNull(
        [item['time'], item['publishTime'], item['createdTime'], item['updateTime']]));
    final dateText = _formatMonthDay(_firstNonNull([
      item['time'],
      gDate.isEmpty ? null : gDate,
      item['recordDate'],
      item['publishTime'],
      item['createdTime'],
      item['updateTime'],
    ]));

    return VipTimelineItem(
      type: type,
      id: _pickText([item['id']]),
      title: title,
      desc: desc,
      timeText: timeText,
      dateText: dateText,
      flow: _normalizeFlowItem(item),
      rankItems: _normalizeRankItems(_unwrapList(item)),
    );
  }

  /// normalizeFlowItem：inflow/outflow ?? 链 + 百分比 clamp(4, 96)，无数据 50/50
  VipFlowData _normalizeFlowItem(Map<String, dynamic> item) {
    final inflow = _toNumber(item['inflowCount'] ??
        item['inCount'] ??
        item['inflowPeople'] ??
        item['inflowUsers'] ??
        item['inflow']);
    final outflow = _toNumber(item['outflowCount'] ??
        item['outCount'] ??
        item['outflowPeople'] ??
        item['outflowUsers'] ??
        item['outflow']);
    final total = inflow + outflow;
    final risePercent =
        total > 0 ? (inflow / total * 100).clamp(4.0, 96.0) : 50.0;
    return VipFlowData(
      inflowText: inflow.round().toString(),
      outflowText: outflow.round().toString(),
      risePercent: risePercent,
      fallPercent: 100 - risePercent,
    );
  }

  /// normalizeRankItems：slice(0, 3)
  List<VipRankRow> _normalizeRankItems(List<dynamic> raw) {
    final out = <VipRankRow>[];
    for (var i = 0; i < raw.length && i < 3; i++) {
      final item = raw[i] is Map
          ? Map<String, dynamic>.from(raw[i] as Map)
          : <String, dynamic>{};
      final rateText = _pickText(
          [item['riseText'], item['rateText'], item['valueText']]);
      out.add(VipRankRow(
        rankText: _pickText([item['rankNo'], item['rank']], fallback: '${i + 1}')
            .padLeft(2, '0'),
        name: _pickText(
            [item['shortName'], item['symbolName'], item['name'], item['fundName'], item['title']],
            fallback: '--'),
        code: _pickText(
            [item['symbolCode'], item['code'], item['displayCode'], item['fundCode'], item['symbol']],
            fallback: '--'),
        rateText: rateText.isNotEmpty
            ? rateText
            : '${_toNumber(item['riseRate'] ?? item['riseRatio'] ?? item['changeRate'] ?? item['changeRatio'] ?? item['attentionRiseRate'] ?? item['rate'] ?? item['percent'] ?? item['value'] ?? 0).toStringAsFixed(2)}%',
      ));
    }
    return out;
  }

  /// unwrapList：在对象内寻找第一个数组字段
  List<dynamic> _unwrapList(dynamic value) {
    if (value is List) return value;
    if (value is! Map) return const [];
    final data = value['data'];
    return _pickFirstArray([
      value['items'],
      value['records'],
      value['list'],
      value['rows'],
      value['ranks'],
      value['details'],
      value['rankItems'],
      value['recentItems'],
      data is Map ? data['items'] : null,
      data is Map ? data['records'] : null,
      data is Map ? data['list'] : null,
      data is Map ? data['ranks'] : null,
      data is Map ? data['details'] : null,
    ]);
  }

  // ===================== 跳转（对齐 hendleNavto/openHomeItem） =====================

  void _openHomeItem(VipTimelineItem item) {
    switch (item.type) {
      case 'morning_report':
        // uni-app: ./details?type=morning&id=
        context.push(item.id.isNotEmpty
            ? '/member/details?type=morning&id=${Uri.encodeComponent(item.id)}'
            : '/member/morning-news');
        break;
      case 'closing_report':
        // uni-app: ./details?type=closing&id=
        context.push(item.id.isNotEmpty
            ? '/member/details?type=closing&id=${Uri.encodeComponent(item.id)}'
            : '/member/closing-news');
        break;
      case 'attention_rise_rank':
        context.push(item.id.isNotEmpty
            ? '/member/rising-chart?id=${Uri.encodeComponent(item.id)}'
            : '/member/rising-chart');
        break;
      case 'flow_data':
        context.push('/member/contrast');
        break;
    }
  }

  // ===================== 格式化工具（逐项对齐 uni-app helpers） =====================

  /// pickFirstText：第一个非空字符串
  static String _pickText(List<dynamic> values, {String fallback = ''}) {
    for (final v in values) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  static dynamic _firstNonNull(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      if (v is String && v.trim().isEmpty) continue;
      return v;
    }
    return null;
  }

  static List<dynamic> _pickFirstArray(List<dynamic> values) {
    for (final v in values) {
      if (v is List) return v;
    }
    return const [];
  }

  static double _toNumber(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceAll('/', '-'));
  }

  /// formatChineseDate: 'MM月DD日 星期X'，解析失败回退当天
  static String _formatChineseDate(dynamic value) {
    final date = _parseDate(value) ?? DateTime.now();
    const weeks = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m月$d日 ${weeks[date.weekday % 7]}';
  }

  /// formatMonthDay: 'MM月DD日'，解析失败返回 ''
  static String _formatMonthDay(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '';
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m月$d日';
  }

  /// formatTimeOnly: 从 'T'/空格后的 HH:mm 提取，fallback '14:40'
  static String _formatTimeOnly(dynamic value) {
    final raw = _pickText([value]);
    final match = RegExp(r'(?:T|\s)(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) return '14:40';
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
  }

  // ===================== Build =====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // .bg: #F1F1F3 / .theme-dark #111315
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF1F1F3);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          // .title 固定头部（z-paging :fixed="false"，不随滚动）：
          // height 44 + 状态栏（SafeArea 承担），32rpx→16
          Container(
            height: 44,
            color: bg,
            alignment: Alignment.center,
            child: Text('VIP专区',
                style: AppTextStyles.cn(16,
                    weight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkText
                        : const Color(0xFF333333))),
          ),
          Expanded(
            child: ZPagingRefresh(
              isDark: isDark,
              // handleMemberPagingQuery → loadVipHome；onShow 行为由刷新兜底
              onRefresh: () async {
                _loadUser();
                await _loadVipHome();
              },
              child: Column(children: [
                MemberVipHeader(
                  avatar: _avatar,
                  nickname: _nickname,
                  isDark: isDark,
                  onMorningNews: () => context.push('/member/morning-news'),
                  onContrast: () => context.push('/member/contrast'),
                  onRisingChart: () => context.push('/member/rising-chart'),
                  // uni-app ./closingnews
                  onClosingNews: () => context.push('/member/closing-news'),
                ),
                MemberTimeline(
                  isDark: isDark,
                  loaded: _vipHomeLoaded,
                  groups: _groups,
                  onItemTap: _openHomeItem,
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
