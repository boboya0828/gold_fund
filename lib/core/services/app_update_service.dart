import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';

/// 归一化后的更新信息 - 对齐 uni-app app-update.js normalizeAppUpdateInfo
class AppUpdateInfo {
  final bool hasUpdate;
  final bool forceUpdate;
  final String versionName;
  final int versionCode;
  final String title;
  final String description;
  final List<String> updateList;
  final String downloadUrl; // Android 优先
  final String storeUrl;
  final String appStoreUrl; // iOS 优先

  const AppUpdateInfo({
    required this.hasUpdate,
    this.forceUpdate = false,
    this.versionName = '',
    this.versionCode = 0,
    this.title = '发现新版本',
    this.description = '本次更新优化了使用体验，建议升级后使用。',
    this.updateList = const [],
    this.downloadUrl = '',
    this.storeUrl = '',
    this.appStoreUrl = '',
  });
}

/// App 更新服务 - 对齐 uni-app utils/app-update.js
///
/// 说明：uni-app 的 WGT 热更新依赖 plus.runtime，属 uni-app 专有，
/// Flutter 端不适用；此处仅实现"版本检查 + 打开下载/商店地址"这条通用路径。
class AppUpdateService {
  AppUpdateService._();

  static const _skipVersionCodeKey = 'APP_UPDATE_SKIP_VERSION_CODE';
  static const _skipUntilKey = 'APP_UPDATE_SKIP_UNTIL';
  static const _skipDurationMs = 24 * 60 * 60 * 1000;

  static final ApiClient _api = ApiClient();

  /// 构建版本检查入参 - 对齐 buildAppVersionCheckPayload
  static Future<Map<String, dynamic>> _buildPayload() async {
    final info = await PackageInfo.fromPlatform();
    final platform = _platform();
    return {
      'platform': platform,
      'channel': platform == 'ios' ? 'appstore' : 'official',
      'packageName': info.packageName,
      'versionName': info.version,
      'versionCode': int.tryParse(info.buildNumber) ?? 0,
      'device': '',
    };
  }

  static String _platform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'unknown';
    }
  }

  /// 请求版本检查接口并归一化
  static Future<AppUpdateInfo> checkUpdate() async {
    final payload = await _buildPayload();
    final res = await _api.post(ApiEndpoints.checkAppVersion, data: payload);
    return _normalize(res.data, payload);
  }

  static AppUpdateInfo _normalize(dynamic response, Map<String, dynamic> current) {
    Map data = {};
    if (response is Map) {
      data = response.containsKey('code') ? (response['data'] as Map? ?? {}) : response;
    }

    final latestVersionCode = _toInt(data['versionCode'] ?? data['latestVersionCode']);
    final latestVersionName =
        (data['versionName'] ?? data['latestVersionName'] ?? data['latestVersion'] ?? '').toString();
    final currentVersionCode = _toInt(current['versionCode']);
    final currentVersionName = (current['versionName'] ?? '').toString();

    final hasByCode = latestVersionCode > 0 && latestVersionCode > currentVersionCode;
    final hasByName = _isNewerVersionName(latestVersionName, currentVersionName);
    final explicit = data['hasUpdate'] ?? data['needUpdate'] ?? data['update'];
    final hasUpdate = explicit != null ? explicit == true : (hasByCode || hasByName);

    return AppUpdateInfo(
      hasUpdate: hasUpdate,
      forceUpdate: (data['forceUpdate'] ?? data['force'] ?? data['isForceUpdate'] ?? data['isForce']) == true,
      versionName: latestVersionName.isNotEmpty ? latestVersionName : currentVersionName,
      versionCode: latestVersionCode,
      title: (data['title'] ?? '发现新版本').toString(),
      description:
          (data['description'] ?? data['desc'] ?? data['updateDesc'] ?? '本次更新优化了使用体验，建议升级后使用。').toString(),
      updateList: _normalizeList(data['content'] ?? data['updateList'] ?? data['releaseNotes']),
      downloadUrl: (data['downloadUrl'] ?? data['marketUrl'] ?? data['storeUrl'] ?? data['apkUrl'] ?? data['url'] ?? '')
          .toString(),
      storeUrl: (data['storeUrl'] ?? data['marketUrl'] ?? '').toString(),
      appStoreUrl: (data['appStoreUrl'] ?? data['iosUrl'] ?? '').toString(),
    );
  }

  /// 打开更新地址 - 对齐 openAppUpdateUrl（iOS 优先 appStore，Android 优先下载/商店）
  static Future<bool> openUpdateUrl(AppUpdateInfo info) async {
    final isIos = _platform() == 'ios';
    final url = isIos
        ? (info.appStoreUrl.isNotEmpty ? info.appStoreUrl : (info.storeUrl.isNotEmpty ? info.storeUrl : info.downloadUrl))
        : (info.downloadUrl.isNotEmpty ? info.downloadUrl : (info.storeUrl.isNotEmpty ? info.storeUrl : info.appStoreUrl));

    if (url.isEmpty) return false;

    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {
      // 走下方复制降级
    }
    await Clipboard.setData(ClipboardData(text: url));
    return false;
  }

  // ===== 24h 跳过（非强制更新时可用） =====
  static Future<bool> shouldSkip(AppUpdateInfo info) async {
    if (info.forceUpdate) return false;
    final p = await SharedPreferences.getInstance();
    final skipCode = p.getString(_skipVersionCodeKey);
    final skipUntil = p.getInt(_skipUntilKey) ?? 0;
    return skipCode == '${info.versionCode}' && DateTime.now().millisecondsSinceEpoch < skipUntil;
  }

  static Future<void> markSkipped(AppUpdateInfo info) async {
    if (info.versionCode == 0) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_skipVersionCodeKey, '${info.versionCode}');
    await p.setInt(_skipUntilKey, DateTime.now().millisecondsSinceEpoch + _skipDurationMs);
  }

  // ===== helpers =====
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static bool _isNewerVersionName(String latest, String current) {
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = l.length > c.length ? l.length : c.length;
    for (var i = 0; i < len; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  static List<String> _normalizeList(dynamic value) {
    if (value is List) {
      return value.where((e) => e != null).map((e) => e.toString()).toList();
    }
    if (value is String) {
      return value
          .split(RegExp(r'\||\r?\n|；|;'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }
}
