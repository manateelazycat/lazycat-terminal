// Terminal Tab - Wrapper for VTE terminal widget

public class TerminalTab : Gtk.Box {
    private Vte.Terminal terminal;
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
        setup_terminal();
        spawn_shell();
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

    private void setup_terminal() {
        terminal = new Vte.Terminal();

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

        // Scrollbar
        var scrolled = new Gtk.ScrolledWindow();
        scrolled.set_child(terminal);
        scrolled.set_vexpand(true);
        scrolled.set_hexpand(true);
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scrolled.add_css_class("transparent-scroll");

        append(scrolled);

        // Make this container transparent
        add_css_class("transparent-tab");
    }

    private void spawn_shell() {
        string? shell = Environment.get_variable("SHELL");
        if (shell == null) {
            shell = "/bin/bash";
        }

        string[] argv = { shell };
        string[]? envv = Environ.get();

        terminal.spawn_async(
            Vte.PtyFlags.DEFAULT,
            Environment.get_current_dir(),
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
        terminal.grab_focus();
    }

    public void set_background_opacity(double opacity) {
        var bg = Gdk.RGBA();
        bg.red = 0.0f;
        bg.green = 0.0f;
        bg.blue = 0.0f;
        bg.alpha = (float)opacity;
        terminal.set_colors(foreground_color, bg, color_palette);
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
        terminal.set_font(font);
    }

    public void copy_clipboard() {
        terminal.copy_clipboard_format(Vte.Format.TEXT);
    }

    public void paste_clipboard() {
        terminal.paste_clipboard();
    }

    public void select_all() {
        terminal.select_all();
    }
}
