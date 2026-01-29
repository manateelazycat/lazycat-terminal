// KDE-style Window Shadow for GTK4
// Uses CSS box-shadow for natural shadow effects

// Window snap position enum
public enum WindowSnapPosition {
    NONE,           // Normal window, show all shadows
    MAXIMIZED,      // Maximized, no shadows
    LEFT,           // Snapped to left edge, shadow only on right
    RIGHT,          // Snapped to right edge, shadow only on left
    TOP_LEFT,       // Snapped to top-left corner, shadow on right and bottom
    TOP_RIGHT,      // Snapped to top-right corner, shadow on left and bottom
    BOTTOM_LEFT,    // Snapped to bottom-left corner, shadow on right and top
    BOTTOM_RIGHT    // Snapped to bottom-right corner, shadow on left and top
}

public class ShadowWindow : Gtk.ApplicationWindow {
    // Shadow parameters
    private const int SHADOW_SIZE = 12;
    private const int SHADOW_OFFSET_Y = 4;

    // Child content
    private Gtk.Widget? content_widget = null;
    private Gtk.Box content_box;

    // State tracking
    private WindowSnapPosition snap_position = WindowSnapPosition.NONE;
    private int window_width = 0;
    private int window_height = 0;
    private uint position_check_source_id = 0;
    private bool initial_check_done = false;
    private uint input_region_update_source_id = 0;

    // Monitor info for snap detection
    private int monitor_width = 1920;
    private int monitor_height = 1080;

    public ShadowWindow(Gtk.Application app) {
        Object(application: app);
    }

    construct {
        setup_window();
        setup_layout();
        setup_state_tracking();
    }

    private void setup_window() {
        set_decorated(false);

        // Calculate initial window size based on screen dimensions
        var display = Gdk.Display.get_default();
        if (display != null) {
            var monitors = display.get_monitors();
            if (monitors.get_n_items() > 0) {
                var monitor = (Gdk.Monitor)monitors.get_item(0);
                var geometry = monitor.get_geometry();
                int screen_width = geometry.width;
                int screen_height = geometry.height;

                int window_width = (int)(screen_width * 0.618) + SHADOW_SIZE * 2;
                int window_height = (int)(screen_height * 0.618) + SHADOW_SIZE * 2;

                set_default_size(window_width, window_height);
            } else {
                // Fallback if no monitor detected
                set_default_size(900 + SHADOW_SIZE * 2, 600 + SHADOW_SIZE * 2);
            }
        } else {
            // Fallback if no display detected
            set_default_size(900 + SHADOW_SIZE * 2, 600 + SHADOW_SIZE * 2);
        }

        // Make window transparent
        add_css_class("shadow-window");

        // Load CSS with shadow styles
        load_shadow_css();
    }

    private void load_shadow_css() {
        var provider = new Gtk.CssProvider();
        provider.load_from_string("""
            window.shadow-window {
                background-color: transparent;
            }

            .shadow-window {
                background-color: transparent;
            }

            .shadow-container {
                background-color: transparent;
                box-shadow: 0px 4px 12px rgba(0, 0, 0, 0.35);
                border-radius: 6px;
                transition: box-shadow 150ms ease-in-out, border-radius 150ms ease-in-out;
            }

            .shadow-container.unfocused {
                box-shadow: 0px 2px 8px rgba(0, 0, 0, 0.18);
            }

            .shadow-container.maximized {
                box-shadow: none;
                border-radius: 0;
            }

            .shadow-container.snap-left {
                box-shadow: 8px 4px 12px rgba(0, 0, 0, 0.35);
                border-radius: 0;
            }
            .shadow-container.snap-left.unfocused {
                box-shadow: 6px 2px 8px rgba(0, 0, 0, 0.18);
            }

            .shadow-container.snap-right {
                box-shadow: -8px 4px 12px rgba(0, 0, 0, 0.35);
                border-radius: 0;
            }
            .shadow-container.snap-right.unfocused {
                box-shadow: -6px 2px 8px rgba(0, 0, 0, 0.18);
            }

            .shadow-container.snap-top-left {
                box-shadow: 8px 8px 12px rgba(0, 0, 0, 0.35);
                border-radius: 0;
            }
            .shadow-container.snap-top-left.unfocused {
                box-shadow: 6px 6px 8px rgba(0, 0, 0, 0.18);
            }

            .shadow-container.snap-top-right {
                box-shadow: -8px 8px 12px rgba(0, 0, 0, 0.35);
                border-radius: 0;
            }
            .shadow-container.snap-top-right.unfocused {
                box-shadow: -6px 6px 8px rgba(0, 0, 0, 0.18);
            }

            .shadow-container.snap-bottom-left {
                box-shadow: 8px -4px 12px rgba(0, 0, 0, 0.35);
                border-radius: 0;
            }
            .shadow-container.snap-bottom-left.unfocused {
                box-shadow: 6px -2px 8px rgba(0, 0, 0, 0.18);
            }

            .shadow-container.snap-bottom-right {
                box-shadow: -8px -4px 12px rgba(0, 0, 0, 0.35);
                border-radius: 0;
            }
            .shadow-container.snap-bottom-right.unfocused {
                box-shadow: -6px -2px 8px rgba(0, 0, 0, 0.18);
            }
        """);

        StyleHelper.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private void setup_layout() {
        // Content box with shadow via CSS
        content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        content_box.add_css_class("shadow-container");
        content_box.set_hexpand(true);
        content_box.set_vexpand(true);
        content_box.set_overflow(Gtk.Overflow.HIDDEN);
        update_content_margins();

        set_child(content_box);

        // Setup input region for click-through on shadow area
        setup_input_region();
    }

    private void update_content_margins() {
        int top = 0, bottom = 0, left = 0, right = 0;

        // Apply shadow offset: less on top, more on bottom (shadow shifts down)
        int top_margin = SHADOW_SIZE - SHADOW_OFFSET_Y;
        int bottom_margin = SHADOW_SIZE + SHADOW_OFFSET_Y;

        switch (snap_position) {
            case WindowSnapPosition.NONE:
                top = top_margin;
                bottom = bottom_margin;
                left = right = SHADOW_SIZE;
                break;
            case WindowSnapPosition.MAXIMIZED:
                top = bottom = left = right = 0;
                break;
            case WindowSnapPosition.LEFT:
                top = top_margin;
                bottom = bottom_margin;
                right = SHADOW_SIZE;
                break;
            case WindowSnapPosition.RIGHT:
                top = top_margin;
                bottom = bottom_margin;
                left = SHADOW_SIZE;
                break;
            case WindowSnapPosition.TOP_LEFT:
                right = SHADOW_SIZE;
                bottom = bottom_margin;
                break;
            case WindowSnapPosition.TOP_RIGHT:
                left = SHADOW_SIZE;
                bottom = bottom_margin;
                break;
            case WindowSnapPosition.BOTTOM_LEFT:
                right = SHADOW_SIZE;
                top = top_margin;
                break;
            case WindowSnapPosition.BOTTOM_RIGHT:
                left = SHADOW_SIZE;
                top = top_margin;
                break;
        }

        content_box.set_margin_top(top);
        content_box.set_margin_bottom(bottom);
        content_box.set_margin_start(left);
        content_box.set_margin_end(right);
    }

    private void update_shadow_classes() {
        // Remove all snap classes first
        content_box.remove_css_class("maximized");
        content_box.remove_css_class("snap-left");
        content_box.remove_css_class("snap-right");
        content_box.remove_css_class("snap-top-left");
        content_box.remove_css_class("snap-top-right");
        content_box.remove_css_class("snap-bottom-left");
        content_box.remove_css_class("snap-bottom-right");

        // Add appropriate class based on snap position
        switch (snap_position) {
            case WindowSnapPosition.MAXIMIZED:
                content_box.add_css_class("maximized");
                break;
            case WindowSnapPosition.LEFT:
                content_box.add_css_class("snap-left");
                break;
            case WindowSnapPosition.RIGHT:
                content_box.add_css_class("snap-right");
                break;
            case WindowSnapPosition.TOP_LEFT:
                content_box.add_css_class("snap-top-left");
                break;
            case WindowSnapPosition.TOP_RIGHT:
                content_box.add_css_class("snap-top-right");
                break;
            case WindowSnapPosition.BOTTOM_LEFT:
                content_box.add_css_class("snap-bottom-left");
                break;
            case WindowSnapPosition.BOTTOM_RIGHT:
                content_box.add_css_class("snap-bottom-right");
                break;
            default:
                // NONE - use default shadow
                break;
        }
    }

    private bool surface_signals_connected = false;

    private void setup_input_region() {
        // Will connect signals when surface becomes available via tick callback
    }

    private void ensure_surface_signals() {
        if (surface_signals_connected) return;

        var surface = get_surface();
        if (surface != null) {
            surface.notify["state"].connect(on_surface_state_changed);
            surface.notify["width"].connect(on_surface_size_changed);
            surface.notify["height"].connect(on_surface_size_changed);
            surface_signals_connected = true;
        }
    }

    private void on_window_state_changed() {
        update_snap_position();
        update_content_margins();
        update_shadow_classes();
        schedule_input_region_update();
    }

    private void on_surface_state_changed() {
        update_snap_position();
        schedule_input_region_update();
    }

    private void on_surface_size_changed() {
        update_snap_position();
        schedule_input_region_update();
    }

    private void schedule_input_region_update() {
        // Cancel any pending update
        if (input_region_update_source_id != 0) {
            Source.remove(input_region_update_source_id);
            input_region_update_source_id = 0;
        }

        // Schedule update in idle to ensure window geometry is fully updated
        input_region_update_source_id = GLib.Idle.add(() => {
            input_region_update_source_id = 0;
            update_input_region_for_current_state();
            return false;
        });
    }

    private void update_input_region_for_current_state() {
        var surface = get_surface();
        if (surface == null) return;

        int width = get_width();
        int height = get_height();

        if (width <= 0 || height <= 0) return;

        int top = content_box.get_margin_top();
        int bottom = content_box.get_margin_bottom();
        int left = content_box.get_margin_start();
        int right = content_box.get_margin_end();

        int content_width = width - left - right;
        int content_height = height - top - bottom;

        Cairo.Region region;

        // Check if window is maximized, fullscreen, or snapped
        bool is_square_corners = snap_position != WindowSnapPosition.NONE;

        var toplevel = surface as Gdk.Toplevel;
        if (toplevel != null) {
            var state = toplevel.get_state();
            if ((Gdk.ToplevelState.MAXIMIZED in state) ||
                (Gdk.ToplevelState.FULLSCREEN in state) ||
                (Gdk.ToplevelState.TILED in state)) {
                is_square_corners = true;
            }
        }

        if (is_square_corners) {
            // Square corners - simple rectangle
            region = new Cairo.Region.rectangle({
                left, top,
                content_width,
                content_height
            });
        } else {
            // Rounded corners - create region with rounded corners
            // Match the CSS border-radius of 6px
            int corner_radius = 6;

            // Create the rounded rectangle by combining rectangles
            // Main center rectangle (full width, reduced height for corners)
            region = new Cairo.Region.rectangle({
                left,
                top + corner_radius,
                content_width,
                content_height - corner_radius * 2
            });

            // Top rectangle (reduced width for corners)
            region.union_rectangle({
                left + corner_radius,
                top,
                content_width - corner_radius * 2,
                corner_radius
            });

            // Bottom rectangle (reduced width for corners)
            region.union_rectangle({
                left + corner_radius,
                top + content_height - corner_radius,
                content_width - corner_radius * 2,
                corner_radius
            });
        }

        surface.set_input_region(region);
    }

    private void setup_state_tracking() {
        // Track focus changes
        notify["is-active"].connect(() => {
            if (is_active) {
                content_box.remove_css_class("unfocused");
            } else {
                content_box.add_css_class("unfocused");
            }
        });

        // Track maximize and fullscreen state changes
        notify["maximized"].connect(on_window_state_changed);
        notify["fullscreened"].connect(on_window_state_changed);

        // Track size changes with debounce
        notify["default-width"].connect(schedule_position_check);
        notify["default-height"].connect(schedule_position_check);

        // Do initial check once after window is mapped
        map.connect(() => {
            if (!initial_check_done) {
                initial_check_done = true;
                check_window_position();
            }
        });
    }

    private void schedule_position_check() {
        // Debounce: cancel pending check and schedule a new one
        if (position_check_source_id != 0) {
            Source.remove(position_check_source_id);
        }
        position_check_source_id = GLib.Timeout.add(50, () => {
            position_check_source_id = 0;
            check_window_position();
            return false;
        });
    }

    private void check_window_position() {
        var surface = get_surface();
        if (surface == null) return;

        // Ensure surface signals are connected
        ensure_surface_signals();

        var display = Gdk.Display.get_default();
        if (display == null) return;

        var monitors = display.get_monitors();
        if (monitors.get_n_items() == 0) return;

        var monitor = (Gdk.Monitor)monitors.get_item(0);
        var geometry = monitor.get_geometry();
        monitor_width = geometry.width;
        monitor_height = geometry.height;

        window_width = get_width();
        window_height = get_height();

        update_snap_position();
    }

    private void update_snap_position() {
        WindowSnapPosition new_position = WindowSnapPosition.NONE;

        var surface = get_surface();
        if (surface != null) {
            var toplevel = surface as Gdk.Toplevel;
            if (toplevel != null) {
                var state = toplevel.get_state();

                // First check ToplevelState
                if ((Gdk.ToplevelState.MAXIMIZED in state) ||
                    (Gdk.ToplevelState.FULLSCREEN in state) ||
                    (Gdk.ToplevelState.TILED in state)) {
                    new_position = WindowSnapPosition.MAXIMIZED;
                }
            }
        }

        // If ToplevelState not set, detect by window size
        if (new_position == WindowSnapPosition.NONE && monitor_width > 0 && monitor_height > 0) {
            int win_w = get_width();
            int win_h = get_height();

            // Tolerance for size comparison
            int tolerance = SHADOW_SIZE * 2 + 20;

            bool is_full_width = (win_w >= monitor_width - tolerance);
            bool is_half_width = (win_w >= monitor_width / 2 - tolerance) && (win_w <= monitor_width / 2 + tolerance);
            bool is_full_height = (win_h >= monitor_height - tolerance);
            bool is_half_height = (win_h >= monitor_height / 2 - tolerance) && (win_h <= monitor_height / 2 + tolerance);

            if (is_full_width && is_full_height) {
                // Maximized
                new_position = WindowSnapPosition.MAXIMIZED;
            } else if (is_half_width && is_full_height) {
                // Left or right half snap
                new_position = WindowSnapPosition.MAXIMIZED;
            } else if (is_half_width && is_half_height) {
                // Corner snap
                new_position = WindowSnapPosition.MAXIMIZED;
            }
        }

        if (new_position != snap_position) {
            snap_position = new_position;
            update_content_margins();
            update_shadow_classes();
            schedule_input_region_update();
        }
    }

    public void set_snap_position(WindowSnapPosition position) {
        if (snap_position != position) {
            snap_position = position;
            update_content_margins();
            update_shadow_classes();
            schedule_input_region_update();
        }
    }

    public WindowSnapPosition get_snap_position() {
        return snap_position;
    }

    public void set_content(Gtk.Widget widget) {
        if (content_widget != null) {
            content_box.remove(content_widget);
        }
        content_widget = widget;
        content_box.append(widget);
    }

    public Gtk.Widget? get_content() {
        return content_widget;
    }

    public int get_shadow_size() {
        return SHADOW_SIZE;
    }

    public void get_content_bounds(out int x, out int y, out int width, out int height) {
        x = content_box.get_margin_start();
        y = content_box.get_margin_top();
        width = get_width() - x - content_box.get_margin_end();
        height = get_height() - y - content_box.get_margin_bottom();
    }
}
