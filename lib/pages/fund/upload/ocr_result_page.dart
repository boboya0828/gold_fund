import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/widgets/custom_nav_bar.dart';
import '../../../theme/text_styles.dart';
import 'madd_number_keyboard.dart';

/// OCR 识别结果确认页 — 1:1 复刻 uni-app (zdj-v1/pages/index/fund/upload/ocrResult.vue)
/// 展示/编辑/移除识别出的基金持仓记录, 支持继续上传图片识别, 确认后批量导入
/// 注: 本页 uni-app 源码未做深色适配(page-container 无 theme-dark), 故页面固定浅色, 仅键盘跟随主题
class OcrResultPage extends StatefulWidget {
  final String? bookId;
  final String? data; // URL-encoded JSON: {data: [...]} 或 [...]

  const OcrResultPage({super.key, this.bookId, this.data});

  @override
  State<OcrResultPage> createState() => _OcrResultPageState();
}

// ===== 内联数据模型 =====
class _OcrItem {
  final String key;
  String uniqueSymbol;
  String showCode;
  String name;
  String amount;
  String holding;
  int? symbolId;

  _OcrItem({
    required this.key,
    this.uniqueSymbol = '',
    this.showCode = '--',
    this.name = '未知基金',
    this.amount = '',
    this.holding = '',
    this.symbolId,
  });
}

class _EditForm {
  String name = '';
  String amount = '';
  String holding = '';
  String uniqueSymbol = '';
  String showCode = '';
  int? symbolId;
}

class _OcrResultPageState extends State<OcrResultPage> {
  final ApiClient _api = ApiClient();

  int? _selectedBookId;
  bool _importing = false;
  bool _uploading = false;
  String _uploadProgress = '';
  final List<_OcrItem> _resultList = [];
  String _editingKey = '';
  bool _numberKeyboardVisible = false;
  String _activeKeyboardField = ''; // 'amount' | 'holding'
  _EditForm _editForm = _EditForm();
  int _itemKeySeed = 0;

  @override
  void initState() {
    super.initState();
    // onLoad
    _selectedBookId = int.tryParse(widget.bookId ?? '');
    final raw = widget.data;
    if (raw == null || raw.isEmpty) return;
    try {
      final payload = jsonDecode(Uri.decodeComponent(raw));
      final rawList = payload is Map && payload['data'] is List
          ? payload['data'] as List
          : payload is List
              ? payload
              : const [];
      _mergeResultItems(rawList, replace: true);
    } catch (e) {
      debugPrint('解析识别结果失败: $e');
    }
  }

  // ===== 工具 =====
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  static String _toEditText(dynamic value) => value == null ? '' : '$value';

  static String _normalizeNumberText(dynamic value) {
    final text = '$value'.replaceAll(',', '').replaceAll(RegExp(r'[￥¥]'), '').trim();
    if (text.isEmpty) return '';
    final numberValue = double.tryParse(text);
    if (numberValue == null) return text;
    return numberValue.toStringAsFixed(2);
  }

  static String _normalizePositiveDecimalInput(String value) {
    final numeric = value.replaceAll(RegExp(r'[^\d.]'), '');
    final parts = numeric.split('.');
    final intPart = parts.first;
    final decPart = parts.sublist(1).join();
    return '$intPart${parts.length > 1 ? '.$decPart' : ''}';
  }

  static String _normalizeSignedDecimalInput(String value) {
    final isNegative = value.trimLeft().startsWith('-');
    final numeric = value.replaceAll(RegExp(r'[^\d.]'), '');
    final parts = numeric.split('.');
    final intPart = parts.first;
    final decPart = parts.sublist(1).join();
    return '${isNegative ? '-' : ''}$intPart${parts.length > 1 ? '.$decPart' : ''}';
  }

  static String _formatMoneyText(String value) {
    final text = _normalizeNumberText(value);
    return text.isEmpty ? '--' : text;
  }

  static String _formatProfitText(String value) {
    final text = _normalizeNumberText(value);
    if (text.isEmpty) return '--';
    final numberValue = double.tryParse(text);
    if (numberValue == null) return text;
    return numberValue > 0 ? '+$text' : text;
  }

  static Color _profitColor(String value) {
    final text = value.replaceAll(',', '').replaceAll(RegExp(r'[￥¥]'), '').trim();
    final numberValue = double.tryParse(text);
    if (numberValue == null || numberValue == 0) return const Color(0xFF7F7773); // flat
    return numberValue > 0 ? const Color(0xFFFF645D) : const Color(0xFF36BD7B); // rise / fall
  }

  // ===== 去重 key =====
  static String _getRawSymbolCode(Map<String, dynamic> item) =>
      _toEditText(item['symbolInfo'] is Map ? (item['symbolInfo'] as Map)['code'] : null).isNotEmpty
          ? _toEditText((item['symbolInfo'] as Map)['code'])
          : _toEditText(item['uniqueSymbol'] ?? item['showCode'] ?? item['code']);

  String _createItemKey(Map<String, dynamic> item, int index) {
    _itemKeySeed += 1;
    final identity = _getRawSymbolCode(item).isNotEmpty
        ? _getRawSymbolCode(item)
        : _toEditText(item['symbolId'] ??
            (item['symbolInfo'] is Map ? (item['symbolInfo'] as Map)['shortName'] : null) ??
            item['name'] ??
            'fund');
    return '$identity-${DateTime.now().millisecondsSinceEpoch}-$index-$_itemKeySeed';
  }

  static String _normalizeTextKey(dynamic value) => _toEditText(value).trim().toLowerCase();

  String _getDedupKeyOfItem(_OcrItem item) {
    if (item.symbolId != null) return 'id:${item.symbolId}';
    final code = _normalizeTextKey(item.uniqueSymbol.isNotEmpty ? item.uniqueSymbol : item.showCode);
    if (code.isNotEmpty && code != '--') return 'code:$code';
    final name = _normalizeTextKey(item.name);
    if (name.isNotEmpty && name != '未知基金') return 'name:$name';
    return '';
  }

  _OcrItem _normalizeResultItem(Map<String, dynamic> item, int index) {
    final symbolCode = _getRawSymbolCode(item);
    final symbolInfo = item['symbolInfo'] is Map ? item['symbolInfo'] as Map : const {};
    return _OcrItem(
      key: _createItemKey(item, index),
      uniqueSymbol: symbolCode,
      showCode: symbolCode.isNotEmpty ? symbolCode : '--',
      name: _toEditText(symbolInfo['shortName'] ?? item['name'] ?? '').isNotEmpty
          ? _toEditText(symbolInfo['shortName'] ?? item['name'])
          : '未知基金',
      amount: _normalizeNumberText(item['amount'] ?? item['holdAmount'] ?? 0),
      holding: _normalizeNumberText(item['profit'] ?? item['holding'] ?? item['holdProfit'] ?? 0),
      symbolId: (item['symbolId'] ?? symbolInfo['symbolId'] ?? symbolInfo['id']) is num
          ? ((item['symbolId'] ?? symbolInfo['symbolId'] ?? symbolInfo['id']) as num).toInt()
          : int.tryParse('${item['symbolId'] ?? symbolInfo['symbolId'] ?? symbolInfo['id'] ?? ''}'),
    );
  }

  // 合并识别结果 (replace=true 时整表替换), 按 id/code/name 去重
  void _mergeResultItems(List rawList, {bool replace = false}) {
    final normalized = rawList
        .whereType<Map>()
        .mapIndexed((e) => _normalizeResultItem(Map<String, dynamic>.from(e.value), e.key))
        .toList();
    final baseList = replace ? <_OcrItem>[] : List<_OcrItem>.from(_resultList);
    final merged = List<_OcrItem>.from(baseList);
    final seenKeys = baseList.map(_getDedupKeyOfItem).where((k) => k.isNotEmpty).toSet();

    for (final item in normalized) {
      final dedupKey = _getDedupKeyOfItem(item);
      if (dedupKey.isNotEmpty && seenKeys.contains(dedupKey)) continue; // duplicateCount
      if (dedupKey.isNotEmpty) seenKeys.add(dedupKey);
      merged.add(item);
    }
    setState(() {
      _resultList
        ..clear()
        ..addAll(merged);
    });
  }

  // ===== 删除/编辑 =====
  void _handleRemove(String key) {
    setState(() => _resultList.removeWhere((e) => e.key == key));
    if (_editingKey == key) _cancelEdit();
  }

  void _startEdit(_OcrItem item) {
    setState(() {
      _editingKey = item.key;
      _editForm = _EditForm()
        ..name = item.name
        ..amount = item.amount
        ..holding = item.holding
        ..uniqueSymbol = item.uniqueSymbol
        ..showCode = item.showCode
        ..symbolId = item.symbolId;
    });
  }

  void _cancelEdit() {
    _closeNumberKeyboard();
    setState(() {
      _editingKey = '';
      _editForm = _EditForm();
    });
  }

  void _saveEdit(String key) {
    _closeNumberKeyboard();
    final name = _editForm.name.trim();
    final amount = _normalizeNumberText(_editForm.amount);
    final holding = _normalizeNumberText(_editForm.holding);

    if (name.isEmpty) {
      _toast('请输入基金名称');
      return;
    }
    if (amount.isEmpty || double.tryParse(amount) == null) {
      _toast('请输入正确的持有金额');
      return;
    }
    if (holding.isEmpty || double.tryParse(holding) == null) {
      _toast('请输入正确的持有收益');
      return;
    }
    setState(() {
      final item = _resultList.where((e) => e.key == key).firstOrNull;
      if (item != null) {
        item.name = name;
        if (_editForm.uniqueSymbol.isNotEmpty) item.uniqueSymbol = _editForm.uniqueSymbol;
        if (_editForm.showCode.isNotEmpty) item.showCode = _editForm.showCode;
        item.symbolId = _editForm.symbolId ?? item.symbolId;
        item.amount = amount;
        item.holding = holding;
      }
    });
    _cancelEdit();
  }

  // ===== 数字键盘 =====
  String get _numberKeyboardValue => _activeKeyboardField == 'holding' ? _editForm.holding : _editForm.amount;

  void _openNumberKeyboard(String field) {
    setState(() {
      _activeKeyboardField = field;
      _numberKeyboardVisible = true;
    });
  }

  void _closeNumberKeyboard() {
    if (!_numberKeyboardVisible && _activeKeyboardField.isEmpty) return;
    setState(() {
      _numberKeyboardVisible = false;
      _activeKeyboardField = '';
    });
  }

  void _handleNumberKeyboardInput(String value) {
    setState(() {
      if (_activeKeyboardField == 'holding') {
        _editForm.holding = _normalizeSignedDecimalInput(value);
        return;
      }
      _editForm.amount = _normalizePositiveDecimalInput(value);
    });
  }

  // ===== 基金选择 (跳搜索页, 等待返回结果; 对应 uni-app 的 manualMassUploadSelect 事件) =====
  Future<void> _handlePickFund(String key) async {
    _closeNumberKeyboard();
    if (_editingKey != key) {
      final target = _resultList.where((e) => e.key == key).firstOrNull;
      if (target != null) _startEdit(target);
    }
    final query = [
      'selectMode=emit',
      'entryKey=${Uri.encodeComponent(key)}',
      if (_selectedBookId != null) 'bookId=${Uri.encodeComponent('$_selectedBookId')}',
    ].join('&');
    final result = await context.push<Map<String, dynamic>>('/fund/upload/search?$query');
    if (result == null || !mounted) return;
    _handleSearchSelect(result, key);
  }

  void _handleSearchSelect(Map<String, dynamic> result, String entryKey) {
    final shortName = _toEditText(
        result['shortName'] ?? result['displayName'] ?? result['symbolName'] ?? result['name'] ?? result['fundName'] ?? '');
    final showCode =
        _toEditText(result['displayCode'] ?? result['symbolCode'] ?? result['code'] ?? result['ticker'] ?? result['symbol'] ?? '');
    final uniqueSymbol = _toEditText(result['uniqueSymbol'] ?? '').isNotEmpty ? _toEditText(result['uniqueSymbol']) : showCode;
    final rawId = result['symbolId'] ?? result['id'];
    final symbolId = rawId is num ? rawId.toInt() : int.tryParse('$rawId');

    setState(() {
      final item = _resultList.where((e) => e.key == entryKey).firstOrNull;
      if (item != null) {
        if (shortName.isNotEmpty) item.name = shortName;
        if (showCode.isNotEmpty) item.showCode = showCode;
        if (uniqueSymbol.isNotEmpty) item.uniqueSymbol = uniqueSymbol;
        item.symbolId = symbolId;
      }
      if (_editingKey == entryKey) {
        _editForm
          ..name = shortName
          ..showCode = showCode
          ..uniqueSymbol = uniqueSymbol
          ..symbolId = symbolId;
      }
    });
  }

  // ===== 继续上传: 选图 → 压缩 → COS 直传 → OCR 识别 =====
  static String _getFileExt(String filePath) {
    final cleanPath = filePath.split('?').first;
    final match = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(cleanPath);
    return match != null ? '.${match.group(1)!.toLowerCase()}' : '.jpg';
  }

  static List _normalizeOcrResultList(dynamic payload) {
    if (payload is Map && payload['data'] is List) return payload['data'] as List;
    if (payload is List) return payload;
    return const [];
  }

  Future<String> _uploadToCos(String filePath, Map signData) async {
    final cosHost = signData['cosHost'];
    final uploadUrl = 'https://$cosHost/';
    final fileUrl = 'https://$cosHost/${signData['key']}';
    // COS 直传不走 ApiClient(无需业务鉴权头), 对齐 uni.uploadFile
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (_) => true,
    ));
    final formData = FormData.fromMap({
      'key': signData['key'],
      'policy': signData['policy'],
      'q-sign-algorithm': signData['qSignAlgorithm'],
      'q-ak': signData['qAk'],
      'q-key-time': signData['qKeyTime'],
      'q-signature': signData['signature'],
      'Content-Type': 'image/jpeg',
      'file': await MultipartFile.fromFile(filePath, contentType: DioMediaType('image', 'jpeg')),
    });
    final res = await dio.post(uploadUrl, data: formData);
    final status = res.statusCode ?? 0;
    if (status == 200 || status == 204) return fileUrl;
    throw Exception('上传失败: $status');
  }

  Future<List> _processSingleImage(String filePath, int index, int total) async {
    setState(() => _uploadProgress = '识别中 ${index + 1}/$total');
    // uni.compressImage(quality:10) → 选图时已用 imageQuality:10 压缩
    final signRes = await _api.get(ApiEndpoints.userOcrSignForm, queryParameters: {'ext': _getFileExt(filePath)});
    final signBody = signRes.data;
    final signData = signBody is Map ? (signBody['data'] ?? signBody) : signBody;
    if (signData is! Map) throw Exception('获取上传签名失败');
    final fileUrl = await _uploadToCos(filePath, signData);
    final res = await _api.post(ApiEndpoints.assetOcrPic, data: {'imageUrl': fileUrl});
    final body = res.data;
    final payload = body is Map ? (body['data'] ?? body) : body;
    return _normalizeOcrResultList(payload);
  }

  Future<void> _handleContinueUpload() async {
    _closeNumberKeyboard();
    if (_uploading || _importing) return;
    if (_editingKey.isNotEmpty) {
      _toast('请先保存当前修改');
      return;
    }
    // uni.chooseImage({count:4, sizeType:['compressed'], sourceType:['album']})
    final picker = ImagePicker();
    List<XFile> files;
    try {
      files = await picker.pickMultiImage(limit: 4, imageQuality: 10);
    } catch (e) {
      debugPrint('选择图片失败: $e');
      return;
    }
    final filePaths = files.map((f) => f.path).where((p) => p.isNotEmpty).toList();
    if (filePaths.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadProgress = '识别中 0/${filePaths.length}';
    });
    try {
      final nextRawList = <dynamic>[];
      for (var i = 0; i < filePaths.length; i++) {
        final imageResult = await _processSingleImage(filePaths[i], i, filePaths.length);
        nextRawList.addAll(imageResult);
      }
      if (!mounted) return;
      _mergeResultItems(nextRawList);
    } catch (e) {
      debugPrint('继续上传识别失败: $e');
      if (mounted) _toast(e is Exception ? e.toString().replaceFirst('Exception: ', '') : '识别失败');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = '';
        });
      }
    }
  }

  // ===== 确认导入 =====
  Future<void> _handleConfirmImport() async {
    _closeNumberKeyboard();
    if (_selectedBookId == null) {
      _toast('账本ID无效');
      return;
    }
    if (_resultList.isEmpty) {
      _toast('暂无可导入数据');
      return;
    }
    if (_editingKey.isNotEmpty) {
      _toast('请先保存当前修改');
      return;
    }
    if (_uploading || _importing) return;

    final items = _resultList
        .where((item) => item.symbolId != null)
        .map((item) => {
              'bookId': _selectedBookId,
              'symbolId': item.symbolId,
              'holdAmount': double.tryParse(item.amount) ?? 0,
              'holdProfit': double.tryParse(item.holding) ?? 0,
            })
        .toList();
    if (items.isEmpty) {
      _toast('未匹配到可导入基金');
      return;
    }

    setState(() => _importing = true);
    try {
      await _api.post(ApiEndpoints.assetBatchInput, data: {'items': items});
      if (!mounted) return;
      _toast('导入成功');
      // uni.switchTab → 持仓 Tab
      context.go('/position');
    } catch (e) {
      debugPrint('批量导入失败: $e');
      if (mounted) _toast('导入失败');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth <= 375; // @media (max-width: 375px)
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F7),
      appBar: const CustomNavBar(
        title: '识别结果',
        backgroundColor: Color(0xFFFAF7F7),
        titleColor: Color(0xFF333333),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeNumberKeyboard,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 12, right: 12, top: 12, // 24rpx
                  bottom: _numberKeyboardVisible ? 360 : 90, // 720rpx / 180rpx
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResultHead(),
                    const SizedBox(height: 0),
                    Column(
                      children: [
                        for (final item in _resultList)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 9), // 18rpx gap
                            child: _buildResultCard(item, isSmall),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 底部「确认导入」按钮区 (键盘弹出时隐藏)
            if (!_numberKeyboardVisible)
              Positioned(
                left: 0, right: 0, bottom: 20, // 40rpx
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 12 + bottomInset), // 20rpx 24rpx (24rpx+safe)
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00FAF7F7), Color(0xF5FAF7F7), Color(0xFFFAF7F7)],
                        stops: [0.0, 0.24, 1.0],
                      ),
                    ),
                    child: Opacity(
                      opacity: (_importing || _uploading) ? 0.6 : 1.0,
                      child: GestureDetector(
                        onTap: (_importing || _uploading) ? null : _handleConfirmImport,
                        child: Container(
                          height: 46, // 92rpx
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF16967), Color(0xFFE05665)],
                            ),
                            borderRadius: BorderRadius.circular(23), // 999rpx
                            boxShadow: const [
                              BoxShadow(color: Color(0x38E05665), blurRadius: 15, offset: Offset(0, 8)), // rgba(224,86,101,0.22)
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _importing ? '导入中...' : '确认导入',
                            style: AppTextStyles.cn(15, color: Colors.white, weight: FontWeight.w700), // 30rpx
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // 数字键盘
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: MaddNumberKeyboard(
                visible: _numberKeyboardVisible,
                value: _numberKeyboardValue,
                allowNegative: _activeKeyboardField == 'holding',
                onChanged: _handleNumberKeyboardInput,
                onConfirm: _closeNumberKeyboard,
              ),
            ),
            // 识别中 loading 遮罩 (uni.showLoading mask)
            if (_uploading)
              Positioned.fill(
                child: Container(
                  color: const Color(0x59000000),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xCC000000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          Text(_uploadProgress, style: AppTextStyles.cn(13, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHead() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 6, bottom: 12), // 12rpx 8rpx 24rpx
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('识别到 ${_resultList.length} 条基金记录',
                    style: AppTextStyles.cn(17, color: const Color(0xFF2B2A2A), height: 1.3)), // 34rpx
                const SizedBox(height: 5), // 10rpx
                Text('请确认识别结果，错误项可直接移除',
                    style: AppTextStyles.cn(12, color: const Color(0xFF9D9494), height: 1.6)), // 24rpx
              ],
            ),
          ),
          const SizedBox(width: 10), // 20rpx
          Opacity(
            opacity: (_uploading || _importing) ? 0.6 : 1.0,
            child: GestureDetector(
              onTap: (_uploading || _importing) ? null : _handleContinueUpload,
              child: Container(
                height: 30, // 60rpx
                padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15), // 999rpx
                  border: Border.all(color: const Color(0xB8D8C590), width: 0.5), // rgba(216,197,144,0.72)
                  boxShadow: const [
                    BoxShadow(color: Color(0x1FCBBFB9), blurRadius: 11, offset: Offset(0, 5)), // rgba(203,191,185,0.12)
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _uploading ? '识别中...' : '继续上传',
                  style: AppTextStyles.cn(12, color: const Color(0xFFB79B52), weight: FontWeight.w600), // 24rpx
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(_OcrItem item, bool isSmall) {
    final editing = _editingKey == item.key;
    return Container(
      padding: isSmall
          ? const EdgeInsets.only(left: 10, right: 10, top: 11, bottom: 11) // 22rpx 20rpx
          : const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 11), // 24rpx 24rpx 22rpx
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFFFFCFC)],
        ),
        borderRadius: BorderRadius.circular(6), // 12rpx
        border: Border.all(color: const Color(0x99E3DBD7), width: 0.5), // rgba(227,219,215,0.6)
        boxShadow: const [
          BoxShadow(color: Color(0x2ECBBFB9), blurRadius: 15, offset: Offset(0, 6)), // rgba(203,191,185,0.18)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _startEdit(item),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 基金信息
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2), // 4rpx
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(item.showCode, style: AppTextStyles.cn(12, color: const Color(0xFF8D8581), height: 1.0)), // 24rpx
                            const SizedBox(width: 7), // 14rpx
                            Text('基金名称/代码', style: AppTextStyles.cn(11, color: const Color(0xFFB5AAA5), height: 1.0)), // 22rpx
                          ],
                        ),
                        const SizedBox(height: 6), // 12rpx
                        Text(
                          item.name,
                          style: AppTextStyles.cn(13, color: const Color(0xFF2F2A28), height: 1.2), // 26rpx
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10), // 20rpx
                // 指标 + 操作
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricBlock('持有金额', _formatMoneyText(item.amount), const Color(0xFF2E2A29), isSmall),
                    SizedBox(width: isSmall ? 9 : 14), // 18rpx / 28rpx
                    _buildMetricBlock('持有收益', _formatProfitText(item.holding), _profitColor(item.holding), isSmall),
                    SizedBox(width: isSmall ? 9 : 14),
                    Padding(
                      padding: const EdgeInsets.only(left: 4), // 8rpx
                      child: Column(
                        children: [
                          _buildCircleBtn('×', const Color(0xFFB8AAA4), const Color(0xFFF7F3F1),
                              const Color(0xCCD5CCC7), () => _handleRemove(item.key), 17), // rgba(213,204,199,0.8)
                          const SizedBox(height: 8), // 16rpx
                          _buildCircleBtn('✎', const Color(0xFFB79B52), const Color(0xFFFBF7ED),
                              const Color(0xB8D8C590), () => _startEdit(item), 16), // rgba(216,197,144,0.72)
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (editing) ...[
            const SizedBox(height: 10), // 20rpx gap
            _buildEditPanel(item),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBlock(String label, String value, Color valueColor, bool isSmall) {
    return Container(
      constraints: BoxConstraints(minWidth: isSmall ? 53 : 62), // 106rpx / 124rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: AppTextStyles.cn(11, color: const Color(0xFF9B928D), height: 1.0)), // 22rpx
          const SizedBox(height: 7), // 14rpx
          // DIN Alternate → AppTextStyles.num
          Text(value, style: AppTextStyles.num(isSmall ? 16 : 15, color: valueColor, height: 1.0)), // 32rpx / 30rpx
        ],
      ),
    );
  }

  Widget _buildCircleBtn(String text, Color color, Color bg, Color borderColor, VoidCallback onTap, double fontSize) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 22, height: 22, // 44rpx
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color, height: 1.0),
        ),
      ),
    );
  }

  Widget _buildEditPanel(_OcrItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 11, right: 11, top: 13, bottom: 12), // 26rpx 22rpx 24rpx
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(11)), // 22rpx
        border: Border(top: BorderSide(color: Color(0xE6EBE7E4), width: 0.5)), // rgba(235,231,228,0.9)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 11), // 22rpx
            child: Text('手动修改', style: AppTextStyles.cn(15, color: const Color(0xFF2F2A28))), // 30rpx
          ),
          // 基金选择
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _handlePickFund(item.key),
            child: Container(
              height: 43, // 86rpx
              margin: const EdgeInsets.only(bottom: 10), // 20rpx
              padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FA),
                borderRadius: BorderRadius.circular(7), // 14rpx
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editForm.name.isNotEmpty ? _editForm.name : '请选择基金',
                      style: AppTextStyles.cn(14,
                          color: _editForm.name.isNotEmpty ? const Color(0xFF222533) : const Color(0xFF9BA0AD)), // 28rpx
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6), // 12rpx
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90), // 180rpx
                    child: Text(
                      _editForm.showCode.isNotEmpty ? _editForm.showCode : '点击搜索',
                      style: AppTextStyles.cn(12, color: const Color(0xFF9BA0AD)), // 24rpx
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 15, color: Color(0xFFB7B7BB)),
                ],
              ),
            ),
          ),
          // 持有金额
          _buildEditValueInput(
            text: _editForm.amount.isNotEmpty ? _editForm.amount : '持有金额',
            placeholder: _editForm.amount.isEmpty,
            active: _activeKeyboardField == 'amount',
            onTap: () => _openNumberKeyboard('amount'),
          ),
          // 持有收益
          _buildEditValueInput(
            text: _editForm.holding.isNotEmpty ? _editForm.holding : '持有收益',
            placeholder: _editForm.holding.isEmpty,
            active: _activeKeyboardField == 'holding',
            onTap: () => _openNumberKeyboard('holding'),
          ),
          // 操作行
          Padding(
            padding: const EdgeInsets.only(top: 4), // 8rpx
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _saveEdit(item.key),
                  child: Row(
                    children: [
                      Text('保存修改并收起',
                          style: AppTextStyles.cn(14, color: const Color(0xFFD7A61F), weight: FontWeight.w600, height: 22 / 14)), // 28rpx / 44rpx
                      const SizedBox(width: 5), // 10rpx
                      const Icon(Icons.keyboard_arrow_up, size: 14, color: Color(0xFFD7A61F)),
                    ],
                  ),
                ),
                const SizedBox(width: 16), // 32rpx
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _cancelEdit,
                  child: Text('取消', style: AppTextStyles.cn(13, color: const Color(0xFF9B928D), height: 22 / 13)), // 26rpx
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditValueInput({
    required String text,
    required bool placeholder,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 43,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: active ? const Color(0xFF4167F1) : Colors.transparent, width: 1), // 2rpx
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: AppTextStyles.cn(14, color: placeholder ? const Color(0xFF9BA0AD) : const Color(0xFF222533)),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}

// 带索引 map (避免引入 collection 包)
extension _MapIndexed<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(MapEntry<int, E>) f) {
    var i = 0;
    return map((e) => f(MapEntry(i++, e)));
  }
}
