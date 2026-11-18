/// 个股/基金详情切换列表 — 1:1 复刻 uni-app utils/stock-switch-list.js
///
/// 模块级内存暂存（不落盘）：列表页进入详情页时 setStockSwitchList 拿到 token，
/// 详情页用 getStockSwitchList(token) 校验（token 必须等于模块内最新 token，
/// 否则返回 []，会被其它入口覆盖）。
library;

List<int> _switchList = [];
int _token = 0;

/// 写入切换列表并返回 token
int setStockSwitchList(List<int> symbolIds) {
  _switchList = List<int>.from(symbolIds);
  _token = DateTime.now().millisecondsSinceEpoch;
  return _token;
}

/// 读取切换列表：token 不符（被其它入口覆盖）返回 []
List<int> getStockSwitchList(String token) {
  if (token.isEmpty || token != '$_token') return const [];
  return List<int>.from(_switchList);
}
