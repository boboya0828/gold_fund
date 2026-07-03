import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/models/user.dart';
import '../../../core/services/signalr_service.dart';

/// 认证状态
class AuthState {
  final String? token;
  final UserInfo? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  const AuthState({
    this.token,
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    String? token,
    UserInfo? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      token: token ?? this.token,
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 认证 Provider - 匹配 uni-app 的登录流程
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api = ApiClient();
  final SignalRService _signalR = SignalRService();

  AuthNotifier() : super(const AuthState()) {
    _initFromStorage();
  }

  /// 从本地存储恢复登录状态
  Future<void> _initFromStorage() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        // 用 token 获取用户信息
        final response = await _api.get(ApiEndpoints.getCurrentUser);
        final data = response.data as Map<String, dynamic>;
        if (data['code'] == 200) {
          final user = UserInfo.fromJson(data['data'] as Map<String, dynamic>);
          state = state.copyWith(
            token: token,
            user: user,
            isAuthenticated: true,
            isLoading: false,
            clearError: true,
          );
          // 连接 SignalR
          _signalR.connect();
          return;
        }
      }
      // Token 无效或不存在
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 微信登录
  Future<bool> wechatLogin(String code, {String? appId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final path = appId != null
          ? '${ApiEndpoints.wechatLogin}?code=$code&appId=$appId'
          : '${ApiEndpoints.wechatLogin}?code=$code';
      final response = await _api.get(path);
      final data = response.data as Map<String, dynamic>;

      if (data['code'] == 200) {
        return _handleLoginResponse(data['data'] as Map<String, dynamic>);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: data['message'] as String? ?? '微信登录失败',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '网络请求失败: $e',
      );
      return false;
    }
  }

  /// 手机号 + 验证码登录
  Future<bool> phoneLogin(String phoneNumber, String smsCode) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.post(
        ApiEndpoints.phoneLogin,
        // uni-app 实际发送 key="code" (非 smsCode)
        data: {'phoneNumber': phoneNumber, 'code': smsCode},
      );
      final data = response.data as Map<String, dynamic>;

      if (data['code'] == 200) {
        return _handleLoginResponse(data['data'] as Map<String, dynamic>);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: data['message'] as String? ?? '登录失败',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '网络请求失败');
      return false;
    }
  }

  /// 密码登录 — 1:1 复刻 uni-app getLoginPayload()
  Future<bool> passwordLogin(String account, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.post(
        ApiEndpoints.login,
        // uni-app 发送 4 个字段: account, username, phoneNumber, password
        data: {
          'account': account,
          'username': account,
          'phoneNumber': account,
          'password': password,
        },
      );
      final data = response.data as Map<String, dynamic>;

      if (data['code'] == 200) {
        return _handleLoginResponse(data['data'] as Map<String, dynamic>);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: data['message'] as String? ?? '登录失败',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '网络请求失败');
      return false;
    }
  }

  /// 发送短信验证码
  Future<bool> sendSmsCode(String phoneNumber, String captchaId, String captchaAnswer) async {
    try {
      final response = await _api.post(
        ApiEndpoints.sendSmsCode,
        data: {
          'phoneNumber': phoneNumber,
          'captchaId': captchaId,
          'captchaAnswer': captchaAnswer,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200 || data['code'] == 0;
    } catch (e) {
      return false;
    }
  }

  /// 获取人机验证码
  Future<String?> generateCaptcha() async {
    try {
      final response = await _api.get(ApiEndpoints.generateCaptcha);
      final data = response.data as Map<String, dynamic>;
      if (data['code'] == 200) {
        return data['data'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// 登出
  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.logout);
    } catch (_) {}
    // 清除本地存储
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    // 断开 SignalR
    await _signalR.disconnect();
    // 重置状态
    state = const AuthState();
  }

  /// 处理登录响应（保存 token + 用户信息）
  Future<bool> _handleLoginResponse(Map<String, dynamic> loginData) async {
    final token = loginData['token'] as String? ?? '';
    final userJson = loginData['user'] as Map<String, dynamic>?;
    final user = userJson != null ? UserInfo.fromJson(userJson) : null;

    if (token.isEmpty) {
      state = state.copyWith(isLoading: false, error: '登录失败：未获取到 token');
      return false;
    }

    // 持久化 token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);

    // 更新状态
    state = state.copyWith(
      token: token,
      user: user,
      isAuthenticated: true,
      isLoading: false,
      clearError: true,
    );

    // 连接 SignalR
    _signalR.connect();

    return true;
  }
}

/// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
