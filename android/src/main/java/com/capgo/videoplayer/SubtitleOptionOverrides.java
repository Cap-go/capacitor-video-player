package com.capgo.videoplayer;

import org.json.JSONObject;

final class SubtitleOptionOverrides {

    private SubtitleOptionOverrides() {}

    static boolean hasAny(JSONObject options) {
        return options != null && options.length() > 0;
    }

    static boolean hasFontSize(JSONObject options) {
        return hasFontSize(options != null && options.has("fontSize"), options != null ? options.optDouble("fontSize", 16) : 16);
    }

    static boolean hasFontSize(boolean hasFontSizeKey, double fontSizeValue) {
        if (!hasFontSizeKey) {
            return false;
        }
        return Math.round(fontSizeValue) > 0;
    }

    static boolean hasColor(JSONObject options) {
        if (options == null) {
            return false;
        }
        return options.has("foregroundColor") || options.has("backgroundColor");
    }

    static boolean shouldUseFixedTextSize(JSONObject options, boolean hasSidecarUri) {
        return hasFontSize(options) || hasSidecarUri;
    }

    static boolean shouldUseFixedTextSize(boolean hasFontSizeOverride, boolean hasSidecarUri) {
        return hasFontSizeOverride || hasSidecarUri;
    }
}
