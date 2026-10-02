package com.capgo.videoplayer;

public class VideoChapter {

    public final String title;
    public final double startTimeSeconds;
    public final Double endTimeSeconds;

    public VideoChapter(String title, double startTimeSeconds, Double endTimeSeconds) {
        this.title = title != null ? title : "";
        this.startTimeSeconds = startTimeSeconds;
        this.endTimeSeconds = endTimeSeconds;
    }
}
