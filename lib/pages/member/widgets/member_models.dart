/// 会员页时间线数据模型 — 对应 uni-app pages/member/index.vue 中
/// normalizeTimelineItem / normalizeFlowItem / normalizeRankItems 的输出。
library;

/// 流入流出人数（type == flow_data）
class VipFlowData {
  final String inflowText;
  final String outflowText;
  final double risePercent;
  final double fallPercent;

  const VipFlowData({
    required this.inflowText,
    required this.outflowText,
    required this.risePercent,
    required this.fallPercent,
  });
}

/// 关注度飙升榜行（type == attention_rise_rank）
class VipRankRow {
  final String rankText; // '01'
  final String name;
  final String code;
  final String rateText; // '48.23%'

  const VipRankRow({
    required this.rankText,
    required this.name,
    required this.code,
    required this.rateText,
  });
}

/// 时间线条目。
/// type: morning_report / closing_report / flow_data / attention_rise_rank
class VipTimelineItem {
  final String type;
  final String id;
  final String title;
  final String desc;
  final String timeText; // 'HH:mm'
  final String dateText; // 'MM月DD日'
  final VipFlowData? flow;
  final List<VipRankRow> rankItems;

  const VipTimelineItem({
    required this.type,
    required this.id,
    required this.title,
    required this.desc,
    required this.timeText,
    required this.dateText,
    this.flow,
    this.rankItems = const [],
  });
}

/// 按日期分组的时间线
class VipTimelineGroup {
  final String dateText; // 'MM月DD日 星期X'
  final List<VipTimelineItem> items;

  const VipTimelineGroup({required this.dateText, required this.items});
}
