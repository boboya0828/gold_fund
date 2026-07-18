import 'package:flutter/material.dart';
import '../../../theme/text_styles.dart';

/// 闭眼模式选择弹窗 — 1:1 复刻 .asset-visible-panel
/// uni-app assetVisible: 0=全部显示, 1=隐藏持有金额, 2=再隐藏收益金额,
/// 3=再隐藏持有收益率, 4=再隐藏基金名称；底部「显示全部」= 0。
class PositionAssetVisibleDialog extends StatelessWidget {
  final int currentLevel;
  final bool isDark;

  const PositionAssetVisibleDialog({
    super.key,
    required this.currentLevel,
    required this.isDark,
  });

  /// 弹出并返回选中的级别 (null = 未选择/点遮罩关闭)
  static Future<int?> show(
    BuildContext context, {
    required int currentLevel,
    required bool isDark,
  }) {
    return showDialog<int>(
      context: context,
      // 源码 .asset-visible-mask: light rgba(39,26,19,0.28) / dark rgba(0,0,0,0.48)
      barrierColor: isDark
          ? Colors.black.withAlpha(122)
          : const Color(0x48271A13),
      builder: (_) => PositionAssetVisibleDialog(
        currentLevel: currentLevel,
        isDark: isDark,
      ),
    );
  }

  static const _options = [
    (level: 1, title: '模式一', tags: ['仅隐藏【持有金额】']),
    (level: 2, title: '模式二', tags: ['隐藏【持有金额】', '【收益金额】']),
    (level: 3, title: '模式三', tags: ['隐藏【持有金额】', '【收益金额】', '【持有收益率】']),
    (level: 4, title: '模式四', tags: ['隐藏【持有金额】', '【收益金额】', '【持有收益率】', '【基金名称】']),
  ];

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark
        ? const Color(0xFFD7DAE0)
        : const Color(0xFF111111);
    final optionTitleColor = isDark
        ? const Color(0xFFE4E7ED)
        : const Color(0xFF111111);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 310, // max-width 620rpx
          margin: const EdgeInsets.symmetric(horizontal: 16), // mask padding 32rpx
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 9), // 24rpx 24rpx 18rpx
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202125) : Colors.white,
            borderRadius: BorderRadius.circular(9), // 18rpx
            boxShadow: [
              BoxShadow(
                // light 0 16rpx 42rpx rgba(69,32,8,0.16) / dark 0 18rpx 50rpx rgba(0,0,0,0.36)
                color: isDark
                    ? Colors.black.withAlpha(92)
                    : const Color(0x29452008),
                blurRadius: isDark ? 25 : 21,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '闭眼模式选择',
                style: AppTextStyles.cn(
                  14, // 28rpx
                  color: titleColor,
                  weight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 11), // margin-top 22rpx
              for (final opt in _options) ...[
                _option(
                  context,
                  level: opt.level,
                  title: opt.title,
                  tags: opt.tags,
                  titleColor: optionTitleColor,
                ),
                if (opt.level != _options.last.level)
                  const SizedBox(height: 6), // gap 12rpx
              ],
              // 显示全部
              GestureDetector(
                onTap: () => Navigator.pop(context, 0),
                child: Container(
                  margin: const EdgeInsets.only(top: 8), // 16rpx
                  height: 25, // 50rpx
                  alignment: Alignment.center,
                  child: Text(
                    '显示全部',
                    style: AppTextStyles.cn(
                      12, // 24rpx
                      color: const Color(0xFFE05665),
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required int level,
    required String title,
    required List<String> tags,
    required Color titleColor,
  }) {
    final active = currentLevel == level;
    return GestureDetector(
      onTap: () => Navigator.pop(context, level),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 9), // 20rpx 22rpx 18rpx
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0x1FE05665) : const Color(0xFFFFF3F4))
              : (isDark ? const Color(0xFF282828) : const Color(0xFFFFFDFD)),
          border: Border.all(
            width: 0.5, // 1rpx
            color: active
                ? (isDark
                    ? const Color(0x94E05665) // rgba(224,86,101,0.58)
                    : const Color(0x73E05665)) // rgba(224,86,101,0.45)
                : (isDark
                    ? const Color(0xFF2B2D33)
                    : const Color(0xFFF2E4E0)),
          ),
          borderRadius: BorderRadius.circular(6), // 12rpx
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: active
                        ? const Color(0x1AE05665) // rgba(224,86,101,0.1)
                        : const Color(0x0D452008), // rgba(69,32,8,0.05)
                    blurRadius: active ? 10 : 9,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.cn(
                12.5, // 25rpx
                color: titleColor,
                weight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 7), // margin-top 14rpx
            Wrap(
              spacing: 2, // gap 4rpx
              runSpacing: 3, // row-gap 6rpx (>3 个标签时换行)
              children: [
                for (final tag in tags) _tag(tag),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      height: 16, // min-height 32rpx
      padding: const EdgeInsets.symmetric(horizontal: 4), // 0 8rpx
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0x29E05665) // rgba(224,86,101,0.16)
            : const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(3.5), // 7rpx
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppTextStyles.cn(
          9.5, // 19rpx
          color: isDark ? const Color(0xFFEF6672) : const Color(0xFFA95B50),
          weight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
