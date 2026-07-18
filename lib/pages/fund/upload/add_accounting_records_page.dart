import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/widgets/custom_nav_bar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// 添加记账记录 — 选择账本页
/// 1:1 复刻 uni-app (zdj-v1/pages/index/fund/upload/add-accounting-records.vue)
class AddAccountingRecordsPage extends StatefulWidget {
  final String shortName;
  final bool fromDetails;
  final String mode; // 'add' | 'edit'
  final int? symbolId;
  final String marketValue;
  final String holdProfit;

  const AddAccountingRecordsPage({
    super.key,
    this.shortName = '',
    this.fromDetails = false,
    this.mode = 'add',
    this.symbolId,
    this.marketValue = '',
    this.holdProfit = '',
  });

  @override
  State<AddAccountingRecordsPage> createState() => _AddAccountingRecordsPageState();
}

class _AddAccountingRecordsPageState extends State<AddAccountingRecordsPage> {
  final ApiClient _api = ApiClient();

  bool _loading = false;
  List<_BookItem> _bookList = [];
  int? _selectedBookId;

  bool get _isEdit => widget.mode == 'edit';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBookList());
  }

  // ===== 数据 (对应 fetchBookList) =====
  Future<void> _fetchBookList() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiEndpoints.assetBooks);
      final body = res.data;
      final List raw = body is List
          ? body
          : (body is Map && body['data'] is List ? body['data'] as List : const []);
      final list = raw
          .whereType<Map>()
          .map((e) => _BookItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      _BookItem? defaultBook;
      for (final b in list) {
        if (b.isDefault) {
          defaultBook = b;
          break;
        }
      }
      defaultBook ??= list.isNotEmpty ? list.first : null;
      setState(() {
        _bookList = list;
        _selectedBookId = defaultBook?.bookId;
      });
    } catch (_) {
      if (mounted) setState(() => _bookList = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== edit 模式取账本持仓 (对应 resolveBookHoldingPayload 系列) =====

  /// 对应 formatEditAmount
  static String _formatEditAmount(dynamic value) {
    final num? n = value is num ? value : num.tryParse('$value');
    return n != null ? n.toStringAsFixed(2) : '';
  }

  /// 对应 unwrapAssetList
  static List<dynamic> _unwrapAssetList(dynamic body) {
    final data = body is Map ? (body['data'] ?? body) : body;
    if (data is Map && data['list'] is List) return data['list'] as List;
    if (data is List) return data;
    if (body is Map && body['list'] is List) return body['list'] as List;
    return const [];
  }

  /// 对应 findHoldingBySymbol
  Map<String, dynamic>? _findHoldingBySymbol(List<dynamic> list) {
    Map<String, dynamic>? cast(dynamic e) =>
        e is Map ? Map<String, dynamic>.from(e) : null;
    for (final item in list) {
      final m = cast(item);
      if (m != null &&
          (m['symbolId'] as num?)?.toInt() == widget.symbolId &&
          (m['bookId'] as num?)?.toInt() == _selectedBookId) {
        return m;
      }
    }
    for (final item in list) {
      final m = cast(item);
      if (m != null && (m['symbolId'] as num?)?.toInt() == widget.symbolId) return m;
    }
    return null;
  }

  /// 对应 resolveFallbackHoldingAmount
  static num _resolveFallbackHoldingAmount(Map<String, dynamic> detail) {
    final direct = num.tryParse('${detail['marketValue']}');
    final holdQuantity = num.tryParse('${detail['holdQuantity']}');
    final unitMarketValue = num.tryParse('${detail['marketValue']}');
    if (holdQuantity != null && unitMarketValue != null) {
      return holdQuantity * unitMarketValue;
    }
    return direct ?? 0;
  }

  Future<Map<String, String>> _resolveBookHoldingPayload() async {
    if (!_isEdit || widget.marketValue.isNotEmpty || widget.symbolId == null || _selectedBookId == null) {
      return {'marketValue': widget.marketValue, 'holdProfit': widget.holdProfit};
    }
    final bookRes = await _api.get(ApiEndpoints.assetListV2, queryParameters: {'bookId': _selectedBookId});
    final bookDetail = _findHoldingBySymbol(_unwrapAssetList(bookRes.data));
    if (bookDetail != null) {
      return {
        'marketValue': _formatEditAmount(bookDetail['marketValue']),
        'holdProfit': _formatEditAmount(bookDetail['holdProfit']),
      };
    }
    final symbolRes = await _api.get('${ApiEndpoints.assetBySymbol}/${widget.symbolId}');
    final symbolDetail = _findHoldingBySymbol(_unwrapAssetList(symbolRes.data));
    if (symbolDetail == null) {
      throw Exception('selected book holding not found');
    }
    return {
      'marketValue': _formatEditAmount(_resolveFallbackHoldingAmount(symbolDetail)),
      'holdProfit': _formatEditAmount(symbolDetail['holdProfit']),
    };
  }

  // ===== 下一步 (对应 handleNext) =====
  Future<void> _handleNext() async {
    if (widget.fromDetails) {
      var payload = {'marketValue': widget.marketValue, 'holdProfit': widget.holdProfit};
      if (_isEdit) {
        try {
          payload = await _resolveBookHoldingPayload();
        } catch (_) {
          _toast('该账本暂无此基金持仓');
          return;
        }
      }
      final query = [
        'bookId=${Uri.encodeComponent('${_selectedBookId ?? ''}')}',
        'symbolId=${Uri.encodeComponent('${widget.symbolId ?? ''}')}',
        'shortName=${Uri.encodeComponent(widget.shortName)}',
        'mode=${widget.mode}',
        if (_isEdit) ...[
          'marketValue=${Uri.encodeComponent(payload['marketValue'] ?? '')}',
          'holdProfit=${Uri.encodeComponent(payload['holdProfit'] ?? '')}',
        ],
      ].join('&');
      if (mounted) context.push('/fund/upload/maddzx?$query');
    } else {
      final query = 'bookId=${Uri.encodeComponent('${_selectedBookId ?? ''}')}';
      context.push('/fund/upload/mass-upload?$query');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF8F5F6);
    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        Column(children: [
          CustomNavBar(
            title: '选择账本',
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
          ),
          Expanded(
            child: SingleChildScrollView(
              // page-content: padding 16rpx 24rpx 160rpx
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              child: _buildContent(isDark),
            ),
          ),
        ]),
        // bottom-area: 固定底部渐变 + 下一步
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomArea(isDark),
        ),
      ]),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_bookList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60), // 120rpx
        child: Center(
          child: Text(
            _loading ? '加载中...' : '暂无账本',
            style: AppTextStyles.cn(14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFA7A9B6)),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8), // 16rpx
        boxShadow: isDark
            ? null
            : const [BoxShadow(color: Color(0x0A272D4A), offset: Offset(0, 4), blurRadius: 12)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(_bookList.length, (i) => _buildBookItem(_bookList[i], i == _bookList.length - 1, isDark)),
      ),
    );
  }

  Widget _buildBookItem(_BookItem item, bool isLast, bool isDark) {
    final active = _selectedBookId == item.bookId;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedBookId = item.bookId),
      child: Container(
        constraints: const BoxConstraints(minHeight: 47), // 94rpx
        padding: const EdgeInsets.only(left: 11, right: 12), // 22rpx / 24rpx
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFEEF0F5), width: 0.5)),
        ),
        child: Row(children: [
          // radio-icon 30rpx + active 内点 16rpx
          Container(
            width: 15,
            height: 15,
            margin: const EdgeInsets.only(right: 9), // 18rpx
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? AppColors.primary : (isDark ? const Color(0xFF4B505A) : const Color(0xFFCFD4DF)),
                width: 1, // 2rpx
              ),
            ),
            child: active
                ? Center(
                    child: Container(
                      width: 8, // 16rpx
                      height: 8,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              item.bookName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cn(16,
                  color: isDark ? AppColors.darkText : const Color(0xFF2B3150),
                  weight: FontWeight.w500,
                  height: 44 / 32),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10), // 20rpx
            child: Text(
              '共${item.assetCount}个',
              style: AppTextStyles.cn(13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9EA4C2), height: 36 / 26),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBottomArea(bool isDark) {
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF8F5F6);
    return Container(
      // padding 18rpx 24rpx (safe-area + 20rpx)
      padding: EdgeInsets.fromLTRB(12, 9, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.24, 1.0],
          colors: [bg.withAlpha(0), bg, bg],
        ),
      ),
      child: GestureDetector(
        onTap: _handleNext,
        child: Container(
          height: 44, // 88rpx
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(6), // 12rpx
          ),
          child: Text(
            '下一步',
            style: AppTextStyles.cn(16, color: Colors.white, weight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// 账本条目 — 对应 getAssetBooks 返回 { bookId, bookName, assetCount, isDefault }
class _BookItem {
  final int bookId;
  final String bookName;
  final int assetCount;
  final bool isDefault;

  const _BookItem({
    required this.bookId,
    required this.bookName,
    required this.assetCount,
    required this.isDefault,
  });

  factory _BookItem.fromJson(Map<String, dynamic> j) => _BookItem(
        bookId: (j['bookId'] as num?)?.toInt() ?? (j['id'] as num?)?.toInt() ?? 0,
        bookName: j['bookName']?.toString() ?? j['name']?.toString() ?? '',
        assetCount: (j['assetCount'] as num?)?.toInt() ?? 0,
        isDefault: j['isDefault'] == true || j['isDefault'] == 1,
      );
}
