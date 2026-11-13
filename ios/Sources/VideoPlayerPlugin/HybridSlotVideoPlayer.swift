import AVFoundation
import UIKit

/// Native video surface for hybrid-ui slot compositing (no fullscreen chrome).
final class HybridSlotVideoPlayer: NSObject {
    static let slotContentProvideNotification = Notification.Name("CapgoHybridUiSlotContentProvide")

    private let playerId: String
    private let hybridSlotId: String
    private var player: AVPlayer?
    private let playerView = HybridSlotPlayerView()
    private var onPlay: (() -> Void)?
    private var onPause: (() -> Void)?
    private var onReady: (() -> Void)?
    private var onEnd: (() -> Void)?
    private var timeObserver: Any?

    init(playerId: String, hybridSlotId: String) {
        self.playerId = playerId
        self.hybridSlotId = hybridSlotId
        super.init()
    }

    var slotView: UIView { playerView }

    func setup(urlString: String, rate: Float, completion: @escaping (Bool) -> Void) {
        guard let url = HybridSlotVideoPlayer.resolveMediaURL(urlString) else {
            completion(false)
            return
        }
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.rate = rate
        player = avPlayer
        playerView.attach(player: avPlayer)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackEnded),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.emitReadyIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.emitReadyIfNeeded()
            completion(true)
        }
    }

    func publishToHybridSlot() {
        NotificationCenter.default.post(
            name: Self.slotContentProvideNotification,
            object: nil,
            userInfo: ["slotId": hybridSlotId, "view": playerView]
        )
    }

    func play() {
        player?.play()
        onPlay?()
    }

    func pause() {
        player?.pause()
        onPause?()
    }

    func isPlaying() -> Bool {
        player?.rate != 0
    }

    func getCurrentTime() -> Double {
        guard let player else { return 0 }
        let seconds = CMTimeGetSeconds(player.currentTime())
        return seconds.isFinite ? seconds : 0
    }

    func getDuration() -> Double {
        guard let item = player?.currentItem else { return 0 }
        let seconds = CMTimeGetSeconds(item.duration)
        return seconds.isFinite ? seconds : 0
    }

    func setCurrentTime(_ seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    func setVolume(_ volume: Float) {
        player?.volume = volume
    }

    func getVolume() -> Float {
        player?.volume ?? 1
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    func getMuted() -> Bool {
        player?.isMuted ?? false
    }

    func setRate(_ rate: Float) {
        player?.rate = rate
    }

    func getRate() -> Float {
        player?.rate ?? 1
    }

    func teardown() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
        playerView.detach()
        NotificationCenter.default.removeObserver(self)
    }

    func setOnPlay(_ handler: @escaping () -> Void) { onPlay = handler }
    func setOnPause(_ handler: @escaping () -> Void) { onPause = handler }
    func setOnReady(_ handler: @escaping () -> Void) { onReady = handler }
    func setOnEnd(_ handler: @escaping () -> Void) { onEnd = handler }

    private var didEmitReady = false

    private func emitReadyIfNeeded() {
        guard !didEmitReady, player?.currentItem?.status == .readyToPlay else { return }
        didEmitReady = true
        onReady?()
    }

    @objc private func handlePlaybackEnded() {
        onEnd?()
    }

    private static func resolveMediaURL(_ raw: String) -> URL? {
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw)
        }
        return URL(string: raw)
    }
}

private final class HybridSlotPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(player: AVPlayer) {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
    }

    func detach() {
        playerLayer.player = nil
    }
}
