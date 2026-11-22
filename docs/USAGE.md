# Go2Shell 使用文档

Go2Shell 是放在 Finder 工具栏上的一个按钮：点一下，就在当前 Finder 文件夹打开终端。本文说明怎么安装、怎么用、每个设置的含义，以及出问题时怎么办。

> Go2Shell 仍在开发中，目前需要从源码构建。哪些终端和功能已经实测，见 [README 的「支持的终端」和「已知限制」](../README.md#支持的终端)。

## 目录

- [安装](#安装)
- [把 Go2Shell 放到 Finder 工具栏](#把-go2shell-放到-finder-工具栏)
- [日常使用](#日常使用)
- [设置](#设置)
- [命令模板](#命令模板)
- [权限](#权限)
- [从旧版 Go2Shell 迁移](#从旧版-go2shell-迁移)
- [常见问题](#常见问题)
- [命令行参数](#命令行参数)
- [卸载](#卸载)

## 安装

需要 macOS 14 或更高版本，以及 Xcode 或 Xcode 命令行工具。

```sh
git clone https://github.com/bingghost/go2shell.git
cd go2shell
./install.sh
```

脚本会构建 Go2Shell、安装到 `/Applications/Go2Shell.app`，并打开设置窗口。

如果「应用程序」里还装着 ZipZapMac 的旧版 Go2Shell 2.5，它也叫 `Go2Shell.app`，安装时会被替换。旧版 App 不会被删除，而是移到 `~/Library/Application Support/Go2Shell/Replaced Apps/`，想恢复时把它移回去即可。旧版的设置不受影响，见[从旧版 Go2Shell 迁移](#从旧版-go2shell-迁移)。

## 把 Go2Shell 放到 Finder 工具栏

1. 在 Finder 里打开「应用程序」文件夹，找到 Go2Shell。也可以在设置窗口里点「在 Finder 中显示 Go2Shell」。
2. **按住 ⌘**，把 Go2Shell 拖到 Finder 窗口顶部的工具栏上，松开。
3. 工具栏上出现 Go2Shell 的图标，所有 Finder 窗口都会有。

要移除时，按住 ⌘ 把图标拖出工具栏。

## 日常使用

| 操作 | 结果 |
| --- | --- |
| 在 Finder 里点击工具栏上的 Go2Shell | 在当前窗口的文件夹打开终端 |
| 按住 ⌥ 点击工具栏上的 Go2Shell | 打开设置窗口 |
| 从「应用程序」、启动台或 Spotlight 打开 Go2Shell | 打开设置窗口 |
| 设置窗口开着时再点工具栏上的 Go2Shell | 打开终端，设置窗口保持不动 |

打开终端后 Go2Shell 会自动退出，不会在 Dock 里留下图标。

Go2Shell 用哪个文件夹：

- 通常是最前面那个 Finder 窗口显示的文件夹。
- Finder 没有打开任何窗口时，使用桌面（`~/Desktop`）。
- 开启了「只选中一个文件夹时，在该文件夹中打开」，并且恰好选中了一个文件夹时，使用选中的文件夹。选中多个项目、选中的是文件，或选中的是 `.app` 这类包时，仍然使用当前窗口的文件夹。
- 窗口显示的是「最近使用」「隔空投送」这类虚拟位置时，没有对应的文件夹，Go2Shell 会弹窗提示。

## 设置

按住 ⌥ 点击工具栏上的 Go2Shell，或者从「应用程序」打开它。

### 使用的终端

列表里只显示已经安装的终端。各终端的能力不同：

| 终端 | 执行命令模板 | 新标签页 |
| --- | --- | --- |
| Terminal.app | 支持 | 实验性，见下文 |
| iTerm2 | 支持 | 支持 |
| Ghostty、WezTerm、kitty、Alacritty、Warp | 不支持，只在该文件夹打开 | 不支持 |

如果之前选的终端后来被卸载了，Go2Shell 会改用 Terminal.app，并在设置窗口里提示。

### 命令

打开终端后执行的命令，默认是 `cd %PATH%; clear; pwd`。下方的「预览」会显示命令实际执行时的样子。「恢复默认」把命令改回默认值。写法见[命令模板](#命令模板)。

所选终端不支持执行命令时，这一项不起作用。

### 打开方式

- **新窗口**（默认）：每次点击都开一个新的终端窗口。
- **新标签页**：在终端最前面的窗口里开一个新标签页。

Terminal.app 的新标签页是实验性功能：Go2Shell 通过模拟按下 ⌘T 来实现，需要「辅助功能」权限。没有这个权限时，Go2Shell 改为打开新窗口，并在第一次遇到时请求权限。

### 只选中一个文件夹时，在该文件夹中打开

默认关闭。开启后的行为见[日常使用](#日常使用)。

### 测试：在个人文件夹打开终端

按当前设置在个人文件夹（`~`）打开终端，用来检查终端和命令是否符合预期，不需要切回 Finder。

## 命令模板

`%PATH%` 代表文件夹路径。Go2Shell 替换它时已经做好了 shell 引用，**不要再给它加引号**。

| 模板 | 文件夹是 `/Users/you/My Project` 时实际执行 |
| --- | --- |
| `cd %PATH%; clear; pwd` | `cd '/Users/you/My Project'; clear; pwd` |
| `cd %PATH% && ls -la` | `cd '/Users/you/My Project' && ls -la` |
| `cd %PATH%; code .` | `cd '/Users/you/My Project'; code .` |
| `clear`（没有 `%PATH%`） | `cd '/Users/you/My Project'; clear` |
| 留空 | `cd '/Users/you/My Project'` |

规则：

- 模板里的每个 `%PATH%` 都会被替换。
- 模板里没有 `%PATH%` 时，Go2Shell 在前面自动加上 `cd <路径>; `，保证终端仍然在正确的文件夹里。
- 模板留空时，相当于 `cd %PATH%`。
- 文件夹名里有空格、引号、`$`、反引号、中文等字符都能正确处理。

## 权限

Go2Shell 靠 macOS 的「自动化」功能读取 Finder 当前的文件夹，并让终端打开窗口。第一次使用时系统会弹出询问：

- 允许 Go2Shell 控制 **Finder**：必需。
- 允许 Go2Shell 控制 **Terminal** 或 **iTerm2**：使用这两个终端时必需。
- 允许 Go2Shell 控制 **System Events**，以及「辅助功能」权限：只有 Terminal.app 的新标签页模式需要。

之后可以在「系统设置 › 隐私与安全性 › 自动化」和「辅助功能」里查看和修改。

## 从旧版 Go2Shell 迁移

第一次运行时，如果这台电脑上有旧版 Go2Shell（ZipZapMac 的 Go2Shell 2.5）的设置，新版会沿用其中的终端、命令和窗口模式。迁移只做一次，之后在新版里的修改不会被覆盖。

- 旧命令里给 `%PATH%` 加的引号（例如 `cd "%PATH%"`）会被自动去掉。
- 旧设置选的是不支持新标签页的终端时，打开方式改为新窗口。

旧版的 App 在安装新版时已经被替换。工具栏上如果还留着旧版的图标，按住 ⌘ 把它拖出工具栏，再把新版拖上去。

## 常见问题

### 点击后弹出「Go2Shell 没有控制"…"的权限」

之前在系统询问时选了「不允许」。点弹窗里的「打开系统设置」，在「隐私与安全性 › 自动化」里找到 Go2Shell，打开对应的开关，然后再点一次工具栏按钮。

如果列表里找不到 Go2Shell，在终端里执行下面的命令重置授权，再点一次工具栏按钮，系统会重新询问：

```sh
tccutil reset AppleEvents com.bingghost.Go2Shell
```

### 每次重新构建后都要重新授权

构建时没有找到 "Apple Development" 证书，用的是 ad-hoc 签名，每次构建的签名都不一样，macOS 会把它当成另一个 App。用带证书的签名构建可以避免：`make build SIGN_ID=<证书>`。

### 弹出「当前 Finder 窗口不是文件夹」

当前窗口显示的是「最近使用」「隔空投送」、搜索结果这类位置。换到一个普通文件夹再试。

### 弹出「该文件夹已不存在」

Finder 窗口显示的文件夹已被删除或移走。换一个文件夹，或者关掉这个窗口。

### 点击后打开的是设置窗口，不是终端

- 点击时按住了 ⌥。
- Go2Shell 不是从 Finder 启动的。只有 Finder 在最前面时启动 Go2Shell 才会打开终端，从 Dock、启动台、Spotlight 启动都会打开设置。

### 打开的是 Terminal.app，不是我选的终端

选的终端没有安装在这台电脑上。打开设置窗口重新选择。

### 自定义命令没有执行

Ghostty、WezTerm、kitty、Alacritty 和 Warp 不支持执行命令模板，Go2Shell 只会在该文件夹打开它们。需要执行命令时请使用 Terminal.app 或 iTerm2。

### Terminal.app 选了「新标签页」，但打开的还是新窗口

新标签页需要两项权限，缺任何一项都会改为打开新窗口：

- 「系统设置 › 隐私与安全性 › 辅助功能」里 Go2Shell 的开关。
- 「系统设置 › 隐私与安全性 › 自动化」里，Go2Shell 下面的 System Events。

另外，如果按下 ⌘T 后没有出现新标签页（例如 Terminal 最前面是它的设置窗口），Go2Shell 也会改为打开新窗口，不会把命令送进已有的标签页。

### 查看日志

```sh
log stream --level debug --predicate 'subsystem == "com.bingghost.Go2Shell"'
```

运行这条命令后再点一次工具栏按钮，可以看到 Go2Shell 选择的操作、使用的终端和各阶段耗时。文件夹路径在日志里默认不显示。

## 命令行参数

不经过 Finder 工具栏，直接运行可执行文件：

```sh
APP=/Applications/Go2Shell.app/Contents/MacOS/Go2Shell

"$APP" --open ~/Downloads     # 按当前设置在指定文件夹打开终端
"$APP" --settings             # 打开设置窗口
"$APP" --print-finder-path    # 打印 Finder 最前窗口的路径
```

这样运行时，自动化权限算在你运行它的那个终端名下，而不是 Go2Shell。

设置保存在 `com.bingghost.Go2Shell` 里，也可以用 `defaults` 查看和修改：

```sh
defaults read com.bingghost.Go2Shell
defaults write com.bingghost.Go2Shell terminal iTerm2
```

| 键 | 可用的值 |
| --- | --- |
| `terminal` | `appleTerminal`、`iTerm2`、`ghostty`、`wezterm`、`kitty`、`alacritty`、`warp` |
| `commandTemplate` | 命令模板字符串 |
| `openMode` | `newWindow`、`newTab` |
| `preferSelectedFolder` | `true`、`false` |

## 卸载

1. 按住 ⌘，把 Go2Shell 的图标拖出 Finder 工具栏。
2. 删除 App 和设置：

   ```sh
   rm -rf /Applications/Go2Shell.app
   defaults delete com.bingghost.Go2Shell
   ```

3. 如果想清掉授权记录：`tccutil reset AppleEvents com.bingghost.Go2Shell`
