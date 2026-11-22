# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目

Go2Shell：放在 Finder 工具栏上的 macOS 小工具，点一下就在当前 Finder 目录打开终端。它替代 ZipZapMac 的旧版 Go2Shell 2.5（`com.zipzapmac.Go2Shell`），两者同名；文档和代码里的「旧 Go2Shell」「legacy Go2Shell」都指后者，本项目的 Bundle ID 是 `com.bingghost.Go2Shell`。Swift 6（strict concurrency）、macOS 14+、SPM + Makefile 组装 `.app`，没有 Xcode 工程。

设计文档在 `docs/`，改动前先读相关部分：`01-PRD.md`（功能 F*）、`02-TECH-DESIGN.md`（模块设计、测试方案）、`03-REQUIREMENTS.md`（REQ-*）、`04-DEV-PLAN.md`（里程碑 M0–M8 与末尾「进度」表）、`05-GOALS.md`（每个里程碑的 goal 命令）。

## 命令

```sh
make build            # swift build -c release → 组装并签名 .build/Go2Shell.app（UNIVERSAL=1 构建 arm64+x86_64）
make test             # swift test
swift test --filter ShellQuoteTests          # 跑单个测试套件（Swift Testing，可用 --filter 匹配套件或测试名）
make run / install / uninstall / clean
make build CONFIG=debug   # debug 包，输出到 .build/dev/Go2Shell.app

./start.sh [参数]     # 开发调试：构建 debug 包并在前台运行，参数原样传给 App（不带参数时打开设置窗口）
./build.sh            # 构建 release 包 .build/Go2Shell.app（等同 make build）
./install.sh          # build.sh → 装到 /Applications → 打开 App → clean.sh
./clean.sh            # 删除全部编译产物（debug 和 release），保留 SwiftPM 拉取的三方依赖
make reset-tcc        # 重置 com.bingghost.Go2Shell 的 Apple Events 授权
make icon             # 用 Scripts/make-icon.swift 重新生成 Resources/AppIcon.icns 和 docs/images/icon-preview.png

# 调试参数（不经过 Finder 工具栏）
.build/Go2Shell.app/Contents/MacOS/Go2Shell --print-finder-path   # 打印 Finder 最前窗口路径
.build/Go2Shell.app/Contents/MacOS/Go2Shell --open <dir>          # 按当前设置直接打开终端
.build/Go2Shell.app/Contents/MacOS/Go2Shell --settings            # 打开设置窗口
defaults write com.bingghost.Go2Shell terminal iTerm2            # 切换终端（值为 TerminalKind rawValue）
log stream --level debug --predicate 'subsystem == "com.bingghost.Go2Shell"'

Scripts/make-test-dirs.sh      # 在 ~/tmp/go2shell-test 下建特殊字符目录（空格、引号、$、反引号、换行、中文…）
Scripts/check-iterm-cold.sh    # iTerm2 冷启动测试，必须从 Terminal.app 运行
```

- 测试用 Swift Testing（`import Testing`、`@Test`、`#expect`），不是 XCTest；只有 `Go2ShellCore` 有测试 target，需要单元测试的逻辑要放进 Core。
- 签名默认用钥匙串里第一个 "Apple Development" 证书（`make SIGN_ID=...` 覆盖），找不到就 ad-hoc；ad-hoc 每次构建后都要重新授权自动化权限。
- 从 shell 直接运行可执行文件时，TCC 授权算在父终端进程名下；只有从 Finder/Dock 启动才属于 Go2Shell 本身。

## 架构

两个 target：
- **`Go2ShellCore`**（library，**不得 import AppKit**）：纯逻辑，全部单元测试都在这里。`ShellQuote`、`CommandTemplate`（`%PATH%` 渲染/normalize）、`TerminalKind`（各终端 bundle id 与能力 `supportsCommand`/`supportsNewTab`）、`Settings` + `UserDefaultsSettingsStore`、`LegacyMigration`（读旧 Go2Shell `com.zipzapmac.Go2Shell` 配置）、`LaunchRouter`、`Go2ShellError`、`AppleScriptRunner`。
- **`Go2Shell`**（executable）：`main.swift` 先用 `LaunchRouter.route` 分流（顺序：`--print-finder-path` → `--open` → `--settings`/按住 ⌥ → 前台是 Finder 则打开终端 → 否则设置），再交给 `AppController`。打开终端模式下 `LSUIElement=true`、不出 Dock 图标、执行完立即 `NSApp.terminate`；设置模式切到 `.regular`。设置窗口开着时再点工具栏，走 `applicationShouldHandleReopen` 打开终端。
- 流程：`FinderLocator`（AppleScript 取最前 Finder 窗口路径；无窗口退回 `~/Desktop`，虚拟位置抛 `notFileSystem`；设置里开了 `preferSelectedFolder` 且恰好选中一个普通文件夹（非 package）时优先用选中项）→ `LauncherFactory.make(for:)`（配置的终端没装就退回 Terminal.app）→ `ITermLauncher` / `AppleTerminalLauncher`（AppleScript）或 `GenericLauncher`（`NSWorkspace.OpenConfiguration`，用于 Ghostty/WezTerm/Kitty/Alacritty/Warp）→ 出错由 `ErrorPresenter` 弹窗。

- 各终端的差异集中在 `TerminalKind`：加新终端先改这里（bundle id、能力、`workingDirectoryArguments`），再在 `LauncherFactory.make` 里接上 launcher。
- `GenericLauncher` 有两种策略：`workingDirectoryArguments` 返回参数的（WezTerm/kitty/Alacritty）带参数启动新实例；返回 `nil` 的（Ghostty/Warp）用该 app 打开文件夹。它不执行命令模板（这些终端 `supportsCommand == false`）。
- Terminal.app 没有「新标签页」的 AppleScript 命令，新标签页模式靠 System Events 模拟 ⌘T（实验性，需要辅助功能权限）；没有权限时退回新窗口，并只提示一次。脚本只在目标窗口的标签页数量确实增加后才发命令，否则也退回新窗口（不能把命令送进用户已有的标签页）。
- 安装路径 `/Applications/Go2Shell.app` 与旧 Go2Shell 相同：`make deploy` 发现那里是别的 Bundle ID 时，会把它移到 `~/Library/Application Support/Go2Shell/Replaced Apps/` 而不是删除；`make uninstall` 只删我们自己的 App。

### 关键约束（安全与正确性）

- **AppleScript 源码必须是常量**，目标应用一律写 `tell application id "<bundle id>"`，不按名字。运行时数据（路径、命令）只能作为 handler 参数通过 `AppleScriptRunner.call(handler, args)`（`kASSubroutineEvent`）传入，绝不拼接进脚本源码。
- 进入 shell 的只有 `CommandTemplate.render` 的结果，路径一律经 `ShellQuote.quote`（POSIX 单引号整体引用）。`GenericLauncher` 不经过 shell。
- 冷启动终端时要复用终端自动开的那个窗口，避免出现两个窗口（启动前用 `NSRunningApplication` 判断 `wasRunning`，脚本里轮询等待窗口）。
- AppleScript 错误码映射：`-1743` → `automationDenied`，`-600`/`-609` → `targetNotRunning`。
- 本地化不用 `Bundle.module`：Makefile 把 `Resources/*.lproj` 复制进 `.app`，代码用 `L("key")`（`Bundle.main`）读取。`Sources/Go2Shell` 里不允许写死界面字符串，新增文字要同时加到 `en` 和 `zh-Hans` 的 `Localizable.strings`。
- 路径日志用 `.private` 级别。

## 改代码前先查交叉引用

项目在 `.claude/settings.json` 里启用了 `swift-lsp` 插件（SourceKit-LSP，随 Xcode 自带），Claude Code 的 `LSP` 工具可以做语义级的交叉引用，比 grep 准（能区分同名符号、能看到协议实现）。

改动、重命名或删除任何函数、类型、属性、enum case 之前，以及改变它的行为（参数含义、返回值、抛出的错误）之前：

1. 用 `LSP` 的 `findReferences` 查所有引用；函数和方法再用 `incomingCalls` 查调用方，需要时逐层往上查。协议要求（如 `TerminalLauncher.open`、`SettingsStore`）用 `goToImplementation` 找所有实现。
2. 动手前先列出受影响的位置（包括 `Tests/`），改完后这些位置要全部同步更新，再跑 `make test`。
3. 不知道符号在哪时用 `workspaceSymbol` 按名字找，用 `documentSymbol` 看一个文件的结构，不要整文件通读。

LSP 看不到下面这些靠字符串关联的东西，必须另外用 grep 查：

- AppleScript handler 名：脚本源码里的 `on openWindow(...)` 和 `runner.call("openWindow", ...)`。
- 本地化 key：`L("key")` 和两份 `Localizable.strings`。
- UserDefaults key、`TerminalKind` 的 rawValue（会写进用户配置，改名等于破坏已有设置）。
- `docs/`、`Makefile`、脚本里提到的名字和命令行参数。

索引在 `.build` 里，`clean.sh` / `install.sh` 之后会被删掉。如果查询结果为空或明显偏少，先跑一次 `swift build` 再查，并用 grep 交叉核对；不要把空结果当成「没有引用」。

## 工作约定

- `reference-solarhell/` 是参考仓库（已 gitignore），**不要复制其中的代码**。
- README 有两份：`README.md`（英文，GitHub 默认显示）和 `README.zh-CN.md`（中文），章节一一对应，改一份时另一份要同步改。
- 设计与实测不一致时以实测为准，并同步更新 `docs/02-TECH-DESIGN.md`。
- 完成一个里程碑：`make test` 和 `make build` 都要通过，更新 `docs/04-DEV-PLAN.md` 进度表，commit message 以 `M<n>:` 开头。
- 需要用户动手的测试（点击授权、拖到工具栏、按 ⌥、界面截图确认等）不要中途停下来等：先把代码写完，把这些项记到 M8 的 `docs/TEST-CHECKLIST.md`，并在进度表备注里写明推迟了什么（2026-11-22 用户指示，见 `docs/04-DEV-PLAN.md`）。
- iTerm2 冷启动没法在 iTerm2 里的会话中自测（不能退出自己所在的终端），用 `Scripts/check-iterm-cold.sh` 从 Terminal.app 跑。
