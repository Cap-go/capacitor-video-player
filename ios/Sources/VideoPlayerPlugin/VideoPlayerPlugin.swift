import Foundation
import Capacitor
import AVKit

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(VideoPlayerPlugin)
public class VideoPlayerPlugin: CAPPlugin, CAPBridgedPlugin {
    private let pluginVersion: String = "8.3.3"
    public let identifier = "VideoPlayerPlugin"
    public let jsName = "VideoPlayer"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "initPlayer", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isPlaying", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "play", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pause", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getDuration", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getCurrentTime", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setCurrentTime", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getVolume", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setVolume", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getMuted", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setMuted", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setRate", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getRate", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopAllPlayers", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showController", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isControllerIsFullyVisible", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "exitPlayer", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hidePlayer", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showPlayer", returnType: CAPPluginReturnPromise)
    ]

    private var videoPlayers: [String: FullscreenVideoPlayer] = [:]
    private var hybridSlotPlayers: [String: HybridSlotVideoPlayer] = [:]
    private var currentPlayerId: String?

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": self.pluginVersion])
    }
}

extension VideoPlayerPlugin {
    @objc func initPlayer(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "initPlayer",
                "message": "Must provide a PlayerId"
            ])
            return
        }

        guard let url = call.getString("url") else {
            call.resolve([
                "result": false,
                "method": "initPlayer",
                "message": "Must provide an url"
            ])
            return
        }

        let mode = call.getString("mode") ?? "fullscreen"
        if mode == "hybridSlot" {
            initHybridSlotPlayer(call, playerId: playerId)
            return
        }
        guard mode == "fullscreen" else {
            call.resolve([
                "result": false,
                "method": "initPlayer",
                "message": "Only fullscreen or hybridSlot mode is supported on iOS"
            ])
            return
        }

        let rate = call.getFloat("rate") ?? 1.0
        let exitOnEnd = call.getBool("exitOnEnd") ?? true
        let loopOnEnd = call.getBool("loopOnEnd") ?? false
        let pipEnabled = call.getBool("pipEnabled") ?? true
        let bkmodeEnabled = call.getBool("bkmodeEnabled") ?? true
        let showControls = call.getBool("showControls") ?? true
        let chromecast = call.getBool("chromecast") ?? true
        let title = call.getString("title")
        let smallTitle = call.getString("smallTitle")
        let artwork = call.getString("artwork")
        let chromecastUrl = call.getString("chromecastUrl")
        let audioCategory = call.getString("audioCategory")
        let subtitleTracks = Self.parseSubtitleTracks(from: call)
        let subtitleStyleOptions = Self.parseSubtitleStyleOptions(from: call)
        let chapters = Self.parseChapters(from: call)
        let drmOptions = Self.parseDrmOptions(from: call)

        // Create video player
        let player = FullscreenVideoPlayer(
            playerId: playerId,
            url: url,
            rate: rate,
            exitOnEnd: exitOnEnd,
            loopOnEnd: loopOnEnd,
            pipEnabled: pipEnabled,
            bkmodeEnabled: bkmodeEnabled,
            showControls: showControls,
            chromecast: chromecast,
            chromecastUrl: chromecastUrl,
            title: title,
            smallTitle: smallTitle,
            artwork: artwork,
            subtitleTracks: subtitleTracks,
            subtitleStyleOptions: subtitleStyleOptions,
            chapters: chapters,
            fairplayCertificateUrl: drmOptions.fairplayCertificateUrl,
            fairplayContentKeySpcUrl: drmOptions.fairplayContentKeySpcUrl,
            fairplayAssetId: drmOptions.fairplayAssetId,
            widevineLicenseUrl: drmOptions.widevineLicenseUrl,
            audioCategory: audioCategory
        )

        // Present player
        DispatchQueue.main.async {
            guard let viewController = self.bridge?.viewController else {
                call.resolve([
                    "result": false,
                    "method": "initPlayer",
                    "message": "Unable to get view controller"
                ])
                return
            }

            player.setupPlayer {
                self.configureCallbacks(for: player, playerId: playerId)

                // Store player
                self.videoPlayers[playerId] = player
                self.currentPlayerId = playerId

                player.present(on: viewController) {
                    call.resolve([
                        "result": true,
                        "method": "initPlayer",
                        "value": playerId
                    ])
                }
            }
        }
    }

    private static func parseSubtitleStyleOptions(from call: CAPPluginCall) -> SubtitleStyleOptions? {
        guard let options = call.getObject("subtitleOptions") else {
            return nil
        }

        let fontSize: Double?
        if let number = options["fontSize"] as? NSNumber {
            fontSize = number.doubleValue
        } else {
            fontSize = nil
        }

        return SubtitleStyleOptions(
            foregroundColor: options["foregroundColor"] as? String,
            backgroundColor: options["backgroundColor"] as? String,
            fontSize: fontSize
        )
    }

    private static func parseChapters(from call: CAPPluginCall) -> [VideoChapter] {
        guard let entries = call.getArray("chapters") else {
            return []
        }
        var parsed: [VideoChapter] = []
        for (index, entry) in entries.enumerated() {
            guard let jsObject = entry as? JSObject else {
                print("VideoPlayerPlugin: skipping invalid chapter at index \(index)")
                continue
            }
            var dictionary: [String: Any] = [:]
            for (key, value) in jsObject {
                dictionary[key] = value
            }
            if let chapter = VideoChapter(dictionary: dictionary) {
                parsed.append(chapter)
            } else {
                print("VideoPlayerPlugin: skipping invalid chapter at index \(index)")
            }
        }
        return parsed.sorted { $0.startTime < $1.startTime }
    }

    private static func parseSubtitleTracks(from call: CAPPluginCall) -> [VideoSubtitleTrack] {
        let subtitlesArray = call.getArray("subtitles", JSObject.self)?.map { entry -> [String: Any] in
            var dict: [String: Any] = [:]
            if let subtitleUrl = entry["subtitle"] as? String {
                dict["subtitle"] = subtitleUrl
            }
            if let lang = entry["language"] as? String {
                dict["language"] = lang
            }
            return dict
        }
        return VideoSubtitleTrackParser.parse(
            from: subtitlesArray,
            legacySubtitle: call.getString("subtitle"),
            legacyLanguage: call.getString("language")
        )
    }

    private struct ParsedDrmOptions {
        let fairplayCertificateUrl: String?
        let fairplayContentKeySpcUrl: String?
        let fairplayAssetId: String?
        let widevineLicenseUrl: String?
    }

    private static func parseDrmOptions(from call: CAPPluginCall) -> ParsedDrmOptions {
        let drm = call.getObject("drm")
        let fairplay = drm?["fairplay"] as? [String: Any]
        let widevine = drm?["widevine"] as? [String: Any]
        return ParsedDrmOptions(
            fairplayCertificateUrl: fairplay?["certificateUrl"] as? String,
            fairplayContentKeySpcUrl: fairplay?["contentKeySpcUrl"] as? String,
            fairplayAssetId: fairplay?["assetId"] as? String,
            widevineLicenseUrl: widevine?["certificateUrl"] as? String
        )
    }

    private func initHybridSlotPlayer(_ call: CAPPluginCall, playerId: String) {
        guard let hybridSlotId = call.getString("hybridSlotId") else {
            call.resolve([
                "result": false,
                "method": "initPlayer",
                "message": "hybridSlot mode requires hybridSlotId"
            ])
            return
        }
        guard let url = call.getString("url") else {
            call.resolve([
                "result": false,
                "method": "initPlayer",
                "message": "Must provide an url"
            ])
            return
        }

        hybridSlotPlayers[playerId]?.teardown()
        hybridSlotPlayers.removeValue(forKey: playerId)
        let rate = call.getFloat("rate") ?? 1.0
        let nativeZIndex = call.getInt("hybridNativeZIndex") ?? 10
        let slotPlayer = HybridSlotVideoPlayer(playerId: playerId, hybridSlotId: hybridSlotId)
        configureHybridCallbacks(for: slotPlayer, playerId: playerId)

        DispatchQueue.main.async {
            slotPlayer.setup(urlString: url, autoplayRate: rate) { [weak self] ok in
                guard let self else { return }
                guard ok else {
                    call.resolve([
                        "result": false,
                        "method": "initPlayer",
                        "message": "Unable to open video url"
                    ])
                    return
                }
                slotPlayer.publishToHybridSlot(nativeZIndex: nativeZIndex) { claimed in
                    guard claimed else {
                        slotPlayer.teardown()
                        call.resolve([
                            "result": false,
                            "method": "initPlayer",
                            "message": "hybridSlot requires @capgo/capacitor-hybrid-ui native host"
                        ])
                        return
                    }
                    self.hybridSlotPlayers[playerId] = slotPlayer
                    call.resolve([
                        "result": true,
                        "method": "initPlayer",
                        "value": playerId
                    ])
                }
            }
        }
    }

    private func configureHybridCallbacks(for player: HybridSlotVideoPlayer, playerId: String) {
        player.setOnPlay { [weak self, weak player] in
            guard let self, let player else { return }
            self.notifyListeners("jeepCapVideoPlayerPlay", data: [
                "fromPlayerId": playerId,
                "currentTime": player.getCurrentTime()
            ])
        }
        player.setOnPause { [weak self, weak player] in
            guard let self, let player else { return }
            self.notifyListeners("jeepCapVideoPlayerPause", data: [
                "fromPlayerId": playerId,
                "currentTime": player.getCurrentTime()
            ])
        }
        player.setOnReady { [weak self] in
            self?.notifyListeners("jeepCapVideoPlayerReady", data: [
                "fromPlayerId": playerId,
                "currentTime": 0
            ])
        }
        player.setOnEnd { [weak self, weak player] in
            guard let self, let player else { return }
            self.notifyListeners("jeepCapVideoPlayerEnded", data: [
                "fromPlayerId": playerId,
                "currentTime": player.getCurrentTime()
            ])
        }
        player.setOnNativeTap { [weak self] in
            self?.notifyListeners("jeepCapVideoPlayerNativeTap", data: [
                "fromPlayerId": playerId
            ])
        }
    }

    private func configureCallbacks(for player: FullscreenVideoPlayer, playerId: String) {
        player.setOnPlay { [weak self] in
            self?.notifyListeners("jeepCapVideoPlayerPlay", data: [
                "fromPlayerId": playerId,
                "currentTime": player.getCurrentTime()
            ])
        }

        player.setOnPause { [weak self] in
            self?.notifyListeners("jeepCapVideoPlayerPause", data: [
                "fromPlayerId": playerId,
                "currentTime": player.getCurrentTime()
            ])
        }

        player.setOnReady { [weak self] in
            self?.notifyListeners("jeepCapVideoPlayerReady", data: [
                "fromPlayerId": playerId,
                "currentTime": 0
            ])
        }

        player.setOnEnd { [weak self] in
            self?.notifyListeners("jeepCapVideoPlayerEnded", data: [
                "fromPlayerId": playerId,
                "currentTime": player.getCurrentTime()
            ])
        }

        player.setOnExit { [weak self] currentTime in
            self?.videoPlayers.removeValue(forKey: playerId)
            if self?.currentPlayerId == playerId {
                self?.currentPlayerId = nil
            }
            self?.notifyListeners("jeepCapVideoPlayerExit", data: [
                "dismiss": true,
                "currentTime": currentTime
            ])
        }
    }

    @objc func isPlaying(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "isPlaying",
                "message": "Player not found"
            ])
            return
        }
        if let player = videoPlayers[playerId] {
            call.resolve([
                "result": true,
                "method": "isPlaying",
                "value": player.isPlaying()
            ])
            return
        }
        if let hybrid = hybridSlotPlayers[playerId] {
            call.resolve([
                "result": true,
                "method": "isPlaying",
                "value": hybrid.isPlaying()
            ])
            return
        }
        call.resolve([
            "result": false,
            "method": "isPlaying",
            "message": "Player not found"
        ])
    }

    @objc func play(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "play",
                "message": "Player not found"
            ])
            return
        }
        if let player = videoPlayers[playerId] {
            player.play()
            call.resolve([
                "result": true,
                "method": "play",
                "value": true
            ])
            return
        }
        if let hybrid = hybridSlotPlayers[playerId] {
            hybrid.play()
            call.resolve([
                "result": true,
                "method": "play",
                "value": true
            ])
            return
        }
        call.resolve([
            "result": false,
            "method": "play",
            "message": "Player not found"
        ])
    }

    @objc func pause(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "pause",
                "message": "Player not found"
            ])
            return
        }
        if let player = videoPlayers[playerId] {
            player.pause()
            call.resolve([
                "result": true,
                "method": "pause",
                "value": true
            ])
            return
        }
        if let hybrid = hybridSlotPlayers[playerId] {
            hybrid.pause()
            call.resolve([
                "result": true,
                "method": "pause",
                "value": true
            ])
            return
        }
        call.resolve([
            "result": false,
            "method": "pause",
            "message": "Player not found"
        ])
    }

    @objc func getDuration(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "getDuration",
                "message": "Player not found"
            ])
            return
        }
        if let player = videoPlayers[playerId] {
            let duration = player.getDuration()
            call.resolve([
                "result": true,
                "method": "getDuration",
                "value": duration
            ])
            return
        }
        if let hybrid = hybridSlotPlayers[playerId] {
            call.resolve([
                "result": true,
                "method": "getDuration",
                "value": hybrid.getDuration()
            ])
            return
        }
        call.resolve([
            "result": false,
            "method": "getDuration",
            "message": "Player not found"
        ])
    }

    @objc func getCurrentTime(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "getCurrentTime",
                "message": "Player not found"
            ])
            return
        }
        if let player = videoPlayers[playerId] {
            let currentTime = player.getCurrentTime()
            call.resolve([
                "result": true,
                "method": "getCurrentTime",
                "value": currentTime
            ])
            return
        }
        if let hybrid = hybridSlotPlayers[playerId] {
            call.resolve([
                "result": true,
                "method": "getCurrentTime",
                "value": hybrid.getCurrentTime()
            ])
            return
        }
        call.resolve([
            "result": false,
            "method": "getCurrentTime",
            "message": "Player not found"
        ])
    }

    @objc func setCurrentTime(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "setCurrentTime",
                "message": "Player not found"
            ])
            return
        }
        guard let seektime = call.getDouble("seektime") else {
            call.resolve([
                "result": false,
                "method": "setCurrentTime",
                "message": "Must provide a time in seconds"
            ])
            return
        }
        if let player = videoPlayers[playerId] {
            player.setCurrentTime(seektime)
            call.resolve([
                "result": true,
                "method": "setCurrentTime",
                "value": seektime
            ])
            return
        }
        if let hybrid = hybridSlotPlayers[playerId] {
            hybrid.setCurrentTime(seektime)
            call.resolve([
                "result": true,
                "method": "setCurrentTime",
                "value": seektime
            ])
            return
        }
        call.resolve([
            "result": false,
            "method": "setCurrentTime",
            "message": "Player not found"
        ])
    }

    @objc func getVolume(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "getVolume",
                "message": "Player not found"
            ])
            return
        }
        if let player = videoPlayers[playerId] {
            let volume = player.getVolume()
            call.resolve([
                "result": true,
                "method": "getVolume",
                "value": volume
            ])
            return
        }
        if let hybrid = hybridSlotPlayers[playerId] {
            call.resolve([
                "result": true,
                "method": "getVolume",
                "value": hybrid.getVolume()
            ])
            return
        }
        call.resolve([
            "result": false,
            "method": "getVolume",
            "message": "Player not found"
        ])
    }

    @objc func setVolume(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "setVolume",
                "message": "Player not found"
            ])
            return
        }

        guard let volume = call.getFloat("volume") else {
            call.resolve([
                "result": false,
                "method": "setVolume",
                "message": "Must provide a volume value"
            ])
            return
        }

        if let player = videoPlayers[playerId] {
            player.setVolume(volume)
        } else if let hybrid = hybridSlotPlayers[playerId] {
            hybrid.setVolume(volume)
        } else {
            call.resolve([
                "result": false,
                "method": "setVolume",
                "message": "Player not found"
            ])
            return
        }
        call.resolve([
            "result": true,
            "method": "setVolume",
            "value": volume
        ])
    }

    @objc func getMuted(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "getMuted",
                "message": "Player not found"
            ])
            return
        }
        if let player = videoPlayers[playerId] {
            let muted = player.getMuted()
            call.resolve([
                "result": true,
                "method": "getMuted",
                "value": muted
            ])
            return
        }
        if let hybrid = hybridSlotPlayers[playerId] {
            call.resolve([
                "result": true,
                "method": "getMuted",
                "value": hybrid.getMuted()
            ])
            return
        }
        call.resolve([
            "result": false,
            "method": "getMuted",
            "message": "Player not found"
        ])
    }

    @objc func setMuted(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "setMuted",
                "message": "Player not found"
            ])
            return
        }

        guard let muted = call.getBool("muted") else {
            call.resolve([
                "result": false,
                "method": "setMuted",
                "message": "Must provide a boolean value"
            ])
            return
        }

        if let player = videoPlayers[playerId] {
            player.setMuted(muted)
        } else if let hybrid = hybridSlotPlayers[playerId] {
            hybrid.setMuted(muted)
        } else {
            call.resolve([
                "result": false,
                "method": "setMuted",
                "message": "Player not found"
            ])
            return
        }
        call.resolve([
            "result": true,
            "method": "setMuted",
            "value": muted
        ])
    }

    @objc func getRate(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "getRate",
                "message": "Player not found"
            ])
            return
        }
        if let player = videoPlayers[playerId] {
            let rate = player.getRate()
            call.resolve([
                "result": true,
                "method": "getRate",
                "value": rate
            ])
            return
        }
        if let hybrid = hybridSlotPlayers[playerId] {
            call.resolve([
                "result": true,
                "method": "getRate",
                "value": hybrid.getRate()
            ])
            return
        }
        call.resolve([
            "result": false,
            "method": "getRate",
            "message": "Player not found"
        ])
    }

    @objc func setRate(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId") else {
            call.resolve([
                "result": false,
                "method": "setRate",
                "message": "Player not found"
            ])
            return
        }

        guard let rate = call.getFloat("rate") else {
            call.resolve([
                "result": false,
                "method": "setRate",
                "message": "Must provide a rate value"
            ])
            return
        }

        if let player = videoPlayers[playerId] {
            player.setRate(rate)
        } else if let hybrid = hybridSlotPlayers[playerId] {
            hybrid.setRate(rate)
        } else {
            call.resolve([
                "result": false,
                "method": "setRate",
                "message": "Player not found"
            ])
            return
        }
        call.resolve([
            "result": true,
            "method": "setRate",
            "value": rate
        ])
    }

    @objc func stopAllPlayers(_ call: CAPPluginCall) {
        for (_, player) in videoPlayers {
            player.pause()
        }
        for (playerId, player) in hybridSlotPlayers {
            player.teardown()
            hybridSlotPlayers.removeValue(forKey: playerId)
        }

        call.resolve([
            "result": true,
            "method": "stopAllPlayers",
            "value": true
        ])
    }

    @objc func showController(_ call: CAPPluginCall) {
        guard let playerId = currentPlayerId,
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "showController",
                "message": "No active player"
            ])
            return
        }

        player.showController()
        call.resolve([
            "result": true,
            "method": "showController",
            "value": true
        ])
    }

    @objc func isControllerIsFullyVisible(_ call: CAPPluginCall) {
        guard let playerId = currentPlayerId,
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "isControllerIsFullyVisible",
                "message": "No active player"
            ])
            return
        }

        let visible = player.isControllerVisible()
        call.resolve([
            "result": true,
            "method": "isControllerIsFullyVisible",
            "value": visible
        ])
    }

    @objc func exitPlayer(_ call: CAPPluginCall) {
        guard let playerId = currentPlayerId,
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "exitPlayer",
                "message": "No active player"
            ])
            return
        }

        player.dismiss()
        call.resolve([
            "result": true,
            "method": "exitPlayer",
            "value": true
        ])
    }
}

extension VideoPlayerPlugin {
    @objc func hidePlayer(_ call: CAPPluginCall) {
        guard let playerId = currentPlayerId,
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "hidePlayer",
                "message": "No active player"
            ])
            return
        }

        DispatchQueue.main.async {
            player.hide {
                call.resolve([
                    "result": true,
                    "method": "hidePlayer",
                    "value": true
                ])
            }
        }
    }

    @objc func showPlayer(_ call: CAPPluginCall) {
        guard let playerId = currentPlayerId,
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "showPlayer",
                "message": "No active player"
            ])
            return
        }

        DispatchQueue.main.async {
            guard let viewController = self.bridge?.viewController else {
                call.resolve([
                    "result": false,
                    "method": "showPlayer",
                    "message": "Unable to get view controller"
                ])
                return
            }

            player.show(on: viewController) {
                call.resolve([
                    "result": true,
                    "method": "showPlayer",
                    "value": true
                ])
            }
        }
    }
}
