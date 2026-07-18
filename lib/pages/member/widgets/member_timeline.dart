import 'package:flutter/material.dart';

import '../../../theme/text_styles.dart';
import 'member_models.dart';

/// 会员页时间线 — 1:1 复刻 uni-app pages/member/index.vue 的 `.massag` 区域。
///
/// 结构：日期分组（.massag-group） → 时间点（.massag-time） → 三种卡片
///   - .massag-card--simple  早/晚报（整卡可点）
///   - .massag-card--flow    今日流入流出人数（整卡可点）
///   - .massag-card--list    关注度飙升榜（头部可点）
/// 数据加载完成且无内容时显示 .empty-state。
class MemberTimeline extends StatelessWidget {
  final bool isDark;

  /// uni-app vipHomeLoaded：接口请求结束（无论成败）后才显示空态
  final bool loaded;
  final List<VipTimelineGroup> groups;

  /// 卡片点击回调，路由跳转由页面层决定（对齐 uni-app openHomeItem）
  final void Function(VipTimelineItem item) onItemTap;

  const MemberTimeline({
    super.key,
    required this.isDark,
    required this.loaded,
    required this.groups,
    required this.onItemTap,
  });

  // ===== 主题色（对齐 uni-app style 块，含 .theme-dark 覆盖） =====
  static const _cardBgLight = Color(0xFFFFFFFF);
  static const _cardBgDark = Color(0xFF1A1B1F);
  static const _textLight = Color(0xFF333333);
  static const _textDark = Color(0xFFD7DAE0);
  static const _dividerLight = Color(0xFFEFEFEF);
  static const _dividerDark = Color(0xFF24252A);
  static const _mutedLight = Color(0xFF999999); // .massag-card__date
  static const _mutedDark = Color(0xFF8F96A3);
  static const _chevronLight = Color(0xFF7B7C81); // mutedIconColor 默认值
  static const _chevronDark = Color(0xFFA7ADB8);
  static const _subLight = Color(0xFF666666); // rank code/change
  static const _subDark = Color(0xFFA7ADB8);

  Color get _cardBg => isDark ? _cardBgDark : _cardBgLight;
  Color get _text => isDark ? _textDark : _textLight;
  Color get _divider => isDark ? _dividerDark : _dividerLight;
  Color get _muted => isDark ? _mutedDark : _mutedLight;
  Color get _chevron => isDark ? _chevronDark : _chevronLight;
  Color get _sub => isDark ? _subDark : _subLight;

  @override
  Widget build(BuildContext context) {
    // .massag: margin -74rpx 已由头部 Stack 高度吸收；padding-top 6rpx→3，
    // 左右 margin 32rpx→16，padding-bottom 24rpx→12
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 12),
      child: groups.isEmpty
          ? (loaded ? _emptyState() : const SizedBox.shrink())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var gi = 0; gi < groups.length; gi++) ..._buildGroup(gi),
              ],
            ),
    );
  }

  List<Widget> _buildGroup(int groupIndex) {
    final group = groups[groupIndex];
    return [
      // .massag-date: margin-top 100rpx→50；后续分组 28rpx→14；32rpx→16 w600
      SizedBox(height: groupIndex == 0 ? 50 : 14),
      Text(group.dateText,
          style: AppTextStyles.cn(16,
              color: _text, weight: FontWeight.w600, height: 1)),
      for (var ii = 0; ii < group.items.length; ii++) ..._buildItem(group.items[ii], ii),
    ];
  }

  List<Widget> _buildItem(VipTimelineItem item, int itemIndex) {
    return [
      // .massag-time: margin-top 18rpx→9；--spaced 36rpx→18
      SizedBox(height: itemIndex == 0 ? 9 : 18),
      Row(children: [
        // .massag-time__dot: 10rpx→5 圆点 #cab279
        Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
                color: Color(0xFFCAB279), shape: BoxShape.circle)),
        const SizedBox(width: 5), // margin-left 10rpx
        Text(item.timeText,
            style: AppTextStyles.cn(15,
                color: const Color(0xFFBCA778), height: 1)),
      ]),
      // .massag-card margin-top 26rpx→13；--simple 14rpx→7
      SizedBox(height: (item.type == 'morning_report' || item.type == 'closing_report') ? 7 : 13),
      _buildCard(item),
    ];
  }

  Widget _buildCard(VipTimelineItem item) {
    switch (item.type) {
      case 'morning_report':
      case 'closing_report':
        return _simpleCard(item);
      case 'flow_data':
        return _flowCard(item);
      case 'attention_rise_rank':
        return _rankCard(item);
      default:
        // 未知类型按 simple 卡片渲染（uni-app 同样会落入 v-if 之外不渲染，
        // 这里保守处理为 simple，保证标题/描述可见）
        return _simpleCard(item);
    }
  }

  // ===== .massag-card--simple =====
  // padding 26rpx 24rpx，padding-top 28rpx→14，padding-bottom 24rpx→12
  Widget _simpleCard(VipTimelineItem item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemTap(item),
      child: Container(
        decoration: BoxDecoration(
            color: _cardBg, borderRadius: BorderRadius.circular(6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
            // .massag-card__head min-height 48rpx→24
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(item.title,
                        style: AppTextStyles.cn(15,
                            color: _text,
                            weight: FontWeight.w600,
                            height: 1.35)),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: _chevron),
                ],
              ),
            ),
          ),
          // .massag-card__line: margin 18rpx -24rpx 0，1rpx 高
          Container(
              height: 0.5,
              margin: const EdgeInsets.only(top: 9),
              color: _divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
            child: Text(item.desc,
                style: AppTextStyles.cn(14, color: _text, height: 1.4)),
          ),
        ]),
      ),
    );
  }

  // ===== .massag-card--flow =====
  // height 218rpx→109；padding 26/24rpx，padding-bottom 22rpx→11
  Widget _flowCard(VipTimelineItem item) {
    final flow = item.flow;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemTap(item),
      child: Container(
        height: 109,
        padding: const EdgeInsets.fromLTRB(12, 13, 12, 11),
        decoration: BoxDecoration(
            color: _cardBg, borderRadius: BorderRadius.circular(6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // .massag-card__title--strong: 30rpx→15 w600，行内附日期
          Row(children: [
            Text('今日流入流出人数',
                style: AppTextStyles.cn(15,
                    color: _text, weight: FontWeight.w600, height: 1.2)),
            const SizedBox(width: 7), // .massag-card__date margin-left 14rpx
            Text(item.dateText,
                style: AppTextStyles.cn(12, color: _muted, height: 1)),
          ]),
          const SizedBox(height: 22.5), // .massag-flow margin-top 45rpx
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text('流入人数',
                    style: AppTextStyles.cn(14, color: _text, height: 1)),
                const SizedBox(width: 5), // value margin-left 10rpx
                Text(flow?.inflowText ?? '0',
                    style: AppTextStyles.cn(15,
                        color: const Color(0xFFEF7283),
                        weight: FontWeight.w500,
                        height: 1)),
              ]),
              Row(children: [
                Text(flow?.outflowText ?? '0',
                    style: AppTextStyles.cn(15,
                        color: const Color(0xFF1AB8AD),
                        weight: FontWeight.w500,
                        height: 1)),
                const SizedBox(width: 5), // label--right margin-left 10rpx
                Text('流出人数',
                    style: AppTextStyles.cn(14, color: _text, height: 1)),
              ]),
            ],
          ),
          const SizedBox(height: 11), // .massag-progress margin-top 22rpx
          _flowProgress(flow?.risePercent ?? 50),
        ]),
      ),
    );
  }

  // .massag-progress: 22rpx→11 高，圆角 999，红/绿渐变 + 6rpx→3 斜边
  Widget _flowProgress(double risePercent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 11,
        child: LayoutBuilder(builder: (context, c) {
          final total = c.maxWidth;
          var riseW = total * risePercent / 100;
          // rise 段 margin-right 2rpx→1，fall 段 margin-left 1
          riseW = riseW.clamp(0.0, total - 2 > 0 ? total - 2 : 0.0);
          final fallW = total - riseW - 2;
          return Row(children: [
            SizedBox(
              width: riseW,
              child: ClipPath(
                clipper: _SlantClipper(slant: 3, trailing: true),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFEC7E8D), Color(0xFFEA6D80)]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            if (fallW > 0)
              SizedBox(
                width: fallW,
                child: ClipPath(
                  clipper: _SlantClipper(slant: 3, trailing: false),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF1CC1AE), Color(0xFF97DDD6)]),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ),
    );
  }

  // ===== .massag-card--list =====
  // min-height 264rpx→132；padding-top/bottom 0
  Widget _rankCard(VipTimelineItem item) {
    final rows = item.rankItems;
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      decoration: BoxDecoration(
          color: _cardBg, borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        // 头部：height 86rpx→43，padding 0 24rpx→12，margin 0 -24rpx，底部分割线
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onItemTap(item),
          child: Container(
            height: 43,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(width: 0.5, color: _divider))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Text(item.title,
                      style: AppTextStyles.cn(15,
                          color: _text,
                          weight: FontWeight.w600,
                          height: 1.2)),
                  const SizedBox(width: 7),
                  Text(item.dateText,
                      style: AppTextStyles.cn(12, color: _muted, height: 1)),
                ]),
                Icon(Icons.chevron_right, size: 16, color: _chevron),
              ],
            ),
          ),
        ),
        // .massag-rank-row: grid 46rpx/1fr/108rpx/136rpx，gap 10rpx→5，
        // height 88rpx→44，padding 0 2rpx→1，最后一行无下边框
        for (var i = 0; i < rows.length; i++)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? Border(
                        bottom: BorderSide(width: 0.5, color: _divider))
                    : null),
            child: Row(children: [
              SizedBox(
                  width: 23,
                  child: Text(rows[i].rankText,
                      style: AppTextStyles.num(15.5,
                          color: const Color(0xFFF0A33C), height: 1))),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(rows[i].name,
                      style: AppTextStyles.cn(14.5, color: _text, height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 5),
              SizedBox(
                  width: 54,
                  child: Text(rows[i].code,
                      style: AppTextStyles.num(14, color: _sub, height: 1),
                      textAlign: TextAlign.right)),
              const SizedBox(width: 5),
              SizedBox(
                width: 68,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(rows[i].rateText,
                          style:
                              AppTextStyles.num(14, color: _sub, height: 1)),
                      const SizedBox(width: 3), // arrow margin-left 6rpx
                      Image.asset('assets/images/img/upico.png',
                          width: 8, height: 9, fit: BoxFit.contain),
                    ]),
              ),
            ]),
          ),
      ]),
    );
  }

  // ===== .empty-state =====
  Widget _emptyState() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280), // 560rpx
      margin: const EdgeInsets.only(top: 44), // 88rpx
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 42, // 84rpx
          height: 42,
          decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF24262D)
                  : const Color(0xFFF4F5F8),
              shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(Icons.calendar_today_outlined,
              size: 28,
              color: isDark
                  ? const Color(0xFF666C78)
                  : const Color(0xFFC5C8D3)),
        ),
        const SizedBox(height: 11), // 22rpx
        Text('暂无数据',
            style: AppTextStyles.cn(15,
                color: _text, weight: FontWeight.w600, height: 1)),
      ]),
    );
  }
}

/// 进度条斜边裁剪 — 对齐 uni-app clip-path polygon（6rpx→3 斜边）。
/// trailing=true  斜右侧（红段）：(0,0)(w-3,0)(w,h)(0,h)
/// trailing=false 斜左侧（绿段）：(0,0)(w,0)(w,h)(3,h)
class _SlantClipper extends CustomClipper<Path> {
  final double slant;
  final bool trailing;

  const _SlantClipper({required this.slant, required this.trailing});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (trailing) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width - slant, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(slant, size.height)
        ..close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _SlantClipper old) =>
      old.slant != slant || old.trailing != trailing;
}
