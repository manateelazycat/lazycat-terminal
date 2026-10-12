private Gdk.Clipboard? clipboard;

private string? read_path() {
    var loop = new MainLoop();
    string? path = null;
    ClipboardImage.read_path.begin(clipboard, (obj, result) => {
        try {
            path = ClipboardImage.read_path.end(result);
        } catch (Error e) {
            error("Clipboard read failed: %s", e.message);
        }
        loop.quit();
    });
    loop.run();
    return path;
}

private bool require_display() {
    if (clipboard == null) {
        Test.skip("Run with LAZYCAT_TEST_CLIPBOARD=1 in an isolated GTK display");
        return false;
    }
    return true;
}

private Gdk.Texture make_texture() {
    uint8[] pixels = { 255, 0, 0, 255, 0, 255, 0, 255 };
    return new Gdk.MemoryTexture(2, 1, Gdk.MemoryFormat.R8G8B8A8,
                                new Bytes(pixels), 8);
}

private void remove_image(string path) {
    assert(FileUtils.remove(path) == 0);
    assert(DirUtils.remove(Path.get_dirname(path)) == 0);
}

private void test_text_fallback() {
    if (!require_display()) return;
    clipboard.set_text("normal clipboard text");
    assert(read_path() == null);
}

private void test_image_file() {
    if (!require_display()) return;
    clipboard.set_texture(make_texture());
    string? first = read_path();
    string? second = read_path();
    assert(first != null && second != null && first != second);
    assert(first.has_prefix("/tmp/lazycat-terminal-clipboard-"));
    assert(first.has_suffix("/clipboard.png"));
    try {
        var saved = Gdk.Texture.from_file(File.new_for_path(first));
        assert(saved.get_width() == 2 && saved.get_height() == 1);
        var info = File.new_for_path(Path.get_dirname(first)).query_info(
            FileAttribute.UNIX_MODE, FileQueryInfoFlags.NONE);
        assert((info.get_attribute_uint32(FileAttribute.UNIX_MODE) & 0777) == 0700);
    } catch (Error e) {
        error("Saved image validation failed: %s", e.message);
    }
    remove_image(first);
    remove_image(second);
}

private void test_image_mime_with_text() {
    if (!require_display()) return;
    var text = Value(typeof(string));
    text.set_string("image caption");
    clipboard.set_content(new Gdk.ContentProvider.union({
        new Gdk.ContentProvider.for_bytes("image/png", make_texture().save_to_png_bytes()),
        new Gdk.ContentProvider.for_value(text)
    }));
    string? path = read_path();
    assert(path != null);
    remove_image(path);
}

public static int main(string[] args) {
    Test.init(ref args);
    // Do not overwrite the user's clipboard during an ordinary test run.
    if (Environment.get_variable("LAZYCAT_TEST_CLIPBOARD") == "1" && Gtk.init_check()) {
        clipboard = Gdk.Display.get_default().get_clipboard();
    }
    Test.add_func("/clipboard-image/text-fallback", test_text_fallback);
    Test.add_func("/clipboard-image/private-unique-png", test_image_file);
    Test.add_func("/clipboard-image/png-mime-with-text", test_image_mime_with_text);
    return Test.run();
}
