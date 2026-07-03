import 'package:flutter/material.dart';

/// 应用颜色常量 — 精确匹配 uni-app 的设计规范
///
/// rpx → px 换算: rpx / 2 = px (375px 设计宽度)
class AppColors {
  AppColors._();

  // ===== 主色 =====
  static const primary = Color(0xFFE15665);       // uni-app --app-primary
  static const primaryRed = Color(0xFFE15665);     // 同 primary

  // ===== 涨跌色 =====
  static const upColor = Color(0xFFE05665);        // 涨（红）1:1 uni-app is-up
  static const downColor = Color(0xFF31B87A);      // 跌（绿）light 1:1 uni-app is-down
  static const downColorDark = Color(0xFF20B979);  // 跌（绿）dark
  static const fundRateDefault = Color(0xFFff4b52); // 基金涨跌幅默认红

  // ===== 浅色模式 =====
  static const lightBg = Color(0xFFFAF7F7);        // 全局背景
  static const homeBg = Color(0xFFFCFCFC);          // 首页背景
  static const lightSurface = Color(0xFFFFFFFF);    // 卡片表面
  static const lightText = Color(0xFF333333);       // 主文字 --app-text
  static const lightTextSecondary = Color(0xFF999999);  // 次文字 --app-text-muted
  static const lightGoldText = Color(0xFFA59085);   // 资产标签色
  static const lightRollUpBg = Color(0xFFFCF6F6);   // 行情涨背景
  static const lightRollDownBg = Color(0xFFF4FAFB); // 行情跌背景
  static const lightBorder = Color(0x0D000000);     // --app-border rgba(0,0,0,0.05)

  // ===== 深色模式 =====
  static const darkBg = Color(0xFF111315);          // 全局背景/首页背景
  static const darkSurface = Color(0xFF202125);     // 卡片表面
  static const darkText = Color(0xFFD7DAE0);        // 主文字
  static const darkTextSecondary = Color(0xFFA7ADB8); // 次文字
  static const darkTabBg = Color(0xFF111315);       // TabBar 深色背景

  // ===== 通用 =====
  static const white = Colors.white;

  // ===== TabBar =====
  static const tabBarBgLight = Color(0xF2FFFFFF); // rgba(255,255,255,0.95)
  static const tabActiveColor = Color(0xFFE05665); // 深色激活文字色 (.custom-tabbar--dark .tab-text.active)
  static const tabActiveColorLight = Color(0xFFE60012); // 浅色激活文字色 (.tab-text.active)
  static const tabInactiveColor = Color(0xFF999999);
  static const tabInactiveDark = Color(0xFF8F96A3);
  static const tabBorderLight = Color(0x0D000000);
  static const tabBorderDark = Color(0x0FFFFFFF);

  // ===== 通用边框/分割线 =====
  static const darkBorder = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)

  // ===== 资产卡片 =====
  static const assetGradientStart = Color(0xFFFFFBF2); // 渐变起
  static const assetGradientEnd = Color(0xFFFFE5DE);   // 渐变止
  static const assetDivider = Color(0x73D7C3B8);       // rgba(215,195,184,0.45)
  static const assetDividerDark = Color(0xFF2B2D33);   // 深色分割线
  static const assetEmptyBtn = Color(0xFFE45A67);      // 空状态按钮
  static const profitTagUp = Color(0xFFE05665);        // 收益标签涨背景
  static const profitTagDown = Color(0xFF2BC7B4);      // 收益标签跌背景
  static const profitTagHidden = Color(0xFFA59085);    // 收益标签隐藏态

  // ===== 基金卡片 =====
  static const fundUpGradientStart = Color(0xFFFFF8F7);
  static const fundUpGradientEnd = Color(0xFFFDF4F2);
  static const fundDownGradientStart = Color(0xFFF7FCFF);
  static const fundDownGradientEnd = Color(0xFFF2F8FC);
  static const fundCodeBg = Color(0xFFd8ebff);          // 基金代码标签背景
  static const fundCodeText = Color(0xFF2d7dff);        // 基金代码标签文字
  static const fundCodeBgDark = Color(0xFF282828);      // 深色
  static const fundCodeTextDark = Color(0xFFA7ADB8);    // 深色
  static const fundItemTitle = Color(0xFF303030);       // 基金标题
  static const fundItemName = Color(0xFF1f1f1f);        // 基金名称
  static const fundItemPrice = Color(0xFF353535);       // 基金价格

  // ===== 金/银卡片 =====
  static const metalName = Color(0xFF222222);           // 金/银名称
  static const metalPrice = Color(0xFF111111);          // 金/银价格
  static const metalUpBgLight = Color(0xFFfff1f4);      // 涨标签背景
  static const metalDownBgLight = Color(0xFFeef8f6);    // 跌标签背景
  static const metalUpBgDark = Color(0xFF2A1E23);       // 涨标签背景（深色）
  static const metalDownBgDark = Color(0xFF1C2827);     // 跌标签背景（深色）

  // ===== 公告 =====
  static const noticeBg = Color(0xFFfff3e6);
  static const noticeBorder = Color(0xFFf4ddc4);
  static const noticeText = Color(0xFF9a6840);
  static const noticeIcon = Color(0xFFb78255);
  static const noticeClose = Color(0xFFb99678);

  // ===== 账本菜单 =====
  static const menuBgDark = Color(0xFF282B32);
  static const menuShadowLight = Color(0x1F212121);    // rgba(33,33,33,0.12)
  static const menuShadowDark = Color(0x52000000);     // rgba(0,0,0,0.32)
  static const menuItemBorder = Color(0xFFEEF0F4);
  static const menuItemBorderDark = Color(0xFF3A3E48);

  // ===== 分割线 =====
  static const cardDivider = Color(0xFFF0F0F0);
  static const darkDivider = Color(0xFF2C2C2E);

  // ===== 空状态 =====
  static const emptyIconBg = Color(0xFFFFF1F3);        // #FFF1F3
  static const emptyIconBgDark = Color(0xFF282828);

  // ===== 动画背景色 =====
  // 浅色模式闪烁
  static const flashUpStart = Color(0x05FF4144);       // rgba(255,65,68,.02)
  static const flashUpPeak = Color(0x14FF4144);        // rgba(255,65,68,.08)
  static const flashDownStart = Color(0x051DB270);     // rgba(29,178,112,.02)
  static const flashDownPeak = Color(0x141DB270);      // rgba(29,178,112,.08)
  // 深色模式闪烁
  static const flashUpStartDark = Color(0xFF322329);
  static const flashUpPeakDark = Color(0xFF3B2930);
  static const flashDownStartDark = Color(0xFF22302E);
  static const flashDownPeakDark = Color(0xFF293A37);
}
