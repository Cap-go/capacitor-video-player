import Foundation
import AVKit
import AVFoundation
import UIKit

// swiftlint:disable:next type_body_length
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
    private var chromecast: Bool
    private var chromecastUrl: String?
    private var title: String?
    private var smallTitle: String?
    private var artwork: String?
    private var rate: Float
    private var audioCategory: String?
    private var didActivateAudioSession: Bool = false
    private var didEmitExit: Bool = false
    private var timeObserver: Any?
    private var onPlay: (() -> Void)?
    private var onPause: (() -> Void)?
    private var onReady: (() -> Void)?
    private var onEnd: (() -> Void)?
    private var onExit: ((Double) -> Void)?
    private var fairplayCertificateUrl: String?
    private var fairplayContentKeySpcUrl: String?
    private var fairplayAssetId: String?
    private var widevineLicenseUrl: String?
    private var contentKeySession: AVContentKeySession?
    private var castController: VideoPlayerCastController?
    private weak var presentingViewController: UIViewController?
    private var subtitleTracks: [VideoSubtitleTrack] = []
    private var hlsResourceLoader: HLSSubtitleResourceLoader?

    init(
        playerId: String,
        url: String,
        rate: Float,
        exitOnEnd: Bool,
        loopOnEnd: Bool,
        pipEnabled: Bool,
        showControls: Bool,
        chromecast: Bool,
        chromecastUrl: String? = nil,
        title: String? = nil,
        smallTitle: String? = nil,
        artwork: String? = nil,
        subtitleTracks: [VideoSubtitleTrack] = [],
        fairplayCertificateUrl: String? = nil,
        fairplayContentKeySpcUrl: String? = nil,
        fairplayAssetId: String? = nil,
        widevineLicenseUrl: String? = nil,
        audioCategory: String? = nil
    ) {
        self.playerId = playerId
        self.videoUrl = url
        self.rate = rate
        self.exitOnEnd = exitOnEnd
        self.loopOnEnd = loopOnEnd
        self.pipEnabled = pipEnabled
        self.showControls = showControls
        self.chromecast = chromecast
        self.chromecastUrl = chromecastUrl
        self.title = title
        self.smallTitle = smallTitle
        self.artwork = artwork
        self.subtitleTracks = subtitleTracks
        self.fairplayCertificateUrl = fairplayCertificateUrl
        self.fairplayContentKeySpcUrl = fairplayContentKeySpcUrl
        self.fairplayAssetId = fairplayAssetId
        self.widevineLicenseUrl = widevineLicenseUrl
        self.audioCategory = audioCategory
        super.init()
    }

    func setupPlayer(completion: @escaping () -> Void) {
        guard let url = URL(string: videoUrl) else {
            completion()
            return
        }

        configureAudioSession()

        let resolvedTracks = subtitleTracks.compactMap { track -> (URL, String?)? in
            guard let subtitleURL = track.resolvedURL else { return nil }
            return (subtitleURL, track.language)
        }

        guard !resolvedTracks.isEmpty else {
            let asset = makeVideoAsset(url: url, subtitleTracks: [])
            configurePlayer(with: AVPlayerItem(asset: asset))
            completion()
            return
        }

        if HLSVideoAssetFactory.isHLSStream(url) {
            let asset = makeVideoAsset(url: url, subtitleTracks: subtitleTracks)
            configurePlayer(with: AVPlayerItem(asset: asset))
            completion()
            return
        }

        Task {
            let asset = makeVideoAsset(url: url, subtitleTracks: [])
            let item = await ProgressiveVideoPlayerItemFactory.createPlayerItem(
                videoAsset: asset,
                subtitleTracks: subtitleTracks
            )
            await MainActor.run {
                self.configurePlayer(with: item)
                completion()
            }
        }
    }

    private func makeVideoAsset(url: URL, subtitleTracks: [VideoSubtitleTrack]) -> AVURLAsset {
        let result = HLSVideoAssetFactory.makeAsset(
            videoURL: url,
            subtitleTracks: subtitleTracks
        )
        hlsResourceLoader = result.resourceLoader
        let asset = result.asset

        if let certUrl = fairplayCertificateUrl, !certUrl.isEmpty,
           let spcUrl = fairplayContentKeySpcUrl, !spcUrl.isEmpty {
            let session = AVContentKeySession(keySystem: .fairPlayStreaming)
            session.setDelegate(self, queue: DispatchQueue.global(qos: .default))
            session.addContentKeyRecipient(asset)
            self.contentKeySession = session
        }

        return asset
    }

    private func configurePlayer(with item: AVPlayerItem) {
        playerItem = item
        player = AVPlayer(playerItem: playerItem)
        player?.rate = rate

        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        playerViewController?.showsPlaybackControls = showControls
        playerViewController?.allowsPictureInPicturePlayback = pipEnabled
        playerViewController?.delegate = self

        setupChromecast()
        setupObservers()
    }

    private func setupChromecast() {
        guard chromecast,
              let playerViewController = playerViewController,
              let player = player else {
            return
        }

        let castVideoUrl: String
        if let chromecastUrl = chromecastUrl, !chromecastUrl.isEmpty {
            castVideoUrl = chromecastUrl
        } else {
            castVideoUrl = videoUrl
        }

        castController = VideoPlayerCastController(
            videoUrl: castVideoUrl,
            title: title,
            smallTitle: smallTitle,
            artwork: artwork,
            widevineLicenseUrl: widevineLicenseUrl
        )
        castController?.setOnPlay { [weak self] in
            self?.onPlay?()
        }
        castController?.setOnPause { [weak self] in
            self?.onPause?()
        }
        castController?.setOnEnd { [weak self] in
            self?.handlePlaybackEnded()
        }
        castController?.attach(to: playerViewController, player: player)
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

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
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
        handlePlaybackEnded()
    }

    private func handlePlaybackEnded() {
        if loopOnEnd {
            if castController?.restartPlayback() == true {
                return
            }
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

        presentingViewController = viewController
        viewController.present(playerVC, animated: true) {
            playerVC.presentationController?.delegate = self
            self.play()
            completion()
        }
    }

    func show(on viewController: UIViewController, completion: @escaping () -> Void) {
        guard let playerVC = playerViewController else {
            completion()
            return
        }
        if playerVC.presentingViewController != nil {
            completion()
            return
        }
        presentingViewController = viewController
        viewController.present(playerVC, animated: true) {
            playerVC.presentationController?.delegate = self
            completion()
        }
    }

    func hide(completion: @escaping () -> Void) {
        guard let playerVC = playerViewController else {
            completion()
            return
        }
        if playerVC.presentingViewController == nil {
            completion()
            return
        }
        playerVC.dismiss(animated: true) {
            completion()
        }
    }

    func dismiss() {
        let currentTime = getCurrentTime()
        playerViewController?.dismiss(animated: true) { [weak self] in
            self?.emitExitIfNeeded(currentTime: currentTime)
        }
    }

    private func cleanup(stopRemoteMedia: Bool = false) {
        castController?.detach(stopRemoteMedia: stopRemoteMedia)
        castController = nil
        contentKeySession?.setDelegate(nil, queue: nil)
        contentKeySession = nil
        hlsResourceLoader = nil
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
        deactivateAudioSessionIfNeeded()
    }

    private func configureAudioSession() {
        guard let audioCategory else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            switch audioCategory {
            case "ambient":
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            case "playback":
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            case "moviePlayback":
                if #available(iOS 13.0, *) {
                    try session.setCategory(
                        .playback,
                        mode: .moviePlayback,
                        policy: .longFormVideo,
                        options: [.mixWithOthers]
                    )
                } else {
                    try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
                }
            default:
                return
            }

            try session.setActive(true)
            didActivateAudioSession = true
        } catch {
            print("Error configuring AVAudioSession: \(error)")
        }
    }

    private func deactivateAudioSessionIfNeeded() {
        guard didActivateAudioSession else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            didActivateAudioSession = false
        } catch {
            print("Error deactivating AVAudioSession: \(error)")
        }
    }

    private func emitExitIfNeeded(currentTime: Double? = nil) {
        guard !didEmitExit else { return }
        didEmitExit = true

        let time = currentTime ?? getCurrentTime()
        cleanup(stopRemoteMedia: true)
        onExit?(time)
    }

    // MARK: - Playback Control

    func play() {
        if castController?.play() == true {
            return
        }
        player?.play()
    }

    func pause() {
        if castController?.pause() == true {
            return
        }
        player?.pause()
    }

    func isPlaying() -> Bool {
        if castController?.isCasting == true {
            return castController?.isPlaying() ?? false
        }
        guard let player = player else { return false }
        return player.rate > 0
    }

    func getDuration() -> Double {
        if castController?.isCasting == true {
            return castController?.getDuration() ?? 0
        }
        guard let duration = playerItem?.duration else { return 0 }
        return CMTimeGetSeconds(duration)
    }

    func getCurrentTime() -> Double {
        if castController?.isCasting == true {
            return castController?.getCurrentTime() ?? 0
        }
        guard let currentTime = player?.currentTime() else { return 0 }
        return CMTimeGetSeconds(currentTime)
    }

    func setCurrentTime(_ time: Double) {
        if castController?.setCurrentTime(time) == true {
            return
        }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }

    func getVolume() -> Float {
        if castController?.isCasting == true {
            return castController?.getVolume() ?? 0
        }
        return player?.volume ?? 0
    }

    func setVolume(_ volume: Float) {
        if castController?.setVolume(volume) == true {
            return
        }
        player?.volume = volume
    }

    func getMuted() -> Bool {
        if castController?.isCasting == true {
            return castController?.getMuted() ?? false
        }
        return player?.isMuted ?? false
    }

    func setMuted(_ muted: Bool) {
        if castController?.setMuted(muted) == true {
            return
        }
        player?.isMuted = muted
    }

    func getRate() -> Float {
        if castController?.isCasting == true {
            return castController?.getRate() ?? 0
        }
        return player?.rate ?? 0
    }

    func setRate(_ rate: Float) {
        if castController?.setRate(rate) == true {
            self.rate = rate
            return
        }
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

// MARK: - AVPlayerViewControllerDelegate (Picture in Picture)

extension FullscreenVideoPlayer: AVPlayerViewControllerDelegate {
    func playerViewControllerWillEndFullScreenPresentation(
        _ playerViewController: AVPlayerViewController,
        withAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.emitExitIfNeeded()
        }
    }

    func playerViewControllerDidEndFullScreenPresentation(_ playerViewController: AVPlayerViewController) {
        emitExitIfNeeded()
    }

    func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(
        _ playerViewController: AVPlayerViewController
    ) -> Bool {
        true
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        guard let presentingViewController else {
            completionHandler(false)
            return
        }

        if playerViewController.presentingViewController == nil {
            DispatchQueue.main.async {
                presentingViewController.present(playerViewController, animated: false) {
                    completionHandler(true)
                }
            }
        } else {
            completionHandler(true)
        }
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension FullscreenVideoPlayer: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        emitExitIfNeeded()
    }
}

// MARK: - AVContentKeySessionDelegate (FairPlay DRM)

extension FullscreenVideoPlayer: AVContentKeySessionDelegate {
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        handleFairPlayKeyRequest(keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        handleFairPlayKeyRequest(keyRequest)
    }

    private func fairPlayContentIdentifierData(from identifier: Any?) -> Data? {
        if let data = identifier as? Data {
            return data.isEmpty ? nil : data
        }

        let identifierString: String?
        if let url = identifier as? URL {
            identifierString = url.absoluteString
        } else if let string = identifier as? String {
            identifierString = string
        } else {
            identifierString = nil
        }

        guard var string = identifierString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else {
            return nil
        }

        if string.hasPrefix("skd://") {
            string.removeFirst("skd://".count)
        } else if string.hasPrefix("skd:") {
            string.removeFirst("skd:".count)
        }

        while string.hasPrefix("/") {
            string.removeFirst()
        }

        return string.data(using: .utf8)
    }

    private func normalizeFairPlayCkcData(_ data: Data) -> Data {
        if let object = try? JSONSerialization.jsonObject(with: data),
           let dict = object as? [String: Any] {
            let candidateKeys = ["ckc", "CKC", "license", "License", "data"]
            for key in candidateKeys {
                if let value = dict[key] as? String,
                   let decoded = Data(base64Encoded: value) {
                    return decoded
                }
            }
        }

        if let string = String(data: data, encoding: .utf8) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if let decoded = Data(base64Encoded: trimmed) {
                return decoded
            }
        }

        return data
    }

    private func handleFairPlayKeyRequest(_ keyRequest: AVContentKeyRequest) {
        guard let certUrlString = fairplayCertificateUrl,
              let certUrl = URL(string: certUrlString),
              let spcUrlString = fairplayContentKeySpcUrl,
              let spcUrl = URL(string: spcUrlString) else {
            keyRequest.processContentKeyResponseError(
                NSError(domain: "VideoPlayer", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid FairPlay DRM configuration"])
            )
            return
        }

        // 1. Fetch the FairPlay certificate
        URLSession.shared.dataTask(with: certUrl) { [self] certData, certResponse, certError in
            if let httpResponse = certResponse as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                keyRequest.processContentKeyResponseError(
                    NSError(domain: "VideoPlayer", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to fetch FairPlay certificate (HTTP \(httpResponse.statusCode))"
                    ])
                )
                return
            }

            guard let certData = certData else {
                keyRequest.processContentKeyResponseError(
                    certError ?? NSError(domain: "VideoPlayer", code: -2,
                                         userInfo: [NSLocalizedDescriptionKey: "Failed to fetch FairPlay certificate"])
                )
                return
            }

            // 2. Create SPC (Server Playback Context) using the certificate
            let contentIdentifier: Data? = {
                if let assetId = fairplayAssetId?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !assetId.isEmpty {
                    return assetId.data(using: .utf8)
                }
                return fairPlayContentIdentifierData(from: keyRequest.identifier)
            }()

            keyRequest.makeStreamingContentKeyRequestData(
                forApp: certData,
                contentIdentifier: contentIdentifier,
                options: [AVContentKeyRequestProtocolVersionsKey: [1]]
            ) { spcData, spcError in
                guard let spcData = spcData else {
                    keyRequest.processContentKeyResponseError(
                        spcError ?? NSError(domain: "VideoPlayer", code: -4,
                                            userInfo: [NSLocalizedDescriptionKey: "Failed to create FairPlay SPC"])
                    )
                    return
                }

                // 3. Send SPC to the license server and receive the CKC
                var spcRequest = URLRequest(url: spcUrl)
                spcRequest.httpMethod = "POST"
                spcRequest.httpBody = spcData
                spcRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

                URLSession.shared.dataTask(with: spcRequest) { [self] ckcData, ckcResponse, ckcError in
                    if let httpResponse = ckcResponse as? HTTPURLResponse,
                       !(200...299).contains(httpResponse.statusCode) {
                        keyRequest.processContentKeyResponseError(
                            NSError(domain: "VideoPlayer", code: -3, userInfo: [
                                NSLocalizedDescriptionKey: "Failed to obtain FairPlay CKC (HTTP \(httpResponse.statusCode))"
                            ])
                        )
                        return
                    }

                    guard let ckcData = ckcData else {
                        keyRequest.processContentKeyResponseError(
                            ckcError ?? NSError(domain: "VideoPlayer", code: -3,
                                                userInfo: [NSLocalizedDescriptionKey: "Failed to obtain FairPlay CKC"])
                        )
                        return
                    }

                    // 4. Provide the CKC to AVFoundation to decrypt the content
                    let normalizedCkcData = normalizeFairPlayCkcData(ckcData)
                    let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: normalizedCkcData)
                    keyRequest.processContentKeyResponse(keyResponse)
                }.resume()
            }
        }.resume()
    }
}
