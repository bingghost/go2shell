# Go2Term 开发计划

> 依据：`docs/01-PRD.md`、`docs/02-TECH-DESIGN.md`、`docs/03-REQUIREMENTS.md`
> 执行方式：每个里程碑对应 `docs/05-GOALS.md` 里的一条 `/goal` 命令，按顺序执行。
> 每个里程碑完成后：`make test` 通过，`make build` 通过，然后做一次本地 git commit（commit message 写明里程碑编号）。

## 总览

| 里程碑 | 内容 | 覆盖需求 | 预估 | 依赖 |
| --- | --- | --- | --- | --- |
| M0 | 工程骨架、签名、Makefile | INFRA-01～05 | 0.5d | — |
| M1 | 核心逻辑和单元测试 | CORE-01～08 | 0.5d | M0 |
| M2 | AppleScriptRunner、Finder 路径获取 | FINDER-01～05 | 0.5d | M1 |
| M3 | iTerm2 / Terminal.app 启动器、`--open` 参数 | TERM-01～04 | 1d | M2 |
| M4 | 启动编排、错误提示、日志 | APP-01 02 03 05 06 | 0.5d | M3 |
| M5 | 设置窗口、配置迁移、本地化 | UI-01～06、APP-04 | 1d | M4 |
| M6 | 新标签、更多终端、选中项优先 | TERM-05～07、FINDER-06 | 1d | M5 |
| M7 | 图标、一键装到工具栏 | UI-07 08、INFRA-05（icon） | 0.5–1d | M5 |
| M8 | 完整测试、性能、README、发布 v1.0.0 | QA-*、REL-*、INFRA-06 07 | 0.5d | M6 M7 |

M0–M5 完成后就可以替代旧 Go2Shell 日常使用（MVP），合计约 4 天；全部完成约 6 天。

## 里程碑详情

### M0 工程骨架
**任务**
1. `git init`；写 `.gitignore`。
2. 写 `Package.swift`：三个 target、Swift 6 语言模式、`.macOS(.v14)`。
3. 写占位代码：`Go2TermCore` 里放一个 `Version.swift`；`Go2Term/main.swift` 先只做一件事：弹一个空的 NSWindow，标题是 "Go2Term"。
4. 准备 `Resources/Info.plist`（字段见技术 §4）、`Go2Term.entitlements`、`en.lproj` 和 `zh-Hans.lproj` 两份空的 `Localizable.strings`。
5. 写 Makefile，包含 `build`、`test`、`run`、`install`、`uninstall`、`reset-tcc`、`clean`；签名逻辑按技术 §4。

**完成标准**
- `make build` 和 `make test` 都通过
- `codesign -dv --verbose=4 .build/Go2Term.app` 输出中有 `Authority=Apple Development` 和 `flags=...runtime`
- `open .build/Go2Term.app` 能看到窗口
- 已经 commit

### M1 核心逻辑
**任务**：按技术 §3.1，实现 ShellQuote、CommandTemplate、TerminalKind、Settings / SettingsStore / UserDefaultsSettingsStore、LegacyMigration、LaunchRouter、Go2TermError 和错误码映射，并按技术 §9.1 写单元测试。

**完成标准**
- `swift test` 全部通过，技术 §9.1 的每个用例都有对应测试
- ShellQuote 的往返测试是真的调用了 `/bin/sh`
- `Go2TermCore` 不 import AppKit

### M2 Finder 路径获取
**任务**
1. 写 `AppleScriptRunner`（技术 §3.2）。
2. 写 `FinderLocator`（技术 §3.3）。
3. 实现 `--print-finder-path` 参数：输出路径或错误信息，然后退出，退出码非 0 表示出错。

**完成标准**
- `.build/Go2Term.app/Contents/MacOS/Go2Term --print-finder-path` 在以下三种情况下输出都正确：
  - 打开一个普通目录窗口
  - 关掉所有 Finder 窗口
  - 窗口停在「最近使用」
- 第一次运行会弹出自动化授权请求，**这时需要用户手动点「允许」**
- 用 echo handler 往返测试特殊字符的结果已经写进 commit 说明或测试里

### M3 终端启动器
**任务**
1. 写 `TerminalLauncher` 协议、`LauncherFactory` 和 `ITermLauncher`、`AppleTerminalLauncher`（技术 §3.4，先只做新窗口）。
2. 实现 `--open <path>` 参数。
3. 用脚本生成技术 §9.2 列出的特殊字符测试目录。

**完成标准**
- 对每个特殊目录执行 `Go2Term --open <dir>`，iTerm2 都打开新窗口，`pwd` 输出正确
  - 验证方法：用 `osascript` 读取 iTerm 当前 session 的 `contents` 或 `path`，或者人工确认
- iTerm2 冷启动时只出现一个窗口
- 临时把设置改成 Terminal.app（`defaults write com.bingghost.Go2Term terminal appleTerminal`），用同样的方法验证
- 已经 commit

### M4 启动编排
**任务**：完善 `main.swift` 和 `AppController`：
- 分流
- 打开终端时不出现 Dock 图标，执行完就退出
- 设置模式
- reopen 处理
- 按技术 §3.6 实现 ErrorPresenter
- `os.Logger` 日志

然后用 `make install` 装到 `/Applications`，**请用户按住 ⌘ 把它拖到 Finder 工具栏**，再做真实的点击测试。

**完成标准**
- 从工具栏点击能在当前目录打开终端
- 按住 ⌥ 点击会打开设置窗口
- 用 `make reset-tcc` 重置后拒绝授权，会出现引导提示
- 用 `log stream` 能看到耗时日志

### M5 设置窗口、迁移、本地化
**任务**
- 用 SwiftUI 写设置窗口（技术 §3.7）
- 在 App 层读取 `com.zipzapmac.Go2Shell` 的旧配置并迁移（只执行一次）
- 实测 `Use Window` 的含义并修正迁移逻辑
- 完成中英文本地化

**完成标准**
- 第一次启动后，`defaults read com.bingghost.Go2Term` 显示的是从旧配置迁移过来的 iTerm2 和对应命令
- REQ-UI-01～06 的验收都通过
- grep 检查 Sources 里没有写死的中文界面文字

### M6 扩展终端与模式
**任务**
- iTerm2 新标签
- Terminal.app 新标签（实验性）
- GenericLauncher：先核实每个终端的 bundle id 和命令行参数；本机没装的终端在代码注释和 README 里标「未实测」
- 「选中项优先」选项

**完成标准**：REQ-TERM-05～07 和 REQ-FINDER-06 的验收都通过；设置界面上根据终端能力启用或禁用相应选项。

### M7 图标与工具栏
**任务**
- `Scripts/make-icon.swift`：原创图标。思路是一个圆角方块，里面画终端提示符 `>_` 和一个箭头。**不要模仿 Go2Shell 原来的图标**。
- 写 `make icon`。
- 一键装到工具栏：先实测 Finder plist 的结构。可行就实现，并且要备份、弹窗确认、提供卸载；不可行就把结论写进 `docs/02-TECH-DESIGN.md` §3.8，然后放弃这项。

**完成标准**：工具栏上的图标在深色和浅色模式下都清楚；REQ-UI-08 已经实现，或者有书面的放弃结论。

### M8 测试与发布
**任务**
- 写 `docs/TEST-CHECKLIST.md` 并全部跑完
- 测量性能
- 支持 `UNIVERSAL=1`
- 从 git tag 注入版本号
- 写 README.md 和 README_zh.md、CHANGELOG.md
- 打 tag `v1.0.0`

**完成标准**
- 测试清单全部通过
- 用 `git clone` 到临时目录后执行 `make install` 能成功
- tag 已经打上
- 如果已经配置了远端，就 push（按全局规则：push 当前分支和 tag）

## 协作约定
- 需要用户点击的步骤（TCC 授权弹窗、拖到工具栏、切换系统语言、卸载终端）：goal 执行到这一步时停下来，用一句话告诉用户要做什么，等用户确认后再继续。
- 不复制 `reference-solarhell/` 里的代码，只能参考思路。
- 发现文档里的设计和实测结果不一致时：以实测为准，同时更新 `docs/02-TECH-DESIGN.md`，在 commit message 里说明。
- 每个 goal 完成后，在 `docs/04-DEV-PLAN.md` 末尾的「进度」表里把对应里程碑标成完成。

## 进度

| 里程碑 | 状态 | 完成日期 | 备注 |
| --- | --- | --- | --- |
| M0 | ✅ | 2026-11-21 | SPM+Makefile 骨架；Apple Development 签名 + hardened runtime；占位窗口经 osascript 验证 |
| M1 | ✅ | 2026-11-21 | 核心逻辑 + 49 个 Swift Testing 测试（ShellQuote 经 /bin/sh 往返） |
| M2 | ✅ | 2026-11-21 | AppleScriptRunner（handler 传参）+ FinderLocator；--print-finder-path 三种情况实测通过 |
| M3 | ✅ | 2026-11-22 | iTerm2 热启动 10/10、Terminal.app 冷启动和热启动 10/10 通过；**iTerm2 冷启动推迟到 M8 测**（会话就跑在 iTerm 里，没法自己退出 iTerm 来测；用 Scripts/check-iterm-cold.sh 测） |
| M4 | ⬜ | | |
| M5 | ⬜ | | |
| M6 | ⬜ | | |
| M7 | ⬜ | | |
| M8 | ⬜ | | |
