import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/text_styles.dart';

/// 通用 WebView / 文本展示页 — 用于用户协议、隐私政策等静态页面
class WebViewPage extends ConsumerWidget {
  final String title;
  final String? url;
  final String? content;

  const WebViewPage({super.key, required this.title, this.url, this.content});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111315) : const Color(0xFFF1F1F3);
    final textColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.cn(16, color: textColor)),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: content != null
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(content!, style: AppTextStyles.cn(15, color: textColor)),
              )
            : const Center(child: Text('页面加载中...')),
      ),
    );
  }
}
