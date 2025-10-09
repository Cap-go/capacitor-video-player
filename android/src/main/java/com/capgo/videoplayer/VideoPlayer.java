package com.capgo.videoplayer;

import android.content.Context;
import com.getcapacitor.JSObject;
import com.capgo.videoplayer.PickerVideo.PickerVideoFragment;

public class VideoPlayer {

    private final Context context;

    VideoPlayer(Context context) {
        this.context = context;
    }

    public String echo(String value) {
        return value;
    }

    public FullscreenExoPlayerFragment createFullScreenFragment(
        String videoPath,
        Float videoRate,
        Boolean exitOnEnd,
        Boolean loopOnEnd,
        Boolean pipEnabled,
        Boolean bkModeEnabled,
        Boolean showControls,
        String displayMode,
        String subTitle,
        String language,
        JSObject subTitleOptions,
        JSObject headers,
        String title,
        String smallTitle,
        String accentColor,
        Boolean chromecast,
        String artwork,
        Boolean isTV,
        String playerId,
        Boolean isInternal,
        Long videoId
    ) {
        FullscreenExoPlayerFragment fsFragment = new FullscreenExoPlayerFragment();

        fsFragment.videoPath = videoPath;
        fsFragment.videoRate = videoRate;
        fsFragment.exitOnEnd = exitOnEnd;
        fsFragment.loopOnEnd = loopOnEnd;
        fsFragment.pipEnabled = pipEnabled;
        fsFragment.bkModeEnabled = bkModeEnabled;
        fsFragment.showControls = showControls;
        fsFragment.displayMode = displayMode;
        fsFragment.subTitle = subTitle;
        fsFragment.language = language;
        fsFragment.subTitleOptions = subTitleOptions;
        fsFragment.headers = headers;
        fsFragment.title = title;
        fsFragment.smallTitle = smallTitle;
        fsFragment.accentColor = accentColor;
        fsFragment.chromecast = chromecast;
        fsFragment.artwork = artwork;
        fsFragment.isTV = isTV;
        fsFragment.playerId = playerId;
        fsFragment.isInternal = isInternal;
        fsFragment.videoId = videoId;
        return fsFragment;
    }

    public PickerVideoFragment createPickerVideoFragment() {
        return new PickerVideoFragment();
    }
}
