import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// 批量上传 — COS 直传 + OCR 识别管线
/// uni-app 对应: pages/index/fund/upload/mass-upload.vue 中的
/// uploadToCos / recognizeImage / getFileExt / normalizeOcrResultList / processBackendImage
class MassUploadCosUploader {
  MassUploadCosUploader();

  final ApiClient _api = ApiClient();

  /// COS 直传用独立 Dio (不带 baseUrl / Auth 拦截器)
  late final Dio _cosDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));

  /// uni-app getFileExt — 取文件后缀, 默认 .jpg
  static String getFileExt(String filePath) {
    final cleanPath = filePath.split('?').first;
    final match = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(cleanPath);
    return match != null ? '.${match.group(1)!.toLowerCase()}' : '.jpg';
  }

  /// uni-app normalizeOcrResultList — 兼容 {data:[...]} / [...] 两种返回
  static List<dynamic> normalizeOcrResultList(dynamic payload) {
    if (payload is Map && payload['data'] is List) return payload['data'] as List;
    if (payload is List) return payload;
    return const [];
  }

  /// uni-app uploadToCos — POST Object 表单上传, 返回文件 URL
  Future<String> uploadToCos(String filePath, Map<String, dynamic> signData) async {
    final cosHost = signData['cosHost']?.toString() ?? '';
    final key = signData['key']?.toString() ?? '';
    final uploadUrl = 'https://$cosHost/';
    final fileUrl = 'https://$cosHost/$key';

    final formData = FormData.fromMap({
      'key': key,
      'policy': signData['policy']?.toString() ?? '',
      'q-sign-algorithm': signData['qSignAlgorithm']?.toString() ?? '',
      'q-ak': signData['qAk']?.toString() ?? '',
      'q-key-time': signData['qKeyTime']?.toString() ?? '',
      'q-signature': signData['signature']?.toString() ?? '',
      'Content-Type': 'image/jpeg',
      'file': await MultipartFile.fromFile(filePath),
    });

    final res = await _cosDio.post<dynamic>(uploadUrl, data: formData);
    final code = res.statusCode ?? 0;
    if (code == 200 || code == 204) return fileUrl;
    throw Exception('上传失败: $code');
  }

  /// uni-app recognizeImage — 调用后端 OCR 识别
  Future<dynamic> recognizeImage(String fileUrl) async {
    final res = await _api.post(ApiEndpoints.assetOcrPic, data: {'imageUrl': fileUrl});
    final body = res.data;
    return body is Map ? (body['data'] ?? body) : body;
  }

  /// uni-app processBackendImage — 单张图: 取签名 → 上传 COS → OCR
  /// (图片压缩已在 image_picker 选图阶段通过 imageQuality 完成)
  Future<List<dynamic>> processBackendImage(String filePath) async {
    // 每张图单独获取 OCR 表单上传签名, 避免 COS key 重复
    final signRes = await _api.get(
      ApiEndpoints.userOcrSignForm,
      queryParameters: {'ext': getFileExt(filePath)},
    );
    final body = signRes.data;
    final signData = body is Map ? (body['data'] ?? body) : null;
    if (signData is! Map<String, dynamic>) {
      throw Exception('获取上传签名失败');
    }
    final fileUrl = await uploadToCos(filePath, signData);
    final ocrData = await recognizeImage(fileUrl);
    return normalizeOcrResultList(ocrData);
  }
}
