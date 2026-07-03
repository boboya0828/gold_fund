import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 基金群入口 - 对齐 uni-app utils/wechat-mini-program.js
///
/// 源码优先尝试打开微信小程序，失败时降级为打开公众号文章 URL。
/// Flutter 端未集成 fluwx，故直接走"打开文章 URL"这条降级路径
/// （与源码 fallbackToArticleWebview 行为一致）。
class FundGroupService {
  FundGroupService._();

  /// 微信小程序原始 id（保留供后续接入 fluwx 时使用）
  // TODO: 接入 fluwx 后可用 launchWeChatMiniProgram 打开原生小程序
  static const miniProgramId = 'gh_424163b49715';
  static const miniProgramPath =
      'pages/common/webview?title=%E5%9F%BA%E9%87%91%E7%BE%A4&url=https%3A%2F%2Fmp.weixin.qq.com%2Fs%2FGw6gic9XAc2tH5nA1omWAw';

  /// 公众号文章地址（降级打开目标）
  static const articleUrl = 'https://mp.weixin.qq.com/s/Gw6gic9XAc2tH5nA1omWAw';

  /// 打开基金群（当前实现：外部浏览器打开文章 URL）
  static Future<void> open(BuildContext context) async {
    final uri = Uri.parse(articleUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {
      // 忽略，走下方降级
    }
    // 打开失败 → 复制链接并提示
    await Clipboard.setData(const ClipboardData(text: articleUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('链接已复制'), duration: Duration(seconds: 2)),
      );
    }
  }
}
