import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../shared/widgets/custom_nav_bar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/text_styles.dart';
import 'mass_upload_cos_uploader.dart';

/// 批量上传入口页 — 1:1 复刻 uni-app (zdj-v1/pages/index/fund/upload/mass-upload.vue)
/// 上传交易记录截图 → 压缩 → COS 直传 → OCR 识别 → 跳 OCR 结果页
class MassUploadPage extends StatefulWidget {
  /// 对应 uni-app onLoad options.bookId
  final String? bookId;
  const MassUploadPage({super.key, this.bookId});

  @override
  State<MassUploadPage> createState() => _MassUploadPageState();
}

class _MassUploadPageState extends State<MassUploadPage> {
  static const _banners = [
    'assets/images/banner/cbanner1.png',
    'assets/images/banner/cbanner2.png',
    'assets/images/banner/cbanner3.png',
    'assets/images/banner/cbanner4.png',
    'assets/images/banner/cbanner5.png',
    'assets/images/banner/cbanner6.png',
    'assets/images/banner/cbanner7.png',
  ];

  final MassUploadCosUploader _uploader = MassUploadCosUploader();
  final ImagePicker _picker = ImagePicker();
  late final PageController _bannerCtrl;
  Timer? _bannerTimer;

  bool _uploading = false;
  String _loadingText = '';
  int _bannerIndex = 0;

  bool get _hasBookId => widget.bookId != null && widget.bookId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // swiper autoplay circular interval=3000 duration=500
    _bannerCtrl = PageController(initialPage: _banners.length * 1000);
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_bannerCtrl.hasClients) return;
      _bannerCtrl.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    super.dispose();
  }

  // ===== 权限 (对应 chooseImageWithTip: 相册/存储权限) =====
  Future<bool> _ensurePhotoPermission() async {
    var status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;
    status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;
    // Android 12 及以下走旧存储模型 (READ_EXTERNAL_STORAGE)
    var storage = await Permission.storage.status;
    if (storage.isGranted) return true;
    storage = await Permission.storage.request();
    if (storage.isGranted) return true;
    if (mounted && (status.isPermanentlyDenied || storage.isPermanentlyDenied)) {
      _showPermissionDialog();
    } else if (mounted) {
      _toast('未获得相册访问权限');
    }
    return false;
  }

  /// 权限用途说明 (对应 permission-tip.js 的 title/content 文案)
  void _showPermissionDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('相册/存储权限使用说明'),
        content: const Text('用于上传交易凭证，需访问相册以选择本地图片并进行识别上传。仅在您主动选择图片时使用。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  // ===== 选图 + OCR (对应 chooseAndRecognizeImages / handleUpload) =====
  Future<void> _handleUpload() async {
    if (_uploading) return;
    if (!await _ensurePhotoPermission()) return;

    // uni.chooseImage({count:4, sizeType:['compressed'], sourceType:['album']})
    // + uni.compressImage(quality:10) → image_picker 选图阶段压缩
    final files = await _picker.pickMultiImage(imageQuality: 10, limit: 4);
    final filePaths = files.map((f) => f.path).where((p) => p.isNotEmpty).toList();
    if (filePaths.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final resultList = <dynamic>[];
      for (var index = 0; index < filePaths.length; index += 1) {
        if (mounted) setState(() => _loadingText = '识别中 ${index + 1}/${filePaths.length}');
        final imageResult = await _uploader.processBackendImage(filePaths[index]);
        resultList.addAll(imageResult);
      }
      if (resultList.isEmpty) {
        _toast('未识别到基金记录');
        return;
      }
      // 对应 rlist = { data: resultList } → ocrResult?data=&bookId=
      final rlist = jsonEncode({'data': resultList});
      final query = [
        'data=${Uri.encodeComponent(rlist)}',
        if (_hasBookId) 'bookId=${Uri.encodeComponent(widget.bookId!)}',
      ].join('&');
      if (mounted) context.push('/fund/upload/ocr-result?$query');
    } catch (error) {
      // 对应 uni.showToast({ title: error.message || '上传图片失败' })
      final msg = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _toast(msg.isNotEmpty ? msg : '上传图片失败');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _loadingText = '';
        });
      }
    }
  }

  /// 对应 navToManualInput
  void _navToManualInput() {
    if (_hasBookId) {
      context.push('/fund/upload/madd?bookId=${Uri.encodeComponent(widget.bookId!)}');
    } else {
      context.push('/fund/upload/add-records');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F5F5);
    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        Column(children: [
          CustomNavBar(
            title: '养基助手',
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            titleColor: isDark ? AppColors.darkText : const Color(0xFF333333),
          ),
          Expanded(
            // page-content: padding 28rpx 40rpx 120rpx, 垂直居中
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 60),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 74),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBannerSection(isDark),
                      const SizedBox(height: 27), // 54rpx
                      _buildActionGroup(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
        // uni.showLoading({mask:true}) 等价遮罩
        if (_uploading) _buildLoadingOverlay(isDark),
      ]),
    );
  }

  Widget _buildBannerSection(bool isDark) {
    return Column(children: [
      Text(
        '上传交易记录截图即可批量同步基金数据',
        textAlign: TextAlign.center,
        style: AppTextStyles.cn(14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB7ADB0), height: 1.6),
      ),
      const SizedBox(height: 12), // 24rpx
      SizedBox(
        height: 400, // 800rpx
        child: PageView.builder(
          controller: _bannerCtrl,
          onPageChanged: (i) => setState(() => _bannerIndex = i % _banners.length),
          itemBuilder: (context, i) => Center(
            child: Image.asset(
              _banners[i % _banners.length],
              width: 215, // 430rpx
              height: 400,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      const SizedBox(height: 9), // 18rpx
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_banners.length, (index) {
          final active = _bannerIndex == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3), // gap 12rpx
            width: active ? 14 : 5, // 28rpx / 10rpx
            height: 5,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.upColor
                  : (isDark ? const Color(0xFF3A3E48) : const Color(0xFFD8D4DF)),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
      const SizedBox(height: 11), // 22rpx
      Text(
        '请按示意上传持仓截图',
        textAlign: TextAlign.center,
        style: AppTextStyles.cn(16, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9893A1), height: 1.5),
      ),
    ]);
  }

  Widget _buildActionGroup(bool isDark) {
    return FractionallySizedBox(
      widthFactor: 0.8,
      child: Column(children: [
        // action-btn-primary: 去相册选择
        GestureDetector(
          onTap: _handleUpload,
          child: Container(
            width: double.infinity,
            height: 48, // 96rpx
            decoration: BoxDecoration(
              color: AppColors.upColor,
              borderRadius: BorderRadius.circular(5), // 10rpx
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0x33E05665) // rgba(224,86,101,.2)
                      : const Color(0x29E15665), // rgba(225,86,101,.16)
                  offset: const Offset(0, 8), // 16rpx
                  blurRadius: 16, // 32rpx
                ),
              ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(AppIcons.gallery, size: 24, color: Colors.white),
              const SizedBox(width: 7), // 14rpx
              Text(
                _uploading ? '处理中...' : '去相册选择',
                style: AppTextStyles.cn(16, color: Colors.white, weight: FontWeight.w500),
              ),
              const SizedBox(width: 5), // 10rpx
              const Icon(Icons.chevron_right, size: 18, color: Colors.white),
            ]),
          ),
        ),
        const SizedBox(height: 12), // 24rpx
        // action-btn-secondary: 手动输入
        GestureDetector(
          onTap: _navToManualInput,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF282828) : const Color(0x1AE05665),
              borderRadius: BorderRadius.circular(5),
              boxShadow: isDark
                  ? const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 6), blurRadius: 14)]
                  : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(AppIcons.manualInput, size: 20, color: AppColors.upColor),
              const SizedBox(width: 7),
              Text('手动输入', style: AppTextStyles.cn(16, color: AppColors.upColor, weight: FontWeight.w500)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildLoadingOverlay(bool isDark) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.upColor),
            ),
            if (_loadingText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _loadingText,
                style: AppTextStyles.cn(13, color: isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
