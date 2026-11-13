import AVFoundation
import UIKit

/// Native video surface for hybrid-ui slot compositing (no fullscreen chrome).
final class HybridSlotVideoPlayer: NSObject {
    static let slotContentProvideNotification = Notification.Name("CapgoHybridUiSlotContentProvide")
    static let slotContentRemoveNotification = Notification.Name("CapgoHybridUiSlotContentRemove")
    static let slotContentAckNotification = Notification.Name("CapgoHybridUiSlotContentAck")

    private let playerId: String
    private let hybridSlotId: String
    private var player: AVPlayer?
    private let playerView = HybridSlotPlayerView()
    private var onPlay: (() -> Void)?
    private var onPause: (() -> Void)?
    private var onReady: (() -> Void)?
    private var onEnd: (() -> Void)?
    private var onNativeTap: (() -> Void)?
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var backgroundObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var ackObserver: NSObjectProtocol?
    private var didEmitReady = false
    private var didFinishSetup = false
    private var pendingSetupCompletion: ((Bool) -> Void)?

    init(playerId: String, hybridSlotId: String) {
        self.playerId = playerId
        self.hybridSlotId = hybridSlotId
        super.init()
        playerView.onTap = { [weak self] in
            self?.onNativeTap?()
        }
        registerLifecycleObservers()
    }

    var slotView: UIView { playerView }

    func setup(urlString: String, autoplayRate: Float, completion: @escaping (Bool) -> Void) {
        guard let url = HybridSlotVideoPlayer.resolveMediaURL(urlString) else {
            completion(false)
            return
        }
        pendingSetupCompletion = completion
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.automaticallyWaitsToMinimizeStalling = true
        player = avPlayer
        playerView.attach(player: avPlayer)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackEnded),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .readyToPlay:
                self.finishSetupIfNeeded(autoplayRate: autoplayRate, success: true)
            case .failed:
                self.finishSetupIfNeeded(autoplayRate: autoplayRate, success: false)
            default:
                break
            }
        }

        rateObserver = avPlayer.observe(\.rate, options: [.new]) { [weak self] av, _ in
            guard let self, let player = self.player else { return }
            if av.rate > 0 {
                self.onPlay?()
            } else if av.rate == 0, player.timeControlStatus != .waitingToPlayAtSpecifiedRate {
                self.onPause?()
            }
        }

        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.emitReadyIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.finishSetupIfNeeded(autoplayRate: autoplayRate, success: false)
        }
    }

    func publishToHybridSlot(nativeZIndex: Int, completion: @escaping (Bool) -> Void) {
        var didComplete = false
        ackObserver = NotificationCenter.default.addObserver(
            forName: Self.slotContentAckNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let ackSlot = note.userInfo?["slotId"] as? String
            guard ackSlot == self.hybridSlotId else { return }
            guard !didComplete else { return }
            didComplete = true
            if let ackObserver = self.ackObserver {
                NotificationCenter.default.removeObserver(ackObserver)
                self.ackObserver = nil
            }
            completion(true)
        }

        NotificationCenter.default.post(
            name: Self.slotContentProvideNotification,
            object: nil,
            userInfo: [
                "slotId": hybridSlotId,
                "view": playerView,
                "zIndex": nativeZIndex,
                "playerId": playerId,
            ]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, !didComplete else { return }
            didComplete = true
            if let ackObserver = self.ackObserver {
                NotificationCenter.default.removeObserver(ackObserver)
                self.ackObserver = nil
            }
            completion(false)
        }
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func isPlaying() -> Bool {
        guard let player else { return false }
        return player.rate != 0
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
        NotificationCenter.default.post(
            name: Self.slotContentRemoveNotification,
            object: nil,
            userInfo: ["slotId": hybridSlotId, "playerId": playerId]
        )
        if let ackObserver {
            NotificationCenter.default.removeObserver(ackObserver)
            self.ackObserver = nil
        }
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        itemStatusObserver = nil
        rateObserver = nil
        player?.pause()
        player = nil
        playerView.detach()
        NotificationCenter.default.removeObserver(self)
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    func setOnPlay(_ handler: @escaping () -> Void) { onPlay = handler }
    func setOnPause(_ handler: @escaping () -> Void) { onPause = handler }
    func setOnReady(_ handler: @escaping () -> Void) { onReady = handler }
    func setOnEnd(_ handler: @escaping () -> Void) { onEnd = handler }
    func setOnNativeTap(_ handler: @escaping () -> Void) { onNativeTap = handler }

    private func finishSetupIfNeeded(autoplayRate: Float, success: Bool) {
        guard !didFinishSetup, let completion = pendingSetupCompletion else { return }
        didFinishSetup = true
        pendingSetupCompletion = nil
        guard success else {
            completion(false)
            return
        }
        if autoplayRate > 0 {
            player?.play()
            player?.rate = autoplayRate
        }
        emitReadyIfNeeded()
        completion(true)
    }

    private func emitReadyIfNeeded() {
        guard !didEmitReady, player?.currentItem?.status == .readyToPlay else { return }
        didEmitReady = true
        onReady?()
    }

    @objc private func handlePlaybackEnded() {
        onEnd?()
    }

    private func registerLifecycleObservers() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.player?.pause()
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            self.player?.pause()
        }
    }

    private static func resolveMediaURL(_ raw: String) -> URL? {
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw)
        }
        return URL(string: raw)
    }
}

private final class HybridSlotPlayerView: UIView {
    var onTap: (() -> Void)?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        playerLayer.backgroundColor = UIColor.clear.cgColor
        isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?()
    }

    func attach(player: AVPlayer) {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
    }

    func detach() {
        playerLayer.player = nil
    }
}
