import Foundation
import Capacitor
import AVKit

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(VideoPlayerPlugin)
public class VideoPlayerPlugin: CAPPlugin, CAPBridgedPlugin {
    private let PLUGIN_VERSION: String = "7.1.4"
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
        CAPPluginMethod(name: "exitPlayer", returnType: CAPPluginReturnPromise)
    ]

    private var videoPlayers: [String: FullscreenVideoPlayer] = [:]
    private var currentPlayerId: String?

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": self.PLUGIN_VERSION])
    }

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
        guard mode == "fullscreen" else {
            call.resolve([
                "result": false,
                "method": "initPlayer",
                "message": "Only fullscreen mode is supported on iOS"
            ])
            return
        }

        let rate = call.getFloat("rate") ?? 1.0
        let exitOnEnd = call.getBool("exitOnEnd") ?? true
        let loopOnEnd = call.getBool("loopOnEnd") ?? false
        let pipEnabled = call.getBool("pipEnabled") ?? true
        let showControls = call.getBool("showControls") ?? true

        // Create video player
        let player = FullscreenVideoPlayer(
            playerId: playerId,
            url: url,
            rate: rate,
            exitOnEnd: exitOnEnd,
            loopOnEnd: loopOnEnd,
            pipEnabled: pipEnabled,
            showControls: showControls
        )

        player.setupPlayer()

        // Setup callbacks
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

        // Store player
        videoPlayers[playerId] = player
        currentPlayerId = playerId

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

            player.present(on: viewController) {
                call.resolve([
                    "result": true,
                    "method": "initPlayer",
                    "value": playerId
                ])
            }
        }
    }

    @objc func isPlaying(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "isPlaying",
                "message": "Player not found"
            ])
            return
        }

        call.resolve([
            "result": true,
            "method": "isPlaying",
            "value": player.isPlaying()
        ])
    }

    @objc func play(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "play",
                "message": "Player not found"
            ])
            return
        }

        player.play()
        call.resolve([
            "result": true,
            "method": "play",
            "value": true
        ])
    }

    @objc func pause(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "pause",
                "message": "Player not found"
            ])
            return
        }

        player.pause()
        call.resolve([
            "result": true,
            "method": "pause",
            "value": true
        ])
    }

    @objc func getDuration(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "getDuration",
                "message": "Player not found"
            ])
            return
        }

        let duration = player.getDuration()
        call.resolve([
            "result": true,
            "method": "getDuration",
            "value": duration
        ])
    }

    @objc func getCurrentTime(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "getCurrentTime",
                "message": "Player not found"
            ])
            return
        }

        let currentTime = player.getCurrentTime()
        call.resolve([
            "result": true,
            "method": "getCurrentTime",
            "value": currentTime
        ])
    }

    @objc func setCurrentTime(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
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

        player.setCurrentTime(seektime)
        call.resolve([
            "result": true,
            "method": "setCurrentTime",
            "value": seektime
        ])
    }

    @objc func getVolume(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "getVolume",
                "message": "Player not found"
            ])
            return
        }

        let volume = player.getVolume()
        call.resolve([
            "result": true,
            "method": "getVolume",
            "value": volume
        ])
    }

    @objc func setVolume(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
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

        player.setVolume(volume)
        call.resolve([
            "result": true,
            "method": "setVolume",
            "value": volume
        ])
    }

    @objc func getMuted(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "getMuted",
                "message": "Player not found"
            ])
            return
        }

        let muted = player.getMuted()
        call.resolve([
            "result": true,
            "method": "getMuted",
            "value": muted
        ])
    }

    @objc func setMuted(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
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

        player.setMuted(muted)
        call.resolve([
            "result": true,
            "method": "setMuted",
            "value": muted
        ])
    }

    @objc func getRate(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
            call.resolve([
                "result": false,
                "method": "getRate",
                "message": "Player not found"
            ])
            return
        }

        let rate = player.getRate()
        call.resolve([
            "result": true,
            "method": "getRate",
            "value": rate
        ])
    }

    @objc func setRate(_ call: CAPPluginCall) {
        guard let playerId = call.getString("playerId"),
              let player = videoPlayers[playerId] else {
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

        player.setRate(rate)
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
