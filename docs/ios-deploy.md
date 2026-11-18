# iOS 真机打包安装说明（Windows 环境）

本文档记录在没有 Mac 的情况下，把本项目安装到 iPhone 的完整流程：
**推送代码 → GitHub Actions 构建签名 ipa → 下载 → pymobiledevice3 安装到手机**。

---

## 1. 前置条件（一次性配置）

### 1.1 Apple 开发者配置（已在 GitHub Secrets 中配好）

iOS 构建使用 **development 签名**，相关 Secret 在仓库 Settings → Secrets 中：

| Secret | 说明 |
|---|---|
| `IOS_CERTIFICATE` | 开发者证书（.p12 的 base64） |
| `IOS_CERTIFICATE_PASSWORD` | 证书密码 |
| `IOS_PROVISIONING_PROFILE` | 描述文件（YangJiZhu_Dev，base64） |

关键参数（见 `.github/workflows/ios-build.yml`）：
- Team ID：`M7CXGX86SJ`
- Bundle ID：`com.gold.xuansheng`
- 描述文件：`YangJiZhu_Dev`（development 类型）

### 1.2 手机 UDID 必须在描述文件里

development 签名的 ipa **只能安装到描述文件中注册的设备**。当前已注册 4 台（2026-11 时点）：

```
3a80257885a4d3f10edd11347c029cddc3452152
00008150-000A0D480C8A401C
00008130-001829540E92001C
8958d96569624ca27cee757312c32437cf41b97c
```

查看当前连接手机的 UDID（PowerShell）：

```powershell
Get-PnpDevice -PresentOnly -Class USB | Where-Object FriendlyName -Match "Apple Mobile" | Select-Object -ExpandProperty InstanceId
# 输出形如 USB\VID_05AC&PID_12A8\8958D96569624CA27CEE757312C32437CF41B97C，最后一段即 UDID
```

新设备要加入：登录 [Apple Developer](https://developer.apple.com/account/resources/devices/list) 注册 UDID → 重新生成描述文件 → 更新 `IOS_PROVISIONING_PROFILE` secret。

### 1.3 手机侧设置

- 数据线连接（**不能用仅充电线**），手机保持解锁，弹「信任此电脑」点信任
- 首次运行 dev 签名应用：设置 → 通用 → VPN与设备管理 → 信任开发者证书
- iOS 16+ 需开启 设置 → 隐私与安全性 → 开发者模式

### 1.4 安装工具 pymobiledevice3（已备好）

项目内已建好隔离环境 `tools/pyvenv/`（含 pymobiledevice3）。若需重建：

```bash
python -m venv tools/pyvenv
tools/pyvenv/Scripts/python.exe -m pip install pymobiledevice3
```

验证设备连接：

```bash
tools/pyvenv/Scripts/python.exe -m pymobiledevice3 usbmux list
# 能列出 Identifier/ProductVersion 即连接正常
```

---

## 2. 触发构建

### 方式 A：推送 master（自动触发）

```bash
git push origin master
```

推送到 `master` 分支会自动触发 `iOS Build` workflow，`build_id` 取 commit SHA。

### 方式 B：手动触发（可选参数）

仓库 → Actions → iOS Build → Run workflow，可指定 `build_id`、Flutter 版本、Release/Debug 等。

### 用 API 触发/查询（本机 git 凭证里已有 token）

```bash
TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | git credential fill | sed -n 's/^password=//p')

# 触发
curl -X POST -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/boboya0828/gold_fund/actions/workflows/ios-build.yml/dispatches" \
  -d '{"ref":"master","inputs":{"build_id":"dev-'"$(date +%Y%m%d-%H%M%S)"'"}}'

# 查询最新运行状态
curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/boboya0828/gold_fund/actions/workflows/ios-build.yml/runs?per_page=1"
```

构建约 6~9 分钟。产物为 artifact 名 `ipa`（内含 `<build_id>.ipa`）。

---

## 3. 下载 ipa

```bash
RUN_ID=<上一步的 run id>
ART_ID=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/boboya0828/gold_fund/actions/runs/$RUN_ID/artifacts" | grep -m1 '"id"' | grep -oE '[0-9]+')

cd dist
curl -sL -C - --retry 5 --retry-delay 3 \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/boboya0828/gold_fund/actions/artifacts/$ART_ID/zip" -o ipa-artifact.zip
unzip -o ipa-artifact.zip && rm ipa-artifact.zip
```

> 网络提示：本机访问 github.com 直连不稳定（连接常被重置），api.github.com 相对稳定。
> `git push` 失败时直接重试即可（历史上重试 5~7 次内可成功）；下载用 `curl -C -` 断点续传。

验证签名（可选）：

```bash
unzip -l dist/<build_id>.ipa | grep mobileprovision
# 解出 embedded.mobileprovision 可检查 UDID 列表是否包含目标手机
```

---

## 4. 安装到手机

```bash
cd /f/Work/flutter
tools/pyvenv/Scripts/python.exe -m pymobiledevice3 apps install dist/<build_id>.ipa
# 出现 "Installation succeed." 即成功
```

验证已安装：

```bash
tools/pyvenv/Scripts/python.exe -m pymobiledevice3 apps list | grep -i gold
```

---

## 5. 常见问题

| 现象 | 原因与处理 |
|---|---|
| `Device is not connected` | 手机断开/未信任。重新插线、解锁、点信任，再 `usbmux list` 确认 |
| 安装报 `Failed to get parent identifier` 或 `coordinator superseded` | 上一次安装残留状态，重试即可；反复出现则手机上删除旧 App 重装 |
| 安装成功但打开闪退 | 手机 UDID 不在描述文件里（见 1.2），或开发者证书未信任（设置 → 通用 → VPN与设备管理） |
| `git push` 一直 Connection reset | 网络对 github.com 的干扰，重试（脚本里循环重试即可，间歇性恢复） |
| 手机弹「不受信任的开发者」 | 设置 → 通用 → VPN与设备管理 → 信任 M7CXGX86SJ |
| 想换工具安装 | 也可用 MobAI（D:\MobAI\MobAI.exe，需在应用内登录并启动桥接）或爱思助手等 GUI 工具，ipa 路径在 `dist/` |

---

## 6. 日常快速流程（TL;DR）

```bash
# 1. 提交推送（自动触发构建）
git push origin master

# 2. 等 6~9 分钟，Actions 页面确认绿勾

# 3. 下载 artifact（见第 3 节），得到 dist/<sha>.ipa

# 4. 安装
tools/pyvenv/Scripts/python.exe -m pymobiledevice3 apps install dist/<sha>.ipa
```

## 7. 相关文件

- 构建配置：`.github/workflows/ios-build.yml`
- 安装工具：`tools/pyvenv/`（pymobiledevice3 隔离环境）
- 产物目录：`dist/`
- Web 预览服务：`tools/serve_web.py`（`python tools/serve_web.py 7200 build/web`，带 no-cache 头）
