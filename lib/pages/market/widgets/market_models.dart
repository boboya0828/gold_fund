import 'package:flutter/material.dart';

/// 行情页数据模型与共享常量 — 1:1 复刻 zdj-v1 pages/market/index.vue

/// 本页跌/绿色（源码 $color-green: #00ADA0），明暗主题同色（源码无 dark 覆盖）。
const Color kMarketDownColor = Color(0xFF00ADA0);

/// 热门指数卡片（.quote-card）
class QuoteCardData {
  final String symbolId, name, price, change, rate, trend;
  const QuoteCardData({
    required this.symbolId,
    required this.name,
    required this.price,
    required this.change,
    required this.rate,
    required this.trend,
  });
}

/// 涨跌分布柱条（.distribution-item），type: up / down / flat
class DistItem {
  final String label, type;
  final int value, height;
  const DistItem({
    required this.label,
    required this.value,
    required this.height,
    required this.type,
  });
}

/// 板块收益排行行（.sector-row）
class SectorRankItem {
  final int rank;
  final String name, rate, symbolId, trend;
  const SectorRankItem({
    required this.rank,
    required this.name,
    required this.rate,
    required this.symbolId,
    required this.trend,
  });
}

/// 基金自选榜单行（.sector-row.fund-row）
class FundRankItemData {
  final int rank;
  final String name, code, symbolId, netValue, rate, trend;
  const FundRankItemData({
    required this.rank,
    required this.name,
    required this.code,
    required this.symbolId,
    required this.netValue,
    required this.rate,
    required this.trend,
  });
}

/// formatRank: String(rank).padStart(2, '0')
String formatRankNo(int rank) => rank.toString().padLeft(2, '0');

/// rankColorClass: top1 #ee9f1c / top2 #8e8e98 / top3 #d28d5f / 其他 #191919(暗 #D7DAE0)
Color marketRankColor(int rank, bool isDark) {
  switch (rank) {
    case 1:
      return const Color(0xFFEE9F1C);
    case 2:
      return const Color(0xFF8E8E98);
    case 3:
      return const Color(0xFFD28D5F);
    default:
      return isDark ? const Color(0xFFD7DAE0) : const Color(0xFF191919);
  }
}
