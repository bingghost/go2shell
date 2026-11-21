# Go2Term 需求拆解

> 来源：`docs/01-PRD.md`（F*/N*）、`docs/02-TECH-DESIGN.md`（§*）
> 编号规则：REQ-模块-序号。每条需求都要有可以验证的验收标准。优先级 P0 必须做，P1 应该做。
> 每条需求标注了对应的里程碑（M*，见 `docs/04-DEV-PLAN.md`）。

## A. 工程基础（INFRA）

| ID | 需求 | 验收标准 | 优先级 | 来源 | 里程碑 |
| --- | --- | --- | --- | --- | --- |
| REQ-INFRA-01 | 有 git 仓库，`.gitignore` 排除 `.build/`、`.swiftpm/`、`reference-solarhell/`、`*.xcuserstate`、`.DS_Store` | `git status` 干净，参考仓库不会被跟踪 | P0 | — | M0 |
| REQ-INFRA-02 | SPM 工程分成 `Go2TermCore`（library）、`Go2Term`（executable）、`Go2TermCoreTests` 三个 target，Swift 6 语言模式，最低 macOS 14 | `swift build` 和 `swift test` 都能通过 | P0 | 技术 §1 §2 | M0 |
| REQ-INFRA-03 | 用 Makefile 组装 `.app`：可执行文件、Info.plist、icns、lproj 各就各位 | `make build` 产出 `.build/Go2Term.app`，`open` 能正常启动 | P0 | 技术 §4 | M0 |
| REQ-INFRA-04 | 签名：优先用 Apple Development 证书，开启 Hardened Runtime，带 apple-events 权限；找不到证书时退回 ad-hoc 并给出警告 | `codesign -dv --verbose=4` 显示 Authority=Apple Development、flags 含 runtime；`codesign -d --entitlements -` 能看到 apple-events | P0 | N8 | M0 |
| REQ-INFRA-05 | 提供 make 目标：`test`、`run`、`install`、`uninstall`、`reset-tcc`、`clean`、`icon` | 每个目标都能正确执行 | P0 | 技术 §4 | M0 / M7 |
| REQ-INFRA-06 | 版本号从 git tag 注入 | 打上 `v0.1.0` 后，App 的 `CFBundleShortVersionString` 是 0.1.0 | P1 | 技术 §4 | M8 |
| REQ-INFRA-07 | 设置 `UNIVERSAL=1` 时编译出 Universal 二进制 | `lipo -archs` 输出 `x86_64 arm64` | P1 | N1 | M8 |

## B. 核心逻辑（CORE，纯 Swift，有单元测试）

| ID | 需求 | 验收标准 | 优先级 | 来源 | 里程碑 |
| --- | --- | --- | --- | --- | --- |
| REQ-CORE-01 | `ShellQuote.quote`：POSIX 单引号引用 | 技术 §9.1 列出的所有用例都能通过 `/bin/sh` 往返验证 | P0 | N3 | M1 |
| REQ-CORE-02 | `CommandTemplate.render`：替换 `%PATH%`；没有占位符时在前面加 `cd`；模板为空时等同于 `cd %PATH%` | 单元测试覆盖这几种情况 | P0 | F5 | M1 |
| REQ-CORE-03 | `CommandTemplate.normalize`：去掉 `%PATH%` 两边多余的引号 | 测试 `"%PATH%"` 和 `'%PATH%'` | P0 | F8 | M1 |
| REQ-CORE-04 | `TerminalKind`：列出全部 7 种终端的元数据（bundle id、显示名、是否支持命令、是否支持新标签） | 单元测试检查每一项元数据都完整 | P0 | F3 F4 F13 | M1 |
| REQ-CORE-05 | `Settings` 模型、默认值和 `SettingsStore` 协议；`UserDefaultsSettingsStore` 的 key 与技术 §3.1 一致 | 编码往返测试；用临时 suite 做读写测试 | P0 | F6 | M1 |
| REQ-CORE-06 | `LegacyMigration`：把旧 Go2Shell 的配置字典转换成 `Settings` | 技术 §9.1 列出的迁移用例都通过 | P0 | F8 | M1 |
| REQ-CORE-07 | `LaunchRouter`：按 5 条规则和它们的优先级做分流 | 每条规则至少一个用例，另外有优先级冲突的用例 | P0 | F1 F7 | M1 |
| REQ-CORE-08 | 定义 `Go2TermError`，以及从 AppleScript 错误码到它的映射函数（-1743、-600、-609 等） | 单元测试覆盖这个映射 | P0 | 技术 §5 | M1 |

## C. Finder 集成（FINDER）

| ID | 需求 | 验收标准 | 优先级 | 来源 | 里程碑 |
| --- | --- | --- | --- | --- | --- |
| REQ-FINDER-01 | `AppleScriptRunner`：编译固定的脚本，通过 handler 传参调用，并把错误映射好 | 用一个测试脚本 `on echo(x) return x end` 往返传含特殊字符的字符串，结果不变 | P0 | 技术 §3.2 | M2 |
| REQ-FINDER-02 | `FinderLocator.frontWindowDirectory()`：取最前窗口的目录 | `Go2Term --print-finder-path` 输出 Finder 最前窗口的 POSIX 路径 | P0 | F2 | M2 |
| REQ-FINDER-03 | 没有 Finder 窗口时退回 `~/Desktop`（不能用 `URL(string:)` 拼路径） | 关掉所有窗口后，输出 `/Users/<you>/Desktop` | P0 | F2 | M2 |
| REQ-FINDER-04 | 窗口指向虚拟位置时抛出 `notFileSystem` | 打开「最近使用」窗口后执行，返回对应的错误 | P0 | F2 S4 | M2 |
| REQ-FINDER-05 | 拿到的路径必须存在而且是目录，否则做相应处理 | 代码里有校验，并有单元测试或手工测试 | P0 | N4 | M2 |
| REQ-FINDER-06 | 选中项优先（需要开启设置）：只选中一个文件夹时，在这个文件夹里打开 | 手工测试 | P1 | F15 | M6 |

## D. 终端启动（TERM）

| ID | 需求 | 验收标准 | 优先级 | 来源 | 里程碑 |
| --- | --- | --- | --- | --- | --- |
| REQ-TERM-01 | `TerminalLauncher` 协议和 `LauncherFactory`；配置的终端没有安装时退回 Terminal.app | 代码审查，并有手工测试 | P0 | 技术 §3.4 | M3 |
| REQ-TERM-02 | iTerm2 新窗口：冷启动时复用 iTerm 自动打开的那个窗口；已在运行时新建窗口；用 `write text` 执行渲染好的命令 | 手工清单 #1 #2 | P0 | F3 | M3 |
| REQ-TERM-03 | Terminal.app 新窗口：冷启动时用 `in front window`；已在运行时用 `do script` | 手工清单 #3 | P0 | F4 | M3 |
| REQ-TERM-04 | `--open <path>` 参数：跳过 Finder，直接用当前设置打开终端 | `Go2Term --open "$HOME/tmp/go2term-test/it's"` 打开终端，`pwd` 输出正确 | P0 | 技术 §3.1 | M3 |
| REQ-TERM-05 | iTerm2 新标签 | 没有窗口时新建窗口，有窗口时新建标签 | P1 | F12 | M6 |
| REQ-TERM-06 | Terminal.app 新标签（实验性）：用 System Events 模拟 ⌘T；没有辅助功能权限时退回新窗口并提示 | 手工测试 | P1 | F12 | M6 |
| REQ-TERM-07 | 用 GenericLauncher 支持 Ghostty、WezTerm、Kitty、Alacritty、Warp：不经过 shell，bundle id 和参数都要实测核实 | 本机装了的终端都要实测；没装的在文档里注明「未实测」 | P1 | F13 | M6 |

## E. 启动编排（APP）

| ID | 需求 | 验收标准 | 优先级 | 来源 | 里程碑 |
| --- | --- | --- | --- | --- | --- |
| REQ-APP-01 | `main.swift` 收集 LaunchContext 并分流；打开终端时不出现 Dock 图标，执行完就退出 | 从工具栏点击后，进程在 2s 内退出（用 `pgrep` 验证） | P0 | F1 N2 | M4 |
| REQ-APP-02 | 设置模式切换到 `.regular` 并激活，最后一个窗口关掉时退出 | 手工测试 | P0 | F7 | M4 |
| REQ-APP-03 | 处理 reopen：设置窗口开着时点击工具栏，会执行一次打开终端 | 手工清单 #8 | P0 | PRD §5 | M4 |
| REQ-APP-04 | 第一次启动时只执行一次迁移（`didMigrate`） | 第二次启动不会重复迁移，用日志验证 | P0 | F8 | M5 |
| REQ-APP-05 | `ErrorPresenter`：按技术 §3.6 的表格给出提示；「打开系统设置」能跳到自动化页面 | 手工清单 #5 #6 | P0 | F9 S4 | M4 |
| REQ-APP-06 | `os.Logger` 日志：分流结果、终端、各阶段耗时；路径用 `.private` 级别 | 用 `log stream` 能看到这些信息 | P0 | 技术 §6 | M4 |

## F. 设置界面（UI）

| ID | 需求 | 验收标准 | 优先级 | 来源 | 里程碑 |
| --- | --- | --- | --- | --- | --- |
| REQ-UI-01 | 终端单选列表：只列已安装的终端，带图标 | 手工测试 | P0 | F6 | M5 |
| REQ-UI-02 | 命令模板编辑，带「恢复默认」和实时预览；终端不支持执行命令时这部分不可用，并说明原因 | 手工测试 | P0 | F5 F6 | M5 |
| REQ-UI-03 | 新窗口 / 新标签选择；终端不支持新标签时禁用 | 手工测试 | P0 | F6 | M5 |
| REQ-UI-04 | 「测试一下」按钮：在 `~` 打开一次终端 | 手工测试 | P0 | 技术 §3.7 | M5 |
| REQ-UI-05 | 工具栏安装说明，加「在 Finder 中显示 Go2Term」按钮 | 手工测试 | P0 | F10 | M5 |
| REQ-UI-06 | 中英文本地化：所有界面文字和弹窗都走 Localizable.strings | 把系统语言切成英文或中文后，界面文字跟着切换；另外用 grep 检查没有写死在代码里的中文 | P0 | F11 | M5 |
| REQ-UI-07 | App 图标：原创设计，由 `Scripts/make-icon.swift` 生成，深色和浅色工具栏下都清楚 | 用 `make icon` 生成；手工在工具栏里看效果 | P0 | F10 | M7 |
| REQ-UI-08 | 一键装到 / 移除工具栏：先备份，弹窗确认后才重启 Finder | 先实测确认可行；不可行就记录结论并放弃这项 | P1 | F14 | M7 |

## G. 质量与发布（QA / REL）

| ID | 需求 | 验收标准 | 优先级 | 来源 | 里程碑 |
| --- | --- | --- | --- | --- | --- |
| REQ-QA-01 | 写 `docs/TEST-CHECKLIST.md`，并把所有用例跑完 | 每一项都标了通过或失败，失败的已经修复 | P0 | 技术 §9.2 | M8 |
| REQ-QA-02 | 性能：终端已在运行时 ≤ 1s 出现窗口 | 按日志里的耗时记录 | P0 | N2 | M8 |
| REQ-REL-01 | README（中英文）：功能、安装、工具栏设置、权限、排错、卸载 | 文件存在，按 README 的说明能在新环境装好 | P0 | — | M8 |
| REQ-REL-02 | CHANGELOG 和 `v1.0.0` tag | tag 存在 | P0 | — | M8 |
| REQ-REL-03 | 文档里给出停用旧 Go2Shell 的方法：从工具栏拖走、把旧 App 移到废纸篓 | 写进 README（不自动执行） | P0 | — | M8 |
