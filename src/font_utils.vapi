[CCode (cheader_filename = "font_utils.h")]
namespace FontUtils {
    [CCode (cname = "list_mono_or_dot_fonts", array_length = false, array_null_terminated = false)]
    public string[]? list_mono_or_dot_fonts(out int result_length);

    [CCode (cname = "font_match")]
    public string? font_match(string family);
}
