import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/widgets/custom_nav_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'widgets/distribution_donut.dart';

/// 持仓分布页 — 1:1 复刻 uni-app pages/user/distribution.vue
/// 环形图（基金/板块/类型占比）+ 分布列表
///
/// 路由 query 参数（对齐 uni-app onLoad options）:
///   bookId — 账本ID，'all'/空 表示全部账本
///   type   — 'fund'(默认) / 'sector' / 'type'
class DistributionPage extends StatefulWidget {
  final String? bookId;
  final String? type;

  const DistributionPage({super.key, this.bookId, this.type});

  @override
  State<DistributionPage> createState() => _DistributionPageState();
}

class _DistributionPageState extends State<DistributionPage> {
  final ApiClient _api = ApiClient();

  List<DistributionDatum> _list = const [];
  late final String _bookId = widget.bookId ?? '';
  late final String _distType = _normalizeType(widget.type);

  static String _normalizeType(String? type) {
    // uni-app distLabel map: { fund: '基金', sector: '板块', type: '类型' }，默认 fund
    return switch (type) {
      'sector' => 'sector',
      'type' => 'type',
      _ => 'fund',
    };
  }

  /// uni-app: bookId === 'all' ? undefined : Number(bookId)
  int? get _apiBookId => (_bookId.isEmpty || _bookId == 'all') ? null : int.tryParse(_bookId);

  String get _distLabel => switch (_distType) {
        'sector' => '板块',
        'type' => '类型',
        _ => '基金',
      };

  static double _toNum(dynamic v) {
    if (v == null) return 0;
    return num.tryParse(v.toString())?.toDouble() ?? 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDistribution());
  }

  Future<void> _fetchDistribution() async {
    try {
      final res = await _api.get(
        ApiEndpoints.profitDistribution,
        queryParameters: _apiBookId != null ? {'bookId': _apiBookId} : null,
      );
      final body = res.data;
      // uni-app: const data = res?.data || res
      final data = body is Map ? (body['data'] is Map ? body['data'] as Map : body) : const {};
      final key = _distType == 'sector'
          ? 'sectorDistribution'
          : _distType == 'type'
              ? 'typeDistribution'
              : 'fundDistribution';
      final raw = data[key];
      final items = raw is List ? raw.whereType<Map>().toList() : const <Map>[];
      if (!mounted) return;
      setState(() {
        _list = [
          for (var i = 0; i < items.length; i++)
            DistributionDatum(
              name: (items[i]['name'] ?? items[i]['key'] ?? '--').toString(),
              value: _toNum(items[i]['ratio']),
              color: Color(DistributionDonut.pieColors[i % DistributionDonut.pieColors.length]),
            ),
        ];
      });
    } catch (_) {/* 静默处理（对齐 uni-app console.error） */}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : const Color(0xFF333333);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      appBar: CustomNavBar(
        title: '持仓分布',
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        titleColor: textColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20), // .page-content padding: 20px
        child: Column(
          children: [
            // 饼图区域 200×200, margin 30px auto
            Container(
              width: 200,
              height: 200,
              margin: const EdgeInsets.symmetric(vertical: 30),
              child: DistributionDonut(
                isDark: isDark,
                data: _list,
                centerCount: '${_list.length}个',
                centerLabel: _distLabel,
              ),
            ),
            // 列表区域
            Expanded(
              child: ListView.builder(
                itemCount: _list.length,
                itemBuilder: (context, i) => _buildItem(_list[i], isDark, textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(DistributionDatum item, bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12), // padding: 12px 0
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFF5F5F5),
            width: 0.5, // 1rpx
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cn(15, color: textColor),
            ),
          ),
          Text('${item.ratioText}%', style: AppTextStyles.cn(15, color: textColor, weight: FontWeight.w500)),
        ],
      ),
    );
  }
}
