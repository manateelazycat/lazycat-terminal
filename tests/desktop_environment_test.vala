private void test_no_matching_environment() {
    assert(!DesktopEnvironment.values_identify_hyprland_or_omarchy(
        null,
        null,
        "GNOME",
        "gnome-wayland",
        "gnome"
    ));
}

private void test_hyprland_instance_signature() {
    assert(DesktopEnvironment.values_identify_hyprland_or_omarchy(
        "instance-signature",
        null,
        null,
        null,
        null
    ));
}

private void test_omarchy_path() {
    assert(DesktopEnvironment.values_identify_hyprland_or_omarchy(
        null,
        "/usr/share/omarchy",
        null,
        null,
        null
    ));
}

private void test_desktop_names() {
    assert(DesktopEnvironment.values_identify_hyprland_or_omarchy(
        null,
        null,
        "Wayland:Hyprland",
        null,
        null
    ));
    assert(DesktopEnvironment.values_identify_hyprland_or_omarchy(
        null,
        null,
        null,
        null,
        "Omarchy"
    ));
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/desktop-environment/no-match", test_no_matching_environment);
    Test.add_func("/desktop-environment/hyprland-signature", test_hyprland_instance_signature);
    Test.add_func("/desktop-environment/omarchy-path", test_omarchy_path);
    Test.add_func("/desktop-environment/desktop-names", test_desktop_names);
    return Test.run();
}
