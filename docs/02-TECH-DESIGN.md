# Go2Shell 技术设计文档

> 版本：v1.0 草案 · 日期：2026-11-21 · 对应 PRD：`docs/01-PRD.md`

## 1. 技术选型

| 项 | 选择 | 理由 |
| --- | --- | --- |
| 语言 | Swift 6（strict concurrency） | 本机是 Swift 6.4 / Xcode 27.1 |
| UI | AppKit 负责入口和弹窗，SwiftUI 写设置窗口 | 入口逻辑要精确控制启动和退出，设置界面用 SwiftUI 写起来快 |
| 构建 | **Swift Package Manager + Makefile 组装 .app** | 纯文本配置，不需要维护 `.pbxproj`；命令行和 AI 都好操作；`swift test` 可以直接跑测试 |
| 进程间通信 | 固定的 AppleScript 源码，**通过 handler 传参调用**（`NSAppleEventDescriptor`） | 路径和命令不会被拼进脚本源码，从根本上避免 AppleScript 注入 |
| 启动无脚本接口的终端 | `NSWorkspace.openApplication` / `open(_:withApplicationAt:configuration:)` | 不经过 shell，没有注入风险 |
| 日志 | `os.Logger`（subsystem `com.bingghost.Go2Shell`） | 用 `log stream --predicate 'subsystem == "com.bingghost.Go2Shell"'` 查看 |
| 测试 | XCTest 或 Swift Testing，只测 `Go2ShellCore` | 纯逻辑，可以快速跑完 |
| 最低系统 | macOS 14 | |
| 沙盒 | **不开** | 要用 Apple Events 控制多个 App，开沙盒得为每个目标声明 scripting-targets，对个人工具来说没必要 |
| Hardened Runtime | 开，带 `com.apple.security.automation.apple-events` 权限 | 签名后才能正常申请自动化权限 |

## 2. 目录结构

```
go2shell/                         # git 根目录
├── Package.swift
├── Makefile
├── Sources/
│   ├── Go2ShellCore/              # 纯逻辑，不依赖 AppKit，可以单元测试
│   │   ├── ShellQuote.swift
│   │   ├── CommandTemplate.swift
│   │   ├── TerminalKind.swift
│   │   ├── Settings.swift
│   │   ├── LegacyMigration.swift
│   │   ├── LaunchRouter.swift
│   │   ├── Go2ShellError.swift
│   │   └── AppleScriptRunner.swift   # 只依赖 Foundation，放在 Core 里方便单元测试（M2 实测后调整）
│   └── Go2Shell/                  # App：入口、系统交互、UI
│       ├── main.swift
│       ├── AppController.swift
│       ├── FinderLocator.swift
│       ├── Launchers/
│       │   ├── TerminalLauncher.swift        # 协议 + 工厂
│       │   ├── ITermLauncher.swift
│       │   ├── AppleTerminalLauncher.swift
│       │   └── GenericLauncher.swift         # Ghostty / WezTerm / Kitty / Alacritty / Warp
│       ├── ErrorPresenter.swift
│       ├── ToolbarInstaller.swift            # P1
│       └── Settings/
│           ├── SettingsWindowController.swift
│           └── SettingsView.swift
├── Tests/Go2ShellCoreTests/
├── Resources/
│   ├── Info.plist
│   ├── Go2Shell.entitlements
│   ├── AppIcon.icns
│   ├── en.lproj/Localizable.strings
│   └── zh-Hans.lproj/Localizable.strings
├── Scripts/
│   └── make-icon.swift           # 用代码画图标，输出 icns
├── docs/
└── reference-solarhell/          # 参考仓库，写进 .gitignore，不复制它的代码
```

**本地化**：不用 SPM 的 `Bundle.module`（手工组装 .app 时容易找不到资源）。Makefile 直接把 `.lproj` 复制到 `Contents/Resources`，代码里用 `Bundle.main` 读取。

## 3. 模块设计

### 3.1 Go2ShellCore（纯逻辑）

#### ShellQuote
```swift
public enum ShellQuote {
    /// POSIX 单引号整体引用：abc'd → 'abc'\''d'
    public static func quote(_ s: String) -> String
}
```
- 不维护「哪些字符要转义」的列表。单引号内部除了 `'` 以外都没有特殊含义，换行也包括在内。

#### CommandTemplate
```swift
public struct CommandTemplate {
    public static let placeholder = "%PATH%"
    public static let `default` = "cd %PATH%; clear; pwd"
    public init(_ raw: String)
    /// 把 %PATH% 替换成 ShellQuote.quote(path)。如果模板里没有 %PATH%，就在最前面加 "cd <quoted>; "
    public func render(path: String) -> String
    /// 迁移时用：把 "%PATH%" 和 '%PATH%' 这种带引号的写法规范成 %PATH%，避免重复加引号
    public static func normalize(_ raw: String) -> String
}
```
- 模板为空时等同于 `cd %PATH%`。

#### TerminalKind
```swift
public enum TerminalKind: String, CaseIterable, Codable {
    case appleTerminal, iTerm2, ghostty, wezterm, kitty, alacritty, warp
    public var bundleIdentifiers: [String]   // 第一个是首选；兼容历史上用过的 bundle id
    public var displayName: String
    public var supportsCommand: Bool          // 能否执行命令模板
    public var supportsNewTab: Bool
}
```

| Kind | bundle id | 命令 | 新标签 | 启动方式 |
| --- | --- | --- | --- | --- |
| appleTerminal | `com.apple.Terminal` | ✅ | ⚠️ 模拟 ⌘T | AppleScript |
| iTerm2 | `com.googlecode.iterm2` | ✅ | ✅ | AppleScript |
| ghostty | `com.mitchellh.ghostty` | ❌ v1 | ❌ | 用 NSWorkspace 打开目录 |
| wezterm | `com.github.wez.wezterm` | ❌ v1 | ❌ | NSWorkspace，参数 `start --cwd <dir>` |
| kitty | `net.kovidgoyal.kitty` | ❌ v1 | ❌ | NSWorkspace，参数 `--directory <dir>` |
| alacritty | `org.alacritty` | ❌ v1 | ❌ | NSWorkspace，参数 `--working-directory <dir>` |
| warp | `dev.warp.Warp-Stable` | ❌ | ❌ | NSWorkspace 打开目录 |

> 上表的 bundle id 和命令行参数在实现 G6 时**必须对照各终端的官方文档或本机安装包核实**，以核实结果为准。

#### Settings
```swift
public struct Settings: Codable, Equatable {
    public var terminal: TerminalKind = .appleTerminal
    public var commandTemplate: String = CommandTemplate.default
    public var openMode: OpenMode = .newWindow     // .newWindow / .newTab
    public var preferSelectedFolder: Bool = false  // P1 F15
    public var didMigrate: Bool = false
}
public protocol SettingsStore { func load() -> Settings; func save(_: Settings) }
```
- App 里用 `UserDefaultsSettingsStore` 实现，每个字段一个 key：`terminal`、`commandTemplate`、`openMode`、`preferSelectedFolder`、`didMigrate`。

#### LegacyMigration
- 输入是旧 Go2Shell 配置的字典，比如 `["Terminal Identifier": "com.googlecode.iterm2", "Terminal Command": "cd %PATH%; clear; pwd", "Use Window": 0]`，输出 `Settings?`。
- 终端映射：`com.googlecode.iterm2` 和 `net.sourceforge.iTerm` 对应 `.iTerm2`，`com.apple.Terminal` 对应 `.appleTerminal`，其他值退回默认。
- `Use Window` 的含义要在 G5 里实测确认：在旧 Go2Shell 里分别选 New Window 和 New Tab，看 defaults 里的值怎么变。**默认按 `0` 表示新窗口处理。**
- 命令先经过 `CommandTemplate.normalize`。
- App 层用 `UserDefaults(suiteName: "com.zipzapmac.Go2Shell")?.dictionaryRepresentation()` 读取。不开沙盒时可以读到；如果读不到，就退到 `defaults read` 解析 plist。

#### LaunchRouter
```swift
public enum LaunchAction: Equatable { case showSettings, openTerminal(explicitPath: String?), printFinderPath }
public struct LaunchContext { arguments: [String]; frontmostBundleID: String?; optionKeyDown: Bool }
public static func route(_ ctx: LaunchContext) -> LaunchAction
```
判断规则，按顺序：
1. 带 `--print-finder-path`：返回 `.printFinderPath`（调试用）。
2. 带 `--open <path>`：返回 `.openTerminal(explicitPath:)`（调试或命令行用，不经过 Finder）。
3. 带 `--settings`，或者按住了 ⌥：显示设置。
4. 最前台是 `com.apple.finder`：返回 `.openTerminal(nil)`。
5. 其他情况：显示设置。

### 3.2 AppleScriptRunner

> 位置：`Go2ShellCore`（M2 调整）。它只用到 Foundation 的 `NSAppleScript` / `NSAppleEventDescriptor`，四字符码自己定义，不需要 import Carbon；标注了 `@MainActor`。单元测试里有 echo 往返测试，包括模拟注入的字符串。

把固定的脚本源码编译一次，再用 Apple Event 调用其中的 handler，参数作为 descriptor 传进去：

```swift
final class AppleScriptRunner {
    init(source: String) throws                       // 编译失败就 throw
    func call(_ handler: String, _ args: [String]) throws -> NSAppleEventDescriptor
}
```
- 实现方式：构造 `kASAppleScriptSuite` / `kASSubroutineEvent`，用 `keyASSubroutineName` 传小写的 handler 名，参数放进 `NSAppleEventDescriptor.list()`，最后调用 `NSAppleScript.executeAppleEvent(_:error:)`。
- 把 errorDict 里的 `NSAppleScriptErrorNumber` 映射成 `Go2ShellError`：
  - `-1743`：未授权（automationDenied）
  - `-600` / `-609`：目标 App 没有运行或连接失败
  - 其他：`scriptFailed(code, message)`
- **规则：脚本源码里不允许出现任何运行时拼接的字符串。**

### 3.3 FinderLocator

```applescript
on frontWindowPath()
    tell application "Finder"
        if (count of Finder windows) is 0 then return "::NO_WINDOW::"
        try
            return POSIX path of (target of front Finder window as alias)
        on error
            return "::NOT_FILESYSTEM::"
        end try
    end tell
end frontWindowPath

on selectedFolderPath()  -- P1 F15：只有选中一个文件夹时才返回
    ...
end selectedFolderPath
```
- **M2 实测结果**：Finder 的「最近使用」窗口的 `target` 是一个 canned search 文件，转换成 `alias` 时会失败，于是返回 `::NOT_FILESYSTEM::`，符合预期。`on error` 里遇到 -1743 会重新抛出，避免把权限错误当成虚拟位置。
- 返回值语义：`::NO_WINDOW::` 退到 `~/Desktop`（用 `FileManager.default.homeDirectoryForCurrentUser` 拼出来，**不要用 `URL(string:)`**）；`::NOT_FILESYSTEM::` 抛出 `notFileSystem`。
- 拿到路径后再确认一次：路径存在而且是目录。如果是文件（理论上不会出现），就取它的父目录。
- **Finder 最前窗口的定义**：`front Finder window` 会跳过「显示简介」之类的非浏览窗口，正好符合需要。

### 3.4 TerminalLauncher

```swift
protocol TerminalLauncher {
    func open(directory: URL, command: String, mode: OpenMode) throws
}
enum LauncherFactory { static func make(for: TerminalKind) -> TerminalLauncher }
```

**ITermLauncher**（`tell application id "com.googlecode.iterm2"`）：
```applescript
on openWindow(cmd, wasRunning)
    tell application id "com.googlecode.iterm2"
        activate
        if wasRunning is "0" and (count of windows) > 0 then
            set w to current window          -- 冷启动时 iTerm 会自己开一个窗口，直接复用，不然会出现两个窗口
        else
            set w to (create window with default profile)
        end if
        tell current session of w to write text cmd
    end tell
end openWindow

on openTab(cmd)
    tell application id "com.googlecode.iterm2"
        activate
        if (count of windows) is 0 then
            create window with default profile
        else
            tell current window to create tab with default profile
        end if
        tell current session of current window to write text cmd
    end tell
end openTab
```
- 用 `NSRunningApplication.runningApplications(withBundleIdentifier:)` 判断 `wasRunning`，在调用脚本之前判断。
- **M3 实现**：冷启动时 iTerm 的默认窗口不一定马上出现，所以脚本里的 `waitForWindow()` 最多轮询 2 秒（20 次 × 0.1 秒）。等到窗口就复用它；等不到（比如 iTerm 设置成启动时不开窗口）就新建一个。Terminal.app 冷启动时先 `launch`，同样轮询，再用 `do script ... in front window`。实测 Terminal 冷启动约 2.7 秒，主要是 Terminal 自己的启动时间。
- **自动化授权**：从 shell 直接运行 `.build/.../Go2Shell` 时，授权算在父进程（当前终端）名下；只有从 Finder 或 Dock 启动时，授权才属于 Go2Shell 自己。

**AppleTerminalLauncher**（`tell application id "com.apple.Terminal"`）：
- 新窗口：如果已经在运行，用 `do script cmd` 开新窗口；如果没运行，冷启动时 Terminal 会自动开一个窗口，就用 `do script cmd in front window` 复用它，避免出现两个窗口。
- 新标签（P1，实验性）：通过 `System Events` 发送 `keystroke "t" using command down`，按键前记下目标窗口的 id 和标签页数量，按键后轮询（最多约 1.5 秒），**只有标签页数量确实增加了**才 `do script cmd in window id <目标窗口>`；否则返回 `noTab`，由 Swift 侧退回新窗口。这样命令不会被送进用户正在用的标签页。System Events 里按 bundle id 找进程，不按进程名。以下情况都退回新窗口：没有辅助功能权限（提示一次）、System Events 的自动化授权被拒、新标签页没有出现。

**GenericLauncher**：
- 用 `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` 找到 App。
- 只需要打开目录的终端：调用 `NSWorkspace.shared.open([dirURL], withApplicationAt:, configuration:)`。
- 需要传参数的终端：用 `NSWorkspace.OpenConfiguration.arguments` 传。`createsNewApplicationInstance` 是否需要打开，按各终端实测决定。
- 最多等 5 秒让 Launch Services 回调（否则 App 可能在请求发出前就退出）。超时不算失败，只记日志：请求已经交给系统，用户处理完首次启动的确认框后终端仍会打开。

**选择终端的兜底**：配置的终端如果没有安装，就退回 Terminal.app，并记一条日志。

### 3.5 AppController（入口编排）

```
main.swift:
  let ctx = LaunchContext(CommandLine.arguments, NSWorkspace.frontmostApplication, NSEvent.modifierFlags.contains(.option))
  先运行迁移（只跑一次）
  switch LaunchRouter.route(ctx)
    .openTerminal  → 用 NSApplication 运行，不出现 Dock 图标（LSUIElement），执行完调用 NSApp.terminate
    .showSettings  → activationPolicy 设为 .regular，显示设置窗口，关掉最后一个窗口时退出
    .printFinderPath → 打印到 stdout，然后 exit
```
- **为什么打开终端时也要启动 NSApplication**：弹错误提示需要 NSApp 实例；整个过程不进 Dock，执行完马上退出。
- **设置窗口打开时又点了工具栏**：Finder 会给已经在运行的本 App 发送 reopen 事件，在 `applicationShouldHandleReopen` 里执行一次打开终端的动作。
- **超时**：Apple Event 调用默认最多等 2 分钟（系统权限弹窗在等用户操作时会一直卡住）。正常情况下不需要处理，但要记录耗时日志。

### 3.6 ErrorPresenter

| 错误 | 提示 | 按钮 |
| --- | --- | --- |
| automationDenied(target) | 「Go2Shell 没有控制 {target} 的权限」 | 「打开系统设置」，跳转到 `x-apple.systempreferences:com.apple.preference.security?Privacy_Automation`；「好」 |
| notFileSystem | 「当前 Finder 窗口不是一个文件夹」 | 「好」 |
| terminalNotFound | 「找不到 {name}，已改用 Terminal.app」 | 不弹窗，只记日志 |
| scriptFailed | 显示错误码和信息 | 「好」 |

### 3.7 设置窗口（SwiftUI）

内容分三块：
- **终端**：单选列表，只列出已安装的终端，带上 App 图标。
- **命令**：一个 TextField，旁边有「恢复默认」按钮。下面是预览，显示 `render(path: "/Users/you/My Project")` 的结果。如果选中的终端不支持执行命令，就把这一块灰掉并说明原因。
- **打开方式**：新窗口或新标签；终端不支持新标签时禁用这个选项。

另外还有：
- **安装到工具栏**：图文说明加「在 Finder 中显示 Go2Shell」按钮；P1 增加「自动安装到工具栏」。
- **底部**：版本号、「测试一下」按钮（用 `--open ~` 的同一套逻辑打开一次终端）。
- 设置存进 `UserDefaults`，修改后立即生效。

### 3.8 ToolbarInstaller（P1，F14）

- Finder 的工具栏配置存在 `~/Library/Preferences/com.apple.finder.plist` 的 `NSToolbar Configuration Browser` 下（包括 `TB Item Identifiers`、`TB Item Plists` 等）。
- **在实现之前必须先在本机实测**：导出 plist，手动拖一个 App 到工具栏，再导出一次，对比差异，以实测得到的结构为准。
- 流程：
  1. 把配置备份到 `~/Library/Application Support/Go2Shell/finder-toolbar-backup-<时间戳>.plist`
  2. 写入新配置
  3. 执行 `killall cfprefsd Finder`，这一步要先弹窗征得用户确认
  4. 提供「从工具栏移除」
- 如果实测发现新系统上这种方式已经失效（结构变了，或者 Finder 不再读取），就放弃这个功能，只保留手动拖拽的说明。

## 4. 构建与签名（Makefile）

| 目标 | 作用 |
| --- | --- |
| `make build` | `swift build -c release`（加 `UNIVERSAL=1` 时追加 `--arch arm64 --arch x86_64`），然后组装 `.build/Go2Shell.app`，最后签名。`CONFIG=debug` 时构建 debug 包，输出到 `.build/dev/Go2Shell.app` |
| `make test` | `swift test` |
| `make run` | 构建后打开设置窗口 |
| `make install` | 构建后复制到 `/Applications/Go2Shell.app`（会覆盖已有的） |
| `make deploy` | 只复制已经构建好的包到 `/Applications/Go2Shell.app`，不重新构建（`install.sh` 用） |
| `make uninstall` | 删除 `/Applications/Go2Shell.app` |
| `make icon` | 运行 `Scripts/make-icon.swift`，生成 `Resources/AppIcon.icns` |
| `make reset-tcc` | `tccutil reset AppleEvents com.bingghost.Go2Shell` |
| `make clean` | 删除 `.build` 里的编译产物（debug 和 release），保留 SwiftPM 拉取的三方依赖（`checkouts`、`repositories`、`artifacts`、`workspace-state.json`） |

根目录的脚本是对 Makefile 的封装：

| 脚本 | 作用 |
| --- | --- |
| `start.sh [参数]` | 开发调试：`make build CONFIG=debug`，结束上一个 debug 实例，然后在前台直接运行可执行文件，参数原样传给 App |
| `build.sh` | `make build CONFIG=release` |
| `install.sh` | `build.sh` → 结束正在运行的 Go2Shell → `make deploy` → 打开 `/Applications/Go2Shell.app` → `clean.sh` |
| `clean.sh` | `make clean` |

- **签名**：
  - 用 `SIGN_ID ?= Apple Development` 自动选择钥匙串里的证书，命令是 `codesign --force --options runtime --timestamp=none --entitlements Resources/Go2Shell.entitlements --sign "$(SIGN_ID)"`。
  - 找不到证书时退回 ad-hoc 签名（`-`），并打印警告：ad-hoc 签名每次重新编译后都要重新授权自动化权限。
- **版本号**：从 git tag（`v*`）读取并写进 `CFBundleShortVersionString`；`CFBundleVersion` 用提交次数。

### Info.plist 关键字段
- `CFBundleIdentifier`: `com.bingghost.Go2Shell`
- `CFBundleExecutable`: `Go2Shell`
- `LSMinimumSystemVersion`: `14.0`
- `LSUIElement`: **true**。打开终端时完全不出现 Dock 图标，避免闪一下；进入设置模式时在代码里调用 `NSApp.setActivationPolicy(.regular)` 并激活 App，让设置窗口出现在 Dock 和 ⌘Tab 里。
- `NSAppleEventsUsageDescription`：用中英文说明「用于读取 Finder 当前目录，并控制终端打开新窗口」
- `CFBundleIconFile`: `AppIcon`
- `CFBundleDevelopmentRegion`: `en`，`CFBundleLocalizations`: `en`、`zh-Hans`

### Entitlements
```xml
<key>com.apple.security.automation.apple-events</key><true/>
```

## 5. 错误类型

```swift
public enum Go2ShellError: Error, Equatable {
    case automationDenied(target: String)
    case targetNotRunning(target: String)
    case notFileSystem
    case pathNotFound(String)
    case terminalNotFound(TerminalKind)
    case scriptFailed(code: Int, message: String)
}
```

## 6. 日志

- 每次启动记录：分流结果、拿到的路径（日志级别为 `.private`，避免泄露）、用的终端、各阶段耗时。
- 调试命令：`log stream --level debug --predicate 'subsystem == "com.bingghost.Go2Shell"'`。

## 7. 安全要点

1. AppleScript 源码全部是常量，运行时数据只通过 handler 参数传入。
2. 进入 shell 的只有命令模板渲染后的结果：路径一律用单引号引用。命令模板本身由用户自己填写，属于可信输入。
3. GenericLauncher 不经过 shell。
4. 不联网。

## 8. 已知风险

| 风险 | 应对 |
| --- | --- |
| 新系统修改 Finder 工具栏配置的格式 | F14 定为 P1；只要手动拖拽能用就不影响主流程 |
| 签名身份变化导致 TCC 失效 | 固定使用 Apple Development 证书；提供 `make reset-tcc` |
| 冷启动终端时出现两个窗口 | 根据 wasRunning 决定复用还是新建窗口（见 §3.4） |
| 第三方终端改了命令行参数或 bundle id | 支持多个 bundle id；开发时实测；出问题只影响这个终端 |
| Terminal.app 新标签依赖辅助功能权限 | 标为实验性；没有权限时退回新窗口 |

## 9. 测试方案

### 9.1 单元测试（`swift test`）
- **ShellQuote**：空字符串、空格、`'`、`"`、`$HOME`、`` `x` ``、`\`、换行、制表符、emoji、中文、开头是 `-` 的路径。
  - 除了检查输出字符串，还要做往返验证：用 `/bin/sh -c "printf %s <quoted>"` 输出原字符串，结果必须完全一致。
- **CommandTemplate**：默认模板、没有占位符、多个占位符、空模板、对 `"%PATH%"` / `'%PATH%'` 做 normalize。
- **LegacyMigration**：iTerm2 的两种 id、Terminal、未知 id、缺字段、`Use Window` 为 0 和 1。
- **LaunchRouter**：覆盖 §3.1 的 5 条规则以及它们之间的优先级。
- **Settings**：编码往返；对 `UserDefaultsSettingsStore` 用临时 suite 测试。

### 9.2 集成和手工测试清单（`docs/TEST-CHECKLIST.md`，在 G8 里建立）

**测试目录**：在 `~/tmp/go2shell-test/` 下建这几个目录：
- `a b`
- `it's`
- `$HOME`
- `` `whoami` ``
- `中文 目录`
- `🚀rocket`
- `-dash`
- 名字里带换行的目录

**用例**：

| # | 场景 | 期望 |
| --- | --- | --- |
| 1 | 在上面每个测试目录里分别点击工具栏按钮 | 终端打开，`pwd` 输出正确 |
| 2 | iTerm2 未运行 / 已运行 × 新窗口 / 新标签 | 只出现一个新窗口或新标签 |
| 3 | Terminal.app 未运行 / 已运行 × 新窗口 | 不出现多余的窗口 |
| 4 | 关掉所有 Finder 窗口后点击 | 在桌面打开 |
| 5 | Finder 窗口停在「最近使用」或 AirDrop | 弹出「不是文件夹」的提示 |
| 6 | 用 `make reset-tcc` 重置权限后，在权限弹窗里点「拒绝」 | 弹出引导提示，「打开系统设置」能跳到正确页面 |
| 7 | 按住 ⌥ 点击工具栏按钮 | 打开设置窗口 |
| 8 | 设置窗口开着时点击工具栏按钮 | 打开终端，设置窗口保留 |
| 9 | 在设置里选了 iTerm2，然后把 iTerm2 移走 | 退回 Terminal.app |
| 10 | 网络盘或外接盘上的目录 | 正常打开 |
| 11 | 性能 | 从点击到出现终端 ≤ 1s（终端已在运行） |
