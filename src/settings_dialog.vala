// Settings dialog as an overlay widget (centered in parent)

public class SettingsDialog : Gtk.Widget {
    private Gtk.Box shadow_container;
    private Gtk.Box main_box;
    private Gtk.Box overlay_bg;
    private Gtk.DrawingArea close_button;
    private Gdk.RGBA foreground_color;
    private Gdk.RGBA background_color;
    private double background_opacity = 0.95;
    private Gtk.CssProvider? css_provider = null;

    // Close button state
    private bool close_button_hover = false;
    private bool close_button_pressed = false;

    // Shadow parameters
    private const int SHADOW_SIZE = 12;
    private const int CLOSE_BTN_SIZE = 12;
    private const int DIALOG_WIDTH = 828;
    private const int DIALOG_HEIGHT = 576;

    // List controls
    private FontListWidget font_list;
    private FontSizeListWidget font_size_list;
    private ThemeListWidget theme_list;
    private TransparencySlider transparency_slider;

    // Focus management
    private enum FocusTarget {
        FONT_LIST,
        FONT_SIZE_LIST,
        THEME_LIST,
        TRANSPARENCY_SLIDER
    }
    private FocusTarget current_focus = FocusTarget.FONT_LIST;

    // Signals for settings changes
    public signal void font_changed(string font_name);
    public signal void font_size_changed(int font_size);
    public signal void theme_changed(string theme_name);
    public signal void opacity_changed(double opacity);
    public signal void closed();

    public SettingsDialog(Gdk.RGBA fg_color, Gdk.RGBA bg_color, ConfigManager config) {
        foreground_color = fg_color;
        background_color = bg_color;

        // Set layout manager
        set_layout_manager(new Gtk.BinLayout());

        // Enable focus
        set_can_focus(true);
        set_focusable(true);

        setup_layout();
        load_css();
        load_initial_values(config);

        // Grab focus when mapped
        map.connect(() => {
            overlay_bg.grab_focus();
        });
    }

    static construct {
        set_css_name("settings-dialog-widget");
    }

    private void load_initial_values(ConfigManager config) {
        // Load font from config
        string config_font = config.font;
        if (!font_list.set_selected_font(config_font)) {
            // Font not found, try system default Mono font
            string mono_font = get_system_mono_font();
            if (!font_list.set_selected_font(mono_font)) {
                // Mono font not in list, select first font
                font_list.set_selected_index(0);
            }
        }

        // Load font size from config
        int config_size = config.font_size;
        if (config_size < 8 || config_size > 48) {
            config_size = 13;
        }
        font_size_list.set_selected_size(config_size);

        // Load theme from config
        string config_theme = config.theme;
        if (!theme_list.set_selected_theme(config_theme)) {
            // Theme not found, try to select "default"
            if (!theme_list.set_selected_theme("default")) {
                // "default" not found, select first theme
                theme_list.set_selected_index(0);
            }
        }

        // Load opacity from config
        double config_opacity = config.opacity;
        if (config_opacity < 0.0 || config_opacity > 1.0) {
            config_opacity = 0.88;
        }
        transparency_slider.set_value(config_opacity);
    }

    private string get_system_mono_font() {
        // Try to get system default monospace font
        int result_length = 0;
        string[]? fonts = FontUtils.list_mono_or_dot_fonts(out result_length);

        if (result_length > 0 && fonts != null) {
            return fonts[0];
        }

        return "Monospace";
    }

    private void load_css() {
        // Create CSS provider only once, reuse it for updates
        bool first_time = (css_provider == null);
        if (first_time) {
            css_provider = new Gtk.CssProvider();
        }

        string fg_hex = rgba_to_hex(foreground_color);

        // Convert background color to RGB values
        int bg_r = (int)(background_color.red * 255);
        int bg_g = (int)(background_color.green * 255);
        int bg_b = (int)(background_color.blue * 255);

        string css = """
            .settings-dialog-overlay {
                background-color: rgba(0, 0, 0, 0.3);
            }

            .settings-shadow-container {
                background-color: transparent;
                box-shadow: 0px 4px 12px rgba(0, 0, 0, 0.35);
                border-radius: 8px;
            }

            .settings-dialog {
                background-color: rgba(""" + bg_r.to_string() + """, """ + bg_g.to_string() + """, """ + bg_b.to_string() + """, """ + background_opacity.to_string() + """);
                border-radius: 8px;
                border: 1px solid """ + fg_hex + """;
                padding: 50px;
            }
        """;

        css_provider.load_from_string(css);

        // Add provider to global display only on first creation
        if (first_time) {
            StyleHelper.add_provider_for_display(
                Gdk.Display.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }
    }

    private string rgba_to_hex(Gdk.RGBA color) {
        return "#%02x%02x%02x".printf(
            (int)(color.red * 255),
            (int)(color.green * 255),
            (int)(color.blue * 255)
        );
    }

    private void setup_layout() {
        // Outer container for dark overlay background - fills entire parent
        overlay_bg = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        overlay_bg.add_css_class("settings-dialog-overlay");
        overlay_bg.set_hexpand(true);
        overlay_bg.set_vexpand(true);
        overlay_bg.set_can_focus(true);
        overlay_bg.set_focusable(true);

        // Center container
        var center_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        center_box.set_halign(Gtk.Align.CENTER);
        center_box.set_valign(Gtk.Align.CENTER);
        center_box.set_hexpand(true);
        center_box.set_vexpand(true);

        // Shadow container with fixed size
        shadow_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        shadow_container.add_css_class("settings-shadow-container");
        shadow_container.set_size_request(DIALOG_WIDTH + SHADOW_SIZE * 2, DIALOG_HEIGHT + SHADOW_SIZE * 2);
        shadow_container.set_margin_start(SHADOW_SIZE);
        shadow_container.set_margin_end(SHADOW_SIZE);
        shadow_container.set_margin_top(SHADOW_SIZE);
        shadow_container.set_margin_bottom(SHADOW_SIZE);

        // Create overlay for floating close button
        var overlay = new Gtk.Overlay();

        main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        main_box.add_css_class("settings-dialog");

        // Three lists in horizontal layout
        var lists_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 20);
        lists_box.set_vexpand(true);

        // Font list (1.5x width)
        font_list = new FontListWidget(foreground_color, background_color);
        font_list.set_hexpand(true);
        font_list.set_size_request(330, 300);
        lists_box.append(font_list);

        // Font size list (1/3 width)
        font_size_list = new FontSizeListWidget(foreground_color, background_color);
        font_size_list.set_hexpand(false);
        font_size_list.set_size_request(80, 300);
        lists_box.append(font_size_list);

        // Theme list (normal width)
        theme_list = new ThemeListWidget(foreground_color, background_color);
        theme_list.set_hexpand(true);
        theme_list.set_size_request(260, 300);
        lists_box.append(theme_list);

        main_box.append(lists_box);

        // Transparency slider
        transparency_slider = new TransparencySlider(foreground_color);
        transparency_slider.set_margin_top(10);
        transparency_slider.value_changed.connect((new_value) => {
            opacity_changed(new_value);
        });
        main_box.append(transparency_slider);

        // Set main_box as overlay base
        overlay.set_child(main_box);

        // Close button (DrawingArea for custom drawing) - floats on top
        close_button = new Gtk.DrawingArea();
        close_button.set_size_request(CLOSE_BTN_SIZE * 2 + 10, CLOSE_BTN_SIZE * 2 + 10);
        close_button.set_valign(Gtk.Align.START);
        close_button.set_halign(Gtk.Align.END);
        close_button.set_margin_top(12);
        close_button.set_margin_end(12);
        close_button.set_draw_func(draw_close_button);

        // Setup close button interactions
        setup_close_button_interactions();

        // Add close button as overlay
        overlay.add_overlay(close_button);

        shadow_container.append(overlay);
        center_box.append(shadow_container);
        overlay_bg.append(center_box);

        // Set as child
        overlay_bg.set_parent(this);

        // Setup keyboard shortcuts
        setup_keyboard_shortcuts();

        // Click on background to close
        setup_background_click(overlay_bg);

        // Initialize focus
        update_focus_state();
    }

    private void setup_background_click(Gtk.Widget bg) {
        var click_gesture = new Gtk.GestureClick();
        click_gesture.set_button(1);
        click_gesture.pressed.connect((n_press, x, y) => {
            // Only close if clicked outside the dialog
            Graphene.Point point = Graphene.Point();
            point.x = (float)x;
            point.y = (float)y;

            // Check if click is on shadow_container
            Graphene.Point local;
            if (!shadow_container.compute_point(bg, point, out local)) {
                close_dialog();
            } else {
                // Check if point is outside shadow_container bounds
                int w = shadow_container.get_width();
                int h = shadow_container.get_height();
                if (local.x < 0 || local.y < 0 || local.x > w || local.y > h) {
                    close_dialog();
                }
            }
        });
        bg.add_controller(click_gesture);
    }

    private void draw_close_button(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        double center_x = width / 2.0;
        double center_y = height / 2.0;

        // Use VTE foreground color (same as border)
        cr.set_source_rgba(
            foreground_color.red,
            foreground_color.green,
            foreground_color.blue,
            1.0
        );
        cr.set_line_width(1.0);
        cr.set_antialias(Cairo.Antialias.NONE);

        // Draw X shape
        double offset = (CLOSE_BTN_SIZE - 3) / 2.0;
        cr.move_to(center_x - offset, center_y - offset);
        cr.line_to(center_x + offset, center_y + offset);
        cr.stroke();
        cr.move_to(center_x + offset, center_y - offset);
        cr.line_to(center_x - offset, center_y + offset);
        cr.stroke();
    }

    private void setup_close_button_interactions() {
        // Mouse motion
        var motion_controller = new Gtk.EventControllerMotion();
        motion_controller.enter.connect(() => {
            close_button_hover = true;
            close_button.queue_draw();
        });
        motion_controller.leave.connect(() => {
            close_button_hover = false;
            close_button_pressed = false;
            close_button.queue_draw();
        });
        close_button.add_controller(motion_controller);

        // Mouse click
        var click_gesture = new Gtk.GestureClick();
        click_gesture.set_button(1);
        click_gesture.pressed.connect(() => {
            close_button_pressed = true;
            close_button.queue_draw();
        });
        click_gesture.released.connect(() => {
            if (close_button_pressed) {
                close_dialog();
            }
            close_button_pressed = false;
            close_button.queue_draw();
        });
        close_button.add_controller(click_gesture);
    }

    private void setup_keyboard_shortcuts() {
        var controller = new Gtk.EventControllerKey();
        controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);

        controller.key_pressed.connect((keyval, keycode, state) => {
            bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;

            // ESC - close dialog
            if (keyval == Gdk.Key.Escape) {
                close_dialog();
                return true;
            }

            // Tab / Shift+Tab - switch focus
            if (keyval == Gdk.Key.Tab || keyval == Gdk.Key.ISO_Left_Tab) {
                if (shift) {
                    // Shift+Tab: backward
                    current_focus = (FocusTarget)(((int)current_focus - 1 + 4) % 4);
                } else {
                    // Tab: forward
                    current_focus = (FocusTarget)(((int)current_focus + 1) % 4);
                }
                update_focus_state();
                return true;
            }

            // Handle keys based on current focus
            switch (current_focus) {
                case FocusTarget.FONT_LIST:
                case FocusTarget.FONT_SIZE_LIST:
                case FocusTarget.THEME_LIST:
                    // Up/Down or j/k for list navigation
                    if (keyval == Gdk.Key.Up || keyval == Gdk.Key.k) {
                        get_current_list().move_selection_up();
                        return true;
                    }
                    if (keyval == Gdk.Key.Down || keyval == Gdk.Key.j) {
                        get_current_list().move_selection_down();
                        return true;
                    }
                    // Enter to apply selection
                    if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                        apply_current_selection();
                        return true;
                    }
                    break;

                case FocusTarget.TRANSPARENCY_SLIDER:
                    // Left/Right or h/l for slider adjustment
                    if (keyval == Gdk.Key.Left || keyval == Gdk.Key.h) {
                        transparency_slider.decrease_value();
                        return true;
                    }
                    if (keyval == Gdk.Key.Right || keyval == Gdk.Key.l) {
                        transparency_slider.increase_value();
                        return true;
                    }
                    break;
            }

            return false;
        });

        ((Gtk.Widget)overlay_bg).add_controller(controller);
    }

    private void update_focus_state() {
        font_list.set_focused(current_focus == FocusTarget.FONT_LIST);
        font_size_list.set_focused(current_focus == FocusTarget.FONT_SIZE_LIST);
        theme_list.set_focused(current_focus == FocusTarget.THEME_LIST);
        transparency_slider.set_focused(current_focus == FocusTarget.TRANSPARENCY_SLIDER);
    }

    private SettingsListWidget get_current_list() {
        switch (current_focus) {
            case FocusTarget.FONT_LIST:
                return font_list;
            case FocusTarget.FONT_SIZE_LIST:
                return font_size_list;
            case FocusTarget.THEME_LIST:
                return theme_list;
            default:
                return font_list;
        }
    }

    private void apply_current_selection() {
        switch (current_focus) {
            case FocusTarget.FONT_LIST:
                string font = font_list.get_selected_font();
                font_changed(font);
                break;
            case FocusTarget.FONT_SIZE_LIST:
                int size = font_size_list.get_selected_size();
                font_size_changed(size);
                break;
            case FocusTarget.THEME_LIST:
                string theme = theme_list.get_selected_theme();
                theme_changed(theme);
                break;
            case FocusTarget.TRANSPARENCY_SLIDER:
                opacity_changed(transparency_slider.get_value());
                break;
        }
    }

    private void close_dialog() {
        closed();
    }

    // Public method to handle key events from parent window
    public bool handle_key_press(uint keyval, uint keycode, Gdk.ModifierType state) {
        bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;

        // ESC - close dialog
        if (keyval == Gdk.Key.Escape) {
            close_dialog();
            return true;
        }

        // Tab / Shift+Tab - switch focus
        if (keyval == Gdk.Key.Tab || keyval == Gdk.Key.ISO_Left_Tab) {
            if (shift) {
                // Shift+Tab: backward
                current_focus = (FocusTarget)(((int)current_focus - 1 + 4) % 4);
            } else {
                // Tab: forward
                current_focus = (FocusTarget)(((int)current_focus + 1) % 4);
            }
            update_focus_state();
            return true;
        }

        // Handle keys based on current focus
        switch (current_focus) {
            case FocusTarget.FONT_LIST:
            case FocusTarget.FONT_SIZE_LIST:
            case FocusTarget.THEME_LIST:
                // Up/Down or j/k for list navigation
                if (keyval == Gdk.Key.Up || keyval == Gdk.Key.k) {
                    get_current_list().move_selection_up();
                    return true;
                }
                if (keyval == Gdk.Key.Down || keyval == Gdk.Key.j) {
                    get_current_list().move_selection_down();
                    return true;
                }
                // Enter to apply selection
                if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                    apply_current_selection();
                    return true;
                }
                break;

            case FocusTarget.TRANSPARENCY_SLIDER:
                // Left/Right or h/l for slider adjustment
                if (keyval == Gdk.Key.Left || keyval == Gdk.Key.h) {
                    transparency_slider.decrease_value();
                    return true;
                }
                if (keyval == Gdk.Key.Right || keyval == Gdk.Key.l) {
                    transparency_slider.increase_value();
                    return true;
                }
                break;
        }

        return false;
    }

    // Update dialog colors when theme changes
    public void update_theme_colors(Gdk.RGBA new_fg_color, Gdk.RGBA new_bg_color) {
        foreground_color = new_fg_color;
        background_color = new_bg_color;

        // Reload CSS with new colors
        load_css();

        // Update list widgets with new foreground and background colors
        if (font_list != null) {
            font_list.update_colors(new_fg_color, new_bg_color);
        }
        if (font_size_list != null) {
            font_size_list.update_colors(new_fg_color, new_bg_color);
        }
        if (theme_list != null) {
            theme_list.update_colors(new_fg_color, new_bg_color);
        }
        if (transparency_slider != null) {
            transparency_slider.update_foreground_color(new_fg_color);
        }

        // Redraw close button with new foreground color
        if (close_button != null) {
            close_button.queue_draw();
        }
    }

    protected override void dispose() {
        // Unparent all children
        var child = get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            child.unparent();
            child = next;
        }
        base.dispose();
    }
}

// Base class for settings list widgets
private abstract class SettingsListWidget : Gtk.DrawingArea {
    protected Gdk.RGBA foreground_color;
    protected Gdk.RGBA background_color;
    protected int selected_index = 0;
    protected bool is_focused = false;
    protected const int ITEM_HEIGHT = 30;
    protected const int PADDING = 5;

    protected SettingsListWidget(Gdk.RGBA fg_color, Gdk.RGBA bg_color) {
        foreground_color = fg_color;
        background_color = bg_color;
        set_draw_func(draw_list);

        // Add scrolling support
        var scroll_controller = new Gtk.EventControllerScroll(Gtk.EventControllerScrollFlags.VERTICAL);
        scroll_controller.scroll.connect(on_scroll);
        add_controller(scroll_controller);
    }

    protected abstract void draw_list(Gtk.DrawingArea area, Cairo.Context cr, int width, int height);
    protected abstract int get_item_count();

    public void move_selection_up() {
        if (selected_index > 0) {
            selected_index--;
            queue_draw();
        }
    }

    public void move_selection_down() {
        if (selected_index < get_item_count() - 1) {
            selected_index++;
            queue_draw();
        }
    }

    public void set_focused(bool focused) {
        is_focused = focused;
        queue_draw();
    }

    public void update_colors(Gdk.RGBA new_fg_color, Gdk.RGBA new_bg_color) {
        foreground_color = new_fg_color;
        background_color = new_bg_color;
        queue_draw();
    }

    private bool on_scroll(double dx, double dy) {
        if (dy > 0) {
            move_selection_down();
        } else if (dy < 0) {
            move_selection_up();
        }
        return true;
    }

    protected void draw_border(Cairo.Context cr, int width, int height) {
        // First, fill the rounded rectangle with semi-transparent theme background
        double radius = 5.0;
        double line_width = is_focused ? 2.0 : 1.0;
        double x = line_width / 2.0;
        double y = line_width / 2.0;
        double w = width - line_width;
        double h = height - line_width;

        // Draw and fill rounded rectangle background
        cr.new_sub_path();
        cr.arc(x + radius, y + radius, radius, Math.PI, 3 * Math.PI / 2);
        cr.arc(x + w - radius, y + radius, radius, 3 * Math.PI / 2, 0);
        cr.arc(x + w - radius, y + h - radius, radius, 0, Math.PI / 2);
        cr.arc(x + radius, y + h - radius, radius, Math.PI / 2, Math.PI);
        cr.close_path();

        // Fill with semi-transparent theme background (0.3 alpha for dark backgrounds, 0.5 for light)
        double brightness = 0.299 * background_color.red + 0.587 * background_color.green + 0.114 * background_color.blue;
        bool is_light = brightness > 0.5;
        double alpha = is_light ? 0.5 : 0.3;

        cr.set_source_rgba(
            background_color.red,
            background_color.green,
            background_color.blue,
            alpha
        );
        cr.fill_preserve();

        // Draw border
        cr.set_source_rgba(
            foreground_color.red,
            foreground_color.green,
            foreground_color.blue,
            is_focused ? 1.0 : 0.5
        );
        cr.set_line_width(line_width);
        cr.stroke();
    }

    protected void draw_selection_rect(Cairo.Context cr, int y, int width) {
        cr.set_source_rgba(
            foreground_color.red,
            foreground_color.green,
            foreground_color.blue,
            0.2
        );

        // Draw rounded rectangle
        double x = PADDING;
        double rect_width = width - PADDING * 2;
        double rect_height = ITEM_HEIGHT;
        double radius = 4.0;

        cr.new_sub_path();
        cr.arc(x + radius, y + radius, radius, Math.PI, 3 * Math.PI / 2);
        cr.arc(x + rect_width - radius, y + radius, radius, 3 * Math.PI / 2, 0);
        cr.arc(x + rect_width - radius, y + rect_height - radius, radius, 0, Math.PI / 2);
        cr.arc(x + radius, y + rect_height - radius, radius, Math.PI / 2, Math.PI);
        cr.close_path();
        cr.fill();
    }
}

// Font list widget
private class FontListWidget : SettingsListWidget {
    private string[] fonts;

    public FontListWidget(Gdk.RGBA fg_color, Gdk.RGBA bg_color) {
        base(fg_color, bg_color);
        load_fonts();
        set_size_request(200, 300);
    }

    private void load_fonts() {
        int result_length;
        string[]? font_array = FontUtils.list_mono_or_dot_fonts(out result_length);

        if (font_array != null && result_length > 0) {
            fonts = new string[result_length];
            for (int i = 0; i < result_length; i++) {
                fonts[i] = font_array[i];
            }
            // Sort fonts alphabetically
            sort_fonts(ref fonts);
        } else {
            fonts = new string[1];
            fonts[0] = "Monospace";
        }
    }

    private void sort_fonts(ref string[] font_names) {
        // Bubble sort implementation
        for (int i = 0; i < font_names.length - 1; i++) {
            for (int j = 0; j < font_names.length - i - 1; j++) {
                if (font_names[j].ascii_casecmp(font_names[j + 1]) > 0) {
                    // Swap
                    string temp = font_names[j];
                    font_names[j] = font_names[j + 1];
                    font_names[j + 1] = temp;
                }
            }
        }
    }

    protected override int get_item_count() {
        return fonts.length;
    }

    public string get_selected_font() {
        if (selected_index >= 0 && selected_index < fonts.length) {
            return fonts[selected_index];
        }
        return "Monospace";
    }

    // Set selected font by name, return true if found
    public bool set_selected_font(string font_name) {
        for (int i = 0; i < fonts.length; i++) {
            if (fonts[i] == font_name) {
                selected_index = i;
                queue_draw();
                return true;
            }
        }
        return false;
    }

    // Set selected font by index
    public void set_selected_index(int index) {
        if (index >= 0 && index < fonts.length) {
            selected_index = index;
            queue_draw();
        }
    }

    protected override void draw_list(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Clear background to transparent
        cr.set_source_rgba(0, 0, 0, 0);
        cr.set_operator(Cairo.Operator.SOURCE);
        cr.paint();
        cr.set_operator(Cairo.Operator.OVER);

        // Draw border (which also fills the background)
        draw_border(cr, width, height);

        // Calculate visible range
        int visible_items = (height - PADDING * 2) / ITEM_HEIGHT;
        int scroll_offset = int.max(0, selected_index - visible_items / 2);
        scroll_offset = int.min(scroll_offset, int.max(0, fonts.length - visible_items));

        // Draw items
        int y = PADDING;
        for (int i = scroll_offset; i < fonts.length && i < scroll_offset + visible_items; i++) {
            if (i == selected_index) {
                draw_selection_rect(cr, y, width);
            }

            // Always use VTE foreground color for text
            cr.set_source_rgba(
                foreground_color.red,
                foreground_color.green,
                foreground_color.blue,
                1.0
            );

            // Set the font face to the actual font name so it renders in its own style
            cr.select_font_face(fonts[i], Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(16);  // 150% of original 12

            // Calculate text width for centering
            Cairo.TextExtents extents;
            cr.text_extents(fonts[i], out extents);
            double text_x = 10;

            cr.move_to(text_x, y + ITEM_HEIGHT / 2 + 5);
            cr.show_text(fonts[i]);
            y += ITEM_HEIGHT;
        }
    }
}

// Font size list widget
private class FontSizeListWidget : SettingsListWidget {
    private const int MIN_SIZE = 8;
    private const int MAX_SIZE = 48;

    public FontSizeListWidget(Gdk.RGBA fg_color, Gdk.RGBA bg_color) {
        base(fg_color, bg_color);
        set_size_request(200, 300);
        selected_index = 6; // Default to size 14
    }

    protected override int get_item_count() {
        return MAX_SIZE - MIN_SIZE + 1;
    }

    public int get_selected_size() {
        return MIN_SIZE + selected_index;
    }

    // Set selected size by value
    public void set_selected_size(int size) {
        if (size >= MIN_SIZE && size <= MAX_SIZE) {
            selected_index = size - MIN_SIZE;
            queue_draw();
        }
    }

    protected override void draw_list(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Clear background to transparent
        cr.set_source_rgba(0, 0, 0, 0);
        cr.set_operator(Cairo.Operator.SOURCE);
        cr.paint();
        cr.set_operator(Cairo.Operator.OVER);

        // Draw border (which also fills the background)
        draw_border(cr, width, height);

        // Calculate visible range
        int visible_items = (height - PADDING * 2) / ITEM_HEIGHT;
        int scroll_offset = int.max(0, selected_index - visible_items / 2);
        scroll_offset = int.min(scroll_offset, int.max(0, get_item_count() - visible_items));

        // Draw items
        int y = PADDING;
        for (int i = scroll_offset; i < get_item_count() && i < scroll_offset + visible_items; i++) {
            if (i == selected_index) {
                draw_selection_rect(cr, y, width);
            }

            // Always use VTE foreground color for text
            cr.set_source_rgba(
                foreground_color.red,
                foreground_color.green,
                foreground_color.blue,
                1.0
            );

            // Set font size - 150% increase
            cr.select_font_face("monospace", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(18);  // 150% of default

            int size = MIN_SIZE + i;
            string size_text = size.to_string();

            // Calculate text width for centering
            Cairo.TextExtents extents;
            cr.text_extents(size_text, out extents);
            double text_x = (width - extents.width) / 2;

            cr.move_to(text_x, y + ITEM_HEIGHT / 2 + 5);
            cr.show_text(size_text);
            y += ITEM_HEIGHT;
        }
    }
}

// Theme list widget
private class ThemeListWidget : SettingsListWidget {
    private string[] theme_names;
    private ThemeColors[] theme_colors;

    private struct ThemeColors {
        Gdk.RGBA background;
        Gdk.RGBA foreground;
        Gdk.RGBA color_11;  // For "lazycat" (prompt host)
        Gdk.RGBA color_13;  // For "terminal" (prompt path)
        Gdk.RGBA tab;
    }

    public ThemeListWidget(Gdk.RGBA fg_color, Gdk.RGBA bg_color) {
        base(fg_color, bg_color);
        load_themes();
        set_size_request(200, 300);
    }

    private void load_themes() {
        var theme_list = new string[0];
        var colors_list = new ThemeColors[0];

        try {
            var dir = File.new_for_path(Path.build_filename(ConfigManager.data_dir, "theme"));
            var enumerator = dir.enumerate_children(
                FileAttribute.STANDARD_NAME,
                FileQueryInfoFlags.NONE
            );

            FileInfo file_info;
            while ((file_info = enumerator.next_file()) != null) {
                string name = file_info.get_name();
                if (!name.has_prefix(".")) {
                    theme_list += name;

                    // Load theme colors
                    var theme_file = File.new_for_path(ConfigManager.get_theme_path(name));
                    var colors = load_theme_colors(theme_file);
                    colors_list += colors;
                }
            }
        } catch (Error e) {
            warning("Error loading themes: %s", e.message);
        }

        // Sort themes by background brightness (darkest first, default always first)
        sort_themes(ref theme_list, ref colors_list);

        theme_names = theme_list;
        theme_colors = colors_list;
    }

    private void sort_themes(ref string[] names, ref ThemeColors[] colors) {
        // Bubble sort implementation
        for (int i = 0; i < names.length - 1; i++) {
            for (int j = 0; j < names.length - i - 1; j++) {
                if (compare_themes(names[j], colors[j], names[j + 1], colors[j + 1]) > 0) {
                    // Swap names
                    string temp_name = names[j];
                    names[j] = names[j + 1];
                    names[j + 1] = temp_name;

                    // Swap colors
                    ThemeColors temp_color = colors[j];
                    colors[j] = colors[j + 1];
                    colors[j + 1] = temp_color;
                }
            }
        }
    }

    private int compare_themes(string name1, ThemeColors colors1, string name2, ThemeColors colors2) {
        // "default" always comes first
        if (name1 == "default") return -1;
        if (name2 == "default") return 1;

        // Calculate brightness: darker (lower value) should come first
        double brightness1 = get_color_brightness(colors1.background);
        double brightness2 = get_color_brightness(colors2.background);

        if (brightness1 < brightness2) return -1;
        if (brightness1 > brightness2) return 1;
        return 0;
    }

    private double get_color_brightness(Gdk.RGBA color) {
        // Calculate perceived brightness (0.0 = black, 1.0 = white)
        return 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue;
    }

    private ThemeColors load_theme_colors(File theme_file) {
        ThemeColors colors = ThemeColors();

        // Default values
        colors.background = parse_color("#000000");
        colors.foreground = parse_color("#00cd00");
        colors.color_11 = parse_color("#00ff00");  // Default green for host
        colors.color_13 = parse_color("#1e90ff");  // Default blue for path
        colors.tab = parse_color("#2CA7F8");

        try {
            var key_file = new KeyFile();
            key_file.load_from_file(theme_file.get_path(), KeyFileFlags.NONE);

            if (key_file.has_key("theme", "background")) {
                colors.background = parse_color(key_file.get_string("theme", "background").strip());
            }
            if (key_file.has_key("theme", "foreground")) {
                colors.foreground = parse_color(key_file.get_string("theme", "foreground").strip());
            }
            if (key_file.has_key("theme", "color_11")) {
                colors.color_11 = parse_color(key_file.get_string("theme", "color_11").strip());
            }
            if (key_file.has_key("theme", "color_13")) {
                colors.color_13 = parse_color(key_file.get_string("theme", "color_13").strip());
            }
            if (key_file.has_key("theme", "tab")) {
                colors.tab = parse_color(key_file.get_string("theme", "tab").strip());
            }
        } catch (Error e) {
            warning("Error loading theme file %s: %s", theme_file.get_path(), e.message);
        }

        return colors;
    }

    private Gdk.RGBA parse_color(string color_string) {
        var color = Gdk.RGBA();
        if (!color.parse(color_string)) {
            color.parse("#ffffff");
        }
        return color;
    }

    protected override int get_item_count() {
        return theme_names.length;
    }

    public string get_selected_theme() {
        if (selected_index >= 0 && selected_index < theme_names.length) {
            return theme_names[selected_index];
        }
        return "default";
    }

    // Set selected theme by name, return true if found
    public bool set_selected_theme(string theme_name) {
        for (int i = 0; i < theme_names.length; i++) {
            if (theme_names[i] == theme_name) {
                selected_index = i;
                queue_draw();
                return true;
            }
        }
        return false;
    }

    // Set selected theme by index
    public void set_selected_index(int index) {
        if (index >= 0 && index < theme_names.length) {
            selected_index = index;
            queue_draw();
        }
    }

    protected override void draw_list(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Clear background to transparent
        cr.set_source_rgba(0, 0, 0, 0);
        cr.set_operator(Cairo.Operator.SOURCE);
        cr.paint();
        cr.set_operator(Cairo.Operator.OVER);

        // Draw border (which also fills the background)
        draw_border(cr, width, height);

        // Calculate visible range
        const int THEME_ITEM_HEIGHT = 60;
        const int THEME_ITEM_SPACING = 10;
        const int THEME_ITEM_TOTAL = THEME_ITEM_HEIGHT + THEME_ITEM_SPACING;
        int visible_items = (height - PADDING * 2) / THEME_ITEM_TOTAL;
        int scroll_offset = int.max(0, selected_index - visible_items / 2);
        scroll_offset = int.min(scroll_offset, int.max(0, theme_names.length - visible_items));

        // Draw items
        int y = PADDING;
        for (int i = scroll_offset; i < theme_names.length && i < scroll_offset + visible_items; i++) {
            var colors = theme_colors[i];

            // Draw rounded rectangle background
            double x = PADDING + 5;
            double item_width = width - PADDING * 2 - 10;
            double radius = 5.0;

            cr.new_sub_path();
            cr.arc(x + radius, y + radius, radius, Math.PI, 3 * Math.PI / 2);
            cr.arc(x + item_width - radius, y + radius, radius, 3 * Math.PI / 2, 0);
            cr.arc(x + item_width - radius, y + THEME_ITEM_HEIGHT - radius, radius, 0, Math.PI / 2);
            cr.arc(x + radius, y + THEME_ITEM_HEIGHT - radius, radius, Math.PI / 2, Math.PI);
            cr.close_path();

            // Background with 0.8 alpha (matching old ThemeButton)
            cr.set_source_rgba(
                colors.background.red,
                colors.background.green,
                colors.background.blue,
                0.8
            );
            cr.fill_preserve();

            // Draw selection border if selected
            if (i == selected_index) {
                cr.set_source_rgba(
                    foreground_color.red,
                    foreground_color.green,
                    foreground_color.blue,
                    1.0
                );
                cr.set_line_width(2.0);
                cr.stroke();
            } else {
                cr.new_path();
            }

            // First line: "lazycat@terminal:~/Theme$ _"
            cr.select_font_face("monospace", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(16);  // 130% of original 11

            double text_x = x + 8;
            double text_y = y + 20;

            // Check if background is light, if so use darker text colors for better contrast
            bool is_light_background = get_color_brightness(colors.background) > 0.5;

            // "lazycat" in color_11 (prompt host color) or dark color for light backgrounds
            if (is_light_background) {
                // Use darker version of color_11 or fallback to dark color
                double darkness_factor = 0.3;
                cr.set_source_rgba(
                    colors.color_11.red * darkness_factor,
                    colors.color_11.green * darkness_factor,
                    colors.color_11.blue * darkness_factor,
                    1.0
                );
            } else {
                cr.set_source_rgba(colors.color_11.red, colors.color_11.green, colors.color_11.blue, 1.0);
            }
            cr.move_to(text_x, text_y);
            cr.show_text("lazycat");
            Cairo.TextExtents extents;
            cr.text_extents("lazycat", out extents);
            text_x += extents.x_advance;

            // "@" in foreground
            if (is_light_background) {
                double darkness_factor = 0.3;
                cr.set_source_rgba(
                    colors.foreground.red * darkness_factor,
                    colors.foreground.green * darkness_factor,
                    colors.foreground.blue * darkness_factor,
                    1.0
                );
            } else {
                cr.set_source_rgba(colors.foreground.red, colors.foreground.green, colors.foreground.blue, 1.0);
            }
            cr.move_to(text_x, text_y);
            cr.show_text("@");
            cr.text_extents("@", out extents);
            text_x += extents.x_advance;

            // "terminal" in color_13 (prompt path color)
            if (is_light_background) {
                double darkness_factor = 0.3;
                cr.set_source_rgba(
                    colors.color_13.red * darkness_factor,
                    colors.color_13.green * darkness_factor,
                    colors.color_13.blue * darkness_factor,
                    1.0
                );
            } else {
                cr.set_source_rgba(colors.color_13.red, colors.color_13.green, colors.color_13.blue, 1.0);
            }
            cr.move_to(text_x, text_y);
            cr.show_text("terminal");
            cr.text_extents("terminal", out extents);
            text_x += extents.x_advance;

            // ":~/Theme$ _" in foreground
            if (is_light_background) {
                double darkness_factor = 0.3;
                cr.set_source_rgba(
                    colors.foreground.red * darkness_factor,
                    colors.foreground.green * darkness_factor,
                    colors.foreground.blue * darkness_factor,
                    1.0
                );
            } else {
                cr.set_source_rgba(colors.foreground.red, colors.foreground.green, colors.foreground.blue, 1.0);
            }
            cr.move_to(text_x, text_y);
            cr.show_text(":~/Theme$ _");

            // Second line: theme name in foreground color (matching old ThemeButton)
            if (is_light_background) {
                double darkness_factor = 0.3;
                cr.set_source_rgba(
                    colors.foreground.red * darkness_factor,
                    colors.foreground.green * darkness_factor,
                    colors.foreground.blue * darkness_factor,
                    1.0
                );
            } else {
                cr.set_source_rgba(colors.foreground.red, colors.foreground.green, colors.foreground.blue, 1.0);
            }
            cr.move_to(x + 8, y + 40);
            cr.show_text(theme_names[i]);

            y += THEME_ITEM_TOTAL;
        }
    }
}

// Transparency slider widget
private class TransparencySlider : Gtk.DrawingArea {
    private Gdk.RGBA foreground_color;
    private double value = 0.88; // Default transparency
    private bool is_focused = false;
    private const int SLIDER_HEIGHT = 30;
    private const int HANDLE_WIDTH = 10;

    public signal void value_changed(double new_value);

    public TransparencySlider(Gdk.RGBA fg_color) {
        foreground_color = fg_color;
        set_size_request(-1, SLIDER_HEIGHT);
        set_draw_func(draw_slider);

        // Add click support for direct positioning
        var click_gesture = new Gtk.GestureClick();
        click_gesture.set_button(1);
        click_gesture.pressed.connect(on_click);
        add_controller(click_gesture);
    }

    public void set_focused(bool focused) {
        is_focused = focused;
        queue_draw();
    }

    public void update_foreground_color(Gdk.RGBA new_fg_color) {
        foreground_color = new_fg_color;
        queue_draw();
    }

    public double get_value() {
        return value;
    }

    public void set_value(double new_value) {
        value = double.max(0.0, double.min(1.0, new_value));
        queue_draw();
    }

    public void increase_value() {
        value = double.min(1.0, value + 0.01);  // 1% increment
        queue_draw();
        value_changed(value);
    }

    public void decrease_value() {
        value = double.max(0.0, value - 0.01);  // 1% decrement
        queue_draw();
        value_changed(value);
    }

    private void on_click(int n_press, double x, double y) {
        int width = get_width();
        double track_width = width - HANDLE_WIDTH;
        double new_value = (x - HANDLE_WIDTH / 2) / track_width;
        // Round to nearest 1%
        value = double.max(0.0, double.min(1.0, Math.round(new_value * 100) / 100));
        queue_draw();
        value_changed(value);
    }

    private void draw_slider(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Draw track (background)
        double track_y = height / 2;
        double track_height = 4;

        cr.set_source_rgba(
            foreground_color.red,
            foreground_color.green,
            foreground_color.blue,
            0.3
        );
        cr.rectangle(HANDLE_WIDTH / 2, track_y - track_height / 2,
                    width - HANDLE_WIDTH, track_height);
        cr.fill();

        // Draw filled portion with focus-dependent opacity
        double filled_width = (width - HANDLE_WIDTH) * value;
        double fill_alpha = is_focused ? 1.0 : 0.5;
        cr.set_source_rgba(
            foreground_color.red,
            foreground_color.green,
            foreground_color.blue,
            fill_alpha
        );
        cr.rectangle(HANDLE_WIDTH / 2, track_y - track_height / 2,
                    filled_width, track_height);
        cr.fill();

        // Draw handle with focus-dependent opacity
        double handle_x = HANDLE_WIDTH / 2 + filled_width;
        cr.set_source_rgba(
            foreground_color.red,
            foreground_color.green,
            foreground_color.blue,
            fill_alpha
        );
        cr.rectangle(handle_x - HANDLE_WIDTH / 2, track_y - 8,
                    HANDLE_WIDTH, 16);
        cr.fill();
    }
}
