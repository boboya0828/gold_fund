# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在本仓库中工作时提供指导。

## 项目简介

养基助手 (yangji_zhushou) — 一款基金投资管理应用。这个 Flutter 应用是对现有 uni-app（Vue 3）产品的**1:1 迁移**；几乎每个页面都是对某个 `.vue` 页面的忠实重建。uni-app 源码位于本仓库之外（只读参考）：

- `F:\Work\zdj` — **主/最新版**uni-app 源码 (v1.0.15)。开发或修复页面时应以此为对照基准。
- `F:\Work\wxapp-yjzs` — 微信小程序变体（用于自选/我的/会员等页面的参照）。
- API 接口对齐 uni-app 的 `api/api.js`；SignalR 对齐 `utils/signalr.js`。

在实现或修复某个页面时，先找到对应的 `.vue` 源文件，逐项对齐其模板结构、逻辑、颜色和尺寸。`lib/` 下的文件级注释会标注对应的源码路径（如 `/// uni-app 对应: pages/optional/search.vue`）。

## 常用命令

```bash
flutter pub get                       # 安装依赖
flutter run -d chrome                 # 开发预览（本项目默认用 Chrome）。r = 热重载, R = 热重启（改动 provider 默认值/状态后需要）
flutter analyze                       # 对整个项目做静态检查
flutter analyze lib/pages/optional    # 只检查改动涉及的目录 — 每次改完代码都应执行
flutter test                          # 运行全部测试
flutter test test/widget_test.dart    # 运行单个测试文件
flutter build apk|ios|web             # 生产构建
```

**本项目不使用代码生成** —— `build_runner` 只是一个开发依赖，项目中不存在任何 `.g.dart`/`part` 文件。不要运行 codegen，也不要假设有生成文件。

**验证规范：**做完非平凡的改动后，运行 `flutter analyze`（目标是零*新增*告警 —— 代码树中存在一些历史遗留 lint，属于正常现象），条件允许时再 `flutter run` 在明暗两种主题下验证改动。注意：本环境的 Bash 安全分类器有时会临时不可用；若无法执行 `flutter analyze`/`run`，应先自行 review 代码，再把实际运行交给用户。

## 架构

### 页面（screens）与状态（state）—— 一个容易搞混的目录布局
- **`lib/pages/`** 存放真正的页面（首页、持仓、自选、行情、会员、我的、搜索、用户、通用页）。UI 代码都在这里。
- **`lib/features/`** 大部分是空壳。只有三个子目录有内容，且它们存放的是 **Riverpod provider**，而不是页面：`features/auth`（登录页 + `auth_provider`、`theme_provider`）、`features/home`（`home_provider`）、`features/position`（`position_provider`）。不要在 `features/` 下找页面代码。
- 很多页面用普通的 `setState` + 直接调用 `ApiClient()` 来管理自己的状态，而不是走 provider（例如 `pages/optional/optional_page.dart`）。只有当页面确实需要跨页面共享状态时，才引入 provider。

### 路由 (`lib/router.dart`, go_router)
只有一个 `AppRouter.router`。登录相关路由（`/login`、`/login/phone` 等）在 shell 之外（无底部 Tab 栏）。一个 `ShellRoute` 把六个 Tab 页包在 `MainShell` 里（Tab 栏本身是在 `router.dart` 中内联构建的）：`/home /position /optional /market /member /profile`。`/position` 和 `/optional` 通过 `_authGuard` 重定向做登录门槛校验。详情/子页面在 shell 内以 push 方式打开。`initialLocation` 是 `/home`。通过 query 参数传递数据，在对应路由的 `pageBuilder` 里用 `state.uri.queryParameters` 读取；通过 `context.pop(value)` 返回结果，调用方用 `await context.push(...)` 接收。

### 网络层 (`lib/core/network/`)
- `api_client.dart` — 单例 Dio 封装。`AuthInterceptor` 会从 SharedPreferences 的 `token` 键自动附加 `Bearer <token>`；`ErrorInterceptor` 处理 401（清除 token）以及网络/SSL 错误。使用 `ApiClient().get/post/put/delete`。
- `api_endpoints.dart` — 所有接口都以 `static const` 的形式定义，`baseUrl = https://api.huangjinetf.com`。对齐 uni-app 的 `api/api.js`。新增接口应加在这里，而不是把 URL 写死在业务代码里。

### 实时通信 (`lib/core/services/signalr_service.dart`)
基于原生 WebSocket（`web_socket_channel`）实现的轻量级 SignalR，hub 地址为 `ApiEndpoints.signalrUrl`（`/asset/hubs/market`），带指数退避重连。对齐 uni-app 的 `utils/signalr.js`。用于行情/价格的实时推送。

### 本地存储 (`lib/core/services/storage_service.dart`)
- **SharedPreferences** 存简单键值对：`token`、`userInfo`、`appSkinMode`（主题）、隐私协议/渠道/更新跳过等标志位。
- **Hive** 存结构化数据：`homeCache`、`tableConfig`、`userPreferences` 三个 box，均在 `main.dart` 中于 `runApp` 之前打开。

### 主题 (`lib/theme/`)
- `app_theme.dart` — `AppTheme.light` / `AppTheme.dark`（基于 FlexColorScheme 的 Material 3 主题）以及 `AppTheme.setSystemUIOverlay`。在 `app.dart` 中通过 `MaterialApp.router` 应用。
- 深色模式由 `themeModeProvider` 驱动（`AppThemeMode` 枚举，持久化在 `appSkinMode` 中）；可以 watch `isDarkModeProvider` 或 `Theme.of(context).brightness`。每个页面都必须在明暗两种主题下都能正确渲染。
- `app_colors.dart` — 与 uni-app 完全一致的颜色常量（涨/红 `#E05665`，跌/绿 `#31B87A` 等）。应复用这些常量，已有常量时不要再手写十六进制颜色。
- `text_styles.dart` — `AppTextStyles.cn(size,…)` 使用中文字体 `siyuanheitiCNRegular`；`AppTextStyles.num(size,…)` 使用数字字体 `DIN`。文字标签用 `cn`，数值/百分比用 `num`。
- `app_icons.dart` — 自定义 `iconfont.ttf` 图标（`AppIcons.search`、`.add` 等），是 uni-app iconfont 的 1:1 复刻。

### 关键约定：rpx → px 换算
uni-app 中的尺寸单位是 **rpx**（750rpx = 375px 设计稿宽度）。迁移 `.vue` 样式时，**把 rpx 除以 2** 即可得到 Flutter 中的逻辑像素值（例如 `28rpx` → `14`，`80rpx` 高度 → `40`）。现有 Dart 代码中的颜色/间距已经遵循这个规则，继续保持一致即可。

### 数据模型 (`lib/core/models/`)
带 `fromJson` 的普通 Dart 数据类（asset、book、symbol、trade、profit、kline、alert、user）；`models.dart` 是统一导出的 barrel 文件。部分页面会在文件内部直接定义小型内联模型（例如 `optional_page.dart` 里的 `FavItem`/`IndicatorRef`）—— 遇到这种情况应遵循所在页面已有的风格。
