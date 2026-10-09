# 立记 · iOS 离线版

立即去做，记下每一步。

这是完整的 iOS 应用工程包，不是已经编译的 IPA。目标：iPhone / iPad，iOS 16.0 及以上。此工程尚未在 Xcode 或真机中编译验证；需要先完成下述构建。无需服务器、无需游戏加载器。

## 包含功能

- 初始无活动，自行添加活动及专属标签。
- 每天勾选、多选标签、文本备注、补签、统计。
- 活动归档、恢复；归档后可永久删除，删除前确认。
- 内置 Web 页面，离线运行。
- iOS 原生文件窗口导入、导出 JSON 备份。
- WKWebView 持久存储，并将每次修改写入应用私有 JSON 文件（原子写入）。
- 首次启动不包含你的个人记录；可手动导入电脑版导出的备份。

## 方法一：没有 Mac，用 GitHub Actions 构建

1. 登录自己的 GitHub，新建一个仓库，例如 `liji-ios`。可选择私有仓库。
2. 解压本工程。在仓库根目录上传以下内容：`project.yml`、`build.sh`、`Liji` 文件夹，以及 `.github/workflows/build-ios.yml`。不要在仓库外层再套一层 `Liji-iOS` 文件夹。
3. 特别注意：以点开头的 `.github` 文件夹不能遗漏。若网页上传未包含它，可点 Add file → Create new file，文件名填写 `.github/workflows/build-ios.yml`，粘贴同名文件内容。
4. 打开仓库的 Actions → Build Liji iOS → Run workflow。首次启用 Actions 时按 GitHub 提示确认。
5. 等任务变绿，进入该次任务，下载 Artifacts 中的 `Liji-unsigned-IPA`。解压后得到 `Liji-unsigned.ipa`。
6. 用爱思助手或 Sideloadly，以自己的 Apple 账户签名后安装。

工作流使用 GitHub 提供的 macOS 构建环境；是否可运行、可用额度和费用取决于你的 GitHub 账户及仓库设置。如提示计费或额度不足，请先检查账户设置，不要盲目重试。

若构建失败，请把失败步骤的日志发回来修复。不要把工程 ZIP 改名为 IPA；那样无法安装。

## 方法二：有 Mac

1. 安装完整 Xcode，启动一次完成首次配置；在 Xcode 设置中选择 Command Line Tools。
2. 安装 XcodeGen：`brew install xcodegen`。
3. 在本目录执行 `bash build.sh`。
4. 未签名安装包在 `output/Liji-unsigned.ipa`。

也可以先执行 `xcodegen generate`，用 Xcode 打开生成的 `Liji.xcodeproj`，在 Signing & Capabilities 选择自己的 Team 和自动签名，连接设备后运行。

## 安装与数据

- 默认 Bundle ID 是 `com.lirongli.liji`。以后升级请保持相同签名账户及一致的最终 Bundle ID，并覆盖安装。签名工具可能会调整 Bundle ID，请沿用它的设置。
- iOS 按需要开启开发者模式、信任自己的开发者账户。
- 免费账户签名通常需要每七天续签；不要为了续签先删除 App。
- 导出时选择 iCloud 云盘等独立位置；导入会替换当前全部数据，先备份。
- 浏览器与 App 的数据不自动共享。在电脑网页端导出 JSON，传到手机后在 App 内导入即可。
- 不包含推送、登录、后台网络同步，也不要求照片、通讯录、定位权限。

## 文件说明

- `Liji/Web/index.html`：打卡页面与逻辑。
- `Liji/GameViewController.swift`：离线 WebView、文件导入导出、原生确认弹窗、数据持久化。
- `Liji/AppDelegate.swift`：应用入口。
- `project.yml`：XcodeGen 工程配置。
- `build.sh`：无签名 iOS 构建及 IPA 打包。
- `.github/workflows/build-ios.yml`：GitHub Actions 构建配置。

## 已验证与未验证

已检查网页 JavaScript 语法和核心数据逻辑、备份桥接逻辑、工程资源路径、YAML/图标配置以及 shell 语法。当前制作环境为 Linux，没有 Xcode，未运行 Swift 编译、iOS 模拟器或真实设备测试。因此首次 Actions 构建与真机试用仍是必要验证步骤。
