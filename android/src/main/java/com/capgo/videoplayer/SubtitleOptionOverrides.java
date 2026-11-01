package com.capgo.videoplayer;

import java.util.Arrays;
import java.util.List;
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

    static Integer parseRgbaColor(String rgbaColor) {
        if (rgbaColor == null || rgbaColor.length() < 5 || !rgbaColor.regionMatches(true, 0, "rgba", 0, 4)) {
            return null;
        }
        int open = rgbaColor.indexOf('(');
        int close = rgbaColor.indexOf(')');
        if (open < 0 || close <= open) {
            return null;
        }
        String inner = rgbaColor.substring(open + 1, close);
        List<String> colors = Arrays.asList(inner.split(","));
        if (colors.size() != 4) {
            return null;
        }
        try {
            int red = Integer.parseInt(colors.get(0).trim());
            int green = Integer.parseInt(colors.get(1).trim());
            int blue = Integer.parseInt(colors.get(2).trim());
            float alpha = Float.parseFloat(colors.get(3).trim());
            if (!Float.isFinite(alpha) || alpha < 0f || alpha > 1f) {
                return null;
            }
            if (red < 0 || red > 255 || green < 0 || green > 255 || blue < 0 || blue > 255) {
                return null;
            }
            int alphaInt = Math.round(alpha * 255f) & 0xff;
            return (alphaInt << 24) | ((red & 0xff) << 16) | ((green & 0xff) << 8) | (blue & 0xff);
        } catch (NumberFormatException exception) {
            return null;
        }
    }
}
