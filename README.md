# Go2Shell

<img src="docs/images/icon-preview.png" alt="Go2Shell 图标" width="128">

放在 Finder 工具栏上的 macOS 小工具：点一下，就在当前 Finder 文件夹打开你常用的终端，然后自己退出。

它是 ZipZapMac 的旧版 Go2Shell 2.5 的替代品，沿用了这个名字。旧版只有 x86_64 版本，在 Apple Silicon 上要靠 Rosetta 2 运行，而且多年没有更新；这个项目用 Swift 重写，原生支持 Apple Silicon。

> **当前状态：开发中。** 核心功能已经可用（里程碑 M0–M5 完成），还没有发布安装包，需要自己从源码构建。第三方终端的支持和部分手工测试尚未完成，详见[支持的终端](#支持的终端)和[已知限制](#已知限制)。

## 能做什么

- **一键打开终端**：在 Finder 里点工具栏上的 Go2Shell，终端就在当前文件夹打开。Finder 没有打开窗口时使用桌面。
- **自定义命令**：打开终端后执行的命令可以改，默认是 `cd %PATH%; clear; pwd`。`%PATH%` 会被替换成已做好 shell 引用的路径，文件夹名里有空格、引号、`$`、中文都不需要自己加引号。
- **新窗口或新标签页**：可以选择每次开新窗口，还是在已有窗口里开新标签页。
- **选中文件夹优先**（可选）：在 Finder 里恰好选中一个文件夹时，在该文件夹里打开，而不是当前窗口的文件夹。
- **沿用旧版 Go2Shell 的设置**：第一次运行时读取旧 Go2Shell 的终端、命令和窗口模式，只迁移一次。
- **出错有提示**：没有自动化权限、当前窗口是「最近使用」「隔空投送」这类虚拟位置、文件夹已被删除时，会弹窗说明原因；权限问题可以直接跳到系统设置。
- **中英文界面**：跟随系统语言。

## 支持的终端

| 终端 | 在文件夹中打开 | 执行自定义命令 | 新标签页 | 状态 |
| --- | --- | --- | --- | --- |
| Terminal.app | ✅ | ✅ | 实验性 | 冷启动和热启动已实测 |
| iTerm2 | ✅ | ✅ | ✅ | 热启动已实测，冷启动待测 |
| Ghostty、WezTerm、kitty、Alacritty、Warp | ✅ | 不支持 | 不支持 | 代码已实现，尚未逐个实测 |

- 设置里选的终端没有安装时，会改用 Terminal.app。
- Terminal.app 的新标签页是通过模拟 ⌘T 实现的，需要辅助功能权限；没有权限时改为打开新窗口。

## 环境要求

- macOS 14 或更高版本
- Xcode 或 Xcode 命令行工具（提供 Swift 6 工具链）

## 安装

目前没有发布安装包，需要从源码构建：

```sh
git clone https://github.com/bingghost/go2shell.git
cd go2shell
./install.sh
```

`install.sh` 会构建 release 版本、安装到 `/Applications/Go2Shell.app`、打开设置窗口，然后清理编译产物。

> **注意：** 如果「应用程序」里还装着旧版 Go2Shell 2.5，它也叫 `Go2Shell.app`，安装时会被替换。旧版 App 不会被删除，而是移到 `~/Library/Application Support/Go2Shell/Replaced Apps/`；旧版的设置不受影响，第一次运行时仍会迁移过来。

构建时默认用钥匙串里第一个 "Apple Development" 证书签名。没有证书时改用 ad-hoc 签名，这种情况下**每次重新构建后都要重新授予自动化权限**。

## 第一次使用

1. 打开「应用程序」文件夹，按住 ⌘，把 Go2Shell 拖到任意 Finder 窗口的工具栏上。设置窗口里的「在 Finder 中显示 Go2Shell」按钮可以帮你找到它。
2. 在 Finder 里打开一个文件夹，点击工具栏上的 Go2Shell。
3. 第一次点击时 macOS 会询问是否允许 Go2Shell 控制 Finder 和终端，选择允许。
4. 终端在该文件夹打开，Go2Shell 自动退出，不会在 Dock 里留下图标。

之后要修改设置：按住 ⌥ 点击工具栏上的 Go2Shell，或者直接从「应用程序」里打开它。

每个设置的含义、命令模板的写法、权限和常见问题，见[使用文档](docs/USAGE.md)。

## 设置

| 设置项 | 说明 | 默认值 |
| --- | --- | --- |
| 使用的终端 | 点击工具栏按钮时打开哪个终端 | Terminal.app |
| 命令 | 打开终端后执行的命令，`%PATH%` 代表文件夹路径；设置窗口里有实时预览 | `cd %PATH%; clear; pwd` |
| 打开方式 | 新窗口或新标签页 | 新窗口 |
| 只选中一个文件夹时，在该文件夹中打开 | 见上文「选中文件夹优先」 | 关闭 |

命令里不需要给 `%PATH%` 加引号。命令留空时相当于 `cd %PATH%`；命令里没有 `%PATH%` 时，会自动在前面加上 `cd <路径>;`。

## 卸载

```sh
make uninstall                          # 删除 /Applications/Go2Shell.app
defaults delete com.bingghost.Go2Shell   # 删除设置
```

工具栏上的图标需要手动移除：按住 ⌘ 把它拖出工具栏。

## 已知限制

- 没有发布安装包，没有做公证，也没有自动更新。
- 第三方终端（Ghostty、WezTerm、kitty、Alacritty、Warp）只能在文件夹中打开，不能执行自定义命令，也不支持新标签页。
- 以下项目尚未完成手工测试：iTerm2 冷启动、从工具栏点击、按住 ⌥ 打开设置、拒绝授权后的提示。
- 需要自己把图标拖到工具栏，暂时没有一键安装到工具栏的功能。
- 只在 Apple Silicon 上测试过；可以构建 Universal 版本（`make build UNIVERSAL=1`），但没有在 Intel 机器上测试。

## 开发

```sh
make build        # 构建并签名 .build/Go2Shell.app
make test         # 运行单元测试
./start.sh        # 构建 debug 版本并在前台运行，不带参数时打开设置窗口
./clean.sh        # 删除编译产物
make help         # 查看全部 make 目标
```

不经过 Finder 工具栏的调试参数：

```sh
./start.sh --print-finder-path    # 打印 Finder 最前窗口的路径
./start.sh --open ~/Downloads     # 按当前设置在指定文件夹打开终端
./start.sh --settings             # 打开设置窗口
```

从终端直接运行时，自动化权限算在运行它的那个终端名下，而不是 Go2Shell。权限出问题时可以用 `make reset-tcc` 重置。

应用图标由 `Scripts/make-icon.swift` 绘制，修改后用 `make icon` 重新生成。

文档在 [`docs/`](docs/)：

- [使用文档](docs/USAGE.md)
- [产品需求](docs/01-PRD.md)
- [技术设计](docs/02-TECH-DESIGN.md)
- [需求清单](docs/03-REQUIREMENTS.md)
- [开发计划与进度](docs/04-DEV-PLAN.md)

## 许可

尚未选定许可证。
