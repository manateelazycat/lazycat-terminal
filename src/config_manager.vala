// Configuration Manager - Handles loading and parsing config.conf

public class ConfigManager {
    private KeyFile config_file;
    private string config_path;

    // Configuration values
    public string theme { get; private set; }
    public double opacity { get; private set; }
    public string font { get; private set; }
    public int font_size { get; private set; }
    public double line_height { get; private set; }
    public bool hide_tab_bar { get; private set; }
    public bool start_maximized { get; private set; }

    // Shortcut mappings
    private HashTable<string, string> shortcuts;

    // Data directory (where themes and default config are located)
    private static string? _data_dir = null;
    public static string data_dir {
        get {
            if (_data_dir == null) {
                // First check current directory (for development)
                string local_path = Environment.get_current_dir();
                var local_theme = File.new_for_path(Path.build_filename(local_path, "theme"));
                if (local_theme.query_exists()) {
                    _data_dir = local_path;
                } else {
                    // Use system installation path
                    _data_dir = "/usr/share/lazycat-terminal";
                }
            }
            return _data_dir;
        }
    }

    // Get theme file path
    public static string get_theme_path(string theme_name) {
        return Path.build_filename(data_dir, "theme", theme_name);
    }

    public ConfigManager() {
        config_file = new KeyFile();
        shortcuts = new HashTable<string, string>(str_hash, str_equal);

        // Set default configuration path
        string config_dir = Path.build_filename(Environment.get_home_dir(), ".config", "lazycat-terminal");
        config_path = Path.build_filename(config_dir, "config.conf");

        // Check and copy config file if needed
        ensure_config_exists();

        // Load configuration
        load_config();
    }

    private void ensure_config_exists() {
        var config_file_obj = File.new_for_path(config_path);

        // Check if config file exists
        if (!config_file_obj.query_exists()) {
            try {
                // Create config directory if it doesn't exist
                string config_dir = Path.get_dirname(config_path);
                var dir = File.new_for_path(config_dir);
                if (!dir.query_exists()) {
                    dir.make_directory_with_parents();
                }

                // Copy config.conf from data directory to ~/.config/lazycat-terminal/
                string source_path = Path.build_filename(data_dir, "config.conf");
                var source_file = File.new_for_path(source_path);

                if (source_file.query_exists()) {
                    source_file.copy(config_file_obj, FileCopyFlags.NONE);
                } else {
                    stderr.printf("Warning: Source config.conf not found at: %s\n", source_path);
                }
            } catch (Error e) {
                stderr.printf("Error ensuring config exists: %s\n", e.message);
            }
        }
    }

    private void load_config() {
        try {
            config_file.load_from_file(config_path, KeyFileFlags.NONE);

            // Load general settings
            if (config_file.has_group("general")) {
                theme = config_file.get_string("general", "theme");
                opacity = config_file.get_double("general", "opacity");
                font = config_file.get_string("general", "font");
                font_size = config_file.get_integer("general", "font_size");
                // Load line_height with default 1.0 if not present
                try {
                    line_height = config_file.get_double("general", "line_height");
                    // Clamp to valid range 1.0-2.0
                    if (line_height < 1.0) line_height = 1.0;
                    if (line_height > 2.0) line_height = 2.0;
                } catch (KeyFileError e) {
                    line_height = 1.0;
                }
                // Load hide_tab_bar with default false if not present
                try {
                    hide_tab_bar = config_file.get_boolean("general", "hide_tab_bar");
                } catch (KeyFileError e) {
                    hide_tab_bar = false;
                }
                
                // Load start_maximized with default false if not present
                try {
                    start_maximized = config_file.get_boolean("general", "start_maximized");
                } catch (KeyFileError e) {
                    start_maximized = false;
                }
            } else {
                // Set defaults if general section is missing
                theme = "default";
                opacity = 0.88;
                font = "Hack";
                font_size = 13;
                line_height = 1.0;
                hide_tab_bar = false;
                start_maximized = false;
            }

            // Load shortcuts
            if (config_file.has_group("shortcut")) {
                string[] keys = config_file.get_keys("shortcut");
                foreach (string key in keys) {
                    string value = config_file.get_string("shortcut", key).strip();
                    shortcuts.set(key, value);
                }
            }
        } catch (Error e) {
            stderr.printf("Error loading config: %s\n", e.message);
            // Set defaults
            theme = "default";
            opacity = 0.88;
            font = "Hack";
            font_size = 13;
            line_height = 1.0;
            hide_tab_bar = false;
            start_maximized = false;
        }
    }

    // Get shortcut value by name
    public string? get_shortcut(string name) {
        return shortcuts.get(name);
    }

    // Update font setting and save to config file
    public void update_font(string new_font) {
        font = new_font;
        save_config();
    }

    // Update font size setting and save to config file
    public void update_font_size(int new_font_size) {
        font_size = new_font_size;
        save_config();
    }

    // Update theme setting and save to config file
    public void update_theme(string new_theme) {
        theme = new_theme;
        save_config();
    }

    // Update opacity setting and save to config file
    public void update_opacity(double new_opacity) {
        // Round to 2 decimal places
        opacity = Math.round(new_opacity * 100.0) / 100.0;
        save_config();
    }

    // Update hide_tab_bar setting and save to config file
    public void update_hide_tab_bar(bool new_hide_tab_bar) {
        hide_tab_bar = new_hide_tab_bar;
    }

    // Update start_maximized setting and save to config file
    public void update_start_maximized(bool new_start_maximized) {
        start_maximized = new_start_maximized;
        save_config();
    }

    // Save current configuration to file
    private void save_config() {
        try {
            // Update values in config_file
            config_file.set_string("general", "theme", theme);
            // Format opacity to 2 decimal places
            config_file.set_string("general", "opacity", "%.2f".printf(opacity));
            config_file.set_string("general", "font", font);
            config_file.set_integer("general", "font_size", font_size);
            config_file.set_string("general", "line_height", "%.2f".printf(line_height));
            config_file.set_boolean("general", "hide_tab_bar", hide_tab_bar);
            config_file.set_boolean("general", "start_maximized", start_maximized);

            // Save to file
            string data = config_file.to_data();
            FileUtils.set_contents(config_path, data);
        } catch (Error e) {
            stderr.printf("Error saving config: %s\n", e.message);
        }
    }
}
