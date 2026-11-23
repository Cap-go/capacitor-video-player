export interface VideoPlayerPlugin {
  /**
   * Initialize a video player
   *
   */
  initPlayer(options: capVideoPlayerOptions): Promise<capVideoPlayerResult>;
  /**
   * Return if a given playerId is playing
   *
   */
  isPlaying(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Play the current video from a given playerId
   *
   */
  play(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Pause the current video from a given playerId
   *
   */
  pause(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Get the duration of the current video from a given playerId
   *
   */
  getDuration(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Get the current time of the current video from a given playerId
   *
   */
  getCurrentTime(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Set the current time to seek the current video to from a given playerId
   *
   */
  setCurrentTime(options: capVideoTimeOptions): Promise<capVideoPlayerResult>;
  /**
   * Get the volume of the current video from a given playerId
   *
   */
  getVolume(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Set the volume of the current video to from a given playerId
   *
   */
  setVolume(options: capVideoVolumeOptions): Promise<capVideoPlayerResult>;
  /**
   * Get the muted of the current video from a given playerId
   *
   */
  getMuted(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Set the muted of the current video to from a given playerId
   *
   */
  setMuted(options: capVideoMutedOptions): Promise<capVideoPlayerResult>;
  /**
   * Set the rate of the current video from a given playerId
   *
   */
  setRate(options: capVideoRateOptions): Promise<capVideoPlayerResult>;
  /**
   * Get the rate of the current video from a given playerId
   *
   */
  getRate(options: capVideoPlayerIdOptions): Promise<capVideoPlayerResult>;
  /**
   * Stop all players playing
   *
   */
  stopAllPlayers(): Promise<capVideoPlayerResult>;
  /**
   * Show controller
   *
   */
  showController(): Promise<capVideoPlayerResult>;
  /**
   * isControllerIsFullyVisible
   *
   */
  isControllerIsFullyVisible(): Promise<capVideoPlayerResult>;
  /**
   * Exit player
   *
   */
  exitPlayer(): Promise<capVideoPlayerResult>;
  /**
   * Hide the currently presented player UI without stopping playback (native fullscreen).
   *
   * Call `showPlayer()` to show it again.
   */
  hidePlayer(): Promise<capVideoPlayerResult>;
  /**
   * Show again a previously hidden player UI (native fullscreen).
   */
  showPlayer(): Promise<capVideoPlayerResult>;
  /**
   * Get the native Capacitor plugin version.
   * On web, the implementation returns `"web"`.
   *
   * @returns Promise resolving to the plugin version string for this build (`"web"` on web)
   */
  getPluginVersion(): Promise<{ version: string }>;
}
export interface capEchoOptions {
  /**
   *  String to be echoed
   */

  value?: string;
}
export interface capVideoPlayerOptions {
  /**
   * Player mode
   *  - "fullscreen"
   *  - "embedded" (Web only)
   *  - "hybridSlot" (iOS experimental, requires @capgo/capacitor-hybrid-ui)
   */
  mode?: string;
  /**
   * Hybrid-ui slot id when `mode` is `hybridSlot`. Must match `HybridUi.registerSlot`.
   */
  hybridSlotId?: string;
  /**
   * Z-index for the native video slot in the hybrid-ui stack (default 10).
   */
  hybridNativeZIndex?: number;
  /**
   * The url of the video to play
   */
  url?: string;
  /**
   * Optional override URL used when casting to Chromecast (iOS, Android).
   *
   * This lets you cast an alternative rendition/manifest (e.g. MPEG-DASH + Widevine)
   * while keeping the on-device playback URL unchanged (e.g. HLS + FairPlay on iOS).
   */
  chromecastUrl?: string;
  /**
   * The url of subtitle associated with the video
   *
   * Prefer `subtitles` when providing more than one track.
   * Kept for backward compatibility.
   */
  subtitle?: string;
  /**
   * The language of subtitle
   * see https://github.com/libyal/libfwnt/wiki/Language-Code-identifiers
   *
   * Prefer `subtitles` when providing more than one track.
   * Kept for backward compatibility.
   */
  language?: string;
  /**
   * Multiple subtitle tracks (iOS, Android).
   * When provided, takes precedence over `subtitle` / `language`.
   */
  subtitles?: VideoSubtitle[];
  /**
   * Chapter markers for long-form content (iOS, Android).
   * Shown as a chapter list in the native fullscreen player; selecting a chapter seeks to `startTime`.
   */
  chapters?: VideoChapter[];
  /**
   * SubTitle Options
   */
  subtitleOptions?: SubTitleOptions;
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Initial playing rate
   */
  rate?: number;
  /**
   * Exit on VideoEnd (iOS, Android)
   * default: true
   */
  exitOnEnd?: boolean;
  /**
   * Loop on VideoEnd when exitOnEnd false (iOS, Android)
   * default: false
   */
  loopOnEnd?: boolean;
  /**
   * Picture in Picture Enable (iOS, Android)
   * default: true
   */
  pipEnabled?: boolean;
  /**
   * Background Mode Enable (iOS, Android)
   * default: true
   */
  bkmodeEnabled?: boolean;
  /**
   * iOS audio session category behavior (iOS).
   * - "ambient": respects the iPhone silent switch
   * - "playback": ignores the iPhone silent switch
   * - "moviePlayback": playback optimized for video and long-form AirPlay.
   *
   * When omitted, the plugin resolves the category from other options: `"playback"` if
   * `pipEnabled` or `bkmodeEnabled` is true (both default to true), otherwise `"ambient"`.
   */
  audioCategory?: 'ambient' | 'playback' | 'moviePlayback';
  /**
   * Show Controls Enable (iOS, Android)
   * default: true
   */
  showControls?: boolean;
  /**
   * Display Mode ["all", "portrait", "landscape"] (iOS, Android)
   * default: "all"
   */
  displayMode?: string;
  /**
   * Component Tag or DOM Element Tag (React app)
   */
  componentTag?: string;
  /**
   * Player Width (mode "embedded" only)
   */
  width?: number;
  /**
   * Player height (mode "embedded" only)
   */
  height?: number;
  /**
   * Headers for the request (iOS, Android)
   * by Manuel García Marín (https://github.com/PhantomPainX)
   */
  headers?: {
    [key: string]: string;
  };
  /**
   * Title shown in the player and Chromecast metadata (iOS, Android)
   * by Manuel García Marín (https://github.com/PhantomPainX)
   */
  title?: string;
  /**
   * Subtitle shown below the title in the player and Chromecast metadata (iOS, Android)
   * by Manuel García Marín (https://github.com/PhantomPainX)
   */
  smallTitle?: string;
  /**
   * ExoPlayer Progress Bar and Spinner color (Android)
   * by Manuel García Marín (https://github.com/PhantomPainX)
   * Must be a valid hex color code
   * default: #FFFFFF
   */
  accentColor?: string;
  /**
   * Chromecast enable/disable (iOS, Android)
   * iOS requires Google Cast SDK setup and local network Info.plist keys.
   * by Manuel García Marín (https://github.com/PhantomPainX)
   * default: true
   */
  chromecast?: boolean;
  /**
   * Artwork url to be shown in Chromecast player (iOS, Android)
   * by Manuel García Marín (https://github.com/PhantomPainX)
   * default: ""
   */
  artwork?: string;
  /**
   * DRM configuration for protected content (iOS: FairPlay, Android: Widevine)
   *
   * When casting, Widevine's `certificateUrl` (license URL) is also forwarded to Chromecast
   * receivers as `media.customData.laurl`.
   */
  drm?: DrmOptions;
}
export interface capVideoPlayerIdOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
}
export interface capVideoRateOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Rate value
   */
  rate?: number;
}
export interface capVideoVolumeOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Volume value between [0 - 1]
   */
  volume?: number;
}
export interface capVideoTimeOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Video time value you want to seek to
   */
  seektime?: number;
}
export interface capVideoMutedOptions {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Muted value true or false
   */
  muted?: boolean;
}
export interface capVideoListener {
  /**
   * Id of DIV Element parent of the player
   */
  playerId?: string;
  /**
   * Video current time when listener triggered
   */
  currentTime?: number;
}
export interface capExitListener {
  /**
   * Dismiss value true or false
   */
  dismiss?: boolean;
  /**
   * Video current time when listener triggered
   */
  currentTime?: number;
}
export interface capVideoPlayerResult {
  /**
   * result set to true when successful else false
   */
  result?: boolean;
  /**
   * method name
   */
  method?: string;
  /**
   * value returned
   */
  value?: any;
  /**
   * message string
   */
  message?: string;
}
export interface VideoSubtitle {
  /**
   * The url of the subtitle file (vtt, srt, ...)
   */
  subtitle: string;
  /**
   * The language of the subtitle
   * see https://github.com/libyal/libfwnt/wiki/Language-Code-identifiers
   */
  language?: string;
}
export interface VideoChapter {
  /**
   * Chapter title shown in the chapter list
   */
  title: string;
  /**
   * Start time in seconds
   */
  startTime: number;
  /**
   * End time in seconds (optional). Stored for future timeline markers; chapter jumps use `startTime` only in this release.
   */
  endTime?: number;
}
/**
 * Optional styling for on-screen subtitles.
 *
 * On iOS, colors and font size are applied through `AVPlayerItem`
 * `textStyleRules`, which Apple documents for WebVTT only. IMSC1 and other
 * in-manifest timed text formats are not styled through this API.
 * Inline WebVTT cue styles can take precedence over equivalent
 * `subtitleOptions` values; the plugin sets text style rules as a platform
 * fallback, not a guaranteed override of authored cue styling.
 */
export interface SubTitleOptions {
  /**
   * Foreground color in RGBA. On Android, when the plugin applies subtitle
   * styling, omitted values fall back to `rgba(255,255,255,1)`. When
   * `subtitleOptions` is absent, embedded cue colors from the media can
   * override that fallback. On iOS, omitted colors are not set by the plugin;
   * the platform uses the viewer's caption appearance settings instead of fixed
   * plugin defaults.
   */
  foregroundColor?: string;
  /**
   * Background color in RGBA. On Android, when the plugin applies subtitle
   * styling in fullscreen, omitted values fall back to `rgba(0,0,0,1)`. In
   * picture-in-picture, omitted values fall back to transparent when the plugin
   * applies its caption style (for example sidecar subtitles or non-empty
   * `subtitleOptions` that include a color override). An empty
   * `subtitleOptions` object alone does not select that fallback. With
   * font-size-only options, embedded cue styles stay enabled, so authored cue
   * backgrounds can remain visible in PiP. When `subtitleOptions` is absent,
   * embedded cue colors from the media can override the fallback. On iOS,
   * omitted colors are not set by the plugin; the platform uses the viewer's
   * caption appearance settings instead of fixed plugin defaults.
   */
  backgroundColor?: string;
  /**
   * Font size in CSS pixels. On Android, supplied values are rounded to the
   * nearest integer before applying. When omitted on embedded tracks without a
   * sidecar subtitle URI, Android uses `SubtitleView.setUserDefaultTextSize()`
   * (the user's system caption size), not a fixed 16 px size. Sidecar subtitles
   * still use a fixed default size when this property is omitted. On iOS,
   * values map to AVFoundation relative size where 16 equals the system default
   * (100%).
   */
  fontSize?: number;
}
export interface FairPlayDrmOptions {
  /**
   * The URL to fetch the FairPlay certificate
   */
  certificateUrl?: string;
  /**
   * The URL to send the SPC and receive the CKC license (FairPlay license server URL)
   */
  contentKeySpcUrl?: string;
  /**
   * Optional FairPlay asset identifier used when generating the SPC.
   * Defaults to the `skd://` content identifier from the key request.
   */
  assetId?: string;
}
export interface PlayreadyDrmOptions {
  /**
   * The URL to fetch the PlayReady license
   */
  certificateUrl?: string;
}
export interface WidevineDrmOptions {
  /**
   * The URL to fetch the Widevine license
   */
  certificateUrl?: string;
}
export interface DrmOptions {
  /**
   * FairPlay DRM configuration (iOS)
   */
  fairplay?: FairPlayDrmOptions;
  /**
   * PlayReady DRM configuration
   */
  playready?: PlayreadyDrmOptions;
  /**
   * Widevine DRM configuration (Android)
   */
  widevine?: WidevineDrmOptions;
}
