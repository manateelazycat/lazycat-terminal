// Confirmation dialog with transparent background and shadow

public class ConfirmDialog : Gtk.Window {
    private Gtk.Box shadow_container;
    private Gtk.Box main_box;
    private Gtk.Label message_label;
    private Gtk.Button confirm_button;
    private Gtk.DrawingArea close_button;
    private Gdk.RGBA foreground_color;
    private Gdk.RGBA background_color;
    private double background_opacity = 0.95;

    // Close button state
    private bool close_button_hover = false;
    private bool close_button_pressed = false;

    // Shadow parameters (same as ShadowWindow)
    private const int SHADOW_SIZE = 12;
    private const int CLOSE_BTN_SIZE = 12;

    public signal void confirmed();

    public ConfirmDialog(Gtk.Window parent, string message, Gdk.RGBA fg_color, Gdk.RGBA bg_color) {
        Object(transient_for: parent, modal: true);

        foreground_color = fg_color;
        background_color = bg_color;

        setup_window();
        setup_layout(message);
    }

    private void setup_window() {
        set_default_size(320 + SHADOW_SIZE * 2, 130 + SHADOW_SIZE * 2);
        set_decorated(false);
        set_resizable(false);

        // Make window transparent
        add_css_class("confirm-dialog-window");

        // Add CSS for styling
        load_css();
    }

    private void load_css() {
        var css_provider = new Gtk.CssProvider();

        // Use darker background than main window
        string fg_hex = rgba_to_hex(foreground_color);

        // Convert background color to RGB values
        int bg_r = (int)(background_color.red * 255);
        int bg_g = (int)(background_color.green * 255);
        int bg_b = (int)(background_color.blue * 255);

        string css = """
            window.confirm-dialog-window {
                background-color: transparent;
            }

            .confirm-shadow-container {
                background-color: transparent;
                box-shadow: 0px 4px 12px rgba(0, 0, 0, 0.35);
                border-radius: 8px;
            }

            .confirm-dialog {
                background-color: rgba(""" + bg_r.to_string() + """, """ + bg_g.to_string() + """, """ + bg_b.to_string() + """, """ + background_opacity.to_string() + """);
                border-radius: 8px;
                border: 1px solid """ + fg_hex + """;
            }

            .confirm-message {
                color: """ + fg_hex + """;
                font-size: 14px;
                padding: 5px 15px 10px 15px;
            }

            .confirm-button {
                background-color: transparent;
                background-image: none;
                color: """ + fg_hex + """;
                border: 1px solid """ + fg_hex + """;
                border-radius: 4px;
                padding: 6px 12px;
                min-width: 80px;
                outline: none;
                box-shadow: none;
            }

            .confirm-button:focus {
                background-color: transparent;
                background-image: none;
                border: 1px solid """ + fg_hex + """;
                outline: none;
                box-shadow: none;
            }

            .confirm-button:hover {
                background-color: rgba(""" +
                    (foreground_color.red * 255).to_string() + """, """ +
                    (foreground_color.green * 255).to_string() + """, """ +
                    (foreground_color.blue * 255).to_string() + """, 0.2);
                background-image: none;
            }

            .confirm-button:active {
                background-color: rgba(""" +
                    (foreground_color.red * 255).to_string() + """, """ +
                    (foreground_color.green * 255).to_string() + """, """ +
                    (foreground_color.blue * 255).to_string() + """, 0.3);
                background-image: none;
            }
        """;

        css_provider.load_from_string(css);

        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private string rgba_to_hex(Gdk.RGBA color) {
        return "#%02x%02x%02x".printf(
            (int)(color.red * 255),
            (int)(color.green * 255),
            (int)(color.blue * 255)
        );
    }

    private void setup_layout(string message) {
        // Shadow container (with margins for shadow)
        shadow_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        shadow_container.add_css_class("confirm-shadow-container");
        shadow_container.set_margin_start(SHADOW_SIZE);
        shadow_container.set_margin_end(SHADOW_SIZE);
        shadow_container.set_margin_top(SHADOW_SIZE);
        shadow_container.set_margin_bottom(SHADOW_SIZE);
        shadow_container.set_hexpand(true);
        shadow_container.set_vexpand(true);

        // Create overlay for floating close button
        var overlay = new Gtk.Overlay();

        main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        main_box.add_css_class("confirm-dialog");

        // Message label
        message_label = new Gtk.Label(message);
        message_label.add_css_class("confirm-message");
        message_label.set_wrap(true);
        message_label.set_justify(Gtk.Justification.CENTER);
        message_label.set_vexpand(true);
        message_label.set_valign(Gtk.Align.CENTER);
        message_label.set_margin_top(15);

        // Button box
        var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
        button_box.set_halign(Gtk.Align.CENTER);
        button_box.set_margin_bottom(17);

        confirm_button = new Gtk.Button.with_label("Confirm");
        confirm_button.add_css_class("confirm-button");
        confirm_button.clicked.connect(() => {
            confirmed();
            hide();
        });

        button_box.append(confirm_button);

        main_box.append(message_label);
        main_box.append(button_box);

        // Set main_box as overlay base
        overlay.set_child(main_box);

        // Close button (DrawingArea for custom drawing) - floats on top
        close_button = new Gtk.DrawingArea();
        close_button.set_size_request(CLOSE_BTN_SIZE * 2 + 10, CLOSE_BTN_SIZE * 2 + 10);
        close_button.set_valign(Gtk.Align.START);
        close_button.set_halign(Gtk.Align.END);
        close_button.set_margin_top(8);
        close_button.set_margin_end(8);
        close_button.set_draw_func(draw_close_button);

        // Setup close button interactions
        setup_close_button_interactions();

        // Add close button as overlay
        overlay.add_overlay(close_button);

        shadow_container.append(overlay);
        set_child(shadow_container);

        // Setup keyboard shortcuts
        setup_keyboard_shortcuts();

        // Set confirm button as default and grab focus when dialog is shown
        set_default_widget(confirm_button);
        confirm_button.can_focus = true;

        // Grab focus when dialog is mapped
        map.connect(() => {
            confirm_button.grab_focus();
        });
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
                hide();
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
            if (keyval == Gdk.Key.Escape) {
                hide();
                return true;
            }
            return false;
        });

        ((Gtk.Widget)this).add_controller(controller);
    }
}
