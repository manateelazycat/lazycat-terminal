// Terminal Window with transparent background, custom title bar, and KDE-style shadow

public class TerminalWindow : ShadowWindow {
    private TabBar tab_bar;
    private Gtk.Stack stack;
    private List<TerminalTab> tabs;
    private int tab_counter = 0;
    private Gtk.Box main_box;
    private double background_opacity = 0.88;
    private Gdk.RGBA background_color;  // Store background color from theme
    private Gtk.CssProvider css_provider;
    private SettingsDialog? settings_dialog = null;
    private ConfigManager config;

    public TerminalWindow(Gtk.Application app) {
        Object(application: app);
    }

    construct {
        tabs = new List<TerminalTab>();

        // Load configuration
        config = new ConfigManager();

        // Apply configuration values
        background_opacity = config.opacity;

        // Initialize default background color (black)
        background_color = Gdk.RGBA();
        background_color.parse("#000000");

        // Load theme colors from config
        load_theme_colors(config.theme);

        setup_window();
        setup_layout();

        add_new_tab();
        setup_snap_detection();
        setup_close_handler();

        // Maximize window if configured or requested via command line
        if (config.start_maximized || LazyCatTerminal.start_maximized) {
            maximize();
        }
    }

    private void setup_window() {
        set_title("LazyCat Terminal");

        // Set window icon
        setup_icon();

        // Add CSS for styling
        load_css();
    }

    private void setup_icon() {
        // Add icon search paths to icon theme
        // Window managers will look for icons based on WM_CLASS (lazycat-terminal)
        var icon_theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());

        // Add custom icon search paths for different sizes
        string[] icon_paths = {
            "./icons/32x32",
            "./icons/48x48",
            "./icons/96x96",
            "./icons/128x128",
            "./icons"  // For the SVG icon
        };

        foreach (string path in icon_paths) {
            icon_theme.add_search_path(path);
        }
    }

    private void load_css() {
        css_provider = new Gtk.CssProvider();
        update_opacity_css();

        StyleHelper.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private void update_opacity_css() {
        double tab_bar_opacity = double.min(1.0, background_opacity + 0.01);

        // Convert RGBA to RGB values (0-255)
        int r = (int)(background_color.red * 255);
        int g = (int)(background_color.green * 255);
        int b = (int)(background_color.blue * 255);

        string css = """
            .transparent-window {
                background-color: rgba(""" + r.to_string() + """, """ + g.to_string() + """, """ + b.to_string() + """, """ + background_opacity.to_string() + """);
                border-radius: 6px;
            }
            .transparent-window.maximized {
                border-radius: 0;
            }
            .tab-bar {
                background-color: rgba(""" + r.to_string() + """, """ + g.to_string() + """, """ + b.to_string() + """, """ + tab_bar_opacity.to_string() + """);
                min-height: 38px;
                border-radius: 6px 6px 0 0;
            }
            .tab-bar.maximized {
                border-radius: 0;
            }
            .terminal-container {
                background-color: transparent;
            }
            .transparent-scroll {
                background-color: transparent;
            }
            .transparent-scroll > * {
                background-color: transparent;
            }
            scrolledwindow.transparent-scroll {
                background-color: transparent;
            }
            .transparent-tab {
                background-color: transparent;
            }
        """;
        css_provider.load_from_string(css);
    }

    private void setup_layout() {
        main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        main_box.add_css_class("transparent-window");
        main_box.set_overflow(Gtk.Overflow.HIDDEN);

        // Create tab bar
        tab_bar = new TabBar();
        tab_bar.add_css_class("tab-bar");
        tab_bar.set_background_opacity(0.89);  // Initial opacity (0.88 + 0.01)

        // Set initial colors from loaded theme
        tab_bar.set_background_color(background_color);

        // Load and set active tab color from theme
        try {
            var theme_file = File.new_for_path(ConfigManager.get_theme_path(config.theme));
            var key_file = new KeyFile();
            key_file.load_from_file(theme_file.get_path(), KeyFileFlags.NONE);

            if (key_file.has_key("theme", "tab")) {
                string tab_str = key_file.get_string("theme", "tab").strip();
                Gdk.RGBA tab_color = Gdk.RGBA();
                tab_color.parse(tab_str);
                tab_bar.set_active_tab_color(tab_color);
            }
        } catch (Error e) {
            stderr.printf("Error loading theme tab color: %s\n", e.message);
        }

        tab_bar.tab_selected.connect(on_tab_selected);
        tab_bar.tab_closed.connect(on_tab_closed);
        tab_bar.new_tab_requested.connect(add_new_tab);

        // Create stack for terminal tabs
        stack = new Gtk.Stack();
        stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE);
        stack.set_vexpand(true);
        stack.set_hexpand(true);
        stack.add_css_class("terminal-container");

        main_box.append(tab_bar);
        main_box.append(stack);

        // Hide tab bar if configured
        if (config.hide_tab_bar) {
            tab_bar.set_visible(false);
        }

        // Use ShadowWindow's set_content method
        set_content(main_box);

        // Enable window dragging from tab bar
        setup_window_drag();

        // Setup opacity control with Ctrl+Scroll
        setup_opacity_control();
    }

    private void setup_window_drag() {
        bool is_dragging = false;
        double press_x = 0;
        double press_y = 0;

        // Mouse press event
        var click_gesture = new Gtk.GestureClick();
        click_gesture.set_button(1);  // Left button only

        click_gesture.pressed.connect((n_press, x, y) => {
            // Ignore if over window controls
            if (tab_bar.is_over_window_controls((int)x, (int)y)) {
                return;
            }

            if (n_press == 1) {
                // Single click - record press position for potential drag
                press_x = x;
                press_y = y;
                is_dragging = false;
            } else if (n_press == 2) {
                // Double click - toggle maximize (anywhere except window controls)
                if (is_maximized()) {
                    unmaximize();
                } else {
                    maximize();
                }
            }
        });

        click_gesture.released.connect((n_press, x, y) => {
            // Ignore if over window controls
            if (tab_bar.is_over_window_controls((int)x, (int)y)) {
                return;
            }

            // If not dragged, handle as click
            if (!is_dragging && n_press == 1) {
                // Check if clicked on new tab button
                if (tab_bar.is_over_new_tab_button((int)x, (int)y)) {
                    // Already handled by tab_bar's on_click
                    return;
                }

                // Check if clicked on a tab - switch to it
                int tab_index = tab_bar.get_tab_at((int)x, (int)y);
                if (tab_index >= 0 && tab_index != tab_bar.get_active_index()) {
                    tab_bar.set_active_tab(tab_index);
                    on_tab_selected(tab_index);
                }
            }
            is_dragging = false;
        });

        tab_bar.add_controller(click_gesture);

        // Drag gesture for window dragging
        var drag_gesture = new Gtk.GestureDrag();
        drag_gesture.set_button(1);

        drag_gesture.drag_begin.connect((x, y) => {
            // Don't start drag if over window controls
            if (tab_bar.is_over_window_controls((int)x, (int)y)) {
                return;
            }
            press_x = x;
            press_y = y;
            is_dragging = false;
        });

        drag_gesture.drag_update.connect((offset_x, offset_y) => {
            // Start window move if dragged more than a few pixels
            if (!is_dragging && (Math.fabs(offset_x) > 3 || Math.fabs(offset_y) > 3)) {
                // Check if the original press was over window controls
                if (tab_bar.is_over_window_controls((int)press_x, (int)press_y)) {
                    return;
                }

                is_dragging = true;
                var surface = get_surface();
                if (surface != null) {
                    var toplevel = surface as Gdk.Toplevel;
                    if (toplevel != null) {
                        var device = drag_gesture.get_device();
                        if (device != null) {
                            double root_x, root_y;
                            surface.get_device_position(device, out root_x, out root_y, null);
                            toplevel.begin_move(device, 1, (int)root_x, (int)root_y, Gdk.CURRENT_TIME);
                        }
                    }
                }
            }
        });

        tab_bar.add_controller(drag_gesture);

        // Keyboard shortcuts
        setup_keyboard_shortcuts();
    }

    private void setup_keyboard_shortcuts() {
        var controller = new Gtk.EventControllerKey();

        // Set propagation phase to CAPTURE to intercept keys before VTE terminal
        controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);

        controller.key_pressed.connect((keyval, keycode, state) => {
            // Get the key event name using Keymap
            string key_name = Keymap.get_keyevent_name(keyval, state);

            // Skip if it's just a modifier key
            if (key_name == "") {
                return false;
            }

            // Check if search box is visible in current tab
            bool search_box_visible = false;
            if (tabs.length() > 0) {
                var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                if (tab != null) {
                    search_box_visible = tab.is_search_box_visible();
                }
            }

            // If search box is visible, only handle search shortcut to close/reopen it
            // Let other keys pass through to the search box
            if (search_box_visible) {
                string? search_shortcut = config.get_shortcut("search");
                if (search_shortcut != null && key_name == search_shortcut) {
                    if (tabs.length() > 0) {
                        var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                        if (tab != null) tab.show_search_box();
                    }
                    return true;
                }
                return false;  // Let the event propagate to search box
            }

            // Copy
            string? copy_shortcut = config.get_shortcut("copy");
            if (copy_shortcut != null && key_name == copy_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.copy_clipboard();
                }
                return true;
            }

            // Copy last command output
            string? copy_last_output_shortcut = config.get_shortcut("copy_last_output");
            if (copy_last_output_shortcut != null && key_name == copy_last_output_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.copy_last_output();
                }
                return true;
            }

            // Paste
            string? paste_shortcut = config.get_shortcut("paste");
            if (paste_shortcut != null && key_name == paste_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.paste_clipboard();
                }
                return true;
            }

            // Search
            string? search_shortcut = config.get_shortcut("search");
            if (search_shortcut != null && key_name == search_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.show_search_box();
                }
                return true;
            }

            // Zoom in
            string? zoom_in_shortcut = config.get_shortcut("zoom_in");
            if (zoom_in_shortcut != null && key_name == zoom_in_shortcut) {
                increase_all_font_sizes();
                return true;
            }

            // Zoom out
            string? zoom_out_shortcut = config.get_shortcut("zoom_out");
            if (zoom_out_shortcut != null && key_name == zoom_out_shortcut) {
                decrease_all_font_sizes();
                return true;
            }

            // Default size
            string? default_size_shortcut = config.get_shortcut("default_size");
            if (default_size_shortcut != null && key_name == default_size_shortcut) {
                reset_all_font_sizes();
                return true;
            }

            // Select all
            string? select_all_shortcut = config.get_shortcut("select_all");
            if (select_all_shortcut != null && key_name == select_all_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.select_all();
                }
                return true;
            }

            // New workspace
            string? new_workspace_shortcut = config.get_shortcut("new_workspace");
            if (new_workspace_shortcut != null && key_name == new_workspace_shortcut) {
                add_new_tab();
                return true;
            }

            // Close workspace
            string? close_workspace_shortcut = config.get_shortcut("close_workspace");
            if (close_workspace_shortcut != null && key_name == close_workspace_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) close_tab(tab);
                }
                return true;
            }

            // Next workspace
            string? next_workspace_shortcut = config.get_shortcut("next_workspace");
            if (next_workspace_shortcut != null && key_name == next_workspace_shortcut) {
                cycle_tab(1);
                return true;
            }

            // Previous workspace
            string? previous_workspace_shortcut = config.get_shortcut("previous_workspace");
            if (previous_workspace_shortcut != null && key_name == previous_workspace_shortcut) {
                cycle_tab(-1);
                return true;
            }

            // Vertical split
            string? vertical_split_shortcut = config.get_shortcut("vertical_split");
            if (vertical_split_shortcut != null && key_name == vertical_split_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) {
                        tab.split_vertical();
                    }
                }
                return true;
            }

            // Horizontal split
            string? horizontal_split_shortcut = config.get_shortcut("horizontal_split");
            if (horizontal_split_shortcut != null && key_name == horizontal_split_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) {
                        tab.split_horizontal();
                    }
                }
                return true;
            }

            // Select upper window
            string? select_upper_window_shortcut = config.get_shortcut("select_upper_window");
            if (select_upper_window_shortcut != null && key_name == select_upper_window_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.select_up_terminal();
                }
                return true;
            }

            // Select lower window
            string? select_lower_window_shortcut = config.get_shortcut("select_lower_window");
            if (select_lower_window_shortcut != null && key_name == select_lower_window_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.select_down_terminal();
                }
                return true;
            }

            // Select left window
            string? select_left_window_shortcut = config.get_shortcut("select_left_window");
            if (select_left_window_shortcut != null && key_name == select_left_window_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.select_left_terminal();
                }
                return true;
            }

            // Select right window
            string? select_right_window_shortcut = config.get_shortcut("select_right_window");
            if (select_right_window_shortcut != null && key_name == select_right_window_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.select_right_terminal();
                }
                return true;
            }

            // Close window
            string? close_window_shortcut = config.get_shortcut("close_window");
            if (close_window_shortcut != null && key_name == close_window_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.close_focused_terminal();
                }
                return true;
            }

            // Close other windows
            string? close_other_windows_shortcut = config.get_shortcut("close_other_windows");
            if (close_other_windows_shortcut != null && key_name == close_other_windows_shortcut) {
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) tab.close_other_terminals();
                }
                return true;
            }

            // Legacy support for Ctrl+Shift+E (settings dialog) - not in config
            bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
            bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;
            if (ctrl && shift && (keyval == Gdk.Key.E || keyval == Gdk.Key.e)) {
                show_settings_dialog();
                return true;
            }

            return false;
        });
        ((Gtk.Widget)this).add_controller(controller);
    }

    private void setup_opacity_control() {
        var scroll_controller = new Gtk.EventControllerScroll(
            Gtk.EventControllerScrollFlags.VERTICAL
        );

        // Set to CAPTURE phase to intercept before terminal receives event
        scroll_controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);

        scroll_controller.scroll.connect((dx, dy) => {
            var state = scroll_controller.get_current_event_state();
            bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;

            if (ctrl) {
                // dy > 0 means scroll down, dy < 0 means scroll up
                // Scroll up increases opacity, scroll down decreases opacity
                double delta = -dy * 0.05;  // 5% change per scroll step
                background_opacity = double.max(0.3, double.min(1.0, background_opacity + delta));

                // Update CSS for window background
                update_opacity_css();

                // Update tab bar opacity (always 0.01 higher than background)
                double tab_bar_opacity = double.min(1.0, background_opacity + 0.01);
                tab_bar.set_background_opacity(tab_bar_opacity);

                // Update all terminal backgrounds
                update_all_terminal_opacity();

                // Force redraw
                queue_draw();

                return true;
            }

            return false;
        });

        ((Gtk.Widget)this).add_controller(scroll_controller);
    }

    private void update_all_terminal_opacity() {
        foreach (var tab in tabs) {
            tab.set_background_opacity(background_opacity);
        }
    }

    private void increase_all_font_sizes() {
        foreach (var tab in tabs) {
            tab.increase_font_size();
        }
    }

    private void decrease_all_font_sizes() {
        foreach (var tab in tabs) {
            tab.decrease_font_size();
        }
    }

    private void reset_all_font_sizes() {
        foreach (var tab in tabs) {
            tab.reset_font_size();
        }
    }

    private void cycle_tab(int direction) {
        int current = tab_bar.get_active_index();
        int count = (int)tabs.length();
        if (count <= 1) return;

        int next = (current + direction + count) % count;
        tab_bar.set_active_tab(next);
        on_tab_selected(next);
    }

    public void add_new_tab() {
        tab_counter++;
        bool is_first_tab = (tab_counter == 1);
        var tab = new TerminalTab("Terminal " + tab_counter.to_string(), is_first_tab);

        // Set initial background opacity
        tab.set_background_opacity(background_opacity);

        // Apply theme from config
        tab.apply_theme(config.theme);

        // Apply font settings from config
        tab.set_font_name(config.font);
        tab.set_font_size(config.font_size);

        // Initially not active (will be set active below)
        tab.is_active_tab = false;

        tab.title_changed.connect((title) => {
            tab_bar.update_tab_title(tabs.index(tab), title);
        });

        tab.close_requested.connect(() => {
            close_tab(tab);
        });

        tab.background_activity.connect(() => {
            int index = tabs.index(tab);
            // Only highlight if this is not the active tab
            if (index >= 0 && index != tab_bar.get_active_index()) {
                tab_bar.set_tab_highlighted(index, true);
            }
        });

        tabs.append(tab);
        stack.add_named(tab, "tab_" + tab_counter.to_string());
        tab_bar.add_tab("Terminal " + tab_counter.to_string());

        // Switch to new tab and mark it as active
        stack.set_visible_child(tab);
        tab_bar.set_active_tab((int)tabs.length() - 1);

        // Set all tabs as inactive, then set this one as active
        foreach (var t in tabs) {
            t.is_active_tab = false;
        }
        tab.is_active_tab = true;

        tab.grab_focus();
    }

    private void on_tab_selected(int index) {
        if (index >= 0 && index < tabs.length()) {
            var tab = tabs.nth_data((uint)index);
            stack.set_visible_child(tab);

            // Set all tabs as inactive, then set this one as active
            foreach (var t in tabs) {
                t.is_active_tab = false;
            }
            tab.is_active_tab = true;

            // Clear highlight when switching to this tab
            tab_bar.clear_tab_highlight(index);

            tab.grab_focus();
        }
    }

    private void on_tab_closed(int index) {
        if (index >= 0 && index < tabs.length()) {
            var tab = tabs.nth_data((uint)index);
            close_tab(tab);
        }
    }

    private void close_tab(TerminalTab tab) {
        int index = tabs.index(tab);
        if (index < 0) return;

        // Check if tab has any foreground processes
        if (tab.has_any_foreground_process()) {
            tab.close_all_terminals(() => {
                actually_close_tab(tab);
            });
        } else {
            actually_close_tab(tab);
        }
    }

    private void actually_close_tab(TerminalTab tab) {
        int index = tabs.index(tab);
        if (index < 0) return;

        tabs.remove(tab);
        stack.remove(tab);
        tab_bar.remove_tab(index);

        if (tabs.length() == 0) {
            close();
        } else {
            int new_index = index >= tabs.length() ? (int)tabs.length() - 1 : index;
            on_tab_selected(new_index);
            tab_bar.set_active_tab(new_index);
        }
    }

    private void setup_snap_detection() {
        // Monitor window size changes to detect snap positions (debounced by parent class)
        notify["default-width"].connect(detect_snap_position);
        notify["default-height"].connect(detect_snap_position);

        // Monitor maximized state changes
        notify["maximized"].connect(detect_snap_position);

        // Use map signal for initial detection
        map.connect(() => {
            detect_snap_position();
        });
    }

    private void setup_close_handler() {
        close_request.connect(() => {
            // Check if any tab has foreground processes
            bool has_any_process = false;
            foreach (var tab in tabs) {
                if (tab.has_any_foreground_process()) {
                    has_any_process = true;
                    break;
                }
            }

            if (has_any_process) {
                // Show confirmation dialog and prevent immediate close
                var first_tab = tabs.nth_data(0);
                if (first_tab != null) {
                    first_tab.close_all_terminals(() => {
                        // After confirmation, close all tabs
                        force_close_all_tabs();
                    });
                }
                return true;  // Prevent close
            }

            // No active processes, allow close
            return false;
        });
    }

    private void force_close_all_tabs() {
        // Close all tabs without checking for processes
        while (tabs.length() > 0) {
            var tab = tabs.nth_data(0);
            tabs.remove(tab);
            stack.remove(tab);
        }
        close();
    }

    private void detect_snap_position() {
        // Check if maximized first
        if (is_maximized()) {
            set_snap_position(WindowSnapPosition.MAXIMIZED);
            update_corner_style(true);
            return;
        }

        // Get current window dimensions
        int win_width = get_width();
        int win_height = get_height();
        int shadow_size = get_shadow_size();

        // Get monitor dimensions
        var display = Gdk.Display.get_default();
        if (display == null) return;

        var monitors = display.get_monitors();
        if (monitors.get_n_items() == 0) return;

        var monitor = (Gdk.Monitor)monitors.get_item(0);
        var geometry = monitor.get_geometry();
        int mon_width = geometry.width;
        int mon_height = geometry.height;

        // Compensate for shadow margins in calculations
        int content_width = win_width - shadow_size * 2;
        int content_height = win_height - shadow_size * 2;

        // Tolerance for snap detection (pixels)
        int tolerance = 60;

        // Check for half-screen width (left or right snap)
        bool is_half_width = (content_width >= mon_width / 2 - tolerance) &&
                             (content_width <= mon_width / 2 + tolerance);

        // Check for full height (top/bottom snap)
        bool is_full_height = content_height >= mon_height - tolerance;

        // Check for half height (corner snap)
        bool is_half_height = (content_height >= mon_height / 2 - tolerance) &&
                              (content_height <= mon_height / 2 + tolerance);

        // Determine snap position based on window geometry
        // Since GTK4 doesn't directly expose window position, we need to use
        // the window's actual allocation or surface position

        WindowSnapPosition new_position = WindowSnapPosition.NONE;
        bool is_snapped = false;

        if (is_half_width && is_full_height) {
            // Left or right half snap
            is_snapped = true;
            new_position = WindowSnapPosition.MAXIMIZED;
        } else if (is_half_width && is_half_height) {
            // Corner snap
            is_snapped = true;
            new_position = WindowSnapPosition.MAXIMIZED;
        }

        update_corner_style(is_snapped);

        // Only update if different (avoid constant redraws)
        if (new_position != get_snap_position()) {
            set_snap_position(new_position);
        }
    }

    private void update_corner_style(bool is_snapped) {
        if (is_snapped) {
            main_box.add_css_class("maximized");
            tab_bar.add_css_class("maximized");
        } else {
            main_box.remove_css_class("maximized");
            tab_bar.remove_css_class("maximized");
        }
    }

    // Public method to explicitly set snap position from window manager hints
    public void notify_snap_position(WindowSnapPosition position) {
        set_snap_position(position);
        update_corner_style(position == WindowSnapPosition.MAXIMIZED);
    }

    private void show_settings_dialog() {
        // Get foreground color from current tab
        Gdk.RGBA fg_color = Gdk.RGBA();
        fg_color.parse("#00cd00"); // Default green color

        if (tabs.length() > 0) {
            var tab = tabs.nth_data((uint)tab_bar.get_active_index());
            if (tab != null) {
                fg_color = tab.get_foreground_color();
            }
        }

        // Create or show settings dialog
        if (settings_dialog == null) {
            settings_dialog = new SettingsDialog(this, fg_color, background_color, config);
            settings_dialog.close_request.connect(() => {
                settings_dialog = null;
                return false;
            });

            // Connect signals
            settings_dialog.font_changed.connect((font_name) => {
                apply_font(font_name);
            });

            settings_dialog.font_size_changed.connect((font_size) => {
                apply_font_size(font_size);
            });

            settings_dialog.theme_changed.connect((theme_name) => {
                apply_theme(theme_name);
            });

            settings_dialog.opacity_changed.connect((opacity) => {
                apply_opacity(opacity);
            });
        }

        settings_dialog.present();
    }

    private void apply_font(string font_name) {
        // Update config
        config.update_font(font_name);

        // Apply font to all VTE terminals in all tabs
        foreach (var tab in tabs) {
            tab.set_font_name(font_name);
        }
    }

    private void apply_font_size(int font_size) {
        // Update config
        config.update_font_size(font_size);

        // Apply font size to all VTE terminals in all tabs
        foreach (var tab in tabs) {
            tab.set_font_size(font_size);
        }
    }

    // Load theme colors (background and tab colors) without applying to existing tabs
    private void load_theme_colors(string theme_name) {
        try {
            var theme_file = File.new_for_path(ConfigManager.get_theme_path(theme_name));
            var key_file = new KeyFile();
            key_file.load_from_file(theme_file.get_path(), KeyFileFlags.NONE);

            // Load background color from theme
            if (key_file.has_key("theme", "background")) {
                string bg_str = key_file.get_string("theme", "background").strip();
                background_color.parse(bg_str);
            }

            // Load and store active tab color for later use
            if (key_file.has_key("theme", "tab")) {
                string tab_str = key_file.get_string("theme", "tab").strip();
                Gdk.RGBA tab_color = Gdk.RGBA();
                tab_color.parse(tab_str);

                // If tab_bar exists, update it; otherwise it will be set during setup_layout
                if (tab_bar != null) {
                    tab_bar.set_active_tab_color(tab_color);
                    tab_bar.set_background_color(background_color);
                }
            }
        } catch (Error e) {
            stderr.printf("Error loading theme colors: %s\n", e.message);
        }
    }

    private void apply_theme(string theme_name) {
        // Update config
        config.update_theme(theme_name);

        // Load theme colors and update window/tab bar
        load_theme_colors(theme_name);

        // Update tab bar colors (if not already done in load_theme_colors)
        if (tab_bar != null) {
            tab_bar.set_background_color(background_color);
        }

        // Apply theme to all tabs
        foreach (var tab in tabs) {
            tab.apply_theme(theme_name);
        }

        // Update settings dialog if it's open
        if (settings_dialog != null) {
            // Get updated foreground color from current tab
            Gdk.RGBA fg_color = Gdk.RGBA();
            fg_color.parse("#00cd00"); // Default
            if (tabs.length() > 0) {
                var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                if (tab != null) {
                    fg_color = tab.get_foreground_color();
                }
            }
            settings_dialog.update_theme_colors(fg_color, background_color);
        }

        // Reload window UI with new theme colors
        update_opacity_css();
    }

    private void apply_opacity(double opacity) {
        // Update config
        config.update_opacity(opacity);

        // Update window opacity
        background_opacity = opacity;
        update_opacity_css();

        // Update tab bar opacity
        double tab_bar_opacity = double.min(1.0, background_opacity + 0.01);
        tab_bar.set_background_opacity(tab_bar_opacity);

        // Update all terminal backgrounds
        update_all_terminal_opacity();
    }
}
