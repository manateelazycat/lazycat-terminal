#ifndef FONT_UTILS_H
#define FONT_UTILS_H

#include <glib.h>

gchar** list_mono_or_dot_fonts(int* result_length);
gchar* font_match(gchar* family);

#endif /* FONT_UTILS_H */
