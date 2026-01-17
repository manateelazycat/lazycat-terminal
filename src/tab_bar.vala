// Chrome-style Tab Bar with custom drawing

public class TabBar : Gtk.DrawingArea {
    private List<TabInfo> tab_infos;
    private int active_index = -1;
    private int hover_index = -1;
    private int hover_control = -1;  // 0=minimize, 1=maximize, 2=close, -1=none
    private int pressed_control = -1;
    private bool hover_new_tab = false;
    private bool pressed_new_tab = false;
    private bool hover_settings_btn = false;
    private bool pressed_settings_btn = false;
    private double background_opacity = 0.93;  // Default opacity for tab bar

    // Tab close button state
    private int hover_close_index = -1;  // Which tab's close button is being hovered
    private int pressed_close_index = -1;  // Which tab's close button is being pressed

    // Background color
    private Gdk.RGBA background_color;

    // Active tab color (from theme)
    private Gdk.RGBA active_tab_color;

    // Scrolling state
    private bool scrolling_enabled = false;
    private double scroll_offset = 0.0;  // Current scroll position (pixels from left)
    private double target_scroll_offset = 0.0;  // Target for smooth scrolling
    private double max_scroll_offset = 0.0;  // Maximum scroll value
    private bool animating_scroll = false;
    private uint scroll_animation_id = 0;

    // Window control button constants (80% of original 16px)
    private const double CTRL_BTN_SIZE = 12.8;
    private const double CTRL_BTN_SPACING = 20;  // Doubled spacing to avoid accidental clicks
    private const double CTRL_BTN_AREA_WIDTH = 85;

    private const int TAB_HEIGHT = 34;
    private const int TAB_MIN_WIDTH = 80;
    private const int TAB_MAX_WIDTH = 200;
    private const int TAB_OVERLAP = 16;
    private const int TAB_PADDING = 12;
    private const int TAB_CLOSE_BTN_SIZE = 10;  // Close button size (60% of original 16px)
    private const int TAB_CLOSE_BTN_PADDING = 8;  // Padding from right edge
    private const int NEW_TAB_BTN_SIZE = 36;  // 36px button size
    private const int NEW_TAB_BTN_MARGIN_LEFT = 20;  // 20px left margin
    private const int CORNER_RADIUS = 10;
    // Reserved space for right side: new_tab_btn + gap + settings_btn + gap + window_controls
    private const int RIGHT_RESERVED_WIDTH = NEW_TAB_BTN_SIZE + 10 + NEW_TAB_BTN_SIZE + 10 + (int)CTRL_BTN_AREA_WIDTH;  // 177

    // Scrolling constants
    private const int SCROLL_BTN_WIDTH = 24;
    private const int SCROLL_BTN_PADDING = 4;
    private const double SCROLL_SPEED = 30.0;
    private const double SCROLL_ANIMATION_SPEED = 0.2;
    private const int SCROLL_THRESHOLD_WIDTH = 140;

    public signal void tab_selected(int index);
    public signal void tab_closed(int index);
    public signal void new_tab_requested();
    public signal void settings_button_clicked();

    private class TabInfo {
        public string title;
        public int x;
        public int width;
        public bool highlighted;  // Whether tab should be highlighted (background activity)

        public TabInfo(string title) {
            this.title = title;
            this.x = 0;
            this.width = 0;
            this.highlighted = false;
        }
    }

    public TabBar() {
        Object();
    }

    construct {
        tab_infos = new List<TabInfo>();

        // Initialize default background color (black)
        background_color = Gdk.RGBA();
        background_color.parse("#000000");

        // Initialize default active tab color (blue)
        active_tab_color = Gdk.RGBA();
        active_tab_color.parse("#2CA7F8");

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

        // Scroll controller for mouse wheel
        setup_scroll_controller();
    }

    private void draw_tabs(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Calculate tab positions and widths
        calculate_tab_layout(width);

        // Draw background with dynamic opacity
        cr.set_source_rgba(
            background_color.red,
            background_color.green,
            background_color.blue,
            background_opacity
        );
        cr.rectangle(0, 0, width, height);
        cr.fill();

        // If scrolling is enabled, set up clipping region for tabs
        if (scrolling_enabled) {
            cr.save();
            int clip_x = TAB_PADDING;
            int clip_width = width - clip_x - RIGHT_RESERVED_WIDTH;
            cr.rectangle(clip_x, 0, clip_width, height);
            cr.clip();
        }

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

        // Restore context if clipping was applied
        if (scrolling_enabled) {
            cr.restore();
        }

        // Draw new tab button
        draw_new_tab_button(cr, width, height);

        // Draw settings button
        draw_settings_button(cr, width, height);

        // Draw window controls (minimize, maximize, close)
        draw_window_controls(cr, width, height);
    }

    private int calculate_tab_width_for_text(string text) {
        // Use Pango to measure text (supports emoji and complex scripts)
        var layout = create_pango_layout(text);
        var font_desc = Pango.FontDescription.from_string("Sans 11");
        layout.set_font_description(font_desc);

        int text_width, text_height;
        layout.get_pixel_size(out text_width, out text_height);

        // Width = text width + 40px (20px padding on each side)
        int calculated_width = text_width + 40;

        // Cap at maximum width (doubled: 400px)
        int max_width = TAB_MAX_WIDTH * 2;
        return int.min(calculated_width, max_width);
    }

    private void calculate_tab_layout(int available_width) {
        if (tab_infos.length() == 0) {
            scrolling_enabled = false;
            scroll_offset = 0.0;
            target_scroll_offset = 0.0;
            max_scroll_offset = 0.0;
            return;
        }

        // Reserve space for new tab button, settings button, and window controls
        int reserved = RIGHT_RESERVED_WIDTH;
        int usable_width = available_width - reserved - TAB_PADDING;

        // Calculate total width needed using each tab's individual width
        int overlap_total = (int)(tab_infos.length() - 1) * TAB_OVERLAP;
        int total_tabs_width = 0;
        for (int i = 0; i < tab_infos.length(); i++) {
            var info = tab_infos.nth_data((uint)i);
            total_tabs_width += info.width;
        }
        total_tabs_width -= overlap_total;

        // Enable scrolling if tabs don't fit in available width
        if (total_tabs_width > usable_width) {
            // Enable scrolling mode
            scrolling_enabled = true;

            // Calculate maximum scroll offset
            max_scroll_offset = double.max(0, total_tabs_width - usable_width);

            // Clamp current scroll offset
            scroll_offset = double.max(0, double.min(scroll_offset, max_scroll_offset));
            target_scroll_offset = double.max(0, double.min(target_scroll_offset, max_scroll_offset));

            // Set positions with scroll offset applied, using each tab's individual width
            int x = TAB_PADDING - (int)scroll_offset;
            for (int i = 0; i < tab_infos.length(); i++) {
                var info = tab_infos.nth_data((uint)i);
                info.x = x;
                x += info.width - TAB_OVERLAP;
            }
        } else {
            // Normal mode - no scrolling needed
            scrolling_enabled = false;
            scroll_offset = 0.0;
            target_scroll_offset = 0.0;
            max_scroll_offset = 0.0;

            // Use each tab's individual width
            int x = TAB_PADDING;
            for (int i = 0; i < tab_infos.length(); i++) {
                var info = tab_infos.nth_data((uint)i);
                info.x = x;
                x += info.width - TAB_OVERLAP;
            }
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

        // Draw close button if hovering over this tab
        if (hover_index == index) {
            draw_tab_close_button(cr, index, x, y, w, h);
        }

        // Draw underline for active tab (full width of tab)
        if (is_active) {
            double underline_y = height - 2;

            cr.set_source_rgba(active_tab_color.red, active_tab_color.green, active_tab_color.blue, 1.0);
            cr.set_line_width(2.0);
            cr.move_to(x, underline_y);
            cr.line_to(x + w, underline_y);
            cr.stroke();
        }
    }

    private void draw_tab_title(Cairo.Context cr, TabInfo info, double x, double y, double w, double h, bool is_active) {
        // Use Pango for text rendering (supports emoji and complex scripts with font fallback)
        var layout = create_pango_layout(info.title);
        var font_desc = Pango.FontDescription.from_string("Sans 11");
        layout.set_font_description(font_desc);

        // Truncate title if needed
        // Text area: tab width - 40px (20px padding on each side)
        double max_text_width = w - 40;
        layout.set_width((int)(max_text_width * Pango.SCALE));
        layout.set_ellipsize(Pango.EllipsizeMode.END);

        int text_width, text_height;
        layout.get_pixel_size(out text_width, out text_height);

        // Center text horizontally in tab
        double text_x = x + (w - text_width) / 2;
        double text_y = y + (h - text_height) / 2;

        // Choose color based on state
        if (is_active) {
            cr.set_source_rgba(active_tab_color.red, active_tab_color.green, active_tab_color.blue, 1.0);
        } else if (info.highlighted) {
            cr.set_source_rgba(1.0, 0.843, 0.0, 1.0);  // #FFD700 - gold for highlighted (background activity)
        } else {
            cr.set_source_rgba(0.7, 0.7, 0.7, 1.0);  // Gray for inactive
        }

        cr.move_to(text_x, text_y);
        Pango.cairo_show_layout(cr, layout);
    }

    private void draw_tab_close_button(Cairo.Context cr, int index, double tab_x, double tab_y, double tab_w, double tab_h) {
        // Calculate close button position (right side of tab)
        double btn_size = TAB_CLOSE_BTN_SIZE;
        double btn_x = tab_x + tab_w - TAB_CLOSE_BTN_PADDING - btn_size;
        double btn_y = tab_y + (tab_h - btn_size) / 2;
        double center_x = btn_x + btn_size / 2;
        double center_y = btn_y + btn_size / 2;

        // Determine opacity based on hover/pressed state
        double alpha = 0.5;  // Default
        if (pressed_close_index == index) {
            alpha = 1.0;  // Pressed: full opacity
        } else if (hover_close_index == index) {
            alpha = 0.8;  // Hover: brighter
        }

        // Draw circle background
        cr.set_source_rgba(0.7, 0.7, 0.7, alpha * 0.3);  // Semi-transparent circle
        cr.arc(center_x, center_y, btn_size / 2, 0, 2 * Math.PI);
        cr.fill();

        // Draw X mark
        cr.set_source_rgba(0.7, 0.7, 0.7, alpha);
        cr.set_line_width(1.5);
        cr.set_line_cap(Cairo.LineCap.ROUND);

        double x_size = btn_size * 0.4;  // Size of the X
        cr.move_to(center_x - x_size, center_y - x_size);
        cr.line_to(center_x + x_size, center_y + x_size);
        cr.stroke();

        cr.move_to(center_x + x_size, center_y - x_size);
        cr.line_to(center_x - x_size, center_y + x_size);
        cr.stroke();
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

    private void draw_settings_button(Cairo.Context cr, int width, int height) {
        // Position in top-right corner, before window controls
        double margin_right = CTRL_BTN_AREA_WIDTH + 10;
        double btn_x = width - margin_right - NEW_TAB_BTN_SIZE;
        double btn_y = (height - NEW_TAB_BTN_SIZE) / 2;
        double center_x = btn_x + NEW_TAB_BTN_SIZE / 2;
        double center_y = btn_y + NEW_TAB_BTN_SIZE / 2;

        // Determine color based on hover/pressed state
        double alpha = 0.6;  // Default: subtle
        if (pressed_settings_btn) {
            alpha = 1.0;  // Pressed: full brightness
        } else if (hover_settings_btn) {
            alpha = 0.85;  // Hover: brighter
        }
        cr.set_source_rgba(0.7, 0.7, 0.7, alpha);

        // Draw hamburger menu icon (three horizontal lines)
        cr.set_line_width(1.5);
        cr.set_line_cap(Cairo.LineCap.ROUND);

        double line_width = 12;
        double line_spacing = 4;

        // Top line
        cr.move_to(center_x - line_width / 2, center_y - line_spacing);
        cr.line_to(center_x + line_width / 2, center_y - line_spacing);
        cr.stroke();

        // Middle line
        cr.move_to(center_x - line_width / 2, center_y);
        cr.line_to(center_x + line_width / 2, center_y);
        cr.stroke();

        // Bottom line
        cr.move_to(center_x - line_width / 2, center_y + line_spacing);
        cr.line_to(center_x + line_width / 2, center_y + line_spacing);
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

        // In scrolling mode, position is fixed relative to right side
        if (scrolling_enabled) {
            int width = get_width();
            return width - RIGHT_RESERVED_WIDTH;
        }

        var last = tab_infos.nth_data((uint)(tab_infos.length() - 1));
        double natural_x = last.x + last.width - TAB_OVERLAP + 8 + NEW_TAB_BTN_MARGIN_LEFT;
        // Cap position to not overlap with settings button
        double max_x = get_width() - RIGHT_RESERVED_WIDTH;
        return double.min(natural_x, max_x);
    }

    private double get_settings_button_x() {
        // Position in top-right corner, before window controls
        int width = get_width();
        double margin_right = CTRL_BTN_AREA_WIDTH + 10;
        return width - margin_right - NEW_TAB_BTN_SIZE;
    }

    private void on_motion(double x, double y) {
        int old_hover = hover_index;
        int old_hover_control = hover_control;
        bool old_hover_new_tab = hover_new_tab;
        bool old_hover_settings = hover_settings_btn;
        int old_hover_close = hover_close_index;

        hover_index = -1;
        hover_control = -1;
        hover_new_tab = false;
        hover_settings_btn = false;
        hover_close_index = -1;

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

        // Check settings button (only if not hovering control buttons or new tab button)
        if (hover_control < 0 && !hover_new_tab) {
            double settings_x = get_settings_button_x();
            double settings_y = (get_height() - NEW_TAB_BTN_SIZE) / 2;
            double settings_hit_radius = NEW_TAB_BTN_SIZE / 2 + 3;

            if (Math.fabs(x - (settings_x + NEW_TAB_BTN_SIZE / 2)) <= settings_hit_radius &&
                Math.fabs(y - (settings_y + NEW_TAB_BTN_SIZE / 2)) <= settings_hit_radius) {
                hover_settings_btn = true;
            }
        }

        // Check tabs (only if not hovering other controls)
        if (hover_control < 0 && !hover_new_tab && !hover_settings_btn) {
            for (int i = 0; i < tab_infos.length(); i++) {
                var info = tab_infos.nth_data((uint)i);
                if (x >= info.x && x <= info.x + info.width && y <= TAB_HEIGHT + 4) {
                    hover_index = i;

                    // Check if hovering over close button of this tab
                    double close_btn_size = TAB_CLOSE_BTN_SIZE;
                    double close_btn_x = info.x + info.width - TAB_CLOSE_BTN_PADDING - close_btn_size;
                    double close_btn_y = (get_height() - TAB_HEIGHT) + (TAB_HEIGHT - close_btn_size) / 2;
                    double close_center_x = close_btn_x + close_btn_size / 2;
                    double close_center_y = close_btn_y + close_btn_size / 2;
                    double close_hit_radius = close_btn_size / 2 + 2;

                    if (Math.fabs(x - close_center_x) <= close_hit_radius && Math.fabs(y - close_center_y) <= close_hit_radius) {
                        hover_close_index = i;
                    }

                    break;
                }
            }
        }

        if (old_hover != hover_index || old_hover_control != hover_control ||
            old_hover_new_tab != hover_new_tab || old_hover_settings != hover_settings_btn ||
            old_hover_close != hover_close_index) {
            queue_draw();
        }
    }

    private void on_leave() {
        bool need_redraw = hover_index != -1 || hover_control != -1 || hover_new_tab ||
                          hover_settings_btn || hover_close_index != -1;
        hover_index = -1;
        hover_control = -1;
        hover_new_tab = false;
        hover_settings_btn = false;
        hover_close_index = -1;
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

        // Check tab close buttons - set pressed state
        if (hover_close_index >= 0) {
            pressed_close_index = hover_close_index;
            queue_draw();
            return;
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

        // Check settings button - set pressed state
        double settings_x = get_settings_button_x();
        double settings_y = (get_height() - NEW_TAB_BTN_SIZE) / 2;
        double settings_hit_radius = NEW_TAB_BTN_SIZE / 2 + 3;

        if (Math.fabs(x - (settings_x + NEW_TAB_BTN_SIZE / 2)) <= settings_hit_radius &&
            Math.fabs(y - (settings_y + NEW_TAB_BTN_SIZE / 2)) <= settings_hit_radius) {
            pressed_settings_btn = true;
            queue_draw();
            return;
        }

        pressed_control = -1;
        pressed_new_tab = false;
        pressed_settings_btn = false;
        pressed_close_index = -1;
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

        // Check settings button - execute action if released on same button
        double settings_x = get_settings_button_x();
        double settings_y = (get_height() - NEW_TAB_BTN_SIZE) / 2;
        double settings_hit_radius = NEW_TAB_BTN_SIZE / 2 + 3;

        if (Math.fabs(x - (settings_x + NEW_TAB_BTN_SIZE / 2)) <= settings_hit_radius &&
            Math.fabs(y - (settings_y + NEW_TAB_BTN_SIZE / 2)) <= settings_hit_radius) {
            // Only trigger if released on the same button that was pressed
            if (pressed_settings_btn) {
                settings_button_clicked();
            }
            pressed_settings_btn = false;
            queue_draw();
            return;
        }

        pressed_new_tab = false;
        pressed_settings_btn = false;

        // Check tab close button - execute action if released on same button
        if (pressed_close_index >= 0 && hover_close_index == pressed_close_index) {
            tab_closed(pressed_close_index);
            pressed_close_index = -1;
            queue_draw();
            return;
        }

        pressed_close_index = -1;

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

    private void setup_scroll_controller() {
        var scroll_controller = new Gtk.EventControllerScroll(
            Gtk.EventControllerScrollFlags.HORIZONTAL | Gtk.EventControllerScrollFlags.VERTICAL
        );

        scroll_controller.scroll.connect((dx, dy) => {
            if (!scrolling_enabled) {
                return false;
            }

            // Horizontal scroll or vertical scroll converted to horizontal
            double scroll_delta = dx != 0 ? dx : dy;

            target_scroll_offset += scroll_delta * SCROLL_SPEED;
            target_scroll_offset = double.max(0, double.min(target_scroll_offset, max_scroll_offset));

            start_scroll_animation();

            return true;  // Event handled
        });

        add_controller(scroll_controller);
    }

    private void scroll_to_tab(int index) {
        if (!scrolling_enabled || index < 0 || index >= tab_infos.length()) {
            return;
        }

        // Force layout calculation to ensure tab positions are up-to-date
        calculate_tab_layout(get_width());

        var info = tab_infos.nth_data((uint)index);
        int width = get_width();

        // Define visible area boundaries
        int visible_start = TAB_PADDING;
        int visible_end = width - RIGHT_RESERVED_WIDTH;

        // Tab's current screen position (info.x already includes scroll offset)
        int tab_left = info.x;
        int tab_right = info.x + info.width;

        // Check if tab is fully visible
        if (tab_left < visible_start) {
            // Tab is cut off on left, scroll left to show it
            double scroll_amount = visible_start - tab_left + 20;  // 20px padding
            target_scroll_offset = scroll_offset - scroll_amount;
        } else if (tab_right > visible_end) {
            // Tab is cut off on right, scroll right to show it
            double scroll_amount = tab_right - visible_end + 20;  // 20px padding
            target_scroll_offset = scroll_offset + scroll_amount;
        } else {
            // Tab is already visible, no scroll needed
            return;
        }

        // Clamp target
        target_scroll_offset = double.max(0, double.min(target_scroll_offset, max_scroll_offset));

        // Start animation
        start_scroll_animation();
    }

    private void start_scroll_animation() {
        if (animating_scroll) {
            return;  // Already animating
        }

        animating_scroll = true;
        scroll_animation_id = Timeout.add(16, () => {  // ~60 FPS
            // Interpolate toward target
            double diff = target_scroll_offset - scroll_offset;

            if (Math.fabs(diff) < 0.5) {
                // Close enough, snap to target
                scroll_offset = target_scroll_offset;
                animating_scroll = false;
                queue_draw();
                return false;  // Stop animation
            }

            // Smooth interpolation
            scroll_offset += diff * SCROLL_ANIMATION_SPEED;
            queue_draw();
            return true;  // Continue animation
        });
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
        var info = new TabInfo(title);
        // Calculate width based on text content
        info.width = calculate_tab_width_for_text(title);
        tab_infos.append(info);
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

            // Auto-scroll to make active tab visible
            if (scrolling_enabled) {
                scroll_to_tab(index);
            }

            queue_draw();
        }
    }

    public void update_tab_title(int index, string title) {
        if (index >= 0 && index < tab_infos.length()) {
            var info = tab_infos.nth_data((uint)index);
            info.title = title;
            // Recalculate width based on new text content
            info.width = calculate_tab_width_for_text(title);
            queue_draw();
        }
    }

    public int get_active_index() {
        return active_index;
    }

    public void set_background_opacity(double opacity) {
        background_opacity = opacity;
        queue_draw();
    }

    public void set_background_color(Gdk.RGBA color) {
        background_color = color;
        queue_draw();
    }

    public void set_active_tab_color(Gdk.RGBA color) {
        active_tab_color = color;
        queue_draw();
    }

    // Set highlight state for a tab (background activity)
    public void set_tab_highlighted(int index, bool highlighted) {
        if (index >= 0 && index < tab_infos.length()) {
            var info = tab_infos.nth_data((uint)index);
            info.highlighted = highlighted;
            queue_draw();
        }
    }

    // Clear highlight for a tab (when user switches to it)
    public void clear_tab_highlight(int index) {
        set_tab_highlighted(index, false);
    }

    ~TabBar() {
        if (scroll_animation_id > 0) {
            Source.remove(scroll_animation_id);
        }
    }
}
