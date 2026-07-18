import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// 头像上传 — 1:1 复刻 uni-app utils/obs-upload.js 的 OBS 表单直传
/// 流程: getUploadSign → OBS 表单 POST（AccessKeyId；400 时回退 AWSAccessKeyId）
///       → updateAvatar 回写头像 URL
class ProfileAvatarUploader {
  ProfileAvatarUploader();

  final ApiClient _api = ApiClient();

  /// OBS 直传用独立 Dio（不带 baseUrl / Auth 拦截器）
  late final Dio _obsDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));

  /// uni-app normalizeObsSignatureData 的保留字段
  static const _reservedKeys = [
    'action', 'uploadUrl', 'accessKeyId', 'AccessKeyId',
    'key', 'policy', 'signature', 'acl', 'expires',
  ];

  /// 上传头像并回写用户资料，返回头像 URL
  Future<String> uploadAvatar(XFile file) async {
    final signRes = await _api.get(ApiEndpoints.uploadSign);
    final sign = _normalizeObsSign(signRes.data);
    final bytes = await file.readAsBytes();
    final url = await _uploadToObs(bytes, file.name, sign);
    // uni-app profile.vue: await updateAvatar({ avatarUrl: uploadRes.url })
    await _api.put(ApiEndpoints.updateAvatar, data: {'avatarUrl': url});
    return url;
  }

  /// uni-app normalizeObsSignatureData
  Map<String, dynamic> _normalizeObsSign(dynamic response) {
    final body = response is Map ? response : const {};
    final data = body['data'] is Map ? body['data'] as Map : body;
    final extra = <String, String>{};
    data.forEach((k, v) {
      final key = k.toString();
      if (_reservedKeys.contains(key)) return;
      if (v == null || v == '') return;
      extra[key] = v.toString();
    });
    return <String, dynamic>{
      'action': (data['action'] ?? data['uploadUrl'] ?? '').toString(),
      'accessKeyId': (data['accessKeyId'] ?? data['AccessKeyId'] ?? '').toString(),
      'key': (data['key'] ?? '').toString(),
      'policy': (data['policy'] ?? '').toString(),
      'signature': (data['signature'] ?? '').toString(),
      'acl': (data['acl'] ?? '').toString(),
      'extra': extra,
    };
  }

  /// uni-app uploadFileToObs：主表单失败且符合回退条件时换 AWSAccessKeyId 重试
  Future<String> _uploadToObs(List<int> bytes, String filename, Map<String, dynamic> sign) async {
    final action = sign['action'] as String;
    final accessKeyId = sign['accessKeyId'] as String;
    final key = sign['key'] as String;
    final policy = sign['policy'] as String;
    final signature = sign['signature'] as String;
    final acl = sign['acl'] as String;
    final extra = sign['extra'] as Map<String, String>;

    if (bytes.isEmpty) throw Exception('缺少待上传文件');
    if (action.isEmpty || accessKeyId.isEmpty || key.isEmpty || policy.isEmpty || signature.isEmpty) {
      throw Exception('OBS 上传签名参数不完整');
    }

    Map<String, dynamic> fields(String akField) => <String, dynamic>{
          akField: accessKeyId,
          'key': key,
          'policy': policy,
          'signature': signature,
          if (acl.isNotEmpty) 'acl': acl,
          ...extra,
        };

    try {
      await _postForm(action, bytes, filename, fields('AccessKeyId'));
    } on DioException catch (primary) {
      final msg = _errorText(primary);
      // uni-app: 签名类错误直接抛，不回退
      if (msg.contains('InvalidAccessKeyId') ||
          msg.contains('SignatureDoesNotMatch') ||
          msg.contains('AccessDenied')) {
        rethrow;
      }
      final code = primary.response?.statusCode ?? 0;
      if (code != 400 && !msg.contains('InvalidArgument') && !msg.contains('MalformedPOSTRequest')) {
        rethrow;
      }
      // 回退 AWSAccessKeyId 字段名重试一次
      await _postForm(action, bytes, filename, fields('AWSAccessKeyId'));
    }

    // uni-app buildObsPublicUrl
    final base = action.replaceAll(RegExp(r'/+$'), '');
    final objectKey = key.replaceAll(RegExp(r'^/+'), '');
    return '$base/$objectKey';
  }

  Future<void> _postForm(String action, List<int> bytes, String filename, Map<String, dynamic> fields) async {
    final formData = FormData.fromMap(<String, dynamic>{
      ...fields,
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _obsDio.post<dynamic>(action, data: formData);
    final code = res.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'OBS 上传失败，状态码：$code',
      );
    }
  }

  /// uni-app parseObsXmlError：从 XML 响应提取错误信息
  String _errorText(DioException e) {
    final data = e.response?.data;
    return data?.toString() ?? e.message ?? '';
  }
}
