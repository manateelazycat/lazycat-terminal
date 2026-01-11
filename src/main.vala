// LazyCat Terminal - A Chrome-style tabbed terminal emulator

public class LazyCatTerminal : Gtk.Application {
    public static string[] launch_commands = {};
    public static string? working_directory = null;
    public static bool start_maximized = false;

    public LazyCatTerminal() {
        Object(
            application_id: "com.lazycat.terminal",
            flags: ApplicationFlags.HANDLES_COMMAND_LINE | ApplicationFlags.NON_UNIQUE
        );
    }

    protected override void activate() {
        var window = new TerminalWindow(this);
        window.present();
    }

    public override int command_line(GLib.ApplicationCommandLine cmdline) {
        string[] args = cmdline.get_arguments();

        // Parse command line arguments
        bool next_is_directory = false;
        bool next_is_execute = false;

        for (int i = 1; i < args.length; i++) {
            if (next_is_directory) {
                working_directory = args[i];
                next_is_directory = false;
            } else if (next_is_execute) {
                // Collect all remaining arguments as command
                launch_commands = new string[args.length - i];
                for (int j = i; j < args.length; j++) {
                    launch_commands[j - i] = args[j];
                }
                break;
            } else if (args[i] == "--working-directory" || args[i] == "-w") {
                next_is_directory = true;
            } else if (args[i] == "--execute" || args[i] == "-e") {
                next_is_execute = true;
            } else if (args[i] == "--maximized" || args[i] == "-m") {
                start_maximized = true;
            }
        }

        activate();
        return 0;
    }

    public static int main(string[] args) {
        var app = new LazyCatTerminal();
        return app.run(args);
    }
}
