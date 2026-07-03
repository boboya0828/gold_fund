import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 会员页面 - 1:1 复刻 uni-app pages/member/index.vue (来自 wxapp-yjzs)
class MemberPage extends ConsumerStatefulWidget {
  const MemberPage({super.key});
  @override
  ConsumerState<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends ConsumerState<MemberPage> {
  String _avatar = '';
  String _nickname = '未登录';
  String _vipExpiry = '2026-07-15';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    SharedPreferences.getInstance().then((p) {
      final token = p.getString('token');
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _nickname = '未登录');
        return;
      }
      final raw = p.getString('userInfo');
      if (raw != null && raw.isNotEmpty && raw.startsWith('{')) {
        try {
          final userData = Map<String, dynamic>.from(
            const JsonDecoder().convert(raw) as Map);
          if (mounted) setState(() {
            _nickname = (userData['nickname'] ?? userData['nickName'] ?? userData['userName'] ?? userData['username'] ?? 'VIP用户') as String;
            _avatar = (userData['avatarUrl'] ?? userData['avatar'] ?? userData['headimgurl'] ?? '') as String;
          });
        } catch (_) {
          if (mounted) setState(() => _nickname = 'VIP用户');
        }
      } else {
        if (mounted) setState(() => _nickname = 'VIP用户');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF1F1F3);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.upColor,
          onRefresh: () async { _loadUser(); },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            // Fixed title
            Container(
              height: 44,
              color: bg,
              alignment: Alignment.center,
              child: Text('VIP专区', style: AppTextStyles.cn(16, weight: FontWeight.w600, color: isDark ? AppColors.darkText : const Color(0xFF333333))),
            ),
            // ===== User VIP Card + VIP Menu Overlap =====
            // Stack 精确复刻 uni-app 负 margin 叠加: 12+139-65+121-37 = 170
            SizedBox(
              height: 170,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // User card — top:12 matches uni-app margin-top:24rpx
                  Positioned(
                    top: 12, left: 16, right: 16,
                    child: Container(
                      height: 139,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment(-0.7, -1.0), end: Alignment(0.7, 1.0), colors: [Color(0xFFFFF2D6), Color(0xFFFFDED5)]),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      padding: const EdgeInsets.fromLTRB(17, 20, 17, 0),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Avatar
                        Container(width: 50, height: 50, decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: Colors.grey.shade300,
                          image: _avatar.isNotEmpty ? DecorationImage(image: NetworkImage(_avatar), fit: BoxFit.cover) : null,
                        ), child: _avatar.isEmpty ? const Icon(Icons.person, size: 30, color: Colors.white) : null),
                        const SizedBox(width: 12),
                        // Name + VIP badge
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(_nickname, style: AppTextStyles.cn(16, color: const Color(0xFF333333))),
                            const SizedBox(width: 14),
                            _cachedIcon('https://huangjinetf.com/wxapp/image/img/vipico1.png', 14, 12.5),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            Text(_vipExpiry, style: AppTextStyles.cn(13, color: const Color(0xFF717171))),
                            const SizedBox(width: 2),
                            Text('到期', style: AppTextStyles.cn(13, color: const Color(0xFF717171))),
                          ]),
                        ]),
                      ]),
                    ),
                  ),
                  // VIP menu — top:86 = 12+139-65, overlaps user card bottom
                  Positioned(
                    top: 86, left: 0, right: 0,
                    child: Container(
                      height: 121,
                      decoration: BoxDecoration(
                        // 深色模式切换背景图 (对齐 zdj vipMenuBg: vipbg.png / vipbg-b.png)
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(isDark
                              ? 'https://huangjinetf.com/wxapp/image/img/vipbg-b.png'
                              : 'https://huangjinetf.com/wxapp/image/img/vipbg.png'),
                          fit: BoxFit.fill),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _vipMenuItem('https://huangjinetf.com/wxapp/image/img/vipzb.png', 'VIP早报', () => context.push('/member/morning-news')),
                          _vipMenuItem('https://huangjinetf.com/wxapp/image/img/viplc.png', '流入流出', () => context.push('/member/contrast')),
                          _vipMenuItem('https://huangjinetf.com/wxapp/image/img/vipbs.png', '关注度飙升', () => context.push('/member/rising-chart')),
                          _vipMenuItem('https://huangjinetf.com/wxapp/image/img/vipwp.png', '尾盘参考', () {}),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===== Timeline Content =====
            // uni-app: massag padding-top(3px) + massag-date margin-top(50px) = 53px
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 53),
                // Date
                Text('04月20日 星期一', style: AppTextStyles.cn(16, color: isDark ? AppColors.darkText : const Color(0xFF333333), weight: FontWeight.w600)),
                const SizedBox(height: 9),
                // Timeline dot + time
                _timelineDot('14:40', isDark),
                const SizedBox(height: 13),
                // Card 1: Simple
                _simpleCard('指数集体翻红，哪些是机会?', '赶紧点击查看尾盘参考吧～', isDark),
                const SizedBox(height: 18),
                _timelineDot('14:40', isDark),
                const SizedBox(height: 13),
                // Card 2: Inflow/Outflow
                _flowCard(isDark),
                const SizedBox(height: 18),
                _timelineDot('14:40', isDark),
                const SizedBox(height: 13),
                // Card 3: Ranking
                _rankCard(isDark),
              ]),
            ),

            const SizedBox(height: 50), // uni-app: padding-bottom 100rpx
          ]),
        ),
      )),
    );
  }

  /// 缓存的网络图标 — 带透明占位，避免显示破损图标
  Widget _cachedIcon(String url, double w, double h) {
    return CachedNetworkImage(
      imageUrl: url,
      width: w,
      height: h,
      placeholder: (_, _) => SizedBox(width: w, height: h),
      errorWidget: (_, _, _) => SizedBox(width: w, height: h),
    );
  }

  Widget _vipMenuItem(String img, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _cachedIcon(img, 39, 39),
      const SizedBox(height: 4),
      Text(label, style: AppTextStyles.cn(13)),
    ]));

  Widget _timelineDot(String time, bool isDark) => Row(children: [
    Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFcab279), shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(time, style: AppTextStyles.cn(15, color: const Color(0xFFBCA778))),
  ]);

  Widget _simpleCard(String title, String desc, bool isDark) => Container(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
    decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : Colors.white, borderRadius: BorderRadius.circular(6)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => context.push('/member/morning-news'),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(title, style: AppTextStyles.cn(15, color: isDark ? AppColors.darkText : const Color(0xFF333333), weight: FontWeight.w600))),
          Icon(Icons.chevron_right, size: 16, color: isDark ? AppColors.darkText : const Color(0xFF333333)),
        ]),
      ),
      Container(height: 0.5, margin: const EdgeInsets.symmetric(vertical: 9), color: const Color(0xFFefefef)),
      Text(desc, style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF333333))),
    ]));

  Widget _flowCard(bool isDark) => Container(
    height: 109,
    padding: const EdgeInsets.fromLTRB(12, 13, 12, 11),
    decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : Colors.white, borderRadius: BorderRadius.circular(6)),
    child: Column(children: [
      Text('今日流入流出人数', style: AppTextStyles.cn(15, color: isDark ? AppColors.darkText : const Color(0xFF333333), weight: FontWeight.w600)),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Text('流入人数', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF333333))),
          const SizedBox(width: 5),
          Text('49128371', style: AppTextStyles.num(15, color: const Color(0xFFef7283), weight: FontWeight.w500)),
        ]),
        Row(children: [
          Text('49128371', style: AppTextStyles.num(15, color: const Color(0xFF1ab8ad), weight: FontWeight.w500)),
          const SizedBox(width: 5),
          Text('流出人数', style: AppTextStyles.cn(14, color: isDark ? AppColors.darkText : const Color(0xFF333333))),
        ]),
      ]),
      const SizedBox(height: 11),
      ClipRRect(borderRadius: BorderRadius.circular(999), child: SizedBox(height: 11, child: Row(children: [
        Flexible(flex: 675, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFec7e8d), Color(0xFFea6d80)])))),
        Flexible(flex: 325, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1cc1ae), Color(0xFF97ddd6)])))),
      ]))),
    ]));

  Widget _rankCard(bool isDark) => Container(
    padding: const EdgeInsets.all(0),
    decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : Colors.white, borderRadius: BorderRadius.circular(6)),
    child: Column(children: [
      Container(
        height: 43,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFefefef)))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: () => context.push('/member/rising-chart'),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('今日关注度飙升榜', style: AppTextStyles.cn(15, color: isDark ? AppColors.darkText : const Color(0xFF333333), weight: FontWeight.w600)),
              Icon(Icons.chevron_right, size: 16, color: isDark ? AppColors.darkText : const Color(0xFF333333)),
            ]),
          ),
        ]),
      ),
      for (var i = 1; i <= 3; i++)
        Container(
          height: 49,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(border: i < 3 ? Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFefefef))) : null),
          child: Row(children: [
            const SizedBox(width: 10),
            SizedBox(width: 23, child: Text('0$i', style: AppTextStyles.num(15.5, color: const Color(0xFFf0a33c)))),
            Expanded(child: Text('广发远见智选混合C', style: AppTextStyles.cn(14.5, color: isDark ? AppColors.darkText : const Color(0xFF333333)), maxLines: 1, overflow: TextOverflow.ellipsis)),
            SizedBox(width: 54, child: Text('029177', style: AppTextStyles.num(14, color: const Color(0xFF666666)), textAlign: TextAlign.right)),
            SizedBox(width: 68, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('48.23%', style: AppTextStyles.cn(14, color: const Color(0xFF666666))),
              const SizedBox(width: 3),
              Image.asset('assets/images/img/upico.png', width: 8, height: 9),
            ])),
            const SizedBox(width: 10),
          ]),
        ),
      const SizedBox(height: 6),
    ]));
}
