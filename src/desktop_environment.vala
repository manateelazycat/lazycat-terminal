// Desktop environment detection used for window-manager-specific UI behavior.

namespace DesktopEnvironment {
    private bool has_value(string? value) {
        if (value == null) {
            return false;
        }

        return value.strip().length > 0;
    }

    private bool names_hyprland_or_omarchy(string? value) {
        if (value == null) {
            return false;
        }

        string normalized = value.strip().down();
        return normalized.contains("hyprland") || normalized.contains("omarchy");
    }

    public bool values_identify_hyprland_or_omarchy(
        string? hyprland_instance_signature,
        string? omarchy_path,
        string? current_desktop,
        string? session_desktop,
        string? desktop_session
    ) {
        return has_value(hyprland_instance_signature) ||
               has_value(omarchy_path) ||
               names_hyprland_or_omarchy(current_desktop) ||
               names_hyprland_or_omarchy(session_desktop) ||
               names_hyprland_or_omarchy(desktop_session);
    }

    public bool is_hyprland_or_omarchy() {
        return values_identify_hyprland_or_omarchy(
            Environment.get_variable("HYPRLAND_INSTANCE_SIGNATURE"),
            Environment.get_variable("OMARCHY_PATH"),
            Environment.get_variable("XDG_CURRENT_DESKTOP"),
            Environment.get_variable("XDG_SESSION_DESKTOP"),
            Environment.get_variable("DESKTOP_SESSION")
        );
    }
}
