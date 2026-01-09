// Terminal Window with transparent background and custom title bar

public class TerminalWindow : Gtk.ApplicationWindow {
    private TabBar tab_bar;
    private Gtk.Stack stack;
    private List<TerminalTab> tabs;
    private int tab_counter = 0;

    public TerminalWindow(Gtk.Application app) {
        Object(application: app);
    }

    construct {
        tabs = new List<TerminalTab>();
        setup_window();
        setup_layout();
        add_new_tab();
    }

    private void setup_window() {
        // Remove default title bar, use CSD
        set_decorated(false);
        set_default_size(900, 600);
        set_title("LazyCat Terminal");

        // Enable transparency
        setup_transparency();

        // Add CSS for styling
        load_css();
    }

    private void setup_transparency() {
        // Set visual for transparency
        var surface = get_surface();
        if (surface != null) {
            // GTK4 handles transparency differently
        }

        // Add CSS class for transparency
        add_css_class("transparent-window");
    }

    private void load_css() {
        var provider = new Gtk.CssProvider();
        provider.load_from_string("""
            .transparent-window {
                background-color: rgba(0, 0, 0, 0.88);
            }
            .tab-bar {
                background-color: rgba(0, 0, 0, 0.88);
                min-height: 38px;
            }
            .terminal-container {
                background-color: transparent;
            }
        """);

        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private void setup_layout() {
        var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        // Create tab bar
        tab_bar = new TabBar();
        tab_bar.add_css_class("tab-bar");
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

        set_child(main_box);

        // Enable window dragging from tab bar
        setup_window_drag();
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
        controller.key_pressed.connect((keyval, keycode, state) => {
            bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
            bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;

            if (ctrl && shift) {
                switch (keyval) {
                    case Gdk.Key.T:
                        add_new_tab();
                        return true;
                    case Gdk.Key.W:
                        if (tabs.length() > 0) {
                            var tab = tabs.nth_data((uint)tab_bar.get_active_index());
                            if (tab != null) close_tab(tab);
                        }
                        return true;
                    case Gdk.Key.Tab:
                        // Next tab
                        cycle_tab(1);
                        return true;
                    case Gdk.Key.ISO_Left_Tab:
                        // Previous tab
                        cycle_tab(-1);
                        return true;
                }
            } else if (ctrl) {
                // Ctrl+PageUp/PageDown for tab switching
                if (keyval == Gdk.Key.Page_Up) {
                    cycle_tab(-1);
                    return true;
                } else if (keyval == Gdk.Key.Page_Down) {
                    cycle_tab(1);
                    return true;
                }
            }

            return false;
        });
        ((Gtk.Widget)this).add_controller(controller);
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
}
