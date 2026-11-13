import 'package:flutter/material.dart';
import '../../shared/widgets/custom_nav_bar.dart';

/// 攒金 — 对应 uni-app pages/noblemetal/index
/// TODO: 1:1 复刻原页面内容，当前为占位页
class NobleMetalPage extends StatelessWidget {
  const NobleMetalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomNavBar(title: '攒金', showBack: false),
      body: Center(child: Text('攒金')),
    );
  }
}
