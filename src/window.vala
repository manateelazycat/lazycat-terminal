// Terminal Window with transparent background, custom title bar, and KDE-style shadow

public class TerminalWindow : ShadowWindow {
    private TabBar tab_bar;
    private Gtk.Stack stack;
    private List<TerminalTab> tabs;
    private int tab_counter = 0;
    private Gtk.Box main_box;
    private double background_opacity = 0.88;
    private Gtk.CssProvider css_provider;

    public TerminalWindow(Gtk.Application app) {
        Object(application: app);
    }

    construct {
        tabs = new List<TerminalTab>();
        setup_window();
        setup_layout();
        add_new_tab();
        setup_snap_detection();
    }

    private void setup_window() {
        set_title("LazyCat Terminal");

        // Add CSS for styling
        load_css();
    }

    private void load_css() {
        css_provider = new Gtk.CssProvider();
        update_opacity_css();

        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private void update_opacity_css() {
        double tab_bar_opacity = double.min(1.0, background_opacity + 0.01);

        string css = """
            .transparent-window {
                background-color: rgba(0, 0, 0, """ + background_opacity.to_string() + """);
                border-radius: 6px;
            }
            .transparent-window.maximized {
                border-radius: 0;
            }
            .tab-bar {
                background-color: rgba(0, 0, 0, """ + tab_bar_opacity.to_string() + """);
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
            bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
            bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;

            // Debug: Print all Ctrl+Shift key presses
            if (ctrl && shift) {
                stdout.printf("DEBUG: Key pressed - keyval=%u (0x%x), keycode=%u, ctrl=%s, shift=%s\n",
                    keyval, keyval, keycode, ctrl.to_string(), shift.to_string());
            }

            if (ctrl && shift) {
                switch (keyval) {
                    case Gdk.Key.T:
                        // Ctrl+Shift+T: New tab
                        add_new_tab();
                        return true;
                    case Gdk.Key.W:
                        // Ctrl+Shift+W: Close tab
                        if (tabs.length() > 0) {
                            var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                            if (tab != null) close_tab(tab);
                        }
                        return true;
                    case Gdk.Key.C:
                        // Ctrl+Shift+C: Copy
                        if (tabs.length() > 0) {
                            var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                            if (tab != null) tab.copy_clipboard();
                        }
                        return true;
                    case Gdk.Key.V:
                        // Ctrl+Shift+V: Paste
                        if (tabs.length() > 0) {
                            var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                            if (tab != null) tab.paste_clipboard();
                        }
                        return true;
                    case Gdk.Key.A:
                        // Ctrl+Shift+A: Select all
                        if (tabs.length() > 0) {
                            var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                            if (tab != null) tab.select_all();
                        }
                        return true;
                    case Gdk.Key.J:
                        // Ctrl+Shift+J: Split vertically (left-right)
                        stdout.printf("DEBUG: Ctrl+Shift+J pressed\n");
                        if (tabs.length() > 0) {
                            var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                            stdout.printf("DEBUG: tab = %p\n", tab);
                            if (tab != null) {
                                stdout.printf("DEBUG: Calling split_vertical()\n");
                                tab.split_vertical();
                            }
                        }
                        return true;
                    case Gdk.Key.H:
                        // Ctrl+Shift+H: Split horizontally (top-bottom)
                        stdout.printf("DEBUG: Ctrl+Shift+H pressed\n");
                        if (tabs.length() > 0) {
                            var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                            stdout.printf("DEBUG: tab = %p\n", tab);
                            if (tab != null) {
                                stdout.printf("DEBUG: Calling split_horizontal()\n");
                                tab.split_horizontal();
                            }
                        }
                        return true;
                    case Gdk.Key.ISO_Left_Tab:
                        // Ctrl+Shift+Tab: Previous tab (cycles)
                        cycle_tab(-1);
                        return true;
                }
            } else if (ctrl) {
                switch (keyval) {
                    case Gdk.Key.Tab:
                        // Ctrl+Tab: Next tab (cycles)
                        cycle_tab(1);
                        return true;
                    case Gdk.Key.Page_Up:
                        // Ctrl+PageUp: Previous tab
                        cycle_tab(-1);
                        return true;
                    case Gdk.Key.Page_Down:
                        // Ctrl+PageDown: Next tab
                        cycle_tab(1);
                        return true;
                    case Gdk.Key.minus:
                    case Gdk.Key.KP_Subtract:
                        // Ctrl+-: Decrease font size
                        decrease_all_font_sizes();
                        return true;
                    case Gdk.Key.equal:
                    case Gdk.Key.plus:
                    case Gdk.Key.KP_Add:
                        // Ctrl+=: Increase font size
                        increase_all_font_sizes();
                        return true;
                    case Gdk.Key.@0:
                    case Gdk.Key.KP_0:
                        // Ctrl+0: Reset font size
                        reset_all_font_sizes();
                        return true;
                }
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
        var tab = new TerminalTab("Terminal " + tab_counter.to_string());

        // Set initial background opacity
        tab.set_background_opacity(background_opacity);

        tab.title_changed.connect((title) => {
            tab_bar.update_tab_title(tabs.index(tab), title);
        });

        tab.close_requested.connect(() => {
            close_tab(tab);
        });

        tabs.append(tab);
        stack.add_named(tab, "tab_" + tab_counter.to_string());
        tab_bar.add_tab("Terminal " + tab_counter.to_string());

        // Switch to new tab
        stack.set_visible_child(tab);
        tab_bar.set_active_tab((int)tabs.length() - 1);

        tab.grab_focus();
    }

    private void on_tab_selected(int index) {
        if (index >= 0 && index < tabs.length()) {
            var tab = tabs.nth_data((uint)index);
            stack.set_visible_child(tab);
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
        // Monitor window size changes to detect snap positions
        notify["default-width"].connect(detect_snap_position);
        notify["default-height"].connect(detect_snap_position);

        // Use map signal instead of realize
        map.connect(() => {
            detect_snap_position();
        });

        // Use tick callback for continuous position monitoring
        add_tick_callback((widget, clock) => {
            detect_snap_position();
            return true;
        });
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
}
