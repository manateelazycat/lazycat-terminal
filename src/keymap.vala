/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 * -*- coding: utf-8 -*-
 *
 * Copyright (C) 2011 ~ 2018 Deepin, Inc.
 *               2011 ~ 2018 Wang Yong
 *
 * Author:     Wang Yong <wangyong@deepin.com>
 * Maintainer: Wang Yong <wangyong@deepin.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;

namespace Keymap {
    // GTK4 compatible version - takes keyval and state directly
    public string get_keyevent_name(uint keyval, Gdk.ModifierType state) {
        var key_modifiers = get_key_modifiers(state);
        var key_name = get_key_name(keyval);

        // Empty key name means it's a modifier key only
        if (key_name == "") {
            return "";
        }

        if (key_modifiers.length == 0) {
            return key_name;
        } else {
            var name = "";
            foreach (string modifier in key_modifiers) {
                name += modifier + " + ";
            }
            name += key_name;

            return name;
        }
    }

    public string[] get_key_modifiers(Gdk.ModifierType state) {
        string[] modifiers = {};

        if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
            modifiers += "Ctrl";
        }

        if ((state & Gdk.ModifierType.SUPER_MASK) != 0) {
            modifiers += "Super";
        }

        if ((state & Gdk.ModifierType.HYPER_MASK) != 0) {
            modifiers += "Hyper";
        }

        if ((state & Gdk.ModifierType.ALT_MASK) != 0) {
            modifiers += "Alt";
        }

        if ((state & Gdk.ModifierType.SHIFT_MASK) != 0) {
            modifiers += "Shift";
        }

        return modifiers;
    }

    public string get_key_name(uint keyval) {
        // First, get the key name from GDK
        var keyname = Gdk.keyval_name(keyval);

        // Gdk.keyval_name will return null when user's hardware got KEY_UNKNOWN from hardware.
        // So, we need return empty string to protect program won't crash later.
        if (keyname == null) {
            return "";
        }

        // Filter out modifier keys
        if (keyname == "Control_L" || keyname == "Control_R" ||
            keyname == "Shift_L" || keyname == "Shift_R" ||
            keyname == "Alt_L" || keyname == "Alt_R" ||
            keyname == "Super_L" || keyname == "Super_R" ||
            keyname == "Hyper_L" || keyname == "Hyper_R") {
            return "";
        }

        // Handle special cases
        if (keyname == "ISO_Left_Tab") {
            return "Tab";
        }

        // Map symbol key names to their actual symbols for intuitive config
        switch (keyname) {
            case "equal":
                return "=";
            case "minus":
                return "-";
            case "plus":
                return "+";
            case "underscore":
                return "_";
            case "bracketleft":
                return "[";
            case "bracketright":
                return "]";
            case "braceleft":
                return "{";
            case "braceright":
                return "}";
            case "semicolon":
                return ";";
            case "colon":
                return ":";
            case "apostrophe":
                return "'";
            case "quotedbl":
                return "\"";
            case "comma":
                return ",";
            case "period":
                return ".";
            case "slash":
                return "/";
            case "backslash":
                return "\\";
            case "grave":
                return "`";
            case "asciitilde":
                return "~";
            case "exclam":
                return "!";
            case "at":
                return "@";
            case "numbersign":
                return "#";
            case "dollar":
                return "$";
            case "percent":
                return "%";
            case "asciicircum":
                return "^";
            case "ampersand":
                return "&";
            case "asterisk":
                return "*";
            case "parenleft":
                return "(";
            case "parenright":
                return ")";
            case "less":
                return "<";
            case "greater":
                return ">";
            case "question":
                return "?";
            case "bar":
                return "|";
        }

        // For single character keys (usually letters), convert to lowercase
        // This handles both 'a' and 'A' -> 'a'
        if (keyname.length == 1) {
            return keyname.down();
        }

        // For other keys, return as-is (Tab, Enter, F1, etc.)
        return keyname;
    }
}
