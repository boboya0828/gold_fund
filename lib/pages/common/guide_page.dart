import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 引导页 — 1:1 复刻 uni-app pages/guide/index.vue
///
/// 3 张轮播图（每张上下两张图片），最后一页点击"进入App"：
///   写入 hasSeenGuide → 进入首页。
/// 平台专有能力（未实现）：uni.preloadPage 预加载 Tab 页。
class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  // 与 uni-app 保持一致的存储 key
  static const _seenGuideKey = 'hasSeenGuide';

  // 对齐 guideList（注意源码中 image/image1 的配对顺序）
  static const _guideList = [
    _GuideItem('assets/images/guide/tabbg2.png', 'assets/images/guide/tabbg1.png'),
    _GuideItem('assets/images/guide/tabbg3.png', 'assets/images/guide/tabbg4.png'),
    _GuideItem('assets/images/guide/tabbg6.png', 'assets/images/guide/tabbg5.png'),
  ];

  bool get _isLastPage => _currentIndex == _guideList.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 对齐 handleNext：最后一页写标志位进首页，否则翻到下一页
  Future<void> _handleNext() async {
    if (_isLastPage) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenGuideKey, true);
      if (!mounted) return;
      context.go('/home'); // uni.switchTab → /pages/index/index
    } else {
      await _controller.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // linear-gradient(164deg, #FFF1ED 0%, #FFFFFF 100%)
          gradient: LinearGradient(
            begin: const Alignment(-0.28, -0.96),
            end: const Alignment(0.28, 0.96),
            colors: isDark
                ? const [Color(0xFF241A1C), AppColors.darkBg]
                : const [Color(0xFFFFF1ED), Color(0xFFFFFFFF)],
          ),
        ),
        child: Column(children: [
          // 图片轮播（flex: 1）
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _guideList.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) => _buildItem(_guideList[index]),
            ),
          ),
          // 底部按钮区域：padding 0 40rpx calc(60rpx + safe-area-inset-bottom)
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 30 + bottomInset),
            child: _buildActionButton(),
          ),
        ]),
      ),
    );
  }

  Widget _buildItem(_GuideItem item) {
    // FittedBox(scaleDown)：标准屏 1:1 渲染，小屏整体缩小避免溢出
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30), // 60rpx
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _guideImage(item.image),
          const SizedBox(height: 40), // 80rpx
          _guideImage(item.image1),
          const SizedBox(height: 40), // 80rpx（源码两张图均带 margin-bottom）
        ]),
      ),
    );
  }

  Widget _guideImage(String asset) {
    return Image.asset(
      asset,
      width: 300, // 600rpx
      height: 300,
      fit: BoxFit.contain, // mode="aspectFit"
      errorBuilder: (context, error, stackTrace) {
        debugPrint('引导页图片加载失败: $asset'); // 对齐 onImageError
        return const SizedBox(width: 300, height: 300);
      },
    );
  }

  Widget _buildActionButton() {
    return GestureDetector(
      onTap: _handleNext,
      child: Container(
        width: double.infinity,
        height: 44, // 88rpx
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22), // 44rpx
          // btn-enter: linear-gradient(135deg, #E05665 0%, #ff7b8a 100%)
          gradient: _isLastPage
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.upColor, Color(0xFFFF7B8A)],
                )
              : null,
          color: _isLastPage ? null : AppColors.upColor, // #E05665
          // btn-enter: box-shadow 0 8rpx 30rpx rgba(224,86,101,0.4)
          boxShadow: _isLastPage
              ? const [
                  BoxShadow(
                    color: Color(0x66E05665),
                    offset: Offset(0, 4),
                    blurRadius: 15,
                  ),
                ]
              : null,
        ),
        child: Text(
          _isLastPage ? '进入App' : '下一页',
          style: AppTextStyles.cn(16, // 32rpx
              color: Colors.white, weight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _GuideItem {
  final String image;
  final String image1;
  const _GuideItem(this.image, this.image1);
}
