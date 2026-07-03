import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 全局文字样式 — 确保思源黑体和 DIN 字体总是被正确应用
class AppTextStyles {
  AppTextStyles._();

  // 直接字面量避免 static const 可能导致的 Web 端加载时序问题
  static const String _cn = 'siyuanheitiCNRegular';
  static const String _num = 'DIN';

  // ===== 中文字体 (siyuanheitiCNRegular) =====
  static TextStyle cn(double size, {Color? color, FontWeight? weight, double? height}) {
    return TextStyle(
      fontFamily: _cn,
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
    );
  }

  // ===== 数字字体 (DIN) =====
  static TextStyle num(double size, {Color? color, FontWeight? weight, double? height}) {
    return TextStyle(
      fontFamily: _num,
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height ?? 1.0,
    );
  }

  // ===== 常用预设 =====
  // 标题 (32rpx=16px)
  static TextStyle get headerTitle => cn(16, color: AppColors.lightText, weight: FontWeight.bold);
  // 卡片标题 (28rpx=14px)
  static TextStyle get cardTitle => cn(14, color: AppColors.lightText, weight: FontWeight.w600);
  // 正文 (24rpx=12px)
  static TextStyle get body => cn(12, height: 1.0);
  // 次要文字 (20rpx=10px)
  static TextStyle get caption => cn(10);
  // 大数字 (46rpx=23px)
  static TextStyle get bigNumber => num(23, color: AppColors.lightText);
  // 中数字 (22rpx=11px)
  static TextStyle get mediumNumber => num(11, weight: FontWeight.w600);
  // 小数字 (19rpx=9.5px)
  static TextStyle get smallNumber => num(9.5, color: AppColors.fundItemPrice);
}
