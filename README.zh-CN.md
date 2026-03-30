[English](./README.md) | 简体中文

### LazyCat Terminal 一个支持多标签、分屏和透明背景的高性能的终端模拟器，使用 Vala 和 Gtk4 技术开发

<p align="center">
  <img src="screenshot.png" alt="LazyCat Terminal">
</p>

- 极简设计： 无边框、Chrome 风格的多标签、透明背景都是为了尽量减少对用户注意力的干扰
- 超强分屏： 内置分屏功能，无限分屏，Vim 风格的分屏间导航，全键盘操作，沉浸式开发
- 兼容性强： 基于 VTE 控件开发，完整支持终端转义序列和 Unicode 渲染
- 优秀性能： Vala 语言会编译成 C，启动速度超级快，开发手感类似 C#
- 内置主题： 内置 47 款流行主题，风格随心换，支持等宽和点阵字体
- 贴心设计： 后台标签活动高亮、透明度实时调节、主题自适应右键菜单、URL 超链打开/复制、实时搜索、前台进程安全确认...
- Vibe Coding: 一键拷贝最后一个命令输出，输出反馈给 AI 速度更快

### 安装

```bash
yay -S lazycat-terminal
```

### 快捷键

所有快捷键都可以在 `~/.config/lazycat-terminal/config.conf` 中自定义。

#### 基本操作

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+Shift+C` | 复制选中文本 |
| `Ctrl+Shift+V` | 粘贴剪贴板内容 |
| `Ctrl+Shift+A` | 全选终端内容 |
| `Ctrl+Alt+C` | 复制最后一条命令的输出 |

#### 标签页管理

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+Shift+T` | 新建标签页 |
| `Ctrl+Shift+W` | 关闭当前标签页 |
| `Ctrl+Tab` | 切换到下一个标签页 |
| `Ctrl+Shift+Tab` | 切换到上一个标签页 |
| `Alt+1 ... Alt+9` | 切换到第 1 ... 9 个标签页 |
| `Alt+0` | 切换到最后一个标签页 |
| `Ctrl+Shift+Home` | 将当前标签移到最前 |
| `Ctrl+Shift+Page_Up` | 将当前标签向左移动 |
| `Ctrl+Shift+Page_Down` | 将当前标签向右移动 |
| `Ctrl+Shift+End` | 将当前标签移到最后 |

#### 分屏操作

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+Shift+J` | 垂直分屏（左右分割） |
| `Ctrl+Shift+H` | 水平分屏（上下分割） |
| `Alt+H` | 焦点移到左边终端 |
| `Alt+L` | 焦点移到右边终端 |
| `Alt+K` | 焦点移到上方终端 |
| `Alt+J` | 焦点移到下方终端 |
| `Ctrl+Alt+Q` | 关闭当前终端窗格 |
| `Ctrl+Shift+Q` | 关闭其他终端窗格 |

#### 字体缩放

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+=` | 放大字体 |
| `Ctrl+-` | 缩小字体 |
| `Ctrl+0` | 恢复默认字体大小 |

#### 搜索操作

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+Shift+F` | 打开搜索框 |
| `Enter` | 搜索下一个匹配项 |
| `Ctrl+Enter` | 搜索上一个匹配项 |
| `Escape` | 关闭搜索框 |

#### 设置界面的操作

| 快捷键 | 功能 |
|--------|------|
| `Tab` | 切换到下一个子设置 |
| `Shift+Tab` | 切换到上一个子设置 |
| `Down` 或 `j` | 当前子设置选中下一项 |
| `Up` 或 `k` | 当前子设置选中上一项 |
| `Left` 或 `h` | 滑块向左移动 |
| `Right` 或 `l` | 滑块向右移动 |
| `Return` 或 `Enter` | 保存设置 |

注：`Return` 指的是主键盘区的回车键；`Enter` 指的是数字键盘区的回车键

#### 其他

| 快捷键 | 功能 |
|--------|------|
| `F11` | 切换全屏模式 |
| `Ctrl+滚轮` | 调节窗口透明度 |
| `Ctrl+Shift+E` | 打开设置对话框 |
| `Ctrl+Shift+B` | 随机切换背景图片（目录模式） |
| `Ctrl+点击链接` | 在浏览器中打开 URL |

### 鼠标操作

| 操作 | 功能 |
|------|------|
| `右键终端区域` | 打开终端右键菜单：复制、粘贴、全选、搜索、复制上一条命令输出、垂直分屏、水平分屏、关闭当前窗格、关闭其他窗格 |
| `右键链接` | 打开链接右键菜单：打开链接、复制链接，以及复制/粘贴/全选等常用操作 |
| `右键标签页` | 打开标签页右键菜单：新建标签页、关闭当前标签页、切换上一个/下一个标签页、左移/右移/移到最前/最后 |

注：右键菜单为自绘制样式，会跟随当前主题颜色和透明度变化自动适配。

### 行为说明

- 新建标签页和新建分屏会尽量继承当前终端的工作目录
- 关闭包含前台进程的窗格、标签页或窗口时会先弹出确认框
- 后台标签页有活动时会高亮提示

### 使用及命令参数

```bash
lazycat-terminal [选项]

选项:
  -w, --working-directory <目录>   在指定目录启动终端
  -e, --execute <命令>              启动后执行指定命令
  -m, --maximized                  以最大化窗口启动
```

### 配置文件

配置文件位于 `~/.config/lazycat-terminal/config.conf`。首次启动时会自动从默认配置创建。

#### 通用设置

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `theme` | 字符串 | `default` | 颜色主题名称。查看 `theme/` 目录获取可用主题（如 `dracula`、`gruvbox`、`nord`） |
| `opacity` | 浮点数 | `0.88` | 窗口背景不透明度。范围：0.0（完全透明）到 1.0（完全不透明） |
| `font` | 字符串 | `Hack` | 终端字体系列名称。支持等宽字体和点阵字体 |
| `font_size` | 整数 | `13` | 终端字体大小 |
| `line_height` | 浮点数 | `1.0` | 终端行高缩放。范围：`1.0` 到 `2.0` |
| `settings_scroll_speed` | 浮点数 | `1.00` | 设置界面列表的滚轮速度。范围：`0.25` 到 `2.0`，值越小越慢，值越大越快 |
| `hide_tab_bar` | 布尔值 | `false` | 隐藏标签栏。适合单标签使用或外部窗口管理器场景 |
| `start_maximized` | 布尔值 | `false` | 启动时窗口最大化 |
| `start_fullscreen` | 布尔值 | `false` | 启动时进入全屏模式（隐藏任务栏和系统托盘） |
| `background_image` | 字符串 | _（空）_ | 背景图片路径。支持：指定文件路径显示固定背景，或指定目录路径每次启动随机选择一张图片。支持 `~/` 路径展开。支持格式：`.jpg`、`.jpeg`、`.png`、`.webp`、`.bmp`。配合 `opacity` 控制背景图显示强度（值越低背景越清晰） |

#### 键盘快捷键

`[shortcut]` 部分的所有键盘快捷键都可以自定义。格式为 `动作名称 = 修饰键 + 按键`。

可用修饰键：`Ctrl`、`Shift`、`Alt`、`Super`

**基本操作：**
- `copy` - 复制选中文本（默认：`Ctrl + Shift + c`）
- `paste` - 粘贴剪贴板内容（默认：`Ctrl + Shift + v`）
- `select_all` - 全选终端内容（默认：`Ctrl + Shift + a`）
- `copy_last_output` - 复制最后一条命令输出（默认：`Ctrl + Alt + c`）
- `search` - 打开搜索框（默认：`Ctrl + Shift + f`）

**标签页管理：**
- `new_workspace` - 新建标签页（默认：`Ctrl + Shift + t`）
- `close_workspace` - 关闭当前标签页（默认：`Ctrl + Shift + w`）
- `next_workspace` - 切换到下一个标签页（默认：`Ctrl + Tab`）
- `previous_workspace` - 切换到上一个标签页（默认：`Ctrl + Shift + Tab`）
- `switch_to_workspace_1` ... `switch_to_workspace_9` - 切换到第 1 ... 9 个标签页（默认：`Alt + 1` ... `Alt + 9`）
- `switch_to_last_workspace` - 切换到最后一个标签页（默认：`Alt + 0`）
- `move_workspace_to_first` - 将当前标签移到最前（默认：`Ctrl + Shift + Home`）
- `move_workspace_left` - 将当前标签向左移动（默认：`Ctrl + Shift + Page_Up`）
- `move_workspace_right` - 将当前标签向右移动（默认：`Ctrl + Shift + Page_Down`）
- `move_workspace_to_end` - 将当前标签移到最后（默认：`Ctrl + Shift + End`）

**分屏操作：**
- `vertical_split` - 垂直分屏（左右分割）（默认：`Ctrl + Shift + j`）
- `horizontal_split` - 水平分屏（上下分割）（默认：`Ctrl + Shift + h`）
- `select_left_window` - 焦点移到左边终端（默认：`Alt + h`）
- `select_right_window` - 焦点移到右边终端（默认：`Alt + l`）
- `select_upper_window` - 焦点移到上方终端（默认：`Alt + k`）
- `select_lower_window` - 焦点移到下方终端（默认：`Alt + j`）
- `close_window` - 关闭当前终端窗格（默认：`Ctrl + Alt + q`）
- `close_other_windows` - 关闭其他终端窗格（默认：`Ctrl + Shift + q`）
- 终端右键菜单支持“移出到新标签页”：仅在当前标签包含多个窗格时可用，新标签会插入到当前标签右侧并自动获得焦点

**字体缩放：**
- `zoom_in` - 放大字体（默认：`Ctrl + =`）
- `zoom_out` - 缩小字体（默认：`Ctrl + -`）
- `default_size` - 恢复默认字体大小（默认：`Ctrl + 0`）

**其他：**
- `fullscreen` - 切换全屏模式（默认：`F11`）
- `switch_background` - 随机切换背景图片（默认：`Ctrl + Shift + b`），仅在背景图片为目录模式时生效

**配置示例：**

```ini
[general]
theme=dracula
opacity=0.95
font=JetBrains Mono
font_size=14
line_height=1.0
hide_tab_bar=false
start_maximized=false
start_fullscreen=false
background_image=

[shortcut]
fullscreen=F11
copy=Ctrl + Shift + c
paste=Ctrl + Shift + v
search=Ctrl + Shift + f
switch_to_workspace_1=Alt + 1
switch_to_workspace_2=Alt + 2
# ...
switch_to_last_workspace=Alt + 0
# ... 其他快捷键 ...
switch_background=Ctrl + Shift + b
```

**背景图片配置示例：**

```ini
# 固定背景图片
background_image=~/Pictures/wallpaper.jpg

# 随机背景（每次启动从目录中随机选取一张）
background_image=~/Pictures/terminal-backgrounds/
# 使用 Ctrl+Shift+B 可以在运行时随机切换到目录中的另一张图片
```

### 源码开发

#### 安装开发依赖
构建此项目需要以下依赖：
- **Vala** - Vala 编译器
- **Meson** (>= 0.50.0) - 构建系统
- **GTK4** - GUI 工具包
- **VTE** (vte-2.91-gtk4, >= 0.78) - 终端模拟器库

**Arch Linux:**

```bash
sudo pacman -S vala meson gtk4 vte4
```

**Debian/Ubuntu:**

```bash
sudo apt install valac meson libgtk-4-dev libvte-2.91-gtk4-dev
```

**Fedora:**

```bash
sudo dnf install vala meson gtk4-devel vte291-gtk4-devel
```

#### 编译源码
```bash
# 克隆仓库
git clone https://github.com/manateelazycat/lazycat-terminal.git
cd lazycat-terminal

# 配置构建目录
meson setup build

# 编译
meson compile -C build

# 安装到系统 (需要 root 权限)
sudo meson install -C build
```

### 项目结构

```
lazycat-terminal/
├── meson.build              # Meson 构建配置文件
├── config.conf              # 默认配置文件
├── src/
│   ├── main.vala            # 程序入口，命令行参数解析
│   ├── window.vala          # 主窗口，标签页管理和快捷键处理
│   ├── shadow_window.vala   # 阴影窗口基类，处理窗口阴影自绘和窗口管理器对接
│   ├── tab_bar.vala         # Chrome 风格标签栏的自定义绘制
│   ├── terminal_tab.vala    # VTE 终端封装，分屏逻辑
│   ├── context_menu.vala    # 主题自适应的自绘右键菜单
│   ├── settings_dialog.vala # 设置对话框
│   ├── confirm_dialog.vala  # 进程安全退出确认对话框
│   ├── config_manager.vala  # 配置文件管理
│   ├── keymap.vala          # 快捷键解析
│   └── style_helper.vala    # GTK4 样式辅助函数
├── theme/                   # 主题文件目录
├── icons/                   # 应用图标
├── LICENSE                  # GPL-3.0 许可证
└── README.md                # 本文件
```

### 开源贡献

欢迎提交 Issue 和 Pull Request！

本项目采用 [GNU General Public License v3.0](LICENSE) 许可证。
