package com.capgo.videoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.json.JSONObject;
import org.junit.Test;

public class SubtitleOptionOverridesTest {

    @Test
    public void fixedTextSizeOnlyWhenFontSizeOrSidecar() {
        assertFalse(SubtitleOptionOverrides.shouldUseFixedTextSize(false, false));
        assertTrue(SubtitleOptionOverrides.shouldUseFixedTextSize(false, true));
        assertTrue(SubtitleOptionOverrides.shouldUseFixedTextSize(true, false));
    }

    @Test
    public void detectsFontSizeAndColorKeys() throws Exception {
        assertTrue(SubtitleOptionOverrides.hasFontSize(true, 12));
        assertFalse(SubtitleOptionOverrides.hasFontSize(true, 0));
        assertFalse(SubtitleOptionOverrides.hasFontSize(false, 12));
        JSONObject foregroundOnly = new JSONObject();
        foregroundOnly.put("foregroundColor", "rgba(1,2,3,1)");
        assertTrue(SubtitleOptionOverrides.hasColor(foregroundOnly));
        assertFalse(SubtitleOptionOverrides.hasBackgroundColor(foregroundOnly));
        JSONObject withBackground = new JSONObject();
        withBackground.put("backgroundColor", "rgba(0,0,0,1)");
        assertTrue(SubtitleOptionOverrides.hasBackgroundColor(withBackground));
    }

    @Test
    public void parseRgbaColorAcceptsValidValuesAndRejectsMalformedInput() {
        assertEquals(Integer.valueOf(0xffffffff), SubtitleOptionOverrides.parseRgbaColor("rgba(255,255,255,1)"));
        assertEquals(Integer.valueOf(0x800a141e), SubtitleOptionOverrides.parseRgbaColor("rgba(10,20,30,0.5)"));
        assertNull(SubtitleOptionOverrides.parseRgbaColor("rgba(255,255,255,NaN)"));
        assertNull(SubtitleOptionOverrides.parseRgbaColor("rgba(256,0,0,1)"));
        assertNull(SubtitleOptionOverrides.parseRgbaColor("rgba(255,255,255,1"));
        assertNull(SubtitleOptionOverrides.parseRgbaColor("not-a-color"));
    }
}
