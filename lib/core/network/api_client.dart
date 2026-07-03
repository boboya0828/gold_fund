import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_endpoints.dart';

/// API 客户端 - 封装 Dio 实例，匹配 uni-app api/req.js 的行为
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
    ));

    dio.interceptors.add(AuthInterceptor());
    dio.interceptors.add(ErrorInterceptor());
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[API] $obj'),
    ));
  }

  /// 便捷 GET 请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return dio.get<T>(path, queryParameters: queryParameters);
  }

  /// 便捷 POST 请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
  }) {
    return dio.post<T>(path, data: data);
  }

  /// 便捷 PUT 请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) {
    return dio.put<T>(path, data: data);
  }

  /// 便捷 DELETE 请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
  }) {
    return dio.delete<T>(path, data: data);
  }
}

/// 认证拦截器 - 自动添加 Bearer token，匹配 req.js 的行为
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// 错误拦截器 - 处理 401 重定向、网络错误等，匹配 req.js 的行为
class ErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final code = response.statusCode ?? 0;
    final data = response.data;

    if (code == 401) {
      // 401 未授权 → 清除 token 并触发登录重定向
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('token');
      });
      // 通过事件总线通知 UI 层跳转登录
      print('[API] 401 Unauthorized - redirect to login');
    }

    if (data is Map && data['code'] != null) {
      final apiCode = data['code'];
      if (apiCode == 200 || apiCode == 0) {
        // 成功
        handler.next(response);
      } else {
        // 业务错误，仍然传递但标记
        handler.next(response);
      }
    } else {
      handler.next(response);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final message = err.message ?? '';

    // 检测网络不可用
    final isNetworkUnavailable = _networkUnavailablePatterns.any(
      (pattern) => message.contains(pattern),
    );

    if (isNetworkUnavailable) {
      print('[API] Network unavailable, silently handled: $message');
    } else if (_isSslError(message)) {
      print('[API] SSL certificate error: $message');
    } else {
      print('[API] Request failed: $message');
    }

    handler.next(err);
  }

  static const _networkUnavailablePatterns = [
    '-1009',
    'statusCode:-1',
    'request:fail abort',
    '断开与互联网的连接',
    'Internet connection appears to be offline',
    'Connection refused',
    'Network is unreachable',
  ];

  static bool _isSslError(String message) {
    const patterns = [
      '2300060',
      'Invalid SSL peer certificate',
      'SSL peer certificate',
      'HandshakeException',
      'CERTIFICATE_VERIFY_FAILED',
    ];
    return patterns.any((p) => message.contains(p));
  }
}
