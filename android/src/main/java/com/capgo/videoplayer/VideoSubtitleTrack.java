package com.capgo.videoplayer;

public class VideoSubtitleTrack {

    public final String url;
    public final String language;

    public VideoSubtitleTrack(String url, String language) {
        this.url = url;
        this.language = language != null ? language : "";
    }
}
