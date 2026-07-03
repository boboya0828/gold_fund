/// 用户相关模型
class UserInfo {
  final int id;
  final String? nickname;
  final String? avatarUrl;
  final String? phoneNumber;
  final bool hasWechat;
  final String? wechatNickname;
  final bool isVip;
  final DateTime? vipExpireAt;

  const UserInfo({
    required this.id,
    this.nickname,
    this.avatarUrl,
    this.phoneNumber,
    this.hasWechat = false,
    this.wechatNickname,
    this.isVip = false,
    this.vipExpireAt,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] as int? ?? 0,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      hasWechat: json['hasWechat'] as bool? ?? false,
      wechatNickname: json['wechatNickname'] as String?,
      isVip: json['isVip'] as bool? ?? false,
      vipExpireAt: json['vipExpireAt'] != null
          ? DateTime.tryParse(json['vipExpireAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
    'phoneNumber': phoneNumber,
    'hasWechat': hasWechat,
    'wechatNickname': wechatNickname,
    'isVip': isVip,
    'vipExpireAt': vipExpireAt?.toIso8601String(),
  };

  UserInfo copyWith({
    int? id,
    String? nickname,
    String? avatarUrl,
    String? phoneNumber,
    bool? hasWechat,
    String? wechatNickname,
    bool? isVip,
    DateTime? vipExpireAt,
  }) {
    return UserInfo(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      hasWechat: hasWechat ?? this.hasWechat,
      wechatNickname: wechatNickname ?? this.wechatNickname,
      isVip: isVip ?? this.isVip,
      vipExpireAt: vipExpireAt ?? this.vipExpireAt,
    );
  }
}

/// 登录响应
class LoginResponse {
  final String token;
  final UserInfo user;

  const LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String? ?? '',
      user: UserInfo.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// 短信验证码请求
class SendSmsCodeRequest {
  final String phoneNumber;
  final String captchaId;
  final String captchaAnswer;

  const SendSmsCodeRequest({
    required this.phoneNumber,
    required this.captchaId,
    required this.captchaAnswer,
  });

  Map<String, dynamic> toJson() => {
    'phoneNumber': phoneNumber,
    'captchaId': captchaId,
    'captchaAnswer': captchaAnswer,
  };
}

/// 手机号登录请求
class PhoneLoginRequest {
  final String phoneNumber;
  final String smsCode;

  const PhoneLoginRequest({
    required this.phoneNumber,
    required this.smsCode,
  });

  Map<String, dynamic> toJson() => {
    'phoneNumber': phoneNumber,
    'smsCode': smsCode,
  };
}

/// 密码登录请求
class PasswordLoginRequest {
  final String account;
  final String password;

  const PasswordLoginRequest({
    required this.account,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'account': account,
    'password': password,
  };
}
