package com.capgo.videoplayer;

import org.json.JSONObject;

final class SubtitleOptionOverrides {

    private SubtitleOptionOverrides() {}

    static boolean hasAny(JSONObject options) {
        return options != null && options.length() > 0;
    }

    static boolean hasFontSize(JSONObject options) {
        if (options == null || !options.has("fontSize")) {
            return false;
        }
        return Math.round(options.optDouble("fontSize", 16)) > 0;
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
}
