package com.capgo.videoplayer;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class SubtitleOptionOverridesTest {

    @Test
    public void fixedTextSizeOnlyWhenFontSizeOrSidecar() {
        assertFalse(SubtitleOptionOverrides.shouldUseFixedTextSize(false, false));
        assertTrue(SubtitleOptionOverrides.shouldUseFixedTextSize(false, true));
        assertTrue(SubtitleOptionOverrides.shouldUseFixedTextSize(true, false));
    }

    @Test
    public void detectsFontSizeAndColorKeys() {
        assertTrue(SubtitleOptionOverrides.hasFontSize(true, 12));
        assertFalse(SubtitleOptionOverrides.hasFontSize(true, 0));
        assertFalse(SubtitleOptionOverrides.hasFontSize(false, 12));
    }
}
