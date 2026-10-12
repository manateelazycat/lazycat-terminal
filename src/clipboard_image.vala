// Materialize clipboard images as local files that CLI tools can read.
public class ClipboardImage : Object {
    public static async string? read_path(Gdk.Clipboard clipboard) throws Error {
        if (!clipboard.get_formats().contain_gtype(typeof(Gdk.Texture))) {
            return null;
        }

        var texture = yield clipboard.read_texture_async(null);
        if (texture == null) {
            return null;
        }

        // Use /tmp explicitly, even when TMPDIR points inside the user's home.
        // mkdtemp creates a private directory with mode 0700.
        string template = "/tmp/lazycat-terminal-clipboard-XXXXXX";
        string? directory = DirUtils.mkdtemp(template);
        if (directory == null) {
            throw new IOError.FAILED("Could not create clipboard image directory in /tmp");
        }
        string path = Path.build_filename(directory, "clipboard.png");
        if (!texture.save_to_png(path)) {
            FileUtils.remove(path);
            DirUtils.remove(directory);
            throw new IOError.FAILED("Could not save clipboard image as PNG");
        }
        // Keep the file after pasting: the CLI may read it later in the session.
        return path;
    }
}
