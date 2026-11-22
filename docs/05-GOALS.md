# Go2Shell Goal 命令列表

按 G0 → G8 的顺序，一次复制一条到 Claude Code 里执行。上一条完成并确认之后，再执行下一条。
每条命令都可以单独执行，里面已经包含了通用约束：

- 先读 `docs/01-PRD.md`、`docs/02-TECH-DESIGN.md`、`docs/03-REQUIREMENTS.md`、`docs/04-DEV-PLAN.md` 里和这一步相关的部分
- 不复制 `reference-solarhell/` 里的代码
- 设计和实测结果不一致时，以实测为准，并同步更新文档
- 需要用户点击授权或拖拽的步骤，停下来提示用户
- 完成后 `make test` 和 `make build` 都要通过，更新 `04-DEV-PLAN.md` 的进度表，然后做一次本地 git commit（不 push，最后一步 G8 除外）

---

## G0 工程骨架（M0）

```
/goal 在 /Users/bobby/Code/Tools/go2shell 完成 Go2Shell 的里程碑 M0（工程骨架）。先阅读 docs/01-PRD.md、docs/02-TECH-DESIGN.md（§1 §2 §4）、docs/03-REQUIREMENTS.md（REQ-INFRA-01～05）、docs/04-DEV-PLAN.md（M0）。要做的事：git init，写 .gitignore（排除 .build/ .swiftpm/ reference-solarhell/ .DS_Store），设置仓库本地的 user.name=bingghost；写 Package.swift，包含 Go2ShellCore（library）、Go2Shell（executable）、Go2ShellCoreTests 三个 target，使用 Swift 6 语言模式、最低 macOS 14；写占位代码，让 App 启动后显示一个标题为 Go2Shell 的空窗口；按技术文档 §4 准备 Resources/Info.plist（LSUIElement=true，以及 NSAppleEventsUsageDescription）、Go2Shell.entitlements、en.lproj 和 zh-Hans.lproj 的 Localizable.strings；写 Makefile，提供 build/test/run/install/uninstall/reset-tcc/clean 目标，签名默认使用钥匙串里的 "Apple Development" 证书并开启 hardened runtime，找不到证书时退回 ad-hoc 并打印警告。不要复制 reference-solarhell 里的代码。完成标准：make build 和 make test 都通过；codesign -dv --verbose=4 .build/Go2Shell.app 的输出包含 Authority=Apple Development 和 runtime 标志；codesign -d --entitlements - 能看到 com.apple.security.automation.apple-events；open .build/Go2Shell.app 后能看到窗口（自己用截图或 osascript 验证）；docs/04-DEV-PLAN.md 的进度表里 M0 已标为完成；已完成一次本地 git commit，message 以 "M0:" 开头。
```

## G1 核心逻辑与单元测试（M1）

```
/goal 完成 Go2Shell 的里程碑 M1（核心逻辑）。先阅读 docs/02-TECH-DESIGN.md 的 §3.1、§5、§9.1，以及 docs/03-REQUIREMENTS.md 的 REQ-CORE-01～08。在 Sources/Go2ShellCore 里实现 ShellQuote、CommandTemplate（render 和 normalize）、TerminalKind（7 种终端的元数据）、Settings、SettingsStore 和 UserDefaultsSettingsStore、LegacyMigration、LaunchRouter（5 条分流规则及其优先级）、Go2ShellError 以及 AppleScript 错误码映射。Go2ShellCore 不能 import AppKit。在 Tests/Go2ShellCoreTests 里覆盖技术文档 §9.1 列出的全部用例，其中 ShellQuote 必须真的调用 /bin/sh -c 'printf %s ...' 做往返验证，测试目录名要包含空格、单引号、双引号、$、反引号、反斜杠、换行、制表符、emoji、中文、以 - 开头的名字。完成标准：swift test 全部通过，测试数量不少于 30 个；make build 通过；进度表里 M1 已标为完成；已完成本地 commit，message 以 "M1:" 开头。
```

## G2 Finder 路径获取（M2）

```
/goal 完成 Go2Shell 的里程碑 M2（Finder 路径获取）。先阅读 docs/02-TECH-DESIGN.md 的 §3.2 和 §3.3，以及 REQ-FINDER-01～05。实现 AppleScriptRunner：编译固定的 AppleScript 源码，通过 kASSubroutineEvent 调用 handler 并传参，脚本源码里绝对不能拼接运行时字符串，错误要映射成 Go2ShellError。实现 FinderLocator：取 Finder 最前窗口的 POSIX 路径；没有窗口时退回 ~/Desktop；虚拟位置要抛出 notFileSystem；拿到的路径要校验存在并且是目录。增加 --print-finder-path 调试参数：成功时把路径输出到 stdout 并以退出码 0 退出，失败时把错误输出到 stderr 并以非 0 退出码退出。另外写一个 echo handler 的往返测试（可以作为测试 target 里依赖 OSAKit/NSAppleScript 的测试，或者作为 App 的调试参数），验证特殊字符不会被破坏。第一次调用 Finder 时会弹出自动化授权，这时停下来提示我点「允许」，等我确认后再继续。完成标准：在以下三种情况下运行 .build/Go2Shell.app/Contents/MacOS/Go2Shell --print-finder-path，结果都符合预期：(1) 用 open 打开 ~/Downloads 窗口，(2) 用 osascript 关掉所有 Finder 窗口，(3) 窗口停在「最近使用」；make test 和 make build 都通过；进度表里 M2 已标为完成；已完成本地 commit，message 以 "M2:" 开头。
```

## G3 iTerm2 / Terminal.app 启动器（M3）

```
/goal 完成 Go2Shell 的里程碑 M3（终端启动器）。先阅读 docs/02-TECH-DESIGN.md 的 §3.4，以及 REQ-TERM-01～04。实现 TerminalLauncher 协议、LauncherFactory（配置的终端没装时退回 Terminal.app）、ITermLauncher 和 AppleTerminalLauncher（这一步只做新窗口模式）：冷启动时复用终端自动打开的那个窗口，已在运行时新建窗口；命令用 CommandTemplate.render 渲染，然后作为 handler 参数传进 AppleScript。实现 --open <path> 参数：跳过 Finder，直接按当前设置打开终端。写一个 Scripts/make-test-dirs.sh，在 ~/tmp/go2shell-test/ 下创建技术文档 §9.2 列出的所有特殊字符目录（包括名字里带换行的目录）。验证方法：对每个测试目录执行 Go2Shell --open <dir>，然后用 osascript 读取 iTerm2 当前 session 的 contents（Terminal.app 则读取 front window 的 history），确认 pwd 的输出等于这个目录；分别验证 iTerm2 冷启动（先用 osascript 退出 iTerm）和已在运行两种情况，并确认窗口数量正确，没有多余的窗口；然后执行 defaults write com.bingghost.Go2Shell terminal appleTerminal，对 Terminal.app 重复同样的验证，最后把设置改回 iTerm2。需要授权控制 iTerm 或 Terminal 时，停下来提示我点「允许」。完成标准：上面的验证全部通过，并把验证结果整理成表格写进 commit message；make test 和 make build 都通过；进度表里 M3 已标为完成；已完成本地 commit，message 以 "M3:" 开头。
```

## G4 启动编排、错误提示、日志（M4）

```
/goal 完成 Go2Shell 的里程碑 M4（启动编排）。先阅读 docs/02-TECH-DESIGN.md 的 §3.5、§3.6、§6，以及 REQ-APP-01、02、03、05、06。在 main.swift 和 AppController 里接入 LaunchRouter：打开终端时不出现 Dock 图标，执行完就退出；设置模式下 setActivationPolicy(.regular) 并激活 App，关掉最后一个窗口时退出（设置窗口这一步先用占位界面）；在 applicationShouldHandleReopen 里执行一次打开终端；按技术文档 §3.6 实现 ErrorPresenter，其中「打开系统设置」按钮跳转到 x-apple.systempreferences:com.apple.preference.security?Privacy_Automation；用 os.Logger 记录分流结果、终端和各阶段耗时，路径用 .private 级别。然后执行 make install，停下来请我按住 ⌘ 把 /Applications/Go2Shell.app 拖到 Finder 工具栏，并请我做这几项点击测试：普通目录、按住 ⌥ 点击、设置窗口开着时再点击、make reset-tcc 之后拒绝授权。在我测试的同时，你用 log stream --predicate 'subsystem == "com.bingghost.Go2Shell"' 收集日志，并用 pgrep 确认进程在 2 秒内退出。完成标准：上面 4 项测试我都确认通过；日志里能看到耗时；make test 和 make build 都通过；进度表里 M4 已标为完成；已完成本地 commit，message 以 "M4:" 开头。
```

## G5 设置窗口、迁移、本地化（M5）

```
/goal 完成 Go2Shell 的里程碑 M5（设置窗口、迁移、本地化）。先阅读 docs/01-PRD.md 的 F5～F11、docs/02-TECH-DESIGN.md 的 §3.1 LegacyMigration 和 §3.7，以及 REQ-UI-01～06、REQ-APP-04。用 SwiftUI 实现设置窗口，包括：终端单选列表（只列已安装的终端，带 App 图标）、命令模板编辑（带「恢复默认」按钮，预览用 /Users/you/My Project 实时渲染）、新窗口或新标签选择（根据终端能力启用或禁用）、「测试一下」按钮（在 ~ 打开终端）、工具栏安装说明和「在 Finder 中显示 Go2Shell」按钮、版本号。在 App 层实现第一次启动时的迁移：从 UserDefaults(suiteName: "com.zipzapmac.Go2Shell") 读取旧配置，读不到就退回去解析 defaults export 的结果，然后写入 didMigrate。要实测 Use Window 的含义：请我在旧 Go2Shell 的设置里切换 New Window 和 New Tab，你对比切换前后 defaults read com.zipzapmac.Go2Shell 的变化，据此修正 LegacyMigration 和它的单元测试，并更新技术文档。所有界面文字和弹窗都要走 en 和 zh-Hans 的 Localizable.strings。完成标准：先执行 defaults delete com.bingghost.Go2Shell，再启动 App，之后 defaults read com.bingghost.Go2Shell 显示 terminal=iTerm2，命令与旧配置一致，didMigrate=1；第二次启动不会重复迁移；用 grep 检查 Sources/Go2Shell 里没有写死的中文界面字符串；用 -AppleLanguages '(en)' 和 '(zh-Hans)' 启动时界面语言正确（截图确认）；make test 和 make build 都通过；进度表里 M5 已标为完成；已完成本地 commit，message 以 "M5:" 开头。到这里 MVP 完成，提醒我可以开始用新的 Go2Shell 替换旧 Go2Shell。
```

## G6 新标签、更多终端、选中项优先（M6）

```
/goal 完成 Go2Shell 的里程碑 M6（扩展终端与模式）。先阅读 docs/02-TECH-DESIGN.md 的 §3.3 和 §3.4，以及 REQ-TERM-05～07、REQ-FINDER-06。实现以下功能：(1) iTerm2 新标签：没有窗口时新建窗口，有窗口时在当前窗口新建标签；(2) Terminal.app 新标签（实验性）：用 System Events 模拟 ⌘T，没有辅助功能权限时退回新窗口并提示一次；(3) GenericLauncher 支持 Ghostty、WezTerm、Kitty、Alacritty、Warp：先查各终端的官方文档，有安装包的话也读一下它的 Info.plist，核实 bundle id 和指定工作目录的命令行参数；整个实现不经过 shell，用 NSWorkspace.OpenConfiguration；把核实结果更新到技术文档 §3.1 的表格里，本机没装的终端标注「未实测」；(4) 「选中项优先」设置：只选中一个文件夹时，在这个文件夹里打开。设置界面要根据每个终端的 supportsCommand 和 supportsNewTab 启用或禁用相应选项。验证：iTerm2 新标签模式在冷启动和已运行两种情况下用 --open 测试，用 osascript 统计窗口和标签数量；本机装了的其他终端逐个用 --open 测试；选中项优先在 Finder 里实际操作测试。完成标准：上面的验证都通过，或者已经记录了「未实测」；make test 和 make build 都通过；进度表里 M6 已标为完成；已完成本地 commit，message 以 "M6:" 开头。
```

## G7 图标与一键装到工具栏（M7）

```
/goal 完成 Go2Shell 的里程碑 M7（图标与工具栏）。先阅读 docs/02-TECH-DESIGN.md 的 §3.8，以及 REQ-UI-07、REQ-UI-08。(1) 写 Scripts/make-icon.swift：用 AppKit 或 CoreGraphics 画一个原创图标，不要模仿旧 Go2Shell 的图标。图标是一个圆角方块，里面有终端提示符 >_ 和一个表示「进入」的箭头，生成全部尺寸并用 iconutil 打包成 Resources/AppIcon.icns；在 Makefile 里加上 make icon；把预览图保存为 docs/images/icon-preview.png 给我看。(2) 一键装到工具栏：先执行 defaults export com.apple.finder 把当前配置备份到 scratchpad，然后请我手动把某个 App 拖到工具栏，你再导出一次并对比两次的差异，弄清楚 NSToolbar Configuration Browser 的结构。如果可行，就实现 ToolbarInstaller：先把配置备份到 ~/Library/Application Support/Go2Shell/，修改前弹窗征得确认，然后重启 Finder，同时提供「从工具栏移除」；在设置窗口里加上对应的按钮。如果实测发现不可行，就把结论写进技术文档 §3.8，并在 REQ-UI-08 上标注放弃。改动 Finder 配置和执行 killall Finder 之前必须先问我。完成标准：在深色和浅色模式下，图标在 Finder 工具栏上都清楚（请我确认）；REQ-UI-08 要么已经实现并通过安装和移除的往返测试，要么已经写明放弃的原因；make test 和 make build 都通过；进度表里 M7 已标为完成；已完成本地 commit，message 以 "M7:" 开头。
```

## G8 完整测试与发布 v1.0.0（M8）

```
/goal 完成 Go2Shell 的里程碑 M8（测试与发布）。先阅读 docs/02-TECH-DESIGN.md 的 §9，以及 REQ-QA-*、REQ-REL-*、REQ-INFRA-06、REQ-INFRA-07。(1) 根据技术文档 §9.2 写 docs/TEST-CHECKLIST.md，逐项执行：能自动化的用 --open、osascript、log stream 和 pgrep 完成；需要我操作的停下来一次性列出来让我做；把每一项标成通过或失败，失败的项修复后重新测试。(2) 性能：从日志里取 10 次打开耗时，算出中位数，目标是 ≤ 1s，把结果写进测试清单。(3) Makefile 支持 UNIVERSAL=1，用 lipo -archs 验证；从 git tag 注入版本号。(4) 写 README.md（英文）和 README_zh.md：用途、功能、安装（make install）、添加到工具栏、权限说明、排错（make reset-tcc、日志命令）、卸载、怎么停用旧 Go2Shell，以及各终端支持情况和实测状态；再写 CHANGELOG.md。(5) 验证：git clone 到 scratchpad 的临时目录里执行 make build，确认能成功。(6) 先 commit，message 以 "M8:" 开头，再打 tag v1.0.0。(7) 询问我 GitHub 仓库是否已经建好（默认是 git@github-personal:bingghost/go2shell.git）；建好了就添加 origin，并 push 当前分支和 v1.0.0 tag。完成标准：测试清单全部通过；Universal 构建验证通过；从全新 clone 能构建成功；tag v1.0.0 已经存在；进度表里 M8 已标为完成；如果配置了远端，push 已经成功。
```
