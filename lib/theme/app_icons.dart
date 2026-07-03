/// 自定义 iconfont 图标 — 1:1 复刻 zdj static/fonts/iconfont.css
/// 使用方式: Icon(AppIcons.search, size: 20, color: ...)
library;

import 'package:flutter/widgets.dart';

/// 应用自定义图标 (iconfont.ttf, family: 'iconfont')
class AppIcons {
  AppIcons._();

  static const _family = 'iconfont';

  // ---- 导航/通用 ----
  /// 搜索 icon-sousuo \e61f
  static const search = IconData(0xe61f, fontFamily: _family);
  /// 添加 icon-tianjia \e607
  static const add = IconData(0xe607, fontFamily: _family);
  /// 设置 icon-shezhi \e733
  static const settings = IconData(0xe733, fontFamily: _family);
  /// 更多 icon-gengduo \e61c
  static const more = IconData(0xe61c, fontFamily: _family);
  /// 通知 icon-tongzhi \e64a
  static const notification = IconData(0xe64a, fontFamily: _family);

  // ---- 快捷菜单 ----
  /// 复制页面 icon-fuzhiyemian \e772
  static const copyPage = IconData(0xe772, fontFamily: _family);
  /// 统计 icon-tongji \e609
  static const statistics = IconData(0xe609, fontFamily: _family);

  // ---- 切换/模式 ----
  /// 切换 icon-qiehuan1 \e656
  static const switchIcon = IconData(0xe656, fontFamily: _family);
  /// 切换2 icon-qiehuan \e61a
  static const switch2 = IconData(0xe61a, fontFamily: _family);

  // ---- 图片/输入 ----
  /// 相册 icon-xiangce-xianxing \e7bf
  static const gallery = IconData(0xe7bf, fontFamily: _family);
  /// 手动输入 icon-shoudongshuru \e608
  static const manualInput = IconData(0xe608, fontFamily: _family);

  // ---- 交易 ----
  /// 买入 icon-mairu \e660
  static const buy = IconData(0xe660, fontFamily: _family);
  /// 卖出 icon-maichu \e661
  static const sell = IconData(0xe661, fontFamily: _family);

  // ---- 奖牌 ----
  /// 金牌 icon-jinpai \e709
  static const goldMedal = IconData(0xe709, fontFamily: _family);
  /// 银牌 icon-yinpai \e70a
  static const silverMedal = IconData(0xe70a, fontFamily: _family);
  /// 铜牌 icon-tongpai \e600
  static const bronzeMedal = IconData(0xe600, fontFamily: _family);

  // ---- 弹幕 ----
  /// 开启弹幕 icon-meiti_kaiqidanmu \e6b9
  static const danmakuOn = IconData(0xe6b9, fontFamily: _family);
  /// 关闭弹幕 icon-guanbidanmu \eb72
  static const danmakuOff = IconData(0xeb72, fontFamily: _family);

  // ---- 其他 ----
  /// 记录 icon-jilu \e69f
  static const record = IconData(0xe69f, fontFamily: _family);
  /// 简洁模式 icon-jianjiemoshi \e6cc
  static const simpleMode = IconData(0xe6cc, fontFamily: _family);
  /// 添加(变体) icon-tianjia1 \e62c
  static const addAlt = IconData(0xe62c, fontFamily: _family);
  /// 添加成功 icon-tianjiachenggong \e670
  static const addSuccess = IconData(0xe670, fontFamily: _family);
}
