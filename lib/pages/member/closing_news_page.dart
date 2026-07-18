import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import 'widgets/member_report_list_view.dart';

/// 尾盘参考（收盘播报）— 1:1 复刻 uni-app pages/member/closingnews.vue
///
/// 数据：GET /asset/api/Vip/closing-reports?pageNum=&pageSize=20
/// （uni-app getVipClosingReports）。
class ClosingNewsPage extends ConsumerWidget {
  const ClosingNewsPage({super.key});

  static const _endpoint = ApiEndpoints.vipClosingReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // .page-container: #F1F1F3 / .theme-dark #111315
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF1F1F3);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        // bgState:false → 纯色导航栏：浅 #ffffff / 深 #202125
        CustomNavBar(
          title: '尾盘参考',
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
        ),
        Expanded(
          // .ml-4.mr-4 = 1rem = 16px
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MemberReportListView(
              isDark: isDark,
              fetchPage: _fetchPage,
              // formatDateTitle: 固定 尾盘
              reportNameFor: (_) => '尾盘',
              summaryText: '赶紧点击查看尾盘参考吧～',
              emptyText: '暂无尾盘',
              errorText: '获取尾盘失败',
              onOpen: (item) => _openReport(context, item),
            ),
          ),
        ),
      ]),
    );
  }

  Future<MemberReportPageData> _fetchPage(int pageNum, int pageSize) async {
    final res = await ApiClient().get(_endpoint,
        queryParameters: {'pageNum': pageNum, 'pageSize': pageSize});
    return MemberReportPageData.fromBody(res.data);
  }

  /// openReport：无 id → toast 暂无详情；否则 ./details?type=closing&id=
  void _openReport(BuildContext context, MemberReportItem item) {
    if (item.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无详情')),
      );
      return;
    }
    // 1:1 ./details?type=closing&id=
    context.push('/member/details?type=closing&id=${Uri.encodeComponent(item.id)}');
  }
}
