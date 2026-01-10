// LazyCat Terminal - A Chrome-style tabbed terminal emulator

public class LazyCatTerminal : Gtk.Application {
    public static string[] launch_commands = {};
    public static string? working_directory = null;

    public LazyCatTerminal() {
        Object(
            application_id: "com.lazycat.terminal",
            flags: ApplicationFlags.HANDLES_COMMAND_LINE
        );
    }

    protected override void activate() {
        var window = new TerminalWindow(this);
        window.present();
    }

    public override int command_line(GLib.ApplicationCommandLine cmdline) {
        string[] args = cmdline.get_arguments();

        // Write debug to file
        try {
            var file = File.new_for_path("/tmp/lazycat-command-line-debug.txt");
            var stream = file.create(FileCreateFlags.REPLACE_DESTINATION);
            var data_stream = new DataOutputStream(stream);

            data_stream.put_string("command_line() called with %d arguments\n".printf(args.length));
            for (int i = 0; i < args.length; i++) {
                data_stream.put_string("args[%d] = %s\n".printf(i, args[i]));
            }
        } catch (Error e) {
            stderr.printf("Error writing debug file: %s\n", e.message);
        }

        stderr.printf("DEBUG: command_line() called with %d arguments\n", args.length);
        for (int i = 0; i < args.length; i++) {
            stderr.printf("DEBUG: args[%d] = %s\n", i, args[i]);
        }

        // Parse command line arguments
        bool next_is_directory = false;
        bool next_is_execute = false;

        for (int i = 1; i < args.length; i++) {
            if (next_is_directory) {
                working_directory = args[i];
                stderr.printf("DEBUG: Set working_directory = %s\n", working_directory);
                next_is_directory = false;
            } else if (next_is_execute) {
                // Collect all remaining arguments as command
                launch_commands = new string[args.length - i];
                for (int j = i; j < args.length; j++) {
                    launch_commands[j - i] = args[j];
                }
                stderr.printf("DEBUG: Set launch_commands with %d items\n", launch_commands.length);
                for (int k = 0; k < launch_commands.length; k++) {
                    stderr.printf("DEBUG: launch_commands[%d] = %s\n", k, launch_commands[k]);
                }
                break;
            } else if (args[i] == "--working-directory" || args[i] == "-w") {
                next_is_directory = true;
            } else if (args[i] == "--execute" || args[i] == "-e") {
                next_is_execute = true;
                stderr.printf("DEBUG: Found -e flag\n");
            }
        }

        // Write final state to file
        try {
            var file = File.new_for_path("/tmp/lazycat-command-line-debug.txt");
            var stream = file.append_to(FileCreateFlags.NONE);
            var data_stream = new DataOutputStream(stream);

            data_stream.put_string("\nFinal launch_commands.length = %d\n".printf(launch_commands.length));
            for (int i = 0; i < launch_commands.length; i++) {
                data_stream.put_string("launch_commands[%d] = %s\n".printf(i, launch_commands[i]));
            }
        } catch (Error e) {
            stderr.printf("Error appending debug file: %s\n", e.message);
        }

        stderr.printf("DEBUG: Final launch_commands.length = %d\n", launch_commands.length);
        activate();
        return 0;
    }

    public static int main(string[] args) {
        var app = new LazyCatTerminal();
        return app.run(args);
    }
}
