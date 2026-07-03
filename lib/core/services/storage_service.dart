import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

/// 本地存储服务 - 封装 SharedPreferences + Hive
/// SharedPreferences: token, user info, theme preference (简单 KV)
/// Hive: 首页缓存, 表格配置, 用户偏好设置 (结构化数据)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // ===== SharedPreferences Keys (匹配 uni-app uni.getStorageSync 的 key) =====
  static const _tokenKey = 'token';
  static const _userInfoKey = 'userInfo';
  static const _skinModeKey = 'appSkinMode';
  static const _privacyKey = 'APP_PRIVACY_ACCEPTED';
  static const _channelKey = 'APP_CHANNEL';
  static const _updateSkipKey = 'APP_UPDATE_SKIP_VERSION_CODE';

  // ===== Hive Box Names =====
  static const _homeCacheBox = 'homeCache';
  static const _tableConfigBox = 'tableConfig';
  static const _userPrefsBox = 'userPreferences';

  late final Box _homeCacheBoxInstance;
  late final Box _tableConfigBoxInstance;
  late final Box _userPrefsBoxInstance;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _homeCacheBoxInstance = await Hive.openBox(_homeCacheBox);
    _tableConfigBoxInstance = await Hive.openBox(_tableConfigBox);
    _userPrefsBoxInstance = await Hive.openBox(_userPrefsBox);
    _initialized = true;
  }

  // ===== Token 管理 =====
  Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ===== 用户信息 =====
  Future<Map<String, dynamic>?> get userInfo async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_userInfoKey);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  Future<void> setUserInfo(Map<String, dynamic> info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userInfoKey, jsonEncode(info));
  }

  // ===== 主题 =====
  Future<String> get skinMode async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_skinModeKey) ?? 'light';
  }

  Future<void> setSkinMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skinModeKey, mode);
  }

  // ===== 隐私协议 =====
  Future<bool> get hasAcceptedPrivacy async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_privacyKey) ?? false;
  }

  Future<void> setPrivacyAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyKey, true);
  }

  // ===== 渠道 =====
  Future<String?> get channel async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_channelKey);
  }

  // ===== 更新跳过版本 =====
  Future<int> get updateSkipVersion async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_updateSkipKey) ?? 0;
  }

  Future<void> setUpdateSkipVersion(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_updateSkipKey, versionCode);
  }

  // ===== Hive: 首页缓存 =====
  dynamic getHomeCache(String key) {
    return _homeCacheBoxInstance.get(key);
  }

  Future<void> setHomeCache(String key, dynamic value) async {
    await _homeCacheBoxInstance.put(key, value);
  }

  // ===== Hive: 表格配置 =====
  dynamic getTableConfig(String key) {
    return _tableConfigBoxInstance.get(key);
  }

  Future<void> setTableConfig(String key, dynamic value) async {
    await _tableConfigBoxInstance.put(key, value);
  }

  // ===== Hive: 用户偏好 =====
  dynamic getUserPreference(String key) {
    return _userPrefsBoxInstance.get(key);
  }

  Future<void> setUserPreference(String key, dynamic value) async {
    await _userPrefsBoxInstance.put(key, value);
  }
}
