import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/text_styles.dart';

/// 持仓详情页 — 占位
/// uni-app 对应: pages/index/fund/position-details.vue
class PositionDetailsPage extends ConsumerWidget {
  final String symbolId;
  final int assetType;
  final int? assetId;

  const PositionDetailsPage({super.key, this.symbolId = '', this.assetType = 3, this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111315) : const Color(0xFFF1F1F3);
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('持仓详情', style: AppTextStyles.cn(16, color: textColor)),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('持仓详情', style: AppTextStyles.cn(16, color: textColor)),
          Text('symbolId: $symbolId  assetType: $assetType',
              style: AppTextStyles.cn(12, color: const Color(0xFF8D8B87))),
          const SizedBox(height: 16),
          Text('详情页待迁移...', style: AppTextStyles.cn(14, color: const Color(0xFFA7ADB8))),
        ]),
      ),
    );
  }
}
