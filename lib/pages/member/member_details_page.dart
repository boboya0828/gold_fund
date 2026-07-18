import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 早晚报详情 — 1:1 复刻 uni-app pages/member/details.vue
///
/// 通过 type/id 打开：type=morning → VIP早报；type=closing → 尾盘参考。
/// 接口：
///   GET /asset/api/Vip/morning-reports/{id}（getVipMorningReportDetail）
///   GET /asset/api/Vip/closing-reports/{id}（getVipClosingReportDetail）
///
/// 说明：uni-app 用 rich-text 渲染 HTML；Flutter 端无 HTML 渲染依赖
/// （pubspec.yaml 不可改），用轻量分段渲染替代（文本 + 图片），详见报告 REMAINING。
class MemberDetailsPage extends ConsumerStatefulWidget {
  /// 'morning' | 'closing'
  final String type;
  final String id;

  const MemberDetailsPage({super.key, this.type = 'morning', this.id = ''});

  @override
  ConsumerState<MemberDetailsPage> createState() => _MemberDetailsPageState();
}

class _MemberDetailsPageState extends ConsumerState<MemberDetailsPage> {
  static const _morningDetailBase = ApiEndpoints.vipMorningReports;
  static const _closingDetailBase = ApiEndpoints.vipClosingReports;

  final ApiClient _api = ApiClient();

  bool _loading = false;
  _ReportDetail _detail = const _ReportDetail();

  bool get _isClosing => widget.type == 'closing';

  /// pageTitle
  String get _pageTitle => _isClosing ? '尾盘参考' : 'VIP早报';

  @override
  void initState() {
    super.initState();
    // uni-app onLoad: 读取 type/id 后 loadDetail
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  Future<void> _loadDetail() async {
    if (widget.id.isEmpty) return; // uni-app: if (!reportId.value) return
    setState(() => _loading = true);
    try {
      final base = _isClosing ? _closingDetailBase : _morningDetailBase;
      final res = await _api.get('$base/${widget.id}');
      // unwrapApiData: res?.data ?? res ?? {}
      dynamic data = res.data;
      if (data is Map && data['data'] != null) data = data['data'];
      final map =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      if (mounted) setState(() => _detail = _normalizeDetail(map));
    } catch (_) {
      // uni-app: console.error + showToast('获取详情失败')
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取详情失败')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// normalizeDetail
  _ReportDetail _normalizeDetail(Map<String, dynamic> data) {
    final publishTime = _firstNonNull([
      data['time'],
      data['publishTime'],
      data['releaseTime'],
      data['createdTime'],
      data['updateTime'],
      data['date'],
    ]);
    final content = _pickText([
      data['content'],
      data['htmlContent'],
      data['contentHtml'],
      data['body'],
      data['text'],
      data['markdown'],
      data['summary'],
      data['desc'],
      data['description'],
    ]);
    final isHtml = _looksLikeHtml(content);
    return _ReportDetail(
      title: _pickText(
          [data['title'], data['name'], data['reportTitle'], _pageTitle]),
      subtitle:
          '$_pageTitle ${_formatSubtitleTime(publishTime)}'.trim(),
      summary: _pickText([data['summary'], data['desc'], data['description']]),
      content: content,
      cover: _pickText(
          [data['coverImage'], data['image'], data['thumbnail'], data['banner']]),
      isHtml: isHtml,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // .page-container/.page-content: #FFFBF8 / .theme-dark #111315
    final bg = isDark ? AppColors.darkBg : const Color(0xFFFFFBF8);
    final titleColor =
        isDark ? AppColors.darkText : const Color(0xFF202124);
    final subColor =
        isDark ? const Color(0xFFA7ADB8) : const Color(0xFF8A8F99);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        // bgState:false → 纯色导航栏：浅 #ffffff / 深 #202125
        CustomNavBar(
          title: _pageTitle,
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
        ),
        Expanded(
          child: ListView(
            // .page-content: padding 20rpx 20rpx 40rpx
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            children: [
              if (_loading)
                _stateBox('加载中...', subColor)
              else if (_detail.title.isEmpty && _detail.content.isEmpty)
                _stateBox('暂无详情', subColor)
              else
                _buildDetail(isDark, titleColor, subColor),
            ],
          ),
        ),
      ]),
    );
  }

  /// .state-box
  Widget _stateBox(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70), // 140rpx
      child:
          Center(child: Text(text, style: AppTextStyles.cn(13, color: color))), // 26rpx
    );
  }

  /// .details
  Widget _buildDetail(bool isDark, Color titleColor, Color subColor) {
    return Container(
      decoration: BoxDecoration(
        // .theme-dark .details { background: #202125 }（浅色下源码背景被注释，为透明）
        color: isDark ? AppColors.darkSurface : null,
        borderRadius: BorderRadius.circular(10), // 20rpx
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // .detail-head
        Text(
          _detail.title,
          style: AppTextStyles.cn(19, // 38rpx
              weight: FontWeight.w700, height: 1.35, color: titleColor),
        ),
        if (_detail.subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 9), // 18rpx
            child: Text(
              _detail.subtitle,
              style: AppTextStyles.cn(14, height: 1.4, color: subColor), // 28rpx
            ),
          ),
        // .detail-summary
        if (_detail.summary.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 14), // 28rpx
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11), // 22rpx 24rpx
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF282B32)
                  : const Color(0xFFFFF6F1),
              borderRadius: BorderRadius.circular(6), // 12rpx
            ),
            child: Text(
              _detail.summary,
              style: AppTextStyles.cn(13.5, // 27rpx
                  height: 1.6,
                  color: isDark
                      ? const Color(0xFFC9CDD4)
                      : const Color(0xFF6B5A4D)),
            ),
          ),
        // .detail-cover（mode="widthFix"）
        if (_detail.cover.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14), // 28rpx
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7), // 14rpx
              child: Image.network(
                _detail.cover,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        // .detail-content
        Padding(
          padding: const EdgeInsets.only(top: 16), // 32rpx
          child: _detail.isHtml
              ? _HtmlLiteContent(
                  html: _detail.content,
                  style: AppTextStyles.cn(15, // 30rpx
                      height: 1.75,
                      color: isDark
                          ? AppColors.darkText
                          : const Color(0xFF333333)),
                )
              : Text(
                  _detail.content,
                  style: AppTextStyles.cn(15,
                      height: 1.75,
                      color: isDark
                          ? AppColors.darkText
                          : const Color(0xFF333333)),
                ),
        ),
      ]),
    );
  }

  // ===================== 格式化工具（逐项对齐 uni-app helpers） =====================

  static String _pickText(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static dynamic _firstNonNull(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      if (v is String && v.trim().isEmpty) continue;
      return v;
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceAll('/', '-'));
  }

  static String _pad2(int v) => v.toString().padLeft(2, '0');

  /// formatSubtitleTime：MM-dd HH:mm
  /// （源码 normalizeDetail 还计算了 timeText/formatDateTime，但模板未展示，这里省略）
  static String _formatSubtitleTime(dynamic value) {
    final raw = _pickText([value]);
    if (raw.isEmpty) return '';
    final date = _parseDate(raw);
    if (date == null) {
      final s = raw.length > 16 ? raw.substring(5, 16) : raw;
      return s.replaceFirst('T', ' ');
    }
    return '${_pad2(date.month)}-${_pad2(date.day)} '
        '${_pad2(date.hour)}:${_pad2(date.minute)}';
  }

  /// looksLikeHtml
  static bool _looksLikeHtml(String value) =>
      RegExp(r'<\/?[a-z][\s\S]*>', caseSensitive: false).hasMatch(value);
}

/// normalizeDetail 输出
class _ReportDetail {
  final String title;
  final String subtitle;
  final String summary;
  final String content;
  final String cover;
  final bool isHtml;

  const _ReportDetail({
    this.title = '',
    this.subtitle = '',
    this.summary = '',
    this.content = '',
    this.cover = '',
    this.isHtml = false,
  });
}

/// 轻量 HTML 分段渲染 —— 替代 uni-app rich-text：
/// 提取 <img> 作为图片段，其余标签剥离为纯文本段（块级标签转换行）。
/// 对应源码 constrainRichContent 的目的（图片限宽、块级换行），
/// 完整富文本渲染需引入 HTML 依赖，见报告 REMAINING。
class _HtmlLiteContent extends StatelessWidget {
  final String html;
  final TextStyle style;

  const _HtmlLiteContent({required this.html, required this.style});

  @override
  Widget build(BuildContext context) {
    final segments = _parse(html);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final seg in segments)
          if (seg.isImage)
            // .detail-content img: display block, width 100%, height auto, margin 16rpx 0
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.network(
                seg.text,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            )
          else
            Text(seg.text, style: style),
      ],
    );
  }

  static List<_Seg> _parse(String html) {
    final imgRe = RegExp(r'<img\b[^>]*>', caseSensitive: false);
    final srcRe =
        RegExp('src\\s*=\\s*["\x27]([^"\x27]+)', caseSensitive: false);
    final out = <_Seg>[];
    var last = 0;
    for (final m in imgRe.allMatches(html)) {
      if (m.start > last) {
        final text = _htmlToText(html.substring(last, m.start));
        if (text.isNotEmpty) out.add(_Seg(text, false));
      }
      final src = srcRe.firstMatch(m.group(0)!)?.group(1)?.trim() ?? '';
      if (src.isNotEmpty) out.add(_Seg(src, true));
      last = m.end;
    }
    if (last < html.length) {
      final text = _htmlToText(html.substring(last));
      if (text.isNotEmpty) out.add(_Seg(text, false));
    }
    if (out.isEmpty) {
      final text = _htmlToText(html);
      if (text.isNotEmpty) out.add(_Seg(text, false));
    }
    return out;
  }

  /// 剥离标签：块级结束标签与 <br> 转换行，其余标签删除，解码常用实体
  static String _htmlToText(String input) {
    var s = input;
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(
        RegExp(
            '</(?:p|div|section|article|figure|blockquote|pre|ul|ol|li|tr|table|h[1-6])\\s*>',
            caseSensitive: false),
        '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }
}

class _Seg {
  final String text;
  final bool isImage;
  const _Seg(this.text, this.isImage);
}
