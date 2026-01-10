// Terminal Tab - Wrapper for VTE terminal widget with split support

public class TerminalTab : Gtk.Box {
    private Gtk.Widget root_widget;  // Can be a scrolled window or a Paned
    private Vte.Terminal? focused_terminal;  // Currently focused terminal
    private List<Vte.Terminal> terminal_list;  // Track all terminals in this tab
    public string tab_title { get; private set; }
    private Gdk.RGBA foreground_color;
    private Gdk.RGBA background_color;  // Store background color for brightness detection
    private Gdk.RGBA[] color_palette;
    private Gtk.CssProvider paned_css_provider;
    private double current_opacity = 0.88;
    private HashTable<Vte.Terminal, string> terminal_titles;  // Store title for each terminal
    private HashTable<Vte.Terminal, int> terminal_pids;  // Store child pid for each terminal
    private HashTable<Vte.Terminal, bool> press_anything;  // Track if user pressed any key in terminal
    public bool is_active_tab { get; set; default = false; }  // Track if this tab is currently active

    // Command execution support
    private bool child_has_exit = false;
    private bool has_print_exit_notify = false;
    private bool _is_first_tab = false;

    public bool is_first_tab {
        get { return _is_first_tab; }
        set { _is_first_tab = value; }
    }

    // Search box components
    private Gtk.Box? search_box = null;
    private Gtk.Entry? search_entry = null;
    private Gtk.DrawingArea? search_icon = null;
    private bool search_box_visible = false;
    private string last_search_text = "";
    private int64 last_search_position = -1;

    private static string? cached_mono_font = null;
    private const int DEFAULT_FONT_SIZE = 14;
    private const int MIN_FONT_SIZE = 6;
    private const int MAX_FONT_SIZE = 48;
    private int current_font_size = DEFAULT_FONT_SIZE;

    public signal void title_changed(string title);
    public signal void close_requested();
    public signal void background_activity();  // Signal when background terminal has activity

    public TerminalTab(string title, bool first_tab = false) {
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        tab_title = title;
        is_first_tab = first_tab;

        // Initialize shell/command after construct block
        GLib.Idle.add(() => {
            initialize_terminal();
            return false;
        });
    }

    private void initialize_terminal() {
        if (focused_terminal == null) {
            return;
        }

        // Check if we need to launch a command or spawn a shell
        stderr.printf("DEBUG: initialize_terminal() - is_first_tab=%s\n", is_first_tab.to_string());
        stderr.printf("DEBUG: initialize_terminal() - is_launch_command()=%s\n", is_launch_command().to_string());
        stderr.printf("DEBUG: initialize_terminal() - launch_commands.length=%d\n", LazyCatTerminal.launch_commands.length);

        if (is_launch_command() && is_first_tab) {
            stderr.printf("DEBUG: Launching command instead of shell\n");
            launch_command(focused_terminal, LazyCatTerminal.working_directory);
        } else {
            stderr.printf("DEBUG: Spawning shell\n");
            // Spawn shell in current directory
            spawn_shell_in_terminal(focused_terminal, null);
        }
    }

    construct {
        // Initialize terminal list (GLib.List starts as null)
        terminal_list = null;

        // Initialize terminal titles hash table
        terminal_titles = new HashTable<Vte.Terminal, string>(direct_hash, direct_equal);

        // Initialize terminal pids hash table
        terminal_pids = new HashTable<Vte.Terminal, int>(direct_hash, direct_equal);

        // Initialize press_anything hash table
        press_anything = new HashTable<Vte.Terminal, bool>(direct_hash, direct_equal);

        // Initialize CSS provider for paned styling
        paned_css_provider = new Gtk.CssProvider();
        update_paned_style();

        // Create initial terminal with current directory as initial title
        var terminal = create_terminal();
        focused_terminal = terminal;

        // Get current directory for initial title
        string initial_dir = Environment.get_current_dir();
        string initial_title = Path.get_basename(initial_dir);
        terminal_titles.set(terminal, initial_title);
        tab_title = initial_title;

        // Wrap in scrolled window
        var scrolled = create_scrolled_window(terminal);
        root_widget = scrolled;

        // Create overlay to hold terminal and search box
        var overlay = new Gtk.Overlay();
        overlay.set_child(root_widget);

        // Create search box (initially hidden)
        create_search_box();
        overlay.add_overlay(search_box);

        append(overlay);
        add_css_class("transparent-tab");

        // Note: Terminal initialization (spawn shell or launch command)
        // is deferred to initialize_terminal() which is called via GLib.Idle.add()
        // in the constructor, after is_first_tab has been properly set.
    }

    private static string get_mono_font() {
        if (cached_mono_font != null) {
            return cached_mono_font;
        }

        int result_length = 0;
        string[]? fonts = FontUtils.list_mono_or_dot_fonts(out result_length);

        if (result_length > 0 && fonts != null) {
            cached_mono_font = fonts[0];
            return cached_mono_font;
        }

        // Fallback to default monospace font
        cached_mono_font = "Monospace";
        return cached_mono_font;
    }

    private Vte.Terminal create_terminal() {
        var terminal = new Vte.Terminal();

        // Terminal appearance
        terminal.set_scrollback_lines(10000);
        terminal.set_scroll_on_output(false);
        terminal.set_scroll_on_keystroke(true);

        // Background and Foreground
        background_color = Gdk.RGBA();
        background_color.red = 0.0f;
        background_color.green = 0.0f;
        background_color.blue = 0.0f;
        background_color.alpha = 0.88f;
        terminal.set_color_background(background_color);
        terminal.set_clear_background(false);  // Enable transparent background

        foreground_color = Gdk.RGBA();
        foreground_color.parse("#00cd00");  // Green foreground
        terminal.set_color_foreground(foreground_color);

        // Set 16-color palette
        color_palette = new Gdk.RGBA[16];

        // Color 0-7 (normal colors)
        color_palette[0].parse("#073642");  // color_1
        color_palette[1].parse("#bdb76b");  // color_2
        color_palette[2].parse("#859900");  // color_3
        color_palette[3].parse("#b58900");  // color_4
        color_palette[4].parse("#3465a4");  // color_5
        color_palette[5].parse("#d33682");  // color_6
        color_palette[6].parse("#2aa198");  // color_7
        color_palette[7].parse("#eee8d5");  // color_8

        // Color 8-15 (bright colors)
        color_palette[8].parse("#002b36");   // color_9
        color_palette[9].parse("#8b0000");   // color_10
        color_palette[10].parse("#00ff00");  // color_11
        color_palette[11].parse("#657b83");  // color_12
        color_palette[12].parse("#1e90ff");  // color_13
        color_palette[13].parse("#6c71c4");  // color_14
        color_palette[14].parse("#93a1a1");  // color_15
        color_palette[15].parse("#fdf6e3");  // color_16

        terminal.set_colors(foreground_color, background_color, color_palette);

        // Set font - use first available monospace font from system
        string mono_font = get_mono_font();
        var font = Pango.FontDescription.from_string(mono_font + " 14");
        terminal.set_font(font);

        terminal.set_vexpand(true);
        terminal.set_hexpand(true);

        // Connect signals - use termprop_changed for title updates (VTE 0.78+)
        terminal.termprop_changed.connect((prop_name) => {
            if (prop_name == "xterm.title") {
                size_t length;
                var title = terminal.get_termprop_string(prop_name, out length);
                if (title != null && length > 0) {
                    // Update this terminal's title in the hash table
                    terminal_titles.set(terminal, title);

                    stdout.printf("DEBUG: Title changed for terminal %p: %s\n", terminal, title);
                    stdout.printf("DEBUG: is_active_tab=%s, press_anything=%s\n",
                        is_active_tab.to_string(),
                        press_anything.get(terminal).to_string());

                    // Check if this tab is in background (not active)
                    if (!is_active_tab) {
                        // Check if user has pressed any key
                        bool? has_pressed = press_anything.get(terminal);
                        if (has_pressed != null && has_pressed) {
                            stdout.printf("DEBUG: Emitting background_activity signal!\n");
                            // Emit signal to highlight the tab
                            background_activity();
                        }
                    }

                    // Update tab title based on focused terminal
                    if (terminal == focused_terminal) {
                        tab_title = title;
                        title_changed(title);
                    }
                }
            }
        });

        terminal.child_exited.connect(() => {
            stderr.printf("DEBUG: child_exited signal - is_launch_command()=%s, is_first_tab=%s\n",
                is_launch_command().to_string(), is_first_tab.to_string());

            // If this is a command execution, handle it differently
            if (is_launch_command() && is_first_tab) {
                stderr.printf("DEBUG: Command execution finished, setting child_has_exit=true\n");
                child_has_exit = true;
                print_exit_notify(terminal);
            } else {
                stderr.printf("DEBUG: Shell exited, closing terminal normally\n");
                close_terminal(terminal);
            }
        });

        // Setup key press tracking
        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect((keyval, keycode, state) => {
            // Exit terminal if got 'child_exited' signal by command execute finish
            if (child_has_exit && is_launch_command() && is_first_tab) {
                if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                    // Close the terminal when Enter is pressed after command completes
                    close_terminal(terminal);
                    return true;
                }
            }

            // Set press_anything flag when user presses any key
            press_anything.set(terminal, true);
            stdout.printf("DEBUG: Key pressed in terminal %p, press_anything set to true\n", terminal);
            return false;  // Don't consume the event
        });
        terminal.add_controller(key_controller);

        // Setup focus tracking using GTK4 EventControllerFocus
        var focus_controller = new Gtk.EventControllerFocus();
        focus_controller.enter.connect(() => {
            focused_terminal = terminal;

            // Reset press_anything flag when terminal gains focus
            press_anything.set(terminal, false);

            // Update tab title when terminal gains focus
            update_tab_title_from_focused_terminal();
        });
        terminal.add_controller(focus_controller);

        // Add terminal to list
        terminal_list.append(terminal);

        return terminal;
    }

    private Gtk.ScrolledWindow create_scrolled_window(Vte.Terminal terminal) {
        var scrolled = new Gtk.ScrolledWindow();
        scrolled.set_child(terminal);
        scrolled.set_vexpand(true);
        scrolled.set_hexpand(true);
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scrolled.add_css_class("transparent-scroll");
        return scrolled;
    }

    private void spawn_shell_in_terminal(Vte.Terminal terminal, string? working_directory) {
        string? shell = Environment.get_variable("SHELL");
        if (shell == null) {
            shell = "/bin/bash";
        }

        string[] argv = { shell };
        string[]? envv = Environ.get();

        // Use provided working directory or current directory
        string cwd = working_directory ?? Environment.get_current_dir();

        terminal.spawn_async(
            Vte.PtyFlags.DEFAULT,
            cwd,
            argv,
            envv,
            0,  // GLib.SpawnFlags
            null,
            -1,
            null,
            (term, pid, error) => {
                if (error != null) {
                    stderr.printf("Error spawning shell: %s\n", error.message);
                } else {
                    // Store the child pid
                    terminal_pids.set(terminal, (int)pid);
                    stdout.printf("DEBUG: Spawned shell with pid=%d for terminal %p\n", (int)pid, terminal);
                }
            }
        );
    }

    public new void grab_focus() {
        if (focused_terminal != null) {
            focused_terminal.grab_focus();
        }
    }

    // Check if terminal has a foreground process
    private bool try_get_foreground_pid(Vte.Terminal terminal, out int pid) {
        if (terminal.get_pty() == null) {
            pid = -1;
            return false;
        }

        int? child_pid = terminal_pids.get(terminal);
        if (child_pid == null) {
            pid = -1;
            return false;
        }

        int pty_fd = terminal.get_pty().fd;
        int fgpid = Posix.tcgetpgrp(pty_fd);

        if (fgpid != child_pid && fgpid > 0) {
            pid = fgpid;
            return true;
        } else {
            pid = -1;
            return false;
        }
    }

    private bool has_foreground_process(Vte.Terminal terminal) {
        int pid;
        return try_get_foreground_pid(terminal, out pid);
    }

    private void kill_foreground_process(Vte.Terminal terminal) {
        int fg_pid;
        if (try_get_foreground_pid(terminal, out fg_pid)) {
            stdout.printf("DEBUG: Killing foreground process %d\n", fg_pid);
            Posix.kill(fg_pid, Posix.Signal.KILL);
        }
    }

    // Helper method to recursively find all terminals in the widget tree
    private void foreach_terminal(Gtk.Widget widget, owned TerminalCallback callback) {
        if (widget is Vte.Terminal) {
            callback((Vte.Terminal)widget);
        } else if (widget is Gtk.Paned) {
            var paned = (Gtk.Paned)widget;
            var start_child = paned.get_start_child();
            var end_child = paned.get_end_child();
            if (start_child != null) foreach_terminal(start_child, callback);
            if (end_child != null) foreach_terminal(end_child, callback);
        } else if (widget is Gtk.ScrolledWindow) {
            var scrolled = (Gtk.ScrolledWindow)widget;
            var child = scrolled.get_child();
            if (child != null) foreach_terminal(child, callback);
        }
    }

    private delegate void TerminalCallback(Vte.Terminal terminal);

    // Update tab title from currently focused terminal
    private void update_tab_title_from_focused_terminal() {
        if (focused_terminal == null) {
            return;
        }

        // Get title from hash table, or use working directory as fallback
        string? terminal_title = terminal_titles.get(focused_terminal);
        if (terminal_title == null) {
            // If no title set yet, try to get current directory
            string? cwd = get_terminal_working_directory(focused_terminal);
            if (cwd != null) {
                terminal_title = Path.get_basename(cwd);
            } else {
                terminal_title = "Terminal";
            }
            terminal_titles.set(focused_terminal, terminal_title);
        }

        tab_title = terminal_title;
        title_changed(terminal_title);
    }

    // Get working directory of a specific terminal
    private string? get_terminal_working_directory(Vte.Terminal terminal) {
        string? uri = terminal.get_current_directory_uri();
        if (uri == null) {
            return null;
        }

        // Convert URI to path (e.g., "file:///home/user" -> "/home/user")
        if (uri.has_prefix("file://")) {
            return uri.substring(7);
        }

        return null;
    }

    public void set_background_opacity(double opacity) {
        current_opacity = opacity;

        background_color.alpha = (float)opacity;

        // Apply to all terminals in the tab (only if root_widget is valid)
        if (root_widget != null) {
            foreach_terminal(root_widget, (terminal) => {
                terminal.set_colors(foreground_color, background_color, color_palette);
            });
        }

        // Update paned separator style
        update_paned_style();
    }

    // Check if a color is dark (brightness < 0.5)
    private bool is_color_dark(Gdk.RGBA color) {
        // Calculate relative luminance using ITU-R BT.709 formula
        double brightness = (0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue);
        return brightness < 0.5;
    }

    // Update Paned separator style based on background color and opacity
    private void update_paned_style() {
        // Choose separator color based on background color brightness
        string separator_color = is_color_dark(background_color) ? "#111" : "#bbb";

        // Make paned separator more visible by increasing opacity
        // Use higher opacity than window background (min 0.6, or +0.3 from current)
        double paned_opacity = double.max(0.6, double.min(1.0, current_opacity + 0.3));

        // Create CSS with higher opacity for better visibility and wider handle for easier dragging
        string css = """
            .terminal-paned paned > separator {
                background-color: rgba(%s, %s, %s, %f);
                min-width: 2px;
                min-height: 2px;
            }
            .terminal-paned paned > separator:hover {
                background-color: rgba(%s, %s, %s, %f);
            }
        """.printf(
            separator_color == "#111" ? "0.067" : "0.733",  // R (17/255 or 187/255)
            separator_color == "#111" ? "0.067" : "0.733",  // G
            separator_color == "#111" ? "0.067" : "0.733",  // B
            paned_opacity,
            // Hover state - slightly brighter
            separator_color == "#111" ? "0.2" : "0.867",  // Brighter on hover
            separator_color == "#111" ? "0.2" : "0.867",
            separator_color == "#111" ? "0.2" : "0.867",
            paned_opacity
        );

        paned_css_provider.load_from_string(css);

        // Apply style to all paned widgets (only if root_widget is valid)
        if (root_widget != null) {
            apply_paned_style_to_widget(root_widget);
        }
    }

    // Recursively apply paned style to all paned widgets in the tree
    private void apply_paned_style_to_widget(Gtk.Widget? widget) {
        if (widget == null) return;
        if (widget is Gtk.Paned) {
            var paned = (Gtk.Paned)widget;

            // Add CSS class
            paned.add_css_class("terminal-paned");

            // Add CSS provider
            paned.get_style_context().add_provider(
                paned_css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            // Recursively apply to children
            var start_child = paned.get_start_child();
            var end_child = paned.get_end_child();
            if (start_child != null) apply_paned_style_to_widget(start_child);
            if (end_child != null) apply_paned_style_to_widget(end_child);
        } else if (widget is Gtk.ScrolledWindow) {
            // ScrolledWindow might contain paned, so continue recursion
            var scrolled = (Gtk.ScrolledWindow)widget;
            var child = scrolled.get_child();
            if (child != null) apply_paned_style_to_widget(child);
        }
    }

    public void increase_font_size() {
        if (current_font_size < MAX_FONT_SIZE) {
            current_font_size++;
            update_font();
        }
    }

    public void decrease_font_size() {
        if (current_font_size > MIN_FONT_SIZE) {
            current_font_size--;
            update_font();
        }
    }

    public void reset_font_size() {
        current_font_size = DEFAULT_FONT_SIZE;
        update_font();
    }

    private void update_font() {
        string mono_font = get_mono_font();
        var font = Pango.FontDescription.from_string(mono_font + " " + current_font_size.to_string());

        // Apply to all terminals in the tab (only if root_widget is valid)
        if (root_widget != null) {
            foreach_terminal(root_widget, (terminal) => {
                terminal.set_font(font);
            });
        }
    }

    public void copy_clipboard() {
        if (focused_terminal != null) {
            focused_terminal.copy_clipboard_format(Vte.Format.TEXT);
        }
    }

    public void paste_clipboard() {
        if (focused_terminal != null) {
            focused_terminal.paste_clipboard();
        }
    }

    public void select_all() {
        if (focused_terminal != null) {
            focused_terminal.select_all();
        }
    }

    // Get current working directory from focused terminal
    private string? get_current_working_directory() {
        if (focused_terminal == null) {
            return null;
        }

        string? uri = focused_terminal.get_current_directory_uri();
        if (uri == null) {
            return null;
        }

        // Convert URI to path (e.g., "file:///home/user" -> "/home/user")
        if (uri.has_prefix("file://")) {
            return uri.substring(7);
        }

        return null;
    }

    // Split the focused terminal vertically (left-right)
    public void split_vertical() {
        stdout.printf("DEBUG: split_vertical() called\n");

        if (focused_terminal == null) {
            stdout.printf("DEBUG: focused_terminal is null, returning\n");
            return;
        }
        stdout.printf("DEBUG: focused_terminal = %p\n", focused_terminal);

        // Get current working directory
        string? cwd = get_current_working_directory();
        stdout.printf("DEBUG: cwd = %s\n", cwd ?? "null");

        // Create new terminal
        var new_terminal = create_terminal();
        var new_scrolled = create_scrolled_window(new_terminal);
        new_scrolled.set_visible(true);
        new_terminal.set_visible(true);
        stdout.printf("DEBUG: Created new terminal and scrolled window\n");

        // Initialize new terminal's title with directory name
        if (cwd != null) {
            string dir_name = Path.get_basename(cwd);
            terminal_titles.set(new_terminal, dir_name);
        } else {
            terminal_titles.set(new_terminal, "Terminal");
        }

        // Find the parent of the focused terminal's scrolled window
        Gtk.Widget? focused_scrolled = focused_terminal.get_parent();
        stdout.printf("DEBUG: focused_scrolled = %p\n", focused_scrolled);

        if (focused_scrolled == null || !(focused_scrolled is Gtk.ScrolledWindow)) {
            stdout.printf("DEBUG: focused_scrolled is null or not a ScrolledWindow, returning\n");
            return;
        }

        // Get allocation BEFORE removing from parent
        Gtk.Allocation alloc;
        focused_scrolled.get_allocation(out alloc);
        stdout.printf("DEBUG: focused_scrolled allocation: width=%d, height=%d\n", alloc.width, alloc.height);

        Gtk.Widget? parent = focused_scrolled.get_parent();
        stdout.printf("DEBUG: parent = %p, this = %p\n", parent, this);

        // Create a horizontal paned (for vertical split - left/right)
        var paned = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
        paned.set_vexpand(true);
        paned.set_hexpand(true);
        paned.set_visible(true);
        paned.set_resize_start_child(true);  // Allow resizing start child
        paned.set_resize_end_child(true);    // Allow resizing end child
        paned.set_shrink_start_child(false); // Prevent shrinking to 0
        paned.set_shrink_end_child(false);   // Prevent shrinking to 0
        stdout.printf("DEBUG: Created paned\n");

        // Apply paned styling
        apply_paned_style_to_widget(paned);

        if (parent == this) {
            stdout.printf("DEBUG: parent == this, replacing root widget\n");
            // The focused terminal is the root widget
            remove(focused_scrolled);
            paned.set_start_child(focused_scrolled);
            paned.set_end_child(new_scrolled);
            paned.set_position(alloc.width / 2);
            root_widget = paned;
            append(paned);
            stdout.printf("DEBUG: Replaced root widget with paned\n");
        } else if (parent is Gtk.Paned) {
            stdout.printf("DEBUG: parent is Paned, inserting into existing paned\n");
            // The focused terminal is in a paned
            var parent_paned = (Gtk.Paned)parent;

            // Determine which child the focused terminal is
            if (parent_paned.get_start_child() == focused_scrolled) {
                parent_paned.set_start_child(null);
                paned.set_start_child(focused_scrolled);
                paned.set_end_child(new_scrolled);
                parent_paned.set_start_child(paned);
            } else {
                parent_paned.set_end_child(null);
                paned.set_start_child(focused_scrolled);
                paned.set_end_child(new_scrolled);
                parent_paned.set_end_child(paned);
            }

            paned.set_position(alloc.width / 2);
            stdout.printf("DEBUG: Inserted into existing paned\n");
        } else {
            stdout.printf("DEBUG: parent is neither this nor Paned, doing nothing\n");
        }

        // Spawn shell in new terminal with same working directory
        spawn_shell_in_terminal(new_terminal, cwd);
        stdout.printf("DEBUG: Spawned shell in new terminal\n");

        // Show all widgets and update layout
        this.show();
        paned.show();
        focused_scrolled.show();
        new_scrolled.show();
        new_terminal.show();
        this.queue_resize();
        stdout.printf("DEBUG: Called show() and queue_resize()\n");

        // Focus the new terminal
        focused_terminal = new_terminal;
        new_terminal.grab_focus();
        stdout.printf("DEBUG: Focused new terminal\n");
    }

    // Split the focused terminal horizontally (top-bottom)
    public void split_horizontal() {
        stdout.printf("DEBUG: split_horizontal() called\n");

        if (focused_terminal == null) {
            stdout.printf("DEBUG: focused_terminal is null, returning\n");
            return;
        }
        stdout.printf("DEBUG: focused_terminal = %p\n", focused_terminal);

        // Get current working directory
        string? cwd = get_current_working_directory();
        stdout.printf("DEBUG: cwd = %s\n", cwd ?? "null");

        // Create new terminal
        var new_terminal = create_terminal();
        var new_scrolled = create_scrolled_window(new_terminal);
        new_scrolled.set_visible(true);
        new_terminal.set_visible(true);
        stdout.printf("DEBUG: Created new terminal and scrolled window\n");

        // Initialize new terminal's title with directory name
        if (cwd != null) {
            string dir_name = Path.get_basename(cwd);
            terminal_titles.set(new_terminal, dir_name);
        } else {
            terminal_titles.set(new_terminal, "Terminal");
        }

        // Find the parent of the focused terminal's scrolled window
        Gtk.Widget? focused_scrolled = focused_terminal.get_parent();
        stdout.printf("DEBUG: focused_scrolled = %p\n", focused_scrolled);

        if (focused_scrolled == null || !(focused_scrolled is Gtk.ScrolledWindow)) {
            stdout.printf("DEBUG: focused_scrolled is null or not a ScrolledWindow, returning\n");
            return;
        }

        // Get allocation BEFORE removing from parent
        Gtk.Allocation alloc;
        focused_scrolled.get_allocation(out alloc);
        stdout.printf("DEBUG: focused_scrolled allocation: width=%d, height=%d\n", alloc.width, alloc.height);

        Gtk.Widget? parent = focused_scrolled.get_parent();
        stdout.printf("DEBUG: parent = %p, this = %p\n", parent, this);

        // Create a vertical paned (for horizontal split - top/bottom)
        var paned = new Gtk.Paned(Gtk.Orientation.VERTICAL);
        paned.set_vexpand(true);
        paned.set_hexpand(true);
        paned.set_visible(true);
        paned.set_resize_start_child(true);  // Allow resizing start child
        paned.set_resize_end_child(true);    // Allow resizing end child
        paned.set_shrink_start_child(false); // Prevent shrinking to 0
        paned.set_shrink_end_child(false);   // Prevent shrinking to 0
        stdout.printf("DEBUG: Created paned\n");

        // Apply paned styling
        apply_paned_style_to_widget(paned);

        if (parent == this) {
            stdout.printf("DEBUG: parent == this, replacing root widget\n");
            // The focused terminal is the root widget
            remove(focused_scrolled);
            paned.set_start_child(focused_scrolled);
            paned.set_end_child(new_scrolled);
            paned.set_position(alloc.height / 2);
            root_widget = paned;
            append(paned);
            stdout.printf("DEBUG: Replaced root widget with paned\n");
        } else if (parent is Gtk.Paned) {
            stdout.printf("DEBUG: parent is Paned, inserting into existing paned\n");
            // The focused terminal is in a paned
            var parent_paned = (Gtk.Paned)parent;

            // Determine which child the focused terminal is
            if (parent_paned.get_start_child() == focused_scrolled) {
                parent_paned.set_start_child(null);
                paned.set_start_child(focused_scrolled);
                paned.set_end_child(new_scrolled);
                parent_paned.set_start_child(paned);
            } else {
                parent_paned.set_end_child(null);
                paned.set_start_child(focused_scrolled);
                paned.set_end_child(new_scrolled);
                parent_paned.set_end_child(paned);
            }

            paned.set_position(alloc.height / 2);
            stdout.printf("DEBUG: Inserted into existing paned\n");
        } else {
            stdout.printf("DEBUG: parent is neither this nor Paned, doing nothing\n");
        }

        // Spawn shell in new terminal with same working directory
        spawn_shell_in_terminal(new_terminal, cwd);
        stdout.printf("DEBUG: Spawned shell in new terminal\n");

        // Show all widgets and update layout
        this.show();
        paned.show();
        focused_scrolled.show();
        new_scrolled.show();
        new_terminal.show();
        this.queue_resize();
        stdout.printf("DEBUG: Called show() and queue_resize()\n");

        // Focus the new terminal
        focused_terminal = new_terminal;
        new_terminal.grab_focus();
        stdout.printf("DEBUG: Focused new terminal\n");
    }

    // Close a single terminal and clean up the widget tree
    private void close_terminal(Vte.Terminal terminal) {
        stdout.printf("DEBUG: close_terminal() called for terminal %p\n", terminal);

        // Remove from terminal list
        terminal_list.remove(terminal);
        stdout.printf("DEBUG: Removed from terminal_list, remaining terminals: %u\n", terminal_list.length());

        // Get the terminal's parent (should be ScrolledWindow)
        Gtk.Widget? scrolled = terminal.get_parent();
        if (scrolled == null) {
            stdout.printf("DEBUG: Terminal has no parent, returning\n");
            return;
        }

        // Get the ScrolledWindow's parent (could be TerminalTab or Paned)
        Gtk.Widget? parent = scrolled.get_parent();
        if (parent == null) {
            stdout.printf("DEBUG: ScrolledWindow has no parent, returning\n");
            return;
        }

        // Remove the scrolled window from its parent
        if (parent is Gtk.Box) {
            ((Gtk.Box)parent).remove(scrolled);
        } else if (parent is Gtk.Paned) {
            var paned = (Gtk.Paned)parent;
            if (paned.get_start_child() == scrolled) {
                paned.set_start_child(null);
            } else {
                paned.set_end_child(null);
            }
        }

        stdout.printf("DEBUG: Removed terminal and scrolled window from parent\n");

        // Clean up unused parent containers
        clean_unused_parent(parent);

        // If no terminals left, close the tab
        if (terminal_list.length() == 0) {
            stdout.printf("DEBUG: No terminals left, closing tab\n");
            close_requested();
        }
    }

    // Recursively clean up empty parent containers
    private void clean_unused_parent(Gtk.Widget container) {
        stdout.printf("DEBUG: clean_unused_parent() called for container %p\n", container);

        if (container is Gtk.Paned) {
            var paned = (Gtk.Paned)container;
            var start_child = paned.get_start_child();
            var end_child = paned.get_end_child();

            // If paned has no children, remove it
            if (start_child == null && end_child == null) {
                stdout.printf("DEBUG: Paned has no children, removing it\n");
                Gtk.Widget? parent = paned.get_parent();
                if (parent == null) {
                    return;
                }

                // Remove paned from its parent
                if (parent is Gtk.Box) {
                    ((Gtk.Box)parent).remove(paned);
                } else if (parent is Gtk.Paned) {
                    var parent_paned = (Gtk.Paned)parent;
                    if (parent_paned.get_start_child() == paned) {
                        parent_paned.set_start_child(null);
                    } else {
                        parent_paned.set_end_child(null);
                    }
                }

                // Continue cleaning up parent
                clean_unused_parent(parent);
            }
            // If paned has only one child, replace paned with that child
            else if (start_child != null && end_child == null) {
                stdout.printf("DEBUG: Paned has only start child, replacing paned with child\n");
                replace_paned_with_child(paned, start_child);
            }
            else if (start_child == null && end_child != null) {
                stdout.printf("DEBUG: Paned has only end child, replacing paned with child\n");
                replace_paned_with_child(paned, end_child);
            }
            // If paned has both children, focus one of them
            else {
                stdout.printf("DEBUG: Paned has both children, focusing one\n");
                focus_terminal_in_widget(start_child);
            }
        } else if (container == this) {
            // If we're at the TerminalTab level, check if we need to close
            stdout.printf("DEBUG: Reached TerminalTab level\n");
            if (terminal_list.length() == 0) {
                stdout.printf("DEBUG: No terminals left at TerminalTab level, closing tab\n");
                close_requested();
            }
        }
    }

    // Replace a paned with its only child
    private void replace_paned_with_child(Gtk.Paned paned, Gtk.Widget child) {
        Gtk.Widget? parent = paned.get_parent();
        if (parent == null) {
            return;
        }

        // Remove child from paned
        if (paned.get_start_child() == child) {
            paned.set_start_child(null);
        } else {
            paned.set_end_child(null);
        }

        // Replace paned with child in parent
        if (parent == this) {
            // Parent is TerminalTab
            remove(paned);
            root_widget = child;
            append(child);
        } else if (parent is Gtk.Paned) {
            // Parent is another Paned
            var parent_paned = (Gtk.Paned)parent;
            if (parent_paned.get_start_child() == paned) {
                parent_paned.set_start_child(null);
                parent_paned.set_start_child(child);
            } else {
                parent_paned.set_end_child(null);
                parent_paned.set_end_child(child);
            }
        }

        // Focus a terminal in the child
        focus_terminal_in_widget(child);
    }

    // Find and focus a terminal in the widget tree
    private void focus_terminal_in_widget(Gtk.Widget widget) {
        if (widget is Gtk.ScrolledWindow) {
            var scrolled = (Gtk.ScrolledWindow)widget;
            var child = scrolled.get_child();
            if (child is Vte.Terminal) {
                var terminal = (Vte.Terminal)child;
                focused_terminal = terminal;
                terminal.grab_focus();
                stdout.printf("DEBUG: Focused terminal %p\n", terminal);
            }
        } else if (widget is Gtk.Paned) {
            var paned = (Gtk.Paned)widget;
            var start_child = paned.get_start_child();
            if (start_child != null) {
                focus_terminal_in_widget(start_child);
            } else {
                var end_child = paned.get_end_child();
                if (end_child != null) {
                    focus_terminal_in_widget(end_child);
                }
            }
        }
    }

    // Get absolute position of a widget relative to this TerminalTab
    private void get_widget_position(Gtk.Widget widget, out int x, out int y, out int width, out int height) {
        Gtk.Allocation alloc;
        widget.get_allocation(out alloc);

        // Translate coordinates to TerminalTab's coordinate system
        double widget_x, widget_y;
        widget.translate_coordinates(this, 0, 0, out widget_x, out widget_y);

        x = (int)widget_x;
        y = (int)widget_y;
        width = alloc.width;
        height = alloc.height;
    }

    // Find terminals that intersect horizontally (for left/right selection)
    private List<Vte.Terminal> find_intersects_horizontal_terminals(int x, int y, int width, int height, bool left) {
        List<Vte.Terminal> intersects = null;
        const int TOLERANCE = 10;  // Tolerance for paned separator width

        stdout.printf("DEBUG: find_intersects_horizontal_terminals() called, looking %s\n", left ? "left" : "right");
        foreach (var terminal in terminal_list) {
            if (terminal == focused_terminal) continue;  // Skip focused terminal

            var scrolled = terminal.get_parent();
            if (scrolled == null) continue;

            int t_x, t_y, t_width, t_height;
            get_widget_position(scrolled, out t_x, out t_y, out t_width, out t_height);
            stdout.printf("DEBUG:   terminal at x=%d, y=%d, width=%d, height=%d\n", t_x, t_y, t_width, t_height);

            // Check if terminals intersect vertically
            if (t_y < y + height && t_y + t_height > y) {
                stdout.printf("DEBUG:   terminals intersect vertically\n");
                if (left) {
                    // Looking for terminal on the left (with tolerance for paned separator)
                    int gap = (t_x + t_width - x).abs();
                    stdout.printf("DEBUG:   checking if on left: gap=%d (tolerance=%d)\n", gap, TOLERANCE);
                    if (gap <= TOLERANCE) {
                        stdout.printf("DEBUG:   FOUND left terminal!\n");
                        intersects.append(terminal);
                    }
                } else {
                    // Looking for terminal on the right (with tolerance for paned separator)
                    int gap = (t_x - (x + width)).abs();
                    stdout.printf("DEBUG:   checking if on right: gap=%d (tolerance=%d)\n", gap, TOLERANCE);
                    if (gap <= TOLERANCE) {
                        stdout.printf("DEBUG:   FOUND right terminal!\n");
                        intersects.append(terminal);
                    }
                }
            } else {
                stdout.printf("DEBUG:   terminals do NOT intersect vertically\n");
            }
        }

        return intersects;
    }

    // Find terminals that intersect vertically (for up/down selection)
    private List<Vte.Terminal> find_intersects_vertical_terminals(int x, int y, int width, int height, bool up) {
        List<Vte.Terminal> intersects = null;
        const int TOLERANCE = 10;  // Tolerance for paned separator width

        stdout.printf("DEBUG: find_intersects_vertical_terminals() called, looking %s\n", up ? "up" : "down");
        foreach (var terminal in terminal_list) {
            if (terminal == focused_terminal) continue;  // Skip focused terminal

            var scrolled = terminal.get_parent();
            if (scrolled == null) continue;

            int t_x, t_y, t_width, t_height;
            get_widget_position(scrolled, out t_x, out t_y, out t_width, out t_height);
            stdout.printf("DEBUG:   terminal at x=%d, y=%d, width=%d, height=%d\n", t_x, t_y, t_width, t_height);

            // Check if terminals intersect horizontally
            if (t_x < x + width && t_x + t_width > x) {
                stdout.printf("DEBUG:   terminals intersect horizontally\n");
                if (up) {
                    // Looking for terminal above (with tolerance for paned separator)
                    int gap = (t_y + t_height - y).abs();
                    stdout.printf("DEBUG:   checking if above: gap=%d (tolerance=%d)\n", gap, TOLERANCE);
                    if (gap <= TOLERANCE) {
                        stdout.printf("DEBUG:   FOUND terminal above!\n");
                        intersects.append(terminal);
                    }
                } else {
                    // Looking for terminal below (with tolerance for paned separator)
                    int gap = (t_y - (y + height)).abs();
                    stdout.printf("DEBUG:   checking if below: gap=%d (tolerance=%d)\n", gap, TOLERANCE);
                    if (gap <= TOLERANCE) {
                        stdout.printf("DEBUG:   FOUND terminal below!\n");
                        intersects.append(terminal);
                    }
                }
            } else {
                stdout.printf("DEBUG:   terminals do NOT intersect horizontally\n");
            }
        }

        return intersects;
    }

    // Select terminal in horizontal direction (left or right)
    private void select_horizontal_terminal(bool left) {
        stdout.printf("DEBUG: select_horizontal_terminal() called, left=%s\n", left.to_string());

        if (focused_terminal == null) {
            stdout.printf("DEBUG: focused_terminal is null\n");
            return;
        }

        var scrolled = focused_terminal.get_parent();
        if (scrolled == null) {
            stdout.printf("DEBUG: scrolled is null\n");
            return;
        }

        int x, y, width, height;
        get_widget_position(scrolled, out x, out y, out width, out height);
        stdout.printf("DEBUG: focused terminal position: x=%d, y=%d, width=%d, height=%d\n", x, y, width, height);
        stdout.printf("DEBUG: terminal_list.length() = %u\n", terminal_list.length());

        var intersects = find_intersects_horizontal_terminals(x, y, width, height, left);
        stdout.printf("DEBUG: found %u intersecting terminals\n", intersects.length());
        if (intersects.length() == 0) return;

        // First, try to find terminal with same y coordinate
        foreach (var terminal in intersects) {
            var t_scrolled = terminal.get_parent();
            if (t_scrolled == null) continue;

            int t_x, t_y, t_width, t_height;
            get_widget_position(t_scrolled, out t_x, out t_y, out t_width, out t_height);

            if (t_y == y) {
                focused_terminal = terminal;
                terminal.grab_focus();
                return;
            }
        }

        // Second, try to find terminal that contains current terminal vertically
        foreach (var terminal in intersects) {
            var t_scrolled = terminal.get_parent();
            if (t_scrolled == null) continue;

            int t_x, t_y, t_width, t_height;
            get_widget_position(t_scrolled, out t_x, out t_y, out t_width, out t_height);

            if (t_y < y && t_y + t_height >= y + height) {
                focused_terminal = terminal;
                terminal.grab_focus();
                return;
            }
        }

        // Finally, find terminal with biggest intersection area
        Vte.Terminal? best_terminal = null;
        int max_area = 0;

        foreach (var terminal in intersects) {
            var t_scrolled = terminal.get_parent();
            if (t_scrolled == null) continue;

            int t_x, t_y, t_width, t_height;
            get_widget_position(t_scrolled, out t_x, out t_y, out t_width, out t_height);

            int area = height + t_height - (t_y - y).abs() - (t_y + t_height - y - height).abs();
            area = area / 2;

            if (area > max_area) {
                max_area = area;
                best_terminal = terminal;
            }
        }

        if (best_terminal != null) {
            focused_terminal = best_terminal;
            best_terminal.grab_focus();
        }
    }

    // Select terminal in vertical direction (up or down)
    private void select_vertical_terminal(bool up) {
        stdout.printf("DEBUG: select_vertical_terminal() called, up=%s\n", up.to_string());

        if (focused_terminal == null) {
            stdout.printf("DEBUG: focused_terminal is null\n");
            return;
        }

        var scrolled = focused_terminal.get_parent();
        if (scrolled == null) {
            stdout.printf("DEBUG: scrolled is null\n");
            return;
        }

        int x, y, width, height;
        get_widget_position(scrolled, out x, out y, out width, out height);
        stdout.printf("DEBUG: focused terminal position: x=%d, y=%d, width=%d, height=%d\n", x, y, width, height);
        stdout.printf("DEBUG: terminal_list.length() = %u\n", terminal_list.length());

        var intersects = find_intersects_vertical_terminals(x, y, width, height, up);
        stdout.printf("DEBUG: found %u intersecting terminals\n", intersects.length());
        if (intersects.length() == 0) return;

        // First, try to find terminal with same x coordinate
        foreach (var terminal in intersects) {
            var t_scrolled = terminal.get_parent();
            if (t_scrolled == null) continue;

            int t_x, t_y, t_width, t_height;
            get_widget_position(t_scrolled, out t_x, out t_y, out t_width, out t_height);

            if (t_x == x) {
                focused_terminal = terminal;
                terminal.grab_focus();
                return;
            }
        }

        // Second, try to find terminal that contains current terminal horizontally
        foreach (var terminal in intersects) {
            var t_scrolled = terminal.get_parent();
            if (t_scrolled == null) continue;

            int t_x, t_y, t_width, t_height;
            get_widget_position(t_scrolled, out t_x, out t_y, out t_width, out t_height);

            if (t_x < x && t_x + t_width >= x + width) {
                focused_terminal = terminal;
                terminal.grab_focus();
                return;
            }
        }

        // Finally, find terminal with biggest intersection area
        Vte.Terminal? best_terminal = null;
        int max_area = 0;

        foreach (var terminal in intersects) {
            var t_scrolled = terminal.get_parent();
            if (t_scrolled == null) continue;

            int t_x, t_y, t_width, t_height;
            get_widget_position(t_scrolled, out t_x, out t_y, out t_width, out t_height);

            int area = width + t_width - (t_x - x).abs() - (t_x + t_width - x - width).abs();
            area = area / 2;

            if (area > max_area) {
                max_area = area;
                best_terminal = terminal;
            }
        }

        if (best_terminal != null) {
            focused_terminal = best_terminal;
            best_terminal.grab_focus();
        }
    }

    // Public methods for terminal selection
    public void select_left_terminal() {
        select_horizontal_terminal(true);
    }

    public void select_right_terminal() {
        select_horizontal_terminal(false);
    }

    public void select_up_terminal() {
        select_vertical_terminal(true);
    }

    public void select_down_terminal() {
        select_vertical_terminal(false);
    }

    // Create search box UI
    private void create_search_box() {
        search_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
        search_box.set_halign(Gtk.Align.END);
        search_box.set_valign(Gtk.Align.START);
        search_box.set_margin_top(10);
        search_box.set_margin_end(10);
        search_box.set_size_request(150, -1);
        search_box.set_visible(false);

        // Apply CSS styling
        var css_provider = new Gtk.CssProvider();
        double paned_opacity = double.max(0.6, double.min(1.0, current_opacity + 0.3));

        // Get separator color (same as paned separator)
        string separator_color = is_color_dark(background_color) ? "#eee" : "#111";

        // Calculate RGBA values for separator color with 0.05 opacity
        string border_rgba = is_color_dark(background_color) ?
            "rgba(238, 238, 238, 0.05)" : "rgba(17, 17, 17, 0.05)";

        string css = """
            .search-box {
                background-color: rgba(17, 17, 17, """ + paned_opacity.to_string() + """);
                border: 1px solid """ + border_rgba + """;
                border-radius: 4px;
                padding: 0;
            }
            .search-entry {
                background-color: transparent;
                background-image: none;
                background: transparent;
                color: #00cd00;
                border: none;
                border-radius: 0;
                padding: 5px 8px 5px 1px;
                min-height: 24px;
                font-size: 16px;
                caret-color: #00cd00;
                outline: none;
                box-shadow: none;
            }
            .search-entry:focus {
                background-color: transparent;
                background-image: none;
                background: transparent;
                border: none;
                outline: none;
                box-shadow: none;
                -gtk-outline-style: none;
                -gtk-outline-width: 0;
            }
            .search-entry:hover {
                background-color: transparent;
                background-image: none;
                background: transparent;
                border: none;
                outline: none;
                box-shadow: none;
            }
            .search-entry:active {
                background-color: transparent;
                background-image: none;
                background: transparent;
                border: none;
                outline: none;
                box-shadow: none;
            }
            .search-entry:disabled {
                background-color: transparent;
                background-image: none;
                background: transparent;
                border: none;
                outline: none;
                box-shadow: none;
            }
            .search-entry text {
                background-color: transparent;
                background-image: none;
                background: transparent;
                outline: none;
                box-shadow: none;
            }
            .search-entry text:focus {
                background-color: transparent;
                background-image: none;
                background: transparent;
                outline: none;
                box-shadow: none;
            }
            .search-entry text:hover {
                background-color: transparent;
                background-image: none;
                background: transparent;
                outline: none;
                box-shadow: none;
            }
            .search-entry text:active {
                background-color: transparent;
                background-image: none;
                background: transparent;
                outline: none;
                box-shadow: none;
            }
            .search-entry selection {
                background-color: rgba(0, 205, 0, 0.3);
                color: #00cd00;
            }
        """;
        css_provider.load_from_string(css);

        search_box.get_style_context().add_provider(
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        search_box.add_css_class("search-box");

        // Create search icon (DrawingArea for custom drawing)
        search_icon = new Gtk.DrawingArea();
        search_icon.set_size_request(34, 34);  // Same height as entry (24px + 5px top + 5px bottom padding)
        search_icon.set_valign(Gtk.Align.CENTER);
        search_icon.set_draw_func(draw_search_icon);

        // Create search entry
        search_entry = new Gtk.Entry();
        search_entry.set_placeholder_text("Search...");
        search_entry.set_hexpand(true);
        search_entry.add_css_class("search-entry");

        search_entry.get_style_context().add_provider(
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        // Setup key event handling
        var key_controller = new Gtk.EventControllerKey();
        key_controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);  // Capture phase to get events before window
        key_controller.key_pressed.connect((keyval, keycode, state) => {
            bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;

            stdout.printf("DEBUG: Search box key pressed - keyval=%u, ctrl=%s\n", keyval, ctrl.to_string());

            if (keyval == Gdk.Key.Escape) {
                hide_search_box();
                return true;
            } else if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                string search_text = search_entry.get_text();
                stdout.printf("DEBUG: Search text: %s\n", search_text);
                if (search_text.length > 0) {
                    if (ctrl) {
                        stdout.printf("DEBUG: Calling search_backward\n");
                        search_backward(search_text);
                    } else {
                        stdout.printf("DEBUG: Calling search_forward\n");
                        search_forward(search_text);
                    }
                }
                return true;
            }
            return false;
        });
        search_entry.add_controller(key_controller);

        search_box.append(search_icon);
        search_box.append(search_entry);
    }

    // Draw search icon (magnifying glass with handle pointing right)
    private void draw_search_icon(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        double center_x = width / 2.0;
        double center_y = height / 2.0;

        // Use VTE foreground color
        cr.set_source_rgba(
            foreground_color.red,
            foreground_color.green,
            foreground_color.blue,
            1.0
        );
        cr.set_line_width(1.5);
        cr.set_antialias(Cairo.Antialias.DEFAULT);

        // Draw circle (magnifying glass lens)
        // Shift right by 3px (increase left padding by 5px, decrease right padding by 5px)
        double radius = 5.0;
        cr.arc(center_x + 3, center_y - 2, radius, 0, 2 * Math.PI);
        cr.stroke();

        // Draw handle (pointing to bottom-right)
        double handle_length = 6.0;
        double angle = Math.PI / 4;  // 45 degrees to bottom-right
        double start_x = center_x + 3 + radius * Math.cos(angle);
        double start_y = center_y - 2 + radius * Math.sin(angle);
        double end_x = start_x + handle_length * Math.cos(angle);
        double end_y = start_y + handle_length * Math.sin(angle);

        cr.move_to(start_x, start_y);
        cr.line_to(end_x, end_y);
        cr.stroke();
    }

    // Check if search box is visible
    public bool is_search_box_visible() {
        return search_box_visible;
    }

    // Show search box
    public void show_search_box() {
        if (search_box != null) {
            search_box.set_visible(true);
            search_box_visible = true;
            if (search_entry != null) {
                // Clear previous search text
                search_entry.set_text("");
                search_entry.grab_focus();
            }
            // Reset search position tracking
            last_search_text = "";
            last_search_position = -1;
        }
    }

    // Hide search box
    private void hide_search_box() {
        if (search_box != null) {
            search_box.set_visible(false);
            search_box_visible = false;
        }
        // Return focus to terminal
        if (focused_terminal != null) {
            focused_terminal.grab_focus();
        }
    }

    // Search forward in terminal
    private void search_forward(string text) {
        if (focused_terminal == null) {
            stdout.printf("DEBUG: focused_terminal is null\n");
            return;
        }

        stdout.printf("DEBUG: Searching forward for: %s in terminal %p\n", text, focused_terminal);

        try {
            // Only set regex if search text changed
            if (text != last_search_text) {
                stdout.printf("DEBUG: Search text changed, setting new regex\n");
                // PCRE2_CASELESS flag for case-insensitive search
                uint32 flags = 0x00000008;  // PCRE2_CASELESS
                var regex = new Vte.Regex.for_search(text, text.length, flags);

                focused_terminal.search_set_regex(regex, 0);
                focused_terminal.search_set_wrap_around(true);

                last_search_text = text;
                last_search_position = -1;  // Reset position for new search
            }

            stdout.printf("DEBUG: Calling search_find_next\n");
            bool found = focused_terminal.search_find_next();
            stdout.printf("DEBUG: Search result: %s\n", found.to_string());

            if (!found) {
                stdout.printf("DEBUG: No more matches, wrapping to keep highlight\n");
                // When no more matches found, search from beginning to restore highlight
                // This keeps the search result highlighted
                focused_terminal.search_find_next();
            }
        } catch (Error e) {
            stderr.printf("Error setting search regex: %s\n", e.message);
        }
    }

    // Search backward in terminal
    private void search_backward(string text) {
        if (focused_terminal == null) {
            stdout.printf("DEBUG: focused_terminal is null\n");
            return;
        }

        stdout.printf("DEBUG: Searching backward for: %s in terminal %p\n", text, focused_terminal);

        try {
            // Only set regex if search text changed
            if (text != last_search_text) {
                stdout.printf("DEBUG: Search text changed, setting new regex\n");
                // PCRE2_CASELESS flag for case-insensitive search
                uint32 flags = 0x00000008;  // PCRE2_CASELESS
                var regex = new Vte.Regex.for_search(text, text.length, flags);

                focused_terminal.search_set_regex(regex, 0);
                focused_terminal.search_set_wrap_around(true);

                last_search_text = text;
                last_search_position = -1;  // Reset position for new search
            }

            bool found = focused_terminal.search_find_previous();
            stdout.printf("DEBUG: Search result: %s\n", found.to_string());

            if (!found) {
                stdout.printf("DEBUG: No more matches, wrapping to keep highlight\n");
                // When no more matches found, search from end to restore highlight
                // This keeps the search result highlighted
                focused_terminal.search_find_previous();
            }
        } catch (Error e) {
            stderr.printf("Error setting search regex: %s\n", e.message);
        }
    }

    // Close the currently focused terminal
    public void close_focused_terminal() {
        if (focused_terminal == null) {
            return;
        }

        // Check if terminal has foreground process
        if (has_foreground_process(focused_terminal)) {
            show_close_confirmation_dialog(focused_terminal, () => {
                kill_foreground_process(focused_terminal);
                close_terminal(focused_terminal);
            });
        } else {
            close_terminal(focused_terminal);
        }
    }

    // Close all terminals except the focused one
    public void close_other_terminals() {
        if (focused_terminal == null) {
            return;
        }

        // Create a copy of the list to avoid modifying it while iterating
        List<Vte.Terminal> terminals_to_close = null;
        bool has_active_processes = false;

        foreach (var terminal in terminal_list) {
            if (terminal != focused_terminal) {
                terminals_to_close.append(terminal);
                if (has_foreground_process(terminal)) {
                    has_active_processes = true;
                }
            }
        }

        if (has_active_processes) {
            // Show confirmation for all terminals with active processes
            show_close_confirmation_dialog(null, () => {
                foreach (var terminal in terminals_to_close) {
                    kill_foreground_process(terminal);
                    close_terminal(terminal);
                }
            });
        } else {
            // Close all terminals without confirmation
            foreach (var terminal in terminals_to_close) {
                close_terminal(terminal);
            }
        }
    }

    // Check if any terminal in the tab has foreground process
    public bool has_any_foreground_process() {
        foreach (var terminal in terminal_list) {
            if (has_foreground_process(terminal)) {
                return true;
            }
        }
        return false;
    }

    public delegate void VoidCallback();

    // Close all terminals in the tab (for window close)
    public void close_all_terminals(owned VoidCallback? callback) {
        if (has_any_foreground_process()) {
            show_close_confirmation_dialog(null, () => {
                foreach (var terminal in terminal_list) {
                    kill_foreground_process(terminal);
                }
                if (callback != null) {
                    callback();
                }
            });
        } else {
            if (callback != null) {
                callback();
            }
        }
    }

    // Show confirmation dialog for closing terminal with active process
    private void show_close_confirmation_dialog(Vte.Terminal? specific_terminal, owned VoidCallback on_confirmed) {
        var window = (Gtk.Window)this.get_root();
        if (window == null) {
            return;
        }

        string message;
        if (specific_terminal != null) {
            message = "Process is running in terminal\nConfirm to terminate?";
        } else {
            message = "Processes are running in terminals\nConfirm to terminate all?";
        }

        var dialog = new ConfirmDialog(window, message, foreground_color);
        dialog.confirmed.connect(() => {
            on_confirmed();
        });
        dialog.present();
    }

    // Check if we need to launch a command
    private bool is_launch_command() {
        return LazyCatTerminal.launch_commands.length > 0;
    }

    // Launch command instead of shell
    private void launch_command(Vte.Terminal terminal, string? working_directory) {
        string[] argv = LazyCatTerminal.launch_commands;
        string[]? envv = Environ.get();

        // Use provided working directory or current directory
        string cwd = working_directory ?? Environment.get_current_dir();

        terminal.spawn_async(
            Vte.PtyFlags.DEFAULT,
            cwd,
            argv,
            envv,
            GLib.SpawnFlags.SEARCH_PATH,
            null,
            -1,
            null,
            (term, pid, error) => {
                if (error != null) {
                    stderr.printf("Error spawning command: %s\n", error.message);
                } else {
                    // Store the child pid
                    terminal_pids.set(terminal, (int)pid);
                    stdout.printf("Spawned command with pid=%d for terminal %p\n", (int)pid, terminal);
                }
            }
        );
    }

    // Print exit notification after command completes
    private void print_exit_notify(Vte.Terminal terminal) {
        if (!has_print_exit_notify) {
            GLib.Timeout.add(200, () => {
                // Use feed to directly output text to terminal without spawning a new process
                string message = "\r\nCommand has been completed, press ENTER to exit the terminal.\r\n";
                terminal.feed(message.data);

                return false;
            });

            has_print_exit_notify = true;
        }
    }
}
