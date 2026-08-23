// Terminal Window with transparent background, custom title bar, and KDE-style shadow

public class TerminalWindow : ShadowWindow {
    private TabBar tab_bar;
    private Gtk.Stack stack;
    private List<TerminalTab> tabs;
    private int tab_counter = 0;
    private Gtk.Overlay main_overlay;
    private Gtk.Box main_box;
    private double background_opacity = 0.88;
    private Gdk.RGBA background_color;  // Store background color from theme
    private Gdk.RGBA tab_color;  // Store tab color from theme for scrollbar styling
    private Gtk.CssProvider css_provider;
    private SettingsDialog? settings_dialog = null;
    private ConfirmDialog? confirm_dialog = null;
    private ContextMenuOverlay? context_menu = null;
    private ConfigManager config;
    private Gtk.Picture? background_picture = null;
    private string? current_background_path = null;
    private File? background_dir = null;

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

        // Initialize default tab color (blue)
        tab_color = Gdk.RGBA();
        tab_color.parse("#2CA7F8");

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

        // Fullscreen window if configured
        if (config.start_fullscreen) {
            fullscreen();
        }
    }

    // Toggle fullscreen mode
    public void toggle_fullscreen() {
        if (is_fullscreen()) {
            unfullscreen();
        } else {
            fullscreen();
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

        // Convert tab color to RGB values (0-255) for scrollbar styling
        int tr = (int)(tab_color.red * 255);
        int tg = (int)(tab_color.green * 255);
        int tb = (int)(tab_color.blue * 255);

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
            .transparent-scroll scrollbar,
            .transparent-scroll scrollbar trough {
                background-color: transparent;
                border: none;
                box-shadow: none;
                outline: none;
            }
            .transparent-scroll scrollbar slider {
                background-color: rgba(""" + tr.to_string() + """, """ + tg.to_string() + """, """ + tb.to_string() + """, 0);
                border: none;
                box-shadow: none;
                outline: none;
                transition: background-color 200ms ease-in-out;
            }
            .transparent-scroll scrollbar:hover slider {
                background-color: rgba(""" + tr.to_string() + """, """ + tg.to_string() + """, """ + tb.to_string() + """, 0.65);
            }
            .transparent-scroll scrollbar slider:hover {
                background-color: rgba(""" + tr.to_string() + """, """ + tg.to_string() + """, """ + tb.to_string() + """, 0.8);
            }
            .transparent-scroll scrollbar slider:active {
                background-color: rgba(""" + tr.to_string() + """, """ + tg.to_string() + """, """ + tb.to_string() + """, 0.9);
            }
        """;
        css_provider.load_from_string(css);
    }

    private void setup_layout() {
        // Create main overlay to hold both content and dialogs
        main_overlay = new Gtk.Overlay();

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
        tab_bar.tab_context_menu_requested.connect(show_tab_context_menu);
        tab_bar.new_tab_requested.connect(add_new_tab);
        tab_bar.settings_button_clicked.connect(show_settings_dialog);

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

        // Setup background image and overlay structure
        setup_background_image();
        if (background_picture != null) {
            main_overlay.set_child(background_picture);
            main_overlay.add_overlay(main_box);
            main_overlay.set_measure_overlay(main_box, true);
        } else {
            main_overlay.set_child(main_box);
        }
        set_content(main_overlay);

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
            // If settings dialog is visible, forward key events to it
            if (settings_dialog != null) {
                return settings_dialog.handle_key_press(keyval, keycode, state);
            }

            // If confirm dialog is visible, forward key events to it
            if (confirm_dialog != null) {
                return confirm_dialog.handle_key_press(keyval, keycode, state);
            }

            // If a context menu is visible, keep input scoped to it
            if (context_menu != null) {
                return context_menu.handle_key_press(keyval, keycode, state);
            }

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

            // Switch to specific workspace
            if (handle_switch_to_workspace_shortcut(key_name)) {
                return true;
            }

            // Move current workspace to first
            string? move_workspace_to_first_shortcut = config.get_shortcut("move_workspace_to_first");
            if (move_workspace_to_first_shortcut != null && key_name == move_workspace_to_first_shortcut) {
                move_active_tab_to_first();
                return true;
            }

            // Move current workspace left
            string? move_workspace_left_shortcut = config.get_shortcut("move_workspace_left");
            if (move_workspace_left_shortcut != null && key_name == move_workspace_left_shortcut) {
                move_active_tab_left();
                return true;
            }

            // Move current workspace right
            string? move_workspace_right_shortcut = config.get_shortcut("move_workspace_right");
            if (move_workspace_right_shortcut != null && key_name == move_workspace_right_shortcut) {
                move_active_tab_right();
                return true;
            }

            // Move current workspace to end
            string? move_workspace_to_end_shortcut = config.get_shortcut("move_workspace_to_end");
            if (move_workspace_to_end_shortcut != null && key_name == move_workspace_to_end_shortcut) {
                move_active_tab_to_end();
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

            // Switch background image
            string? switch_bg_shortcut = config.get_shortcut("switch_background");
            if (switch_bg_shortcut != null && key_name == switch_bg_shortcut) {
                switch_background_image();
                return true;
            }

            // Fullscreen toggle
            string? fullscreen_shortcut = config.get_shortcut("fullscreen");
            if (fullscreen_shortcut != null && key_name == fullscreen_shortcut) {
                toggle_fullscreen();
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

    private TerminalTab? get_active_tab() {
        if (tabs.length() == 0) {
            return null;
        }

        int active_index = tab_bar.get_active_index();
        if (active_index < 0 || active_index >= tabs.length()) {
            return null;
        }

        return tabs.nth_data((uint)active_index);
    }

    private void restore_active_tab_focus() {
        var tab = get_active_tab();
        if (tab != null) {
            tab.grab_focus();
        }
    }

    private Gdk.RGBA get_context_menu_foreground_color() {
        Gdk.RGBA fg_color = Gdk.RGBA();
        fg_color.parse("#00cd00");

        var active_tab = get_active_tab();
        if (active_tab != null) {
            fg_color = active_tab.get_foreground_color();
        }

        return fg_color;
    }

    private bool translate_point_to_ancestor(Gtk.Widget source,
                                             Gtk.Widget ancestor,
                                             double x,
                                             double y,
                                             out double ancestor_x,
                                             out double ancestor_y) {
        if (source == ancestor) {
            ancestor_x = x;
            ancestor_y = y;
            return true;
        }

        Graphene.Point current_point = Graphene.Point() { x = (float)x, y = (float)y };
        Gtk.Widget? current = source;

        while (current != null && current != ancestor) {
            Gtk.Widget? parent = current.get_parent();
            if (parent == null) {
                break;
            }

            Graphene.Point parent_point;
            if (!current.compute_point(parent, current_point, out parent_point)) {
                break;
            }

            current_point = parent_point;
            current = parent;
        }

        if (current == ancestor) {
            ancestor_x = current_point.x;
            ancestor_y = current_point.y;
            return true;
        }

        ancestor_x = 0;
        ancestor_y = 0;
        return false;
    }

    private bool translate_widget_point(Gtk.Widget source, double x, double y, out int overlay_x, out int overlay_y) {
        Graphene.Point src_point = Graphene.Point() { x = (float)x, y = (float)y };
        Graphene.Point dest_point;

        if (source.compute_point(main_overlay, src_point, out dest_point)) {
            overlay_x = (int)Math.round(dest_point.x);
            overlay_y = (int)Math.round(dest_point.y);
            return true;
        }

        double translated_x;
        double translated_y;
        if (translate_point_to_ancestor(source, main_overlay, x, y, out translated_x, out translated_y)) {
            overlay_x = (int)Math.round(translated_x);
            overlay_y = (int)Math.round(translated_y);
            return true;
        }

        var root_widget = get_root() as Gtk.Widget;
        if (root_widget != null) {
            double source_root_x = 0;
            double source_root_y = 0;
            double overlay_root_x = 0;
            double overlay_root_y = 0;

            if (translate_point_to_ancestor(source, root_widget, x, y, out source_root_x, out source_root_y) &&
                translate_point_to_ancestor(main_overlay, root_widget, 0, 0, out overlay_root_x, out overlay_root_y)) {
                overlay_x = (int)Math.round(source_root_x - overlay_root_x);
                overlay_y = (int)Math.round(source_root_y - overlay_root_y);
                return true;
            }
        }

        overlay_x = int.max(0, (int)Math.round(x));
        overlay_y = int.max(0, (int)Math.round(y));
        return false;
    }

    private void close_context_menu() {
        if (context_menu != null) {
            context_menu.close_menu();
        }
    }

    private void update_context_menu_theme() {
        if (context_menu != null) {
            context_menu.update_theme(
                get_context_menu_foreground_color(),
                background_color,
                background_opacity
            );
        }
    }

    private ContextMenuOverlay present_context_menu(ContextMenuItemSpec[] items, int anchor_x, int anchor_y) {
        close_context_menu();

        var menu = new ContextMenuOverlay(
            items,
            get_context_menu_foreground_color(),
            background_color,
            background_opacity,
            anchor_x,
            anchor_y
        );

        context_menu = menu;
        menu.closed.connect(() => {
            if (context_menu == menu) {
                if (menu.get_parent() != null) {
                    main_overlay.remove_overlay(menu);
                }
                context_menu = null;
                restore_active_tab_focus();
            }
        });

        main_overlay.add_overlay(menu);
        menu.grab_focus();
        return menu;
    }

    private ContextMenuItemSpec[] build_terminal_context_menu_items(TerminalTab tab, bool include_url_actions = false) {
        ContextMenuItemSpec[] items = {};

        if (include_url_actions) {
            items += ContextMenuItemSpec.action("open_url", "打开链接");
            items += ContextMenuItemSpec.action("copy_url", "复制链接");
            items += ContextMenuItemSpec.divider();
        }

        items += ContextMenuItemSpec.action("copy", "复制");
        items += ContextMenuItemSpec.action("paste", "粘贴");
        items += ContextMenuItemSpec.action("select_all", "全选");
        items += ContextMenuItemSpec.divider();
        items += ContextMenuItemSpec.action("search", "搜索");
        items += ContextMenuItemSpec.action("copy_last_output", "复制上一条命令输出");
        items += ContextMenuItemSpec.divider();
        items += ContextMenuItemSpec.action("split_vertical", "垂直分屏");
        items += ContextMenuItemSpec.action("split_horizontal", "水平分屏");
        items += ContextMenuItemSpec.action("move_to_new_tab", "移出到新标签页", tab.has_multiple_terminals());
        items += ContextMenuItemSpec.divider();
        items += ContextMenuItemSpec.action("close_terminal", "关闭当前窗格");
        items += ContextMenuItemSpec.action("close_other_terminals", "关闭其他窗格", tab.has_multiple_terminals());

        return items;
    }

    private ContextMenuItemSpec[] build_tab_context_menu_items(int tab_index) {
        int count = (int)tabs.length();
        bool can_cycle = count > 1;
        bool can_move_left = tab_index > 0;
        bool can_move_right = tab_index >= 0 && tab_index < count - 1;

        return {
            ContextMenuItemSpec.action("new_tab", "新建标签页"),
            ContextMenuItemSpec.action("close_tab", "关闭当前标签页"),
            ContextMenuItemSpec.divider(),
            ContextMenuItemSpec.action("previous_tab", "切换到上一个标签页", can_cycle),
            ContextMenuItemSpec.action("next_tab", "切换到下一个标签页", can_cycle),
            ContextMenuItemSpec.divider(),
            ContextMenuItemSpec.action("move_first", "移到最前", can_move_left),
            ContextMenuItemSpec.action("move_left", "左移", can_move_left),
            ContextMenuItemSpec.action("move_right", "右移", can_move_right),
            ContextMenuItemSpec.action("move_end", "移到最后", can_move_right)
        };
    }

    private void show_terminal_context_menu(TerminalTab tab, Vte.Terminal terminal, double x, double y, string? url) {
        if (settings_dialog != null || confirm_dialog != null) {
            return;
        }

        int anchor_x;
        int anchor_y;
        translate_widget_point(terminal, x, y, out anchor_x, out anchor_y);

        bool has_url = (url != null && url.length > 0);
        ContextMenuItemSpec[] items = build_terminal_context_menu_items(tab, has_url);

        var menu = present_context_menu(items, anchor_x, anchor_y);
        menu.item_activated.connect((action_id) => {
            switch (action_id) {
                case "copy":
                    tab.copy_clipboard();
                    break;
                case "paste":
                    tab.paste_clipboard();
                    break;
                case "select_all":
                    tab.select_all();
                    break;
                case "search":
                    tab.show_search_box();
                    break;
                case "copy_last_output":
                    tab.copy_last_output();
                    break;
                case "split_vertical":
                    tab.split_vertical();
                    break;
                case "split_horizontal":
                    tab.split_horizontal();
                    break;
                case "move_to_new_tab":
                    detach_active_pane_to_new_tab_right();
                    break;
                case "close_terminal":
                    tab.close_focused_terminal();
                    break;
                case "close_other_terminals":
                    tab.close_other_terminals();
                    break;
                case "open_url":
                    if (url != null) {
                        tab.open_url_in_default_browser(url);
                    }
                    break;
                case "copy_url":
                    if (url != null) {
                        tab.copy_text_to_clipboard(url);
                    }
                    break;
            }
        });
    }

    private void show_tab_context_menu(int tab_index, double x, double y) {
        if (settings_dialog != null || confirm_dialog != null) {
            return;
        }

        int count = (int)tabs.length();
        if (tab_index < 0 || tab_index >= count) {
            return;
        }

        int anchor_x;
        int anchor_y;
        translate_widget_point(tab_bar, x, y, out anchor_x, out anchor_y);

        var menu = present_context_menu(build_tab_context_menu_items(tab_index), anchor_x, anchor_y);
        menu.item_activated.connect((action_id) => {
            int current_count = (int)tabs.length();
            if (action_id != "new_tab" && (tab_index < 0 || tab_index >= current_count)) {
                return;
            }

            switch (action_id) {
                case "new_tab":
                    add_new_tab_after_index(tab_index);
                    break;
                case "close_tab":
                    var close_target = tabs.nth_data((uint)tab_index);
                    if (close_target != null) {
                        close_tab(close_target);
                    }
                    break;
                case "previous_tab":
                    if (current_count > 1) {
                        switch_to_tab((tab_index - 1 + current_count) % current_count);
                    }
                    break;
                case "next_tab":
                    if (current_count > 1) {
                        switch_to_tab((tab_index + 1) % current_count);
                    }
                    break;
                case "move_first":
                    if (tab_index > 0) {
                        switch_to_tab(tab_index);
                        move_active_tab_to_first();
                    }
                    break;
                case "move_left":
                    if (tab_index > 0) {
                        switch_to_tab(tab_index);
                        move_active_tab_left();
                    }
                    break;
                case "move_right":
                    if (tab_index < current_count - 1) {
                        switch_to_tab(tab_index);
                        move_active_tab_right();
                    }
                    break;
                case "move_end":
                    if (tab_index < current_count - 1) {
                        switch_to_tab(tab_index);
                        move_active_tab_to_end();
                    }
                    break;
            }
        });
    }

    private void cycle_tab(int direction) {
        int current = tab_bar.get_active_index();
        int count = (int)tabs.length();
        if (count <= 1) return;

        int next = (current + direction + count) % count;
        switch_to_tab(next);
    }

    private bool handle_switch_to_workspace_shortcut(string key_name) {
        for (int i = 1; i <= 9; i++) {
            string action_name = "switch_to_workspace_" + i.to_string();
            string? shortcut = config.get_shortcut(action_name);
            if (shortcut != null && key_name == shortcut) {
                switch_to_tab(i - 1);
                return true;
            }
        }

        string? switch_to_last_workspace_shortcut = config.get_shortcut("switch_to_last_workspace");
        if (switch_to_last_workspace_shortcut != null && key_name == switch_to_last_workspace_shortcut) {
            switch_to_tab((int)tabs.length() - 1);
            return true;
        }

        return false;
    }

    private void switch_to_tab(int index) {
        int count = (int)tabs.length();
        if (index < 0 || index >= count) {
            return;
        }

        tab_bar.set_active_tab(index);
        on_tab_selected(index);
    }

    private void move_active_tab_to_index(int target) {
        int current = tab_bar.get_active_index();
        int count = (int)tabs.length();

        if (count <= 1 || current < 0 || current >= count) {
            return;
        }

        int target_index = int.max(0, int.min(target, count - 1));
        if (current == target_index) {
            return;
        }

        var tab = tabs.nth_data((uint)current);
        if (tab == null) {
            return;
        }

        tabs.remove(tab);
        tabs.insert(tab, target_index);
        tab_bar.move_tab(current, target_index);

        tab_bar.set_active_tab(target_index);
        on_tab_selected(target_index);
    }

    private void move_active_tab_to_first() {
        move_active_tab_to_index(0);
    }

    private void move_active_tab_left() {
        int current = tab_bar.get_active_index();
        move_active_tab_to_index(current - 1);
    }

    private void move_active_tab_right() {
        int current = tab_bar.get_active_index();
        move_active_tab_to_index(current + 1);
    }

    private void move_active_tab_to_end() {
        move_active_tab_to_index((int)tabs.length() - 1);
    }

    private int allocate_tab_id() {
        tab_counter++;
        return tab_counter;
    }

    private void prepare_tab(TerminalTab tab) {
        tab.set_background_opacity(background_opacity);
        tab.apply_theme(config.theme);
        tab.set_font_name(config.font);
        tab.set_font_size(config.font_size);
        tab.set_line_height(config.line_height);
        tab.is_active_tab = false;

        tab.title_changed.connect((title) => {
            int index = tabs.index(tab);
            if (index >= 0) {
                tab_bar.update_tab_title(index, title);
            }
        });

        tab.close_requested.connect(() => {
            close_tab(tab);
        });

        tab.background_activity.connect(() => {
            int index = tabs.index(tab);
            if (index >= 0 && index != tab_bar.get_active_index()) {
                tab_bar.set_tab_highlighted(index, true);
            }
        });

        tab.context_menu_requested.connect((terminal, x, y, url) => {
            show_terminal_context_menu(tab, terminal, x, y, url);
        });
    }

    private void insert_tab(TerminalTab tab, string title, int tab_id, int index = -1) {
        int current_count = (int)tabs.length();
        int target_index = index;
        if (target_index < 0 || target_index > current_count) {
            target_index = current_count;
        }

        prepare_tab(tab);

        if (target_index == current_count) {
            tabs.append(tab);
            tab_bar.add_tab(title);
        } else {
            tabs.insert(tab, target_index);
            tab_bar.insert_tab(target_index, title);
        }

        stack.add_named(tab, "tab_" + tab_id.to_string());
    }

    private void detach_active_pane_to_new_tab_right() {
        close_context_menu();

        int current_index = tab_bar.get_active_index();
        if (current_index < 0 || current_index >= tabs.length()) {
            return;
        }

        var source_tab = tabs.nth_data((uint)current_index);
        if (source_tab == null || !source_tab.has_multiple_terminals()) {
            return;
        }

        DetachedTerminalState? detached_state = source_tab.detach_focused_terminal();
        if (detached_state == null) {
            return;
        }

        int tab_id = allocate_tab_id();
        var tab = new TerminalTab.from_detached(detached_state);
        int insert_index = current_index + 1;

        insert_tab(tab, detached_state.title, tab_id, insert_index);
        switch_to_tab(insert_index);
    }

    private void add_new_tab_after_index(int anchor_index) {
        close_context_menu();
        int tab_id = allocate_tab_id();
        bool is_first_tab = (tab_id == 1);
        int current_count = (int)tabs.length();

        int source_index = anchor_index;
        if (source_index < 0 || source_index >= current_count) {
            source_index = tab_bar.get_active_index();
        }

        int insert_index = current_count;
        if (source_index >= 0 && source_index < current_count) {
            insert_index = source_index + 1;
        }

        // Get working directory from the source tab
        string? working_directory = null;
        if (source_index >= 0 && source_index < current_count) {
            var current_tab = tabs.nth_data((uint)source_index);
            if (current_tab != null) {
                working_directory = current_tab.get_current_working_directory();
            }
        }

        var tab = new TerminalTab("Terminal " + tab_id.to_string(), is_first_tab, working_directory);
        insert_tab(tab, "Terminal " + tab_id.to_string(), tab_id, insert_index);
        switch_to_tab(insert_index);
    }

    public void add_new_tab() {
        add_new_tab_after_index(tab_bar.get_active_index());
    }

    private void on_tab_selected(int index) {
        if (index >= 0 && index < tabs.length()) {
            close_context_menu();
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
        close_context_menu();
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

        // Use the outer window size here. KDE quick-tile on X11 may not set a
        // GTK tiled state, but the window geometry still jumps to half-screen.
        int width_tolerance = shadow_size * 2 + 32;
        int height_tolerance = shadow_size * 2 + 64;

        // Check for half-screen width (left or right snap)
        bool is_half_width = (win_width >= mon_width / 2 - width_tolerance) &&
                             (win_width <= mon_width / 2 + width_tolerance);
        bool is_full_width = win_width >= mon_width - width_tolerance;

        // Check for full height (top/bottom snap)
        bool is_full_height = win_height >= mon_height - height_tolerance;

        // Check for half height (corner snap)
        bool is_half_height = (win_height >= mon_height / 2 - height_tolerance) &&
                              (win_height <= mon_height / 2 + height_tolerance);

        // Determine snap position based on window geometry
        // Since GTK4 doesn't directly expose window position, we need to use
        // the window's actual allocation or surface position

        WindowSnapPosition new_position = WindowSnapPosition.NONE;
        bool is_snapped = false;

        if ((is_full_width || is_half_width) && is_full_height) {
            is_snapped = true;
            new_position = WindowSnapPosition.MAXIMIZED;
        } else if (is_half_width && is_half_height) {
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
        close_context_menu();
        // Don't show if already visible
        if (settings_dialog != null) {
            return;
        }

        // Get foreground color from current tab
        Gdk.RGBA fg_color = Gdk.RGBA();
        fg_color.parse("#00cd00"); // Default green color

        if (tabs.length() > 0) {
            var tab = tabs.nth_data((uint)tab_bar.get_active_index());
            if (tab != null) {
                fg_color = tab.get_foreground_color();
            }
        }

        // Create settings dialog as overlay widget
        settings_dialog = new SettingsDialog(fg_color, background_color, config);

        // Connect closed signal to remove dialog
        settings_dialog.closed.connect(() => {
            if (settings_dialog != null) {
                main_overlay.remove_overlay(settings_dialog);
                settings_dialog = null;
                // Return focus to terminal
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) {
                        tab.grab_focus();
                    }
                }
            }
        });

        // Connect settings change signals
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

        settings_dialog.settings_scroll_speed_changed.connect((scroll_speed) => {
            apply_settings_scroll_speed(scroll_speed);
        });

        // Add to overlay and grab focus
        main_overlay.add_overlay(settings_dialog);
        settings_dialog.grab_focus();
    }

    // Public method to show confirmation dialog
    public void show_confirm_dialog(string message, Gdk.RGBA fg_color, Gdk.RGBA bg_color, owned VoidCallback? on_confirmed) {
        close_context_menu();
        // Don't show if already visible
        if (confirm_dialog != null) {
            return;
        }

        // Create confirm dialog as overlay widget
        confirm_dialog = new ConfirmDialog(message, fg_color, bg_color);

        // Connect confirmed signal
        confirm_dialog.confirmed.connect(() => {
            if (on_confirmed != null) {
                on_confirmed();
            }
        });

        // Connect closed signal to remove dialog
        confirm_dialog.closed.connect(() => {
            if (confirm_dialog != null) {
                main_overlay.remove_overlay(confirm_dialog);
                confirm_dialog = null;
                // Return focus to terminal
                if (tabs.length() > 0) {
                    var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                    if (tab != null) {
                        tab.grab_focus();
                    }
                }
            }
        });

        // Add to overlay and grab focus
        main_overlay.add_overlay(confirm_dialog);
        confirm_dialog.grab_focus();
        confirm_dialog.focus_confirm_button();
    }

    // Callback delegate type for confirmation dialogs
    public delegate void VoidCallback();

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
                this.tab_color.parse(tab_str);

                // If tab_bar exists, update it; otherwise it will be set during setup_layout
                if (tab_bar != null) {
                    tab_bar.set_active_tab_color(this.tab_color);
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
        update_context_menu_theme();
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
        update_context_menu_theme();
    }

    private void apply_settings_scroll_speed(double scroll_speed) {
        config.update_settings_scroll_speed(scroll_speed);
    }

    private void setup_background_image() {
        string image_path = config.background_image;
        if (image_path == null || image_path == "") {
            return;
        }

        // Expand ~/ to home directory
        if (image_path.has_prefix("~/")) {
            image_path = Environment.get_home_dir() + image_path.substring(1);
        }

        var file = File.new_for_path(image_path);
        if (!file.query_exists()) {
            stderr.printf("Background image not found: %s\n", image_path);
            return;
        }

        // If it's a directory, pick a random image from it
        try {
            var info = file.query_info(FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
            if (info.get_file_type() == FileType.DIRECTORY) {
                background_dir = file;
                file = pick_random_image(file, null);
                if (file == null) {
                    stderr.printf("No images found in directory: %s\n", image_path);
                    return;
                }
            }
        } catch (Error e) {
            stderr.printf("Error checking path: %s\n", e.message);
            return;
        }

        current_background_path = file.get_path();
        background_picture = new Gtk.Picture.for_file(file);
        background_picture.set_content_fit(Gtk.ContentFit.COVER);
        background_picture.set_can_shrink(true);
        background_picture.set_hexpand(true);
        background_picture.set_vexpand(true);
    }

    private File? pick_random_image(File dir, string? exclude_path) {
        var images = new GenericArray<File>();
        try {
            var enumerator = dir.enumerate_children(
                FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
                FileQueryInfoFlags.NONE
            );
            FileInfo? child_info;
            while ((child_info = enumerator.next_file()) != null) {
                if (child_info.get_file_type() != FileType.REGULAR) {
                    continue;
                }
                string name = child_info.get_name().down();
                if (name.has_suffix(".jpg") || name.has_suffix(".jpeg") ||
                    name.has_suffix(".png") || name.has_suffix(".webp") ||
                    name.has_suffix(".bmp")) {
                    var child = dir.get_child(child_info.get_name());
                    if (exclude_path == null || child.get_path() != exclude_path) {
                        images.add(child);
                    }
                }
            }
        } catch (Error e) {
            stderr.printf("Error reading directory: %s\n", e.message);
            return null;
        }

        if (images.length == 0) {
            return null;
        }

        int index = Random.int_range(0, (int32)images.length);
        return images[index];
    }

    private void switch_background_image() {
        if (background_dir == null || background_picture == null) {
            return;
        }

        var new_image = pick_random_image(background_dir, current_background_path);
        if (new_image != null) {
            current_background_path = new_image.get_path();
            background_picture.set_file(new_image);
        }
    }
}
