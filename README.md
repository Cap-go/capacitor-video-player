# @capgo/capacitor-video-player
 <a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin"> ➡️ Get Instant updates for your App with Capgo</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin"> Missing a feature? We’ll build the plugin for you 💪</a></h2>
</div>
Native video playback for Capacitor apps

## Documentation

The most complete doc is available here: https://capgo.app/docs/plugins/video-player/

## Install

```bash
npm install @capgo/capacitor-video-player
npx cap sync
```

## API

<docgen-index>

* [`echo(...)`](#echo)
* [`initPlayer(...)`](#initplayer)
* [`isPlaying(...)`](#isplaying)
* [`play(...)`](#play)
* [`pause(...)`](#pause)
* [`getDuration(...)`](#getduration)
* [`getCurrentTime(...)`](#getcurrenttime)
* [`setCurrentTime(...)`](#setcurrenttime)
* [`getVolume(...)`](#getvolume)
* [`setVolume(...)`](#setvolume)
* [`getMuted(...)`](#getmuted)
* [`setMuted(...)`](#setmuted)
* [`setRate(...)`](#setrate)
* [`getRate(...)`](#getrate)
* [`stopAllPlayers()`](#stopallplayers)
* [`showController()`](#showcontroller)
* [`isControllerIsFullyVisible()`](#iscontrollerisfullyvisible)
* [`exitPlayer()`](#exitplayer)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### initPlayer(...)

```typescript
initPlayer(options: capVideoPlayerOptions) => Promise<capVideoPlayerResult>
```

Initialize a video player

| Param         | Type                                                                    |
| ------------- | ----------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeroptions">capVideoPlayerOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### isPlaying(...)

```typescript
isPlaying(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Return if a given playerId is playing

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### play(...)

```typescript
play(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Play the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### pause(...)

```typescript
pause(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Pause the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getDuration(...)

```typescript
getDuration(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get the duration of the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getCurrentTime(...)

```typescript
getCurrentTime(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get the current time of the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### setCurrentTime(...)

```typescript
setCurrentTime(options: capVideoTimeOptions) => Promise<capVideoPlayerResult>
```

Set the current time to seek the current video to from a given playerId

| Param         | Type                                                                |
| ------------- | ------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideotimeoptions">capVideoTimeOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getVolume(...)

```typescript
getVolume(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get the volume of the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### setVolume(...)

```typescript
setVolume(options: capVideoVolumeOptions) => Promise<capVideoPlayerResult>
```

Set the volume of the current video to from a given playerId

| Param         | Type                                                                    |
| ------------- | ----------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideovolumeoptions">capVideoVolumeOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getMuted(...)

```typescript
getMuted(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get the muted of the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### setMuted(...)

```typescript
setMuted(options: capVideoMutedOptions) => Promise<capVideoPlayerResult>
```

Set the muted of the current video to from a given playerId

| Param         | Type                                                                  |
| ------------- | --------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideomutedoptions">capVideoMutedOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### setRate(...)

```typescript
setRate(options: capVideoRateOptions) => Promise<capVideoPlayerResult>
```

Set the rate of the current video from a given playerId

| Param         | Type                                                                |
| ------------- | ------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideorateoptions">capVideoRateOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### getRate(...)

```typescript
getRate(options: capVideoPlayerIdOptions) => Promise<capVideoPlayerResult>
```

Get the rate of the current video from a given playerId

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code><a href="#capvideoplayeridoptions">capVideoPlayerIdOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### stopAllPlayers()

```typescript
stopAllPlayers() => Promise<capVideoPlayerResult>
```

Stop all players playing

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### showController()

```typescript
showController() => Promise<capVideoPlayerResult>
```

Show controller

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### isControllerIsFullyVisible()

```typescript
isControllerIsFullyVisible() => Promise<capVideoPlayerResult>
```

isControllerIsFullyVisible

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### exitPlayer()

```typescript
exitPlayer() => Promise<capVideoPlayerResult>
```

Exit player

**Returns:** <code>Promise&lt;<a href="#capvideoplayerresult">capVideoPlayerResult</a>&gt;</code>

--------------------


### Interfaces


#### capVideoPlayerResult

| Prop          | Type                 | Description                                   |
| ------------- | -------------------- | --------------------------------------------- |
| **`result`**  | <code>boolean</code> | result set to true when successful else false |
| **`method`**  | <code>string</code>  | method name                                   |
| **`value`**   | <code>any</code>     | value returned                                |
| **`message`** | <code>string</code>  | message string                                |


#### capEchoOptions

| Prop        | Type                | Description         |
| ----------- | ------------------- | ------------------- |
| **`value`** | <code>string</code> | String to be echoed |


#### capVideoPlayerOptions

| Prop                  | Type                                                        | Description                                                                                                                                                 |
| --------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`mode`**            | <code>string</code>                                         | Player mode - "fullscreen" - "embedded" (Web only)                                                                                                          |
| **`url`**             | <code>string</code>                                         | The url of the video to play                                                                                                                                |
| **`subtitle`**        | <code>string</code>                                         | The url of subtitle associated with the video                                                                                                               |
| **`language`**        | <code>string</code>                                         | The language of subtitle see https://github.com/libyal/libfwnt/wiki/Language-Code-identifiers                                                               |
| **`subtitleOptions`** | <code><a href="#subtitleoptions">SubTitleOptions</a></code> | SubTitle Options                                                                                                                                            |
| **`playerId`**        | <code>string</code>                                         | Id of DIV Element parent of the player                                                                                                                      |
| **`rate`**            | <code>number</code>                                         | Initial playing rate                                                                                                                                        |
| **`exitOnEnd`**       | <code>boolean</code>                                        | Exit on VideoEnd (iOS, Android) default: true                                                                                                               |
| **`loopOnEnd`**       | <code>boolean</code>                                        | Loop on VideoEnd when exitOnEnd false (iOS, Android) default: false                                                                                         |
| **`pipEnabled`**      | <code>boolean</code>                                        | Picture in Picture Enable (iOS, Android) default: true                                                                                                      |
| **`bkmodeEnabled`**   | <code>boolean</code>                                        | Background Mode Enable (iOS, Android) default: true                                                                                                         |
| **`showControls`**    | <code>boolean</code>                                        | Show Controls Enable (iOS, Android) default: true                                                                                                           |
| **`displayMode`**     | <code>string</code>                                         | Display Mode ["all", "portrait", "landscape"] (iOS, Android) default: "all"                                                                                 |
| **`componentTag`**    | <code>string</code>                                         | Component Tag or DOM Element Tag (React app)                                                                                                                |
| **`width`**           | <code>number</code>                                         | Player Width (mode "embedded" only)                                                                                                                         |
| **`height`**          | <code>number</code>                                         | Player height (mode "embedded" only)                                                                                                                        |
| **`headers`**         | <code>{ [key: string]: string; }</code>                     | Headers for the request (iOS, Android) by Manuel García Marín (https://github.com/PhantomPainX)                                                             |
| **`title`**           | <code>string</code>                                         | Title shown in the player (Android) by Manuel García Marín (https://github.com/PhantomPainX)                                                                |
| **`smallTitle`**      | <code>string</code>                                         | Subtitle shown below the title in the player (Android) by Manuel García Marín (https://github.com/PhantomPainX)                                             |
| **`accentColor`**     | <code>string</code>                                         | ExoPlayer Progress Bar and Spinner color (Android) by Manuel García Marín (https://github.com/PhantomPainX) Must be a valid hex color code default: #FFFFFF |
| **`chromecast`**      | <code>boolean</code>                                        | Chromecast enable/disable (Android) by Manuel García Marín (https://github.com/PhantomPainX) default: true                                                  |
| **`artwork`**         | <code>string</code>                                         | Artwork url to be shown in Chromecast player by Manuel García Marín (https://github.com/PhantomPainX) default: ""                                           |


#### SubTitleOptions

| Prop                  | Type                | Description                                           |
| --------------------- | ------------------- | ----------------------------------------------------- |
| **`foregroundColor`** | <code>string</code> | Foreground Color in RGBA (default rgba(255,255,255,1) |
| **`backgroundColor`** | <code>string</code> | Background Color in RGBA (default rgba(0,0,0,1)       |
| **`fontSize`**        | <code>number</code> | Font Size in pixels (default 16)                      |

| Method               | Signature                                    | Description                             |
| -------------------- | -------------------------------------------- | --------------------------------------- |
| **getPluginVersion** | () =&gt; Promise&lt;{ version: string; }&gt; | Get the native Capacitor plugin version |


#### capVideoPlayerIdOptions

| Prop           | Type                | Description                            |
| -------------- | ------------------- | -------------------------------------- |
| **`playerId`** | <code>string</code> | Id of DIV Element parent of the player |


#### capVideoTimeOptions

| Prop           | Type                | Description                            |
| -------------- | ------------------- | -------------------------------------- |
| **`playerId`** | <code>string</code> | Id of DIV Element parent of the player |
| **`seektime`** | <code>number</code> | Video time value you want to seek to   |


#### capVideoVolumeOptions

| Prop           | Type                | Description                            |
| -------------- | ------------------- | -------------------------------------- |
| **`playerId`** | <code>string</code> | Id of DIV Element parent of the player |
| **`volume`**   | <code>number</code> | Volume value between [0 - 1]           |


#### capVideoMutedOptions

| Prop           | Type                 | Description                            |
| -------------- | -------------------- | -------------------------------------- |
| **`playerId`** | <code>string</code>  | Id of DIV Element parent of the player |
| **`muted`**    | <code>boolean</code> | Muted value true or false              |


#### capVideoRateOptions

| Prop           | Type                | Description                            |
| -------------- | ------------------- | -------------------------------------- |
| **`playerId`** | <code>string</code> | Id of DIV Element parent of the player |
| **`rate`**     | <code>number</code> | Rate value                             |

</docgen-api>
