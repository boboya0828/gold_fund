import 'package:flutter/material.dart';

import '../../core/services/app_update_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// 更新弹窗 - 1:1 复刻 uni-app components/UpdatePopup.vue (基准: zdj-v1)
///
/// vue 版弹窗为固定浅色设计（无深色变体），明暗主题下表现一致：
/// 宽 600rpx=300；linear-gradient(0deg, #FFF → #FEF0F0) 自下而上渐变；
/// 圆角 20rpx=10；2rpx=1 白色描边；顶部 tzico 图标 114rpx=57，上移 50rpx=25 与弹窗交叠。
class UpdatePopup extends StatelessWidget {
  final AppUpdateInfo info;

  const UpdatePopup({super.key, required this.info});

  /// 便捷方法：弹出更新弹窗（:mask-click="!forceUpdate"）
  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdatePopup(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    const red = AppColors.upColor; // #E05665
    return PopScope(
      canPop: !info.forceUpdate,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: 300, // 600rpx
              margin: const EdgeInsets.only(top: 25), // 图标上移 50rpx=25
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter, // linear-gradient(0deg, ...)
                  end: Alignment.topCenter,
                  colors: [Colors.white, Color(0xFFFEF0F0)],
                ),
                borderRadius: BorderRadius.circular(10), // 20rpx
                border: Border.all(color: Colors.white, width: 1), // 2rpx
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // 图标侵占区 (114-50)rpx=32 + .update-title margin-top 18rpx=9
                const SizedBox(height: 41),
                Text(
                  info.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cn(20, color: const Color(0xFF222222), weight: FontWeight.bold, height: 1.2),
                ),
                if (info.versionName.isNotEmpty) ...[
                  const SizedBox(height: 7), // .update-version margin-top 14rpx
                  Text('V${info.versionName}', style: AppTextStyles.cn(13, color: red)),
                ],
                // .update-content: margin 34rpx 42rpx 0, padding 28rpx, radius 18rpx,
                // bg rgba(255,255,255,0.72), max-height 330rpx=165
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(21, 17, 21, 0),
                  padding: const EdgeInsets.all(14),
                  constraints: const BoxConstraints(maxHeight: 165),
                  decoration: BoxDecoration(
                    color: const Color(0xB8FFFFFF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  // vue: 有更新列表时只显示列表，否则显示 description
                  child: info.updateList.isEmpty
                      ? Text(info.description, style: AppTextStyles.cn(14, color: const Color(0xFF555555), height: 1.5))
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 110), // scroll-view 220rpx
                          child: SingleChildScrollView(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              for (var i = 0; i < info.updateList.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(top: i == 0 ? 0 : 8), // .update-item margin-top 16rpx，首项 0
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Container(
                                      width: 5, // 10rpx
                                      height: 5,
                                      margin: const EdgeInsets.only(top: 7, right: 7), // 14rpx
                                      decoration: const BoxDecoration(color: red, shape: BoxShape.circle),
                                    ),
                                    Expanded(
                                      child: Text(info.updateList[i],
                                          style: AppTextStyles.cn(13, color: const Color(0xFF333333), height: 19 / 13)),
                                    ),
                                  ]),
                                ),
                            ]),
                          ),
                        ),
                ),
                // .update-actions: margin 46rpx 42rpx 40rpx
                Padding(
                  padding: const EdgeInsets.fromLTRB(21, 23, 21, 20),
                  child: info.forceUpdate
                      ? _primaryButton(context, fullWidth: true)
                      : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          _ghostButton(context),
                          _primaryButton(context),
                        ]),
                ),
              ]),
            ),
            // .update-icon image 114rpx=57，margin-top:-50rpx 与弹窗交叠
            Positioned(
              top: 0,
              child: Image.asset('assets/images/img/tzico.png', width: 57, height: 57),
            ),
          ],
        ),
      ),
    );
  }

  /// 稍后再说 - .update-btn--ghost (248rpx=124 宽, 84rpx=42 高, 1rpx=0.5 描边, 圆角 42rpx=21)
  Widget _ghostButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // vue handleCancel → markAppUpdateSkipped（24h 内跳过该版本）
        await AppUpdateService.markSkipped(info);
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Container(
        width: 124,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.upColor, width: 0.5),
          borderRadius: BorderRadius.circular(21),
        ),
        child: Text('稍后再说', style: AppTextStyles.cn(15, color: AppColors.upColor)),
      ),
    );
  }

  /// 立即更新 - .update-btn--primary / .update-btn--full（强制更新时整行宽）
  Widget _primaryButton(BuildContext context, {bool fullWidth = false}) {
    return GestureDetector(
      onTap: () => _handleConfirm(context),
      child: Container(
        width: fullWidth ? double.infinity : 124,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.upColor,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Text('立即更新', style: AppTextStyles.cn(15, color: Colors.white)),
      ),
    );
  }

  /// vue handleConfirm → openAppUpdateUrl。
  /// 未配置地址：toast '未配置更新地址' 且弹窗保持打开；非强制更新确认后关闭弹窗。
  Future<void> _handleConfirm(BuildContext context) async {
    final hasUrl = info.downloadUrl.isNotEmpty || info.storeUrl.isNotEmpty || info.appStoreUrl.isNotEmpty;
    if (!hasUrl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未配置更新地址'), duration: Duration(seconds: 2)),
      );
      return;
    }
    final ok = await AppUpdateService.openUpdateUrl(info);
    if (!context.mounted) return;
    if (!ok) {
      // 无法打开时降级为复制地址（对齐 uni-app 非 plus 环境的剪贴板降级提示）
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新地址已复制'), duration: Duration(seconds: 2)),
      );
    }
    if (!info.forceUpdate) Navigator.of(context).pop();
  }
}
