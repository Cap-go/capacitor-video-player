import Foundation
import AVKit
import AVFoundation
import UIKit

class FullscreenVideoPlayer: NSObject {
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    private var playerItem: AVPlayerItem?
    private var playerId: String
    private var videoUrl: String
    private var exitOnEnd: Bool
    private var loopOnEnd: Bool
    private var pipEnabled: Bool
    private var showControls: Bool
    private var rate: Float
    private var timeObserver: Any?
    private var onPlay: (() -> Void)?
    private var onPause: (() -> Void)?
    private var onReady: (() -> Void)?
    private var onEnd: (() -> Void)?
    private var onExit: ((Double) -> Void)?

    init(playerId: String, url: String, rate: Float, exitOnEnd: Bool, loopOnEnd: Bool, pipEnabled: Bool, showControls: Bool) {
        self.playerId = playerId
        self.videoUrl = url
        self.rate = rate
        self.exitOnEnd = exitOnEnd
        self.loopOnEnd = loopOnEnd
        self.pipEnabled = pipEnabled
        self.showControls = showControls
        super.init()
    }

    func setupPlayer() {
        guard let url = URL(string: videoUrl) else {
            return
        }

        // Create player item with asset
        let asset = AVAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)

        // Create player
        player = AVPlayer(playerItem: playerItem)
        player?.rate = rate

        // Create player view controller
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        playerViewController?.showsPlaybackControls = showControls

        // Picture in Picture support
        if #available(iOS 14.2, *) {
            playerViewController?.allowsPictureInPicturePlayback = pipEnabled
        }

        // Setup observers
        setupObservers()
    }

    private func setupObservers() {
        guard let player = player else { return }

        // Observe player status
        playerItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)

        // Observe playback end
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        // Observe time updates
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { _ in
            // Can be used for progress updates
        }

        // Observe rate changes (play/pause)
        player.addObserver(self, forKeyPath: "rate", options: [.new, .old], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let item = object as? AVPlayerItem {
                if item.status == .readyToPlay {
                    onReady?()
                }
            }
        } else if keyPath == "rate" {
            if let newRate = change?[.newKey] as? Float,
               let oldRate = change?[.oldKey] as? Float {
                if newRate > 0 && oldRate == 0 {
                    onPlay?()
                } else if newRate == 0 && oldRate > 0 {
                    onPause?()
                }
            }
        }
    }

    @objc private func playerDidFinishPlaying() {
        if loopOnEnd {
            player?.seek(to: .zero)
            player?.play()
        } else if exitOnEnd {
            onEnd?()
            dismiss()
        } else {
            onEnd?()
        }
    }

    func present(on viewController: UIViewController, completion: @escaping () -> Void) {
        guard let playerVC = playerViewController else {
            completion()
            return
        }

        viewController.present(playerVC, animated: true) {
            self.player?.play()
            completion()
        }
    }

    func dismiss() {
        let currentTime = getCurrentTime()
        playerViewController?.dismiss(animated: true) { [weak self] in
            self?.cleanup()
            self?.onExit?(currentTime)
        }
    }

    private func cleanup() {
        if let observer = timeObserver {
            player?.removeObserver(self, forKeyPath: "rate")
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        playerItem?.removeObserver(self, forKeyPath: "status")
        NotificationCenter.default.removeObserver(self)
        player?.pause()
        player = nil
        playerItem = nil
        playerViewController = nil
    }

    // MARK: - Playback Control

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func isPlaying() -> Bool {
        guard let player = player else { return false }
        return player.rate > 0
    }

    func getDuration() -> Double {
        guard let duration = playerItem?.duration else { return 0 }
        return CMTimeGetSeconds(duration)
    }

    func getCurrentTime() -> Double {
        guard let currentTime = player?.currentTime() else { return 0 }
        return CMTimeGetSeconds(currentTime)
    }

    func setCurrentTime(_ time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }

    func getVolume() -> Float {
        return player?.volume ?? 0
    }

    func setVolume(_ volume: Float) {
        player?.volume = volume
    }

    func getMuted() -> Bool {
        return player?.isMuted ?? false
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    func getRate() -> Float {
        return player?.rate ?? 0
    }

    func setRate(_ rate: Float) {
        player?.rate = rate
        self.rate = rate
    }

    func showController() {
        playerViewController?.showsPlaybackControls = true
    }

    func isControllerVisible() -> Bool {
        return playerViewController?.showsPlaybackControls ?? false
    }

    // MARK: - Callbacks

    func setOnPlay(_ callback: @escaping () -> Void) {
        self.onPlay = callback
    }

    func setOnPause(_ callback: @escaping () -> Void) {
        self.onPause = callback
    }

    func setOnReady(_ callback: @escaping () -> Void) {
        self.onReady = callback
    }

    func setOnEnd(_ callback: @escaping () -> Void) {
        self.onEnd = callback
    }

    func setOnExit(_ callback: @escaping (Double) -> Void) {
        self.onExit = callback
    }

    deinit {
        cleanup()
    }
}
