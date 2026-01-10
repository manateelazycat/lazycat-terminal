// Terminal Tab - Wrapper for VTE terminal widget with split support

public class TerminalTab : Gtk.Box {
    private Gtk.Widget root_widget;  // Can be a scrolled window or a Paned
    private Vte.Terminal? focused_terminal;  // Currently focused terminal
    public string tab_title { get; private set; }
    private Gdk.RGBA foreground_color;
    private Gdk.RGBA[] color_palette;

    private static string? cached_mono_font = null;
    private const int DEFAULT_FONT_SIZE = 14;
    private const int MIN_FONT_SIZE = 6;
    private const int MAX_FONT_SIZE = 48;
    private int current_font_size = DEFAULT_FONT_SIZE;

    public signal void title_changed(string title);
    public signal void close_requested();

    public TerminalTab(string title) {
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        tab_title = title;
    }

    construct {
        // Create initial terminal
        var terminal = create_terminal();
        focused_terminal = terminal;

        // Wrap in scrolled window
        var scrolled = create_scrolled_window(terminal);
        root_widget = scrolled;

        append(root_widget);
        add_css_class("transparent-tab");

        // Spawn shell in current directory
        spawn_shell_in_terminal(terminal, null);
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
        var bg = Gdk.RGBA();
        bg.red = 0.0f;
        bg.green = 0.0f;
        bg.blue = 0.0f;
        bg.alpha = 0.88f;
        terminal.set_color_background(bg);
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

        terminal.set_colors(foreground_color, bg, color_palette);

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
                    tab_title = title;
                    title_changed(title);
                }
            }
        });

        terminal.child_exited.connect(() => {
            close_requested();
        });

        // Setup focus tracking using GTK4 EventControllerFocus
        var focus_controller = new Gtk.EventControllerFocus();
        focus_controller.enter.connect(() => {
            focused_terminal = terminal;
        });
        terminal.add_controller(focus_controller);

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
            null
        );
    }

    public new void grab_focus() {
        if (focused_terminal != null) {
            focused_terminal.grab_focus();
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

    public void set_background_opacity(double opacity) {
        var bg = Gdk.RGBA();
        bg.red = 0.0f;
        bg.green = 0.0f;
        bg.blue = 0.0f;
        bg.alpha = (float)opacity;

        // Apply to all terminals in the tab
        foreach_terminal(root_widget, (terminal) => {
            terminal.set_colors(foreground_color, bg, color_palette);
        });
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

        // Apply to all terminals in the tab
        foreach_terminal(root_widget, (terminal) => {
            terminal.set_font(font);
        });
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
        stdout.printf("DEBUG: Created paned\n");

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
        stdout.printf("DEBUG: Created paned\n");

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
}
