import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/text_styles.dart';

/// 行情详情页 — 占位
/// uni-app 对应: pages/market/details.vue (含 ECharts 图表)
class MarketDetailsPage extends ConsumerWidget {
  final String symbolId;
  final String? name;

  const MarketDetailsPage({super.key, this.symbolId = '', this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111315) : const Color(0xFFF1F1F3);
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(name ?? '详情', style: AppTextStyles.cn(16, color: textColor)),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.show_chart, size: 48, color: Color(0xFFE05665)),
              const SizedBox(height: 16),
              Text(name ?? '行情详情', style: AppTextStyles.cn(16, color: textColor)),
              const SizedBox(height: 8),
              Text('symbolId: $symbolId', style: AppTextStyles.cn(12, color: const Color(0xFF8D8B87))),
              const SizedBox(height: 16),
              Text('图表待迁移...', style: AppTextStyles.cn(14, color: const Color(0xFFA7ADB8))),
            ],
          ),
        ),
      ),
    );
  }
}
