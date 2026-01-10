# 命令执行功能实现说明

## 概述

基于 Deepin Terminal 的 terminal.vala 源码，我已经成功将命令执行功能融入到 lazycat-terminal 项目中。现在终端可以通过命令行参数直接执行用户的命令，执行完成后显示提示信息，按 Enter 键退出。

## 实现的功能

1. **命令行参数解析**：支持 `-e` 或 `--execute` 参数执行命令
2. **工作目录指定**：支持 `-w` 或 `--working-directory` 参数指定工作目录
3. **命令执行**：直接执行命令而不是启动 shell
4. **退出提示**：命令执行完成后显示 "Command has been completed, press ENTER to exit the terminal."
5. **Enter 键退出**：按 Enter 键后终端退出

## 修改的文件

### 1. `src/main.vala`

#### 修改内容：
- 添加了 `launch_commands` 静态变量存储要执行的命令
- 添加了 `working_directory` 静态变量存储工作目录
- 将 `ApplicationFlags` 从 `FLAGS_NONE` 改为 `HANDLES_COMMAND_LINE`
- 实现了 `command_line()` 方法解析命令行参数

#### 关键代码：
```vala
public class LazyCatTerminal : Gtk.Application {
    public static string[] launch_commands = {};
    public static string? working_directory = null;

    public LazyCatTerminal() {
        Object(
            application_id: "com.lazycat.terminal",
            flags: ApplicationFlags.HANDLES_COMMAND_LINE
        );
    }

    public override int command_line(GLib.ApplicationCommandLine cmdline) {
        string[] args = cmdline.get_arguments();
        // 解析 -e 和 -w 参数
        // ...
    }
}
```

### 2. `src/terminal_tab.vala`

#### 修改内容：
- 添加了三个标志变量：
  - `child_has_exit`：标记命令是否已经执行完成
  - `has_print_exit_notify`：标记是否已经打印退出提示
  - `is_first_tab`：标记是否是第一个标签页
- 修改了构造函数，接受 `first_tab` 参数
- 修改了 `construct` 方法，检查是否需要执行命令
- 修改了 `child_exited` 信号处理，区分命令执行和 shell 退出
- 修改了按键处理，支持 Enter 键退出
- 添加了三个关键方法：
  - `is_launch_command()`：检查是否有命令需要执行
  - `launch_command()`：执行命令而不是 shell
  - `print_exit_notify()`：打印退出通知

#### 关键代码：
```vala
// 检查是否需要执行命令
if (is_launch_command() && is_first_tab) {
    launch_command(terminal, LazyCatTerminal.working_directory);
} else {
    spawn_shell_in_terminal(terminal, null);
}

// 命令退出处理
terminal.child_exited.connect(() => {
    if (is_launch_command() && is_first_tab) {
        child_has_exit = true;
        print_exit_notify(terminal);
    } else {
        close_terminal(terminal);
    }
});

// Enter 键退出
if (child_has_exit && is_launch_command() && is_first_tab) {
    if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
        close_terminal(terminal);
        return true;
    }
}
```

### 3. `src/window.vala`

#### 修改内容：
- 修改了 `add_new_tab()` 方法，在创建第一个标签页时传递 `first_tab=true` 参数

#### 关键代码：
```vala
public void add_new_tab() {
    tab_counter++;
    bool is_first_tab = (tab_counter == 1);
    var tab = new TerminalTab("Terminal " + tab_counter.to_string(), is_first_tab);
    // ...
}
```

## 使用方法

### 基本用法

```bash
# 执行单个命令
./build/lazycat-terminal -e ls -la

# 执行复杂命令
./build/lazycat-terminal -e sh -c 'echo Hello && sleep 2 && echo World'

# 在指定目录执行命令
./build/lazycat-terminal -w /tmp -e pwd

# 执行 Python 脚本
./build/lazycat-terminal -e python3 script.py
```

### 参数说明

- `-e` 或 `--execute`：指定要执行的命令（后面的所有参数都会作为命令的一部分）
- `-w` 或 `--working-directory`：指定工作目录

### 执行流程

1. 终端启动
2. 执行指定的命令
3. 命令执行完成
4. 显示提示：`Command has been completed, press ENTER to exit the terminal.`
5. 用户按 Enter 键
6. 终端关闭

## 代码提取来源

所有实现都是从 Deepin Terminal 的 `terminal.vala` 源码中提取的关键逻辑：

1. **命令参数存储**：`Application.commands` 的设计模式
2. **launch_command()**：使用 `spawn_async` 直接执行命令
3. **print_exit_notify()**：使用 `echo` 命令打印退出提示
4. **child_exited 信号**：区分命令执行和 shell 退出的处理逻辑
5. **Enter 键处理**：检查 `child_has_exit` 标志并退出

## 测试

运行测试脚本：
```bash
./test-command-execution.sh
```

或手动测试：
```bash
# 测试 1：简单命令
./build/lazycat-terminal -e ls -la

# 测试 2：需要时间的命令
./build/lazycat-terminal -e sleep 3

# 测试 3：在指定目录执行
./build/lazycat-terminal -w /tmp -e pwd

# 测试 4：执行脚本
./build/lazycat-terminal -e sh -c 'echo "Test completed"'
```

## 注意事项

1. 只有第一个标签页（`is_first_tab=true`）才会处理命令执行逻辑
2. 如果没有指定 `-e` 参数，终端会正常启动 shell
3. 命令执行完成后，终端不会自动关闭，需要用户按 Enter 键
4. 新建的标签页始终会启动 shell，不会执行命令
5. 如果命令执行失败，终端仍然会显示退出提示

## 编译

```bash
meson compile -C build
```

## 总结

此实现完全基于 Deepin Terminal 的设计，提取了核心的命令执行逻辑，并成功融入到 lazycat-terminal 项目中。所有功能都按照原始设计实现，确保了功能的完整性和可靠性。
