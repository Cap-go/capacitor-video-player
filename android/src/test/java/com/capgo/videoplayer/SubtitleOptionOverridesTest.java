package com.capgo.videoplayer;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.json.JSONObject;
import org.junit.Test;

public class SubtitleOptionOverridesTest {

    @Test
    public void fixedTextSizeOnlyWhenFontSizeOrSidecar() throws Exception {
        assertFalse(SubtitleOptionOverrides.shouldUseFixedTextSize(null, false));
        assertTrue(SubtitleOptionOverrides.shouldUseFixedTextSize(null, true));
        assertTrue(SubtitleOptionOverrides.shouldUseFixedTextSize(new JSONObject("{\"fontSize\":18}"), false));
        assertFalse(SubtitleOptionOverrides.shouldUseFixedTextSize(new JSONObject("{\"foregroundColor\":\"rgba(1,1,1,1)\"}"), false));
    }

    @Test
    public void detectsFontSizeAndColorKeys() throws Exception {
        assertTrue(SubtitleOptionOverrides.hasFontSize(new JSONObject("{\"fontSize\":12}")));
        assertFalse(SubtitleOptionOverrides.hasFontSize(new JSONObject("{\"fontSize\":0}")));
        assertTrue(SubtitleOptionOverrides.hasColor(new JSONObject("{\"foregroundColor\":\"rgba(1,1,1,1)\"}")));
        assertFalse(SubtitleOptionOverrides.hasColor(new JSONObject("{\"fontSize\":12}")));
    }
}
