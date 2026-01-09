#include <fontconfig/fontconfig.h>
#include <fontconfig/fcfreetype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <regex.h>
#include <glib.h>
#include "font_utils.h"

static int string_rematch(const char* string, const char* pattern) {
    int ret = 0;
    regex_t regex;
    regcomp(&regex, pattern, REG_ICASE);
    if (regexec(&regex, string, 0, NULL, 0) == REG_NOERROR)
        ret = 1;
    regfree(&regex);
    return ret;
}

gchar** list_mono_or_dot_fonts(int* result_length) {
    FcInit();

    FcPattern *pat = FcPatternCreate();
    if (!pat) {
        fprintf(stderr, "Create FcPattern Failed\n");
        *result_length = 0;
        return NULL;
    }

    FcObjectSet *os = FcObjectSetBuild(
        FC_FAMILY,
        FC_FAMILYLANG,
        FC_FULLNAME,
        FC_FULLNAMELANG,
        FC_STYLE,
        FC_FILE,
        FC_LANG,
        FC_SPACING,
        FC_CHARSET,
        NULL);
    if (!os) {
        fprintf(stderr, "Build FcObjectSet Failed\n");
        FcPatternDestroy(pat);
        *result_length = 0;
        return NULL;
    }

    FcFontSet *fs = FcFontList(0, pat, os);
    FcObjectSetDestroy(os);
    FcPatternDestroy(pat);
    if (!fs) {
        fprintf(stderr, "List Font Failed\n");
        *result_length = 0;
        return NULL;
    }

    gchar** fonts = NULL;
    int j;
    int count = 0;
    for (j = 0; j < fs->nfont; j++) {
        char *font_family = (char*) FcPatternFormat(fs->fonts[j], (FcChar8*)"%{family}");
        char *comma = NULL;

        while ((comma = strchr(font_family, ',')) != NULL)
            font_family = comma + 1;

        if (strcmp((char*) FcPatternFormat(fs->fonts[j], (FcChar8*)"%{spacing}"), "100") == 0
            || strcmp((char*) FcPatternFormat(fs->fonts[j], (FcChar8*)"%{spacing}"), "110") == 0
            || string_rematch(font_family, "mono")
            || strcmp(font_family, "YaHei Consolas Hybrid") == 0
            || strcmp(font_family, "Monaco") == 0
            ) {
            fonts = realloc(fonts, (count + 1) * sizeof(gchar*));
            if (fonts == NULL) {
                fprintf(stderr, "Alloc memory at append %d font info failed\n", count + 1);
                *result_length = 0;
                return NULL;
            }

            char *charset = (char*)FcPatternFormat(fs->fonts[j], (FcChar8*)"%{charset}");
            if (charset == NULL || strlen(charset) == 0) {
                free(charset);
                continue;
            }
            free(charset);

            gchar* font = g_strdup(font_family);

            fonts[count] = malloc((strlen(font) + 1) * sizeof(gchar));
            if (fonts[count] == NULL) {
                fprintf(stderr, "Malloc %d failed\n", count + 1);
                free(font);
                *result_length = 0;
                return NULL;
            }

            strcpy(fonts[count], font);

            free(font);

            count++;
        }
    }

    int i, k;
    for (i = 0; i < count; i++) {
        for (j = i + 1; j < count;) {
            if (strcmp(fonts[j], fonts[i]) == 0) {
                for (k = j; k < count; k++) {
                    fonts[k] = fonts[k + 1];
                }
                count--;
            } else
              j++;
        }
    }
    *result_length = count;

    FcFontSetDestroy(fs);

    return fonts;
}

gchar* font_match(gchar* family) {
     FcPattern* pat = FcNameParse((FcChar8*)family);
     if (!pat) {
         return NULL;
     }

     FcConfigSubstitute(NULL, pat, FcMatchPattern);
     FcDefaultSubstitute(pat);

     FcResult result;
     FcPattern* match = FcFontMatch(NULL, pat, &result);
     FcPatternDestroy(pat);
     if (!match) {
         return NULL;
     }

     FcFontSet* fs = FcFontSetCreate();
     if (!fs) {
         FcPatternDestroy(match);
         return NULL;
     }

     FcFontSetAdd(fs, match);
     FcPattern* font = FcPatternFilter(fs->fonts[0], NULL);
     FcChar8* ret = FcPatternFormat(font, (const FcChar8*)"%{family}");

     FcPatternDestroy(font);
     FcFontSetDestroy(fs);
     FcPatternDestroy(match);

     if (!ret) {
         return NULL;
     }

     return (gchar*)ret;
}
