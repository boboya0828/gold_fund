import 'dart:math';

import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../theme/text_styles.dart';
import '../../../core/utils/screen_adapt.dart';
import '../../position/position_provider_types.dart' show BookItem;

/// 移动分组弹框 — 1:1 复刻 .move-group-*（index.vue:425-448 结构）
/// 遮罩 rgba(0,0,0,0.5) + 居中面板（宽 600rpx、圆角 24rpx）：
/// 标题「移动到如下账户」+ 账本单选列表 + 「原账户保留该基金」复选框 + 取消/确定
class PositionMoveGroupDialog extends StatefulWidget {
  final bool isDark;
  final List<int> assetIds; // 移动的资产 id 列表（单个传 [assetId]）
  final int sourceBookId;
  final List<BookItem> books; // 候选账本（已排除源账本）
  final bool initialKeepSource;

  const PositionMoveGroupDialog({
    super.key,
    required this.isDark,
    required this.assetIds,
    required this.sourceBookId,
    required this.books,
    this.initialKeepSource = true,
  });

  /// 打开移动分组弹框；提交成功返回 MoveGroupResult（含 keepSource 供页面决定本地移除策略）
  static Future<MoveGroupResult?> show(
    BuildContext context, {
    required bool isDark,
    required List<int> assetIds,
    required int sourceBookId,
    required List<BookItem> books,
  }) {
    return showGeneralDialog<MoveGroupResult>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '移动分组',
      barrierColor: const Color(0x80000000), // rgba(0,0,0,0.5)
      pageBuilder: (context, _, _) => Center(
        child: PositionMoveGroupDialog(
          isDark: isDark,
          assetIds: assetIds,
          sourceBookId: sourceBookId,
          books: books,
        ),
      ),
    );
  }

  @override
  State<PositionMoveGroupDialog> createState() =>
      _PositionMoveGroupDialogState();
}

/// 移动分组提交结果
class MoveGroupResult {
  final bool moved;
  final bool keepSource;
  const MoveGroupResult({required this.moved, required this.keepSource});
}

class _PositionMoveGroupDialogState extends State<PositionMoveGroupDialog> {
  int? _targetBookId;
  late bool _keepSource = widget.initialKeepSource;
  bool _submitting = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// 1:1 uni-app createMoveRequestId（`move_${Date.now().toString(36)}_${random.toString(36).slice(2,10)}`）
  String _createMoveRequestId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rand = Random().nextInt(0x7fffffff).toRadixString(36);
    final randPadded = '${rand}00000000'.substring(0, 8);
    return 'move_${ts}_$randPadded';
  }

  /// 1:1 uni-app confirmMoveGroup
  Future<void> _confirm() async {
    if (_submitting) return;
    final target = _targetBookId;
    if (target == null) {
      _toast('请选择目标账户');
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ApiClient().post(
        ApiEndpoints.assetFundsMove,
        data: {
          'sourceBookId': widget.sourceBookId,
          'targetBookId': target,
          'assetIds': widget.assetIds,
          'keepSource': _keepSource,
          'requestId': _createMoveRequestId(),
        },
      );
      final code = res.data?['code'] as int?;
      if (code != 200) {
        throw Exception('${res.data?['message'] ?? '移动分组失败'}');
      }
      if (!mounted) return;
      _toast(_keepSource ? '已复制到目标账户' : '已移动到目标账户');
      Navigator.of(context)
          .pop(MoveGroupResult(moved: true, keepSource: _keepSource));
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString().replaceFirst('Exception: ', ''));
      setState(() => _submitting = false);
    }
  }

  void _close() {
    if (_submitting) return; // 提交中禁止关闭（1:1 closeMoveGroupModal）
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final panelBg = isDark ? const Color(0xFF282828) : Colors.white;
    final titleColor = isDark ? const Color(0xFFD7DAE0) : const Color(0xFF333333);
    final nameColor = titleColor;
    final radioBorder = isDark ? const Color(0xFF4A4D55) : const Color(0xFFC9CDD4);
    final keepBg = isDark ? const Color(0xFF202125) : const Color(0xFFFFF4F0);
    final dividerColor = isDark ? const Color(0xFF3A3D45) : const Color(0xFFF0F0F0);
    final cancelColor = isDark ? const Color(0xFFA7ADB8) : const Color(0xFF666666);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300.sx, // 600rpx
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(12.sx), // 24rpx
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // .move-group-title
          Padding(
            padding: EdgeInsets.only(top: 18.sx, bottom: 12.sx), // 36rpx 0 24rpx
            child: Text(
              '移动到如下账户',
              style: AppTextStyles.cn(16.sx,
                  color: titleColor, weight: FontWeight.w600), // 32rpx 600
            ),
          ),
          // .move-group-list（max-height 480rpx，超出滚动）
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 240.sx),
            child: widget.books.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.sx), // 40rpx 0
                    child: Text(
                      '暂无其他账户',
                      style:
                          AppTextStyles.cn(13.sx, color: const Color(0xFF999999)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(horizontal: 24.sx), // 0 48rpx
                    itemCount: widget.books.length,
                    itemBuilder: (context, i) {
                      final book = widget.books[i];
                      final active = _targetBookId == book.bookId;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _targetBookId = book.bookId),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14.sx), // 28rpx 0
                          child: Row(children: [
                            // .move-group-radio（--active: border 10rpx #E05665）
                            Container(
                              width: 16.sx, // 32rpx
                              height: 16.sx,
                              margin: EdgeInsets.only(right: 10.sx), // 20rpx
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: active
                                      ? const Color(0xFFE05665)
                                      : radioBorder,
                                  width: active ? 5.sx : 1, // 10rpx / 2rpx
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                book.bookName,
                                style: AppTextStyles.cn(15.sx,
                                    color: nameColor), // 30rpx
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          // .move-group-keep「原账户保留该基金」
          GestureDetector(
            onTap: () => setState(() => _keepSource = !_keepSource),
            child: Container(
              color: keepBg,
              padding: EdgeInsets.symmetric(
                  horizontal: 24.sx, vertical: 14.sx), // 28rpx 48rpx
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                // .move-group-checkbox（--active 红底 + 白勾 checkmarkempty size 12）
                Container(
                  width: 16.sx, // 32rpx
                  height: 16.sx,
                  margin: EdgeInsets.only(right: 8.sx), // 16rpx
                  decoration: BoxDecoration(
                    color: _keepSource
                        ? const Color(0xFFE05665)
                        : (isDark ? const Color(0xFF202125) : Colors.white),
                    borderRadius: BorderRadius.circular(3.sx), // 6rpx
                    border: Border.all(
                      color: _keepSource
                          ? const Color(0xFFE05665)
                          : radioBorder,
                      width: 1, // 2rpx
                    ),
                  ),
                  child: _keepSource
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                Text(
                  '原账户保留该基金',
                  style: AppTextStyles.cn(14.sx, color: titleColor), // 28rpx
                ),
              ]),
            ),
          ),
          // .move-group-footer：上边框 1rpx #F0F0F0（深 #3A3D45）
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: dividerColor, width: 0.5)),
            ),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _close,
                  child: Container(
                    height: 48.sx, // 96rpx
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(color: dividerColor, width: 0.5)),
                    ),
                    child: Text(
                      '取消',
                      style: AppTextStyles.cn(15.sx, color: cancelColor), // 30rpx
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _submitting ? null : _confirm,
                  child: Opacity(
                    opacity: _submitting ? 0.6 : 1, // --disabled
                    child: SizedBox(
                      height: 48.sx,
                      child: Center(
                        child: Text(
                          _submitting ? '提交中...' : '确定',
                          style: AppTextStyles.cn(15.sx,
                              color: const Color(0xFFE05665),
                              weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
