import 'package:flutter/material.dart';
import '../../shared/widgets/custom_nav_bar.dart';

/// 暗盘 — 对应 uni-app pages/market/dark-market
/// TODO: 1:1 复刻原页面内容，当前为占位页
class DarkMarketPage extends StatelessWidget {
  const DarkMarketPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomNavBar(title: '暗盘', showBack: false),
      body: Center(child: Text('暗盘')),
    );
  }
}
