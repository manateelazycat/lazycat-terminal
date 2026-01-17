English | [简体中文](./README.zh-CN.md)

### LazyCat Terminal, A high-performance terminal emulator with multi-tab, split-pane, and transparent background support, built with Vala and GTK4

<p align="center">
  <img src="screenshot.png" alt="LazyCat Terminal">
</p>

- Minimalist Design: Borderless, Chrome-style tabs, transparent background - all designed to minimize distraction
- Powerful Split-Pane: Built-in split functionality, unlimited splits, Vim-style navigation between panes, full keyboard control for immersive development
- Strong Compatibility: Based on VTE widget, fully supports terminal escape sequences and Unicode rendering
- Excellent Performance: Vala compiles to C for blazing fast startup, with a developer experience similar to C#
- Built-in Themes: 47 popular themes included, switch styles at will, supports both monospace and bitmap fonts
- Thoughtful Features: Background tab process completion notifications, real-time transparency adjustment, one-click URL opening, live search...
- Vibe Coding: Copy last command output with one keystroke, faster feedback to AI

### Installation

```bash
yay -S lazycat-terminal
```

### Keyboard Shortcuts

All keyboard shortcuts can be customized in `~/.config/lazycat-terminal/config.conf`.

Note: The key names in the configuration file are taken from [gdkkeysyms.h](https://gitlab.gnome.org/GNOME/gtk/-/blob/main/gdk/gdkkeysyms.h). For example, `=` is written as `equal`; `-` is written as `minus`; `Enter` on the main keyboard is written as `Return`; and `Enter` on the numeric keypad is written as `Kp_Enter`.

#### Basic Operations

| Shortcut | Function |
|--------|------|
| `Ctrl+Shift+C` | Copy selected text |
| `Ctrl+Shift+V` | Paste clipboard content |
| `Ctrl+Shift+A` | Select all terminal content |
| `Ctrl+Alt+C` | Copy last command output |

#### Tab Management

| Shortcut | Function |
|--------|------|
| `Ctrl+Shift+T` | New tab |
| `Ctrl+Shift+W` | Close current tab |
| `Ctrl+Tab` | Switch to next tab |
| `Ctrl+Shift+Tab` | Switch to previous tab |

#### Split-Pane Operations

| Shortcut | Function |
|--------|------|
| `Ctrl+Shift+J` | Vertical split (left-right) |
| `Ctrl+Shift+H` | Horizontal split (top-bottom) |
| `Alt+H` | Move focus to left terminal |
| `Alt+L` | Move focus to right terminal |
| `Alt+K` | Move focus to upper terminal |
| `Alt+J` | Move focus to lower terminal |
| `Ctrl+Alt+Q` | Close current terminal pane |
| `Ctrl+Shift+Q` | Close other terminal panes |

#### Font Zoom

| Shortcut | Function |
|--------|------|
| `Ctrl+=` | Increase font size |
| `Ctrl+-` | Decrease font size |
| `Ctrl+0` | Reset font size to default |

#### Search Operations

| Shortcut | Function |
|--------|------|
| `Ctrl+Shift+F` | Open search box |
| `Enter` | Search next match |
| `Ctrl+Enter` | Search previous match |
| `Escape` | Close search box |

#### Other

| Shortcut | Function |
|--------|------|
| `Ctrl+Scroll` | Adjust window transparency |
| `Ctrl+Shift+E` | Open settings dialog |
| `Ctrl+Click link` | Open URL in browser |

### Usage and Command Arguments

```bash
lazycat-terminal [options]

Options:
  -w, --working-directory <directory>   Launch terminal in specified directory
  -e, --execute <command>               Execute specified command after launch
  -m, --maximized                       Start with maximized window
```

### Configuration File

The configuration file is located at `~/.config/lazycat-terminal/config.conf`. On first launch, it will be automatically created from the default configuration.

#### General Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `theme` | string | `default` | Color theme name. See `theme/` directory for available themes (e.g., `dracula`, `gruvbox`, `nord`) |
| `opacity` | float | `0.88` | Window background opacity. Range: 0.0 (fully transparent) to 1.0 (fully opaque) |
| `font` | string | `Hack` | Terminal font family name. Supports both monospace and bitmap fonts |
| `font_size` | integer | `13` | Terminal font size in pixel |
| `hide_tab_bar` | boolean | `false` | Hide the tab bar. Useful when using single tab or external window managers |
| `start_maximized` | boolean | `false` | Start terminal in maximized window state |

#### Keyboard Shortcuts

All keyboard shortcuts in the `[shortcut]` section can be customized. The format is `action_name = Modifier + Key`.

Available modifiers: `Ctrl`, `Shift`, `Alt`, `Super`

**Basic Operations:**
- `copy` - Copy selected text (default: `Ctrl + Shift + c`)
- `paste` - Paste clipboard content (default: `Ctrl + Shift + v`)
- `select_all` - Select all terminal content (default: `Ctrl + Shift + a`)
- `copy_last_output` - Copy last command output (default: `Ctrl + Alt + c`)
- `search` - Open search box (default: `Ctrl + Shift + f`)

**Tab Management:**
- `new_workspace` - Create new tab (default: `Ctrl + Shift + t`)
- `close_workspace` - Close current tab (default: `Ctrl + Shift + w`)
- `next_workspace` - Switch to next tab (default: `Ctrl + Tab`)
- `previous_workspace` - Switch to previous tab (default: `Ctrl + Shift + Tab`)

**Split-Pane Operations:**
- `vertical_split` - Vertical split (left-right) (default: `Ctrl + Shift + j`)
- `horizontal_split` - Horizontal split (top-bottom) (default: `Ctrl + Shift + h`)
- `select_left_window` - Focus left terminal (default: `Alt + h`)
- `select_right_window` - Focus right terminal (default: `Alt + l`)
- `select_upper_window` - Focus upper terminal (default: `Alt + k`)
- `select_lower_window` - Focus lower terminal (default: `Alt + j`)
- `close_window` - Close current terminal pane (default: `Ctrl + Alt + q`)
- `close_other_windows` - Close other terminal panes (default: `Ctrl + Shift + q`)

**Font Zoom:**
- `zoom_in` - Increase font size (default: `Ctrl + =`)
- `zoom_out` - Decrease font size (default: `Ctrl + -`)
- `default_size` - Reset font size to default (default: `Ctrl + 0`)

**Example Configuration:**

```ini
[general]
theme=dracula
opacity=0.95
font=JetBrains Mono
font_size=14
hide_tab_bar=false
start_maximized=false

[shortcut]
copy=Ctrl + Shift + c
paste=Ctrl + Shift + v
search=Ctrl + Shift + f
# ... other shortcuts ...
```

### Development

#### Installing Development Dependencies
Building this project requires the following dependencies:
- **Vala** - Vala compiler
- **Meson** (>= 0.50.0) - Build system
- **GTK4** - GUI toolkit
- **VTE** (vte-2.91-gtk4, >= 0.78) - Terminal emulator library

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

#### Compiling Source Code
```bash
# Clone repository
git clone https://github.com/manateelazycat/lazycat-terminal.git
cd lazycat-terminal

# Configure build directory
meson setup build

# Compile
meson compile -C build

# Install to system (requires root privileges)
sudo meson install -C build
```

### Project Structure

```
lazycat-terminal/
├── meson.build              # Meson build configuration file
├── config.conf              # Default configuration file
├── src/
│   ├── main.vala            # Program entry point, command-line argument parsing
│   ├── window.vala          # Main window, tab management and shortcut handling
│   ├── shadow_window.vala   # Shadow window base class, handles window shadow rendering and window manager integration
│   ├── tab_bar.vala         # Custom rendering for Chrome-style tab bar
│   ├── terminal_tab.vala    # VTE terminal wrapper, split-pane logic
│   ├── settings_dialog.vala # Settings dialog
│   ├── confirm_dialog.vala  # Process safe exit confirmation dialog
│   ├── config_manager.vala  # Configuration file management
│   ├── keymap.vala          # Keyboard shortcut parsing
│   └── style_helper.vala    # GTK4 style helper functions
├── theme/                   # Theme files directory
├── icons/                   # Application icons
├── LICENSE                  # GPL-3.0 license
└── README.md                # This file
```

### Contributing

Issues and Pull Requests are welcome!

This project is licensed under [GNU General Public License v3.0](LICENSE).
