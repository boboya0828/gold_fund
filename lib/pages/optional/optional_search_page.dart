import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/text_styles.dart';

/// 自选搜索页 — 占位
/// uni-app 对应: pages/optional/search.vue
class OptionalSearchPage extends ConsumerWidget {
  const OptionalSearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111315) : const Color(0xFFF1F1F3);
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('搜索基金', style: AppTextStyles.cn(16, color: textColor)),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: '输入名称或代码搜索',
              hintStyle: AppTextStyles.cn(14, color: const Color(0xFFBBBBBB)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFA6A6A6)),
              filled: true,
              fillColor: isDark ? const Color(0xFF202125) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const Expanded(child: Center(child: Text('搜索功能待迁移...'))),
      ]),
    );
  }
}
