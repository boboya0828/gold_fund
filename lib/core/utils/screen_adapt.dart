/// 屏幕自适应 — 对齐 uni-app rpx 的换算（750rpx = 屏宽）
///
/// 原约定 rpx÷2=px 只在 375pt 逻辑宽下精确；设备逻辑宽 ≠375 时整页会系统性偏差
/// （如 393pt 手机上小 4.8%）。统一改为：rpx÷2 基准值 × [SA.scale]（随屏宽动态变化）。
///
/// 用法：
/// - 尺寸：`width: 150.sx`（即 300rpx 在任意屏宽下的实际 px）
/// - 字号：`AppTextStyles.cn(15.sx, ...)`（AppTextStyles 内部不改，未迁移页面不受影响）
/// - 不缩放的例外：MediaQuery 的 viewPadding/padding（状态栏等设备真实 px）、
///   0.5px 物理最小分隔线
library;

/// 全局缩放系数（默认 1.0：widget 测试不初始化时行为与旧约定一致）
class SA {
  SA._();

  /// 当前缩放系数 = 逻辑屏宽 / 375（375 为设计稿逻辑宽 pt）
  static double scale = 1.0;

  /// 小屏兜底：低于该宽度按该宽度算（防止超小屏缩得不可读）
  static const double minWidth = 320;

  /// 按屏宽更新系数（在 app 根部 builder 调用；web 拖窗口随 MediaQuery 变化生效）
  static void update(double logicalWidth) {
    final w = logicalWidth < minWidth ? minWidth : logicalWidth;
    scale = w / 375;
  }

  /// rpx÷2 基准值 → 当前屏宽下的实际 px
  static double x(num v) => v * scale;
}

/// 便捷扩展：`16.sx` / `10.5.sx`
extension SxNum on num {
  /// rpx÷2 基准值 → 当前屏宽实际 px
  double get sx => SA.x(this);
}
