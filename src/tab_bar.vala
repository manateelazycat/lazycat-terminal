// Chrome-style Tab Bar with custom drawing

public class TabBar : Gtk.DrawingArea {
    private List<TabInfo> tab_infos;
    private int active_index = -1;
    private int hover_index = -1;
    private int hover_control = -1;  // 0=minimize, 1=maximize, 2=close, -1=none
    private int pressed_control = -1;
    private bool hover_new_tab = false;
    private bool pressed_new_tab = false;

    // Window control button constants (80% of original 16px)
    private const double CTRL_BTN_SIZE = 12.8;
    private const double CTRL_BTN_SPACING = 20;  // Doubled spacing to avoid accidental clicks
    private const double CTRL_BTN_AREA_WIDTH = 85;

    private const int TAB_HEIGHT = 34;
    private const int TAB_MIN_WIDTH = 80;
    private const int TAB_MAX_WIDTH = 200;
    private const int TAB_OVERLAP = 16;
    private const int TAB_PADDING = 12;
    private const int CLOSE_BTN_SIZE = 16;
    private const int NEW_TAB_BTN_SIZE = 36;  // 36px button size
    private const int NEW_TAB_BTN_MARGIN_LEFT = 20;  // 20px left margin
    private const int CORNER_RADIUS = 10;

    public signal void tab_selected(int index);
    public signal void tab_closed(int index);
    public signal void new_tab_requested();

    private class TabInfo {
        public string title;
        public int x;
        public int width;

        public TabInfo(string title) {
            this.title = title;
            this.x = 0;
            this.width = 0;
        }
    }

    public TabBar() {
        Object();
    }

    construct {
        tab_infos = new List<TabInfo>();

        set_content_height(TAB_HEIGHT + 4);
        set_draw_func(draw_tabs);

        // Mouse events
        var motion = new Gtk.EventControllerMotion();
        motion.motion.connect(on_motion);
        motion.leave.connect(on_leave);
        add_controller(motion);

        var click = new Gtk.GestureClick();
        click.set_button(0);
        click.pressed.connect(on_press);
        click.released.connect(on_release);
        add_controller(click);
    }

    private void draw_tabs(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Calculate tab positions and widths
        calculate_tab_layout(width);

        // Draw background - black with 0.88 opacity
        cr.set_source_rgba(0.0, 0.0, 0.0, 0.88);
        cr.rectangle(0, 0, width, height);
        cr.fill();

        // Draw inactive tabs first (back to front for overlap)
        for (int i = (int)tab_infos.length() - 1; i >= 0; i--) {
            if (i != active_index) {
                draw_tab(cr, i, height, false);
            }
        }

        // Draw active tab on top
        if (active_index >= 0 && active_index < tab_infos.length()) {
            draw_tab(cr, active_index, height, true);
        }

        // Draw new tab button
        draw_new_tab_button(cr, width, height);

        // Draw window controls (minimize, maximize, close)
        draw_window_controls(cr, width, height);
    }

    private void calculate_tab_layout(int available_width) {
        if (tab_infos.length() == 0) return;

        // Reserve space for new tab button and window controls
        int reserved = NEW_TAB_BTN_SIZE + 20 + 90;
        int usable_width = available_width - reserved - TAB_PADDING;

        // Calculate tab width
        int overlap_total = (int)(tab_infos.length() - 1) * TAB_OVERLAP;
        int tab_width = (usable_width + overlap_total) / (int)tab_infos.length();
        tab_width = int.min(tab_width, TAB_MAX_WIDTH);
        tab_width = int.max(tab_width, TAB_MIN_WIDTH);

        // Set positions
        int x = TAB_PADDING;
        for (int i = 0; i < tab_infos.length(); i++) {
            var info = tab_infos.nth_data((uint)i);
            info.x = x;
            info.width = tab_width;
            x += tab_width - TAB_OVERLAP;
        }
    }

    private void draw_tab(Cairo.Context cr, int index, int height, bool is_active) {
        var info = tab_infos.nth_data((uint)index);
        if (info == null) return;

        double x = info.x;
        double w = info.width;
        double h = TAB_HEIGHT;
        double y = height - h;

        // Tab title
        draw_tab_title(cr, info, x, y, w, h, is_active);

        // Draw underline for active tab (full width of tab)
        if (is_active) {
            double underline_y = height - 2;

            cr.set_source_rgba(0.172, 0.655, 0.973, 1.0);  // #2CA7F8
            cr.set_line_width(2.0);
            cr.move_to(x, underline_y);
            cr.line_to(x + w, underline_y);
            cr.stroke();
        }
    }

    private void draw_tab_title(Cairo.Context cr, TabInfo info, double x, double y, double w, double h, bool is_active) {
        cr.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size(15);

        // Truncate title if needed
        // Text area: tab width - 40px (20px padding on each side)
        string title = info.title;
        double max_text_width = w - 40;

        Cairo.TextExtents extents;
        cr.text_extents(title, out extents);

        if (extents.width > max_text_width) {
            while (title.length > 3 && extents.width > max_text_width) {
                title = title.substring(0, title.length - 4) + "...";
                cr.text_extents(title, out extents);
            }
        }

        // Center text horizontally in tab
        double text_x = x + (w - extents.width) / 2;
        double text_y = y + h / 2 + extents.height / 2 - 2;

        if (is_active) {
            cr.set_source_rgba(0.172, 0.655, 0.973, 1.0);  // #2CA7F8
        } else {
            cr.set_source_rgba(0.7, 0.7, 0.7, 1.0);
        }

        cr.move_to(text_x, text_y);
        cr.show_text(title);
    }

    private void draw_new_tab_button(Cairo.Context cr, int width, int height) {
        double btn_x = get_new_tab_button_x();
        double btn_y = (height - NEW_TAB_BTN_SIZE) / 2;
        double center_x = btn_x + NEW_TAB_BTN_SIZE / 2;
        double center_y = btn_y + NEW_TAB_BTN_SIZE / 2;

        // Plus icon with 10px padding inside the button area
        cr.set_antialias(Cairo.Antialias.NONE);  // Disable anti-aliasing for crisp lines
        cr.set_line_width(1.0);  // Thinner line to match window control buttons

        // Determine color based on hover/pressed state (same as window control buttons)
        double alpha = 0.6;  // Default: subtle
        if (pressed_new_tab) {
            alpha = 1.0;  // Pressed: full brightness
        } else if (hover_new_tab) {
            alpha = 0.85;  // Hover: brighter
        }
        cr.set_source_rgba(0.7, 0.7, 0.7, alpha);  // Opaque color matching window control buttons

        double offset = 8;  // 10px padding from edges means (36-20)/2 = 8px offset
        cr.move_to(center_x - offset, center_y);
        cr.line_to(center_x + offset, center_y);
        cr.stroke();

        cr.move_to(center_x, center_y - offset);
        cr.line_to(center_x, center_y + offset);
        cr.stroke();
    }

    private void draw_window_controls(Cairo.Context cr, int width, int height) {
        double btn_size = CTRL_BTN_SIZE;
        double spacing = CTRL_BTN_SPACING;
        double start_x = width - CTRL_BTN_AREA_WIDTH;
        double y = height / 2;

        // Check if window is maximized
        bool is_maximized = false;
        var window = get_root() as Gtk.Window;
        if (window != null) {
            is_maximized = window.is_maximized();
        }

        // Disable anti-aliasing for crisp lines
        cr.set_antialias(Cairo.Antialias.NONE);

        // Draw each control button
        for (int i = 0; i < 3; i++) {
            double btn_x = start_x + i * (btn_size + spacing);

            // Determine color based on hover/pressed state
            double alpha = 0.6;  // Default: subtle
            if (pressed_control == i) {
                alpha = 1.0;  // Pressed: full brightness
            } else if (hover_control == i) {
                alpha = 0.85;  // Hover: brighter
            }
            cr.set_source_rgba(0.7, 0.7, 0.7, alpha);
            cr.set_line_width(1.0);  // Thinner, more delicate lines

            if (i == 0) {
                // Minimize button - horizontal line
                cr.move_to(btn_x - btn_size / 2, y);
                cr.line_to(btn_x + btn_size / 2, y);
                cr.stroke();
            } else if (i == 1) {
                // Maximize/Restore button
                double box_size = btn_size - 3;
                if (is_maximized) {
                    // Restore icon: two overlapping rectangles
                    double small_box = box_size * 0.75;
                    double offset = box_size * 0.25;

                    // Back rectangle (top-right)
                    cr.rectangle(btn_x - small_box / 2 + offset, y - small_box / 2 - offset, small_box, small_box);
                    cr.stroke();

                    // Front rectangle (bottom-left) with filled background to cover overlap
                    cr.set_source_rgba(0.16, 0.16, 0.16, 0.9);
                    cr.rectangle(btn_x - small_box / 2 - offset, y - small_box / 2 + offset, small_box, small_box);
                    cr.fill();

                    // Redraw front rectangle outline
                    if (pressed_control == i) {
                        alpha = 1.0;
                    } else if (hover_control == i) {
                        alpha = 0.85;
                    } else {
                        alpha = 0.6;
                    }
                    cr.set_source_rgba(0.7, 0.7, 0.7, alpha);
                    cr.rectangle(btn_x - small_box / 2 - offset, y - small_box / 2 + offset, small_box, small_box);
                    cr.stroke();
                } else {
                    // Maximize icon: single rectangle
                    cr.rectangle(btn_x - box_size / 2, y - box_size / 2, box_size, box_size);
                    cr.stroke();
                }
            } else {
                // Close button - X shape
                double offset = (btn_size - 3) / 2;
                cr.move_to(btn_x - offset, y - offset);
                cr.line_to(btn_x + offset, y + offset);
                cr.stroke();
                cr.move_to(btn_x + offset, y - offset);
                cr.line_to(btn_x - offset, y + offset);
                cr.stroke();
            }
        }
    }

    private double get_new_tab_button_x() {
        if (tab_infos.length() == 0) {
            return TAB_PADDING + NEW_TAB_BTN_MARGIN_LEFT;
        }
        var last = tab_infos.nth_data((uint)(tab_infos.length() - 1));
        return last.x + last.width - TAB_OVERLAP + 8 + NEW_TAB_BTN_MARGIN_LEFT;
    }

    private void on_motion(double x, double y) {
        int old_hover = hover_index;
        int old_hover_control = hover_control;
        bool old_hover_new_tab = hover_new_tab;

        hover_index = -1;
        hover_control = -1;
        hover_new_tab = false;

        // Check window control buttons first
        int width = get_width();
        double btn_size = CTRL_BTN_SIZE;
        double spacing = CTRL_BTN_SPACING;
        double start_x = width - CTRL_BTN_AREA_WIDTH;
        double hit_radius = btn_size / 2 + 3;

        for (int i = 0; i < 3; i++) {
            double btn_x = start_x + i * (btn_size + spacing);
            if (Math.fabs(x - btn_x) <= hit_radius && Math.fabs(y - get_height() / 2) <= hit_radius) {
                hover_control = i;
                break;
            }
        }

        // Check new tab button (only if not hovering control buttons)
        if (hover_control < 0) {
            double new_tab_x = get_new_tab_button_x();
            double new_tab_y = (get_height() - NEW_TAB_BTN_SIZE) / 2;
            double new_tab_hit_radius = NEW_TAB_BTN_SIZE / 2 + 3;

            if (Math.fabs(x - (new_tab_x + NEW_TAB_BTN_SIZE / 2)) <= new_tab_hit_radius &&
                Math.fabs(y - (new_tab_y + NEW_TAB_BTN_SIZE / 2)) <= new_tab_hit_radius) {
                hover_new_tab = true;
            }
        }

        // Check tabs (only if not hovering control buttons or new tab button)
        if (hover_control < 0 && !hover_new_tab) {
            for (int i = 0; i < tab_infos.length(); i++) {
                var info = tab_infos.nth_data((uint)i);
                if (x >= info.x && x <= info.x + info.width && y <= TAB_HEIGHT + 4) {
                    hover_index = i;
                    break;
                }
            }
        }

        if (old_hover != hover_index || old_hover_control != hover_control || old_hover_new_tab != hover_new_tab) {
            queue_draw();
        }
    }

    private void on_leave() {
        bool need_redraw = hover_index != -1 || hover_control != -1 || hover_new_tab;
        hover_index = -1;
        hover_control = -1;
        hover_new_tab = false;
        if (need_redraw) {
            queue_draw();
        }
    }

    private void on_press(int n_press, double x, double y) {
        // Check window control buttons - set pressed state
        int width = get_width();
        double btn_size = CTRL_BTN_SIZE;
        double spacing = CTRL_BTN_SPACING;
        double start_x = width - CTRL_BTN_AREA_WIDTH;
        double hit_radius = btn_size / 2 + 3;

        for (int i = 0; i < 3; i++) {
            double btn_x = start_x + i * (btn_size + spacing);
            if (Math.fabs(x - btn_x) <= hit_radius && Math.fabs(y - get_height() / 2) <= hit_radius) {
                pressed_control = i;
                queue_draw();
                return;
            }
        }

        // Check new tab button - set pressed state
        double new_tab_x = get_new_tab_button_x();
        double new_tab_y = (get_height() - NEW_TAB_BTN_SIZE) / 2;
        double new_tab_hit_radius = NEW_TAB_BTN_SIZE / 2 + 3;

        if (Math.fabs(x - (new_tab_x + NEW_TAB_BTN_SIZE / 2)) <= new_tab_hit_radius &&
            Math.fabs(y - (new_tab_y + NEW_TAB_BTN_SIZE / 2)) <= new_tab_hit_radius) {
            pressed_new_tab = true;
            queue_draw();
            return;
        }

        pressed_control = -1;
        pressed_new_tab = false;
    }

    private void on_release(int n_press, double x, double y) {
        // Check new tab button - execute action if released on same button
        double new_tab_x = get_new_tab_button_x();
        double new_tab_y = (get_height() - NEW_TAB_BTN_SIZE) / 2;
        double new_tab_hit_radius = NEW_TAB_BTN_SIZE / 2 + 3;

        if (Math.fabs(x - (new_tab_x + NEW_TAB_BTN_SIZE / 2)) <= new_tab_hit_radius &&
            Math.fabs(y - (new_tab_y + NEW_TAB_BTN_SIZE / 2)) <= new_tab_hit_radius) {
            // Only trigger if released on the same button that was pressed
            if (pressed_new_tab) {
                new_tab_requested();
            }
            pressed_new_tab = false;
            queue_draw();
            return;
        }

        pressed_new_tab = false;

        // Check window controls - execute action if released on same button
        int width = get_width();
        double btn_size = CTRL_BTN_SIZE;
        double spacing = CTRL_BTN_SPACING;
        double start_x = width - CTRL_BTN_AREA_WIDTH;
        double hit_radius = btn_size / 2 + 3;

        for (int i = 0; i < 3; i++) {
            double ctrl_x = start_x + i * (btn_size + spacing);
            if (Math.fabs(x - ctrl_x) <= hit_radius && Math.fabs(y - get_height() / 2) <= hit_radius) {
                // Only trigger if released on the same button that was pressed
                if (pressed_control == i) {
                    var window = get_root() as Gtk.Window;
                    if (window != null) {
                        if (i == 0) {
                            window.minimize();
                        } else if (i == 1) {
                            if (window.is_maximized()) {
                                window.unmaximize();
                            } else {
                                window.maximize();
                            }
                        } else {
                            window.close();
                        }
                    }
                }
                pressed_control = -1;
                queue_draw();
                return;
            }
        }

        pressed_control = -1;

        // Check tab selection
        if (hover_index >= 0 && hover_index != active_index) {
            active_index = hover_index;
            tab_selected(active_index);
            queue_draw();
        }
    }

    // Check if position is over window control buttons (minimize/maximize/close)
    public bool is_over_window_controls(int x, int y) {
        return x >= get_width() - 90;
    }

    // Get tab index at position, returns -1 if not over any tab
    public int get_tab_at(int x, int y) {
        if (y > TAB_HEIGHT + 4) return -1;

        for (int i = 0; i < tab_infos.length(); i++) {
            var info = tab_infos.nth_data((uint)i);
            if (x >= info.x && x <= info.x + info.width) {
                return i;
            }
        }
        return -1;
    }

    // Check if position is over new tab button
    public bool is_over_new_tab_button(int x, int y) {
        double btn_x = get_new_tab_button_x();
        return x >= btn_x && x <= btn_x + NEW_TAB_BTN_SIZE && y <= TAB_HEIGHT + 4;
    }

    public void add_tab(string title) {
        tab_infos.append(new TabInfo(title));
        queue_draw();
    }

    public void remove_tab(int index) {
        if (index >= 0 && index < tab_infos.length()) {
            var info = tab_infos.nth_data((uint)index);
            tab_infos.remove(info);

            if (active_index >= tab_infos.length()) {
                active_index = (int)tab_infos.length() - 1;
            }
            queue_draw();
        }
    }

    public void set_active_tab(int index) {
        if (index >= 0 && index < tab_infos.length()) {
            active_index = index;
            queue_draw();
        }
    }

    public void update_tab_title(int index, string title) {
        if (index >= 0 && index < tab_infos.length()) {
            var info = tab_infos.nth_data((uint)index);
            info.title = title;
            queue_draw();
        }
    }

    public int get_active_index() {
        return active_index;
    }
}
