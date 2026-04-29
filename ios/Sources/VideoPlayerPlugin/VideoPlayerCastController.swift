import AVFoundation
import AVKit
import Foundation
import UIKit

#if canImport(GoogleCast)
import GoogleCast

final class VideoPlayerCastController: NSObject {
    private enum PendingCastCommand {
        case play
        case pause
        case seek(Double)
        case volume(Float)
        case muted(Bool)
        case rate(Float)
    }

    private let videoUrl: String
    private let title: String?
    private let smallTitle: String?
    private let artwork: String?

    private weak var player: AVPlayer?
    private weak var playerViewController: AVPlayerViewController?
    private weak var castButton: GCKUICastButton?
    private weak var castIndicatorLabel: UILabel?
    private weak var observedRemoteMediaClient: GCKRemoteMediaClient?
    private var mediaLoadRequest: GCKRequest?
    private var pendingCastCommands: [PendingCastCommand] = []
    private var isLoadedOnCast = false
    private var isLoadingOnCast = false
    private var localWasPlaying = false
    private var isDetached = false
    private var lastRemoteIsPlaying: Bool?
    private var didNotifyRemoteEnd = false
    private var onPlay: (() -> Void)?
    private var onPause: (() -> Void)?
    private var onEnd: (() -> Void)?
    private var controlsHideTimer: Timer?
    private weak var tapGestureRecognizer: UITapGestureRecognizer?

    var isCasting: Bool {
        return remoteMediaClient != nil && isLoadedOnCast
    }

    private var remoteMediaClient: GCKRemoteMediaClient? {
        guard GCKCastContext.isSharedInstanceInitialized() else {
            return nil
        }
        return GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient
    }

    init(videoUrl: String, title: String?, smallTitle: String?, artwork: String?) {
        self.videoUrl = videoUrl
        self.title = title
        self.smallTitle = smallTitle
        self.artwork = artwork
        super.init()
    }

    func attach(to playerViewController: AVPlayerViewController, player: AVPlayer) {
        self.playerViewController = playerViewController
        self.player = player

        let attachOnMain = { [weak self] in
            guard let self = self,
                  Self.configureCastContext() else {
                return
            }

            GCKCastContext.sharedInstance().sessionManager.add(self)
            self.addCastButton(to: playerViewController)
            self.addCastIndicator(to: playerViewController)
            self.beginObservingPlayerTaps(playerViewController)
            self.loadMediaIfCastSessionAvailable()
        }

        if Thread.isMainThread {
            attachOnMain()
        } else {
            DispatchQueue.main.async(execute: attachOnMain)
        }
    }

    func detach(stopRemoteMedia: Bool) {
        guard !isDetached else {
            return
        }
        isDetached = true
        clearMediaLoadRequest()
        pendingCastCommands.removeAll()

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  GCKCastContext.isSharedInstanceInitialized() else {
                return
            }

            if stopRemoteMedia {
                self.remoteMediaClient?.stop()
            }

            self.stopRemoteMediaObservation()
            GCKCastContext.sharedInstance().sessionManager.remove(self)
            self.controlsHideTimer?.invalidate()
            self.controlsHideTimer = nil
            if let tapRecognizer = self.tapGestureRecognizer,
               let view = self.playerViewController?.view {
                view.removeGestureRecognizer(tapRecognizer)
            }
            self.tapGestureRecognizer = nil
            self.castButton?.removeFromSuperview()
            self.castButton = nil
            self.castIndicatorLabel?.removeFromSuperview()
            self.castIndicatorLabel = nil
            self.player = nil
            self.playerViewController = nil
            self.isLoadedOnCast = false
            self.isLoadingOnCast = false
        }
    }

    func play() -> Bool {
        guard let remoteMediaClient = remoteMediaClient else {
            return false
        }
        guard isLoadedOnCast else {
            return enqueuePendingCastCommand(.play)
        }
        remoteMediaClient.play()
        return true
    }

    func pause() -> Bool {
        guard let remoteMediaClient = remoteMediaClient else {
            return false
        }
        guard isLoadedOnCast else {
            return enqueuePendingCastCommand(.pause)
        }
        remoteMediaClient.pause()
        return true
    }

    func setCurrentTime(_ time: Double) -> Bool {
        guard let remoteMediaClient = remoteMediaClient else {
            return false
        }
        guard isLoadedOnCast else {
            return enqueuePendingCastCommand(.seek(time))
        }
        let options = GCKMediaSeekOptions()
        options.interval = time
        options.relative = false
        options.resumeState = .unchanged
        remoteMediaClient.seek(with: options)
        return true
    }

    func isPlaying() -> Bool {
        guard let playerState = remoteMediaClient?.mediaStatus?.playerState else {
            return false
        }
        return playerState == .playing || playerState == .buffering
    }

    func getDuration() -> Double {
        return remoteMediaClient?.mediaStatus?.mediaInformation?.streamDuration ?? 0
    }

    func getCurrentTime() -> Double {
        return remoteMediaClient?.approximateStreamPosition() ?? 0
    }

    func getVolume() -> Float {
        return remoteMediaClient?.mediaStatus?.volume ?? 0
    }

    func setVolume(_ volume: Float) -> Bool {
        guard let remoteMediaClient = remoteMediaClient else {
            return false
        }
        guard isLoadedOnCast else {
            return enqueuePendingCastCommand(.volume(volume))
        }
        remoteMediaClient.setStreamVolume(volume)
        return true
    }

    func getMuted() -> Bool {
        return remoteMediaClient?.mediaStatus?.isMuted ?? false
    }

    func setMuted(_ muted: Bool) -> Bool {
        guard let remoteMediaClient = remoteMediaClient else {
            return false
        }
        guard isLoadedOnCast else {
            return enqueuePendingCastCommand(.muted(muted))
        }
        remoteMediaClient.setStreamMuted(muted)
        return true
    }

    func getRate() -> Float {
        return remoteMediaClient?.mediaStatus?.playbackRate ?? 0
    }

    func setRate(_ rate: Float) -> Bool {
        guard let remoteMediaClient = remoteMediaClient else {
            return false
        }
        guard isLoadedOnCast else {
            return enqueuePendingCastCommand(.rate(rate))
        }
        remoteMediaClient.setPlaybackRate(rate)
        return true
    }

    func restartPlayback() -> Bool {
        guard let remoteMediaClient = remoteMediaClient,
              let mediaInfo = makeMediaInformation() else {
            return false
        }

        didNotifyRemoteEnd = false
        isLoadedOnCast = false
        isLoadingOnCast = true
        clearMediaLoadRequest()

        let mediaLoadRequestDataBuilder = GCKMediaLoadRequestDataBuilder()
        mediaLoadRequestDataBuilder.mediaInformation = mediaInfo
        mediaLoadRequestDataBuilder.autoplay = NSNumber(value: true)
        mediaLoadRequestDataBuilder.startTime = 0
        let request = remoteMediaClient.loadMedia(with: mediaLoadRequestDataBuilder.build())
        request.delegate = self
        mediaLoadRequest = request
        return true
    }

    func setOnPlay(_ callback: @escaping () -> Void) {
        onPlay = callback
    }

    func setOnPause(_ callback: @escaping () -> Void) {
        onPause = callback
    }

    func setOnEnd(_ callback: @escaping () -> Void) {
        onEnd = callback
    }
}

private extension VideoPlayerCastController {
    static func configureCastContext() -> Bool {
        guard Thread.isMainThread else {
            return false
        }

        if GCKCastContext.isSharedInstanceInitialized() {
            return true
        }

        // This plugin intentionally uses the default media receiver.
        let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        var error: GCKError?
        return GCKCastContext.setSharedInstanceWith(options, error: &error)
    }

    func addCastButton(to playerViewController: AVPlayerViewController) {
        guard castButton == nil else {
            return
        }

        guard let overlayView = playerViewController.view else {
            return
        }

        overlayView.isUserInteractionEnabled = true
        let button = GCKUICastButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.accessibilityLabel = "Cast"

        overlayView.addSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
            // Position below AVPlayerViewController's top row of controls (Done/X and route picker)
            // using trailing to stay away from the leading-side dismiss button.
            button.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 60),
            button.trailingAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])

        castButton = button
    }

    func addCastIndicator(to playerViewController: AVPlayerViewController) {
        guard castIndicatorLabel == nil else {
            return
        }

        guard let overlayView = playerViewController.view else {
            return
        }

        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Casting"
        label.textColor = .white
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.isHidden = true

        overlayView.addSubview(label)

        if let castButton = castButton {
            NSLayoutConstraint.activate([
                label.centerYAnchor.constraint(equalTo: castButton.centerYAnchor),
                label.trailingAnchor.constraint(equalTo: castButton.leadingAnchor, constant: -8)
            ])
        } else {
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 60),
                label.trailingAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.trailingAnchor, constant: -68)
            ])
        }

        castIndicatorLabel = label
    }

    func beginObservingPlayerTaps(_ playerViewController: AVPlayerViewController) {
        guard let overlayView = playerViewController.view else { return }
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handlePlayerTap))
        tapRecognizer.cancelsTouchesInView = false
        overlayView.addGestureRecognizer(tapRecognizer)
        self.tapGestureRecognizer = tapRecognizer
        // Show the overlay immediately; it will auto-hide after the standard controls delay.
        showOverlayControls()
    }

    @objc func handlePlayerTap() {
        showOverlayControls()
    }

    func showOverlayControls() {
        castButton?.isHidden = false
        castIndicatorLabel?.isHidden = !isCasting
        controlsHideTimer?.invalidate()
        controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hideOverlayControls()
        }
    }

    func hideOverlayControls() {
        controlsHideTimer = nil
        let button = castButton
        let label = castIndicatorLabel
        UIView.animate(withDuration: 0.3, animations: {
            button?.alpha = 0
            label?.alpha = 0
        }, completion: { _ in
            button?.isHidden = true
            label?.isHidden = true
            button?.alpha = 1
            label?.alpha = 1
        })
    }

    func loadMediaIfCastSessionAvailable() {
        guard let remoteMediaClient = remoteMediaClient,
              let mediaInfo = makeMediaInformation() else {
            return
        }

        observeRemoteMediaClient(remoteMediaClient)
        let playPosition = player?.currentTime().seconds ?? 0
        localWasPlaying = (player?.rate ?? 0) > 0
        player?.pause()
        isLoadedOnCast = false
        isLoadingOnCast = true
        lastRemoteIsPlaying = nil
        didNotifyRemoteEnd = false
        clearMediaLoadRequest()

        let mediaLoadRequestDataBuilder = GCKMediaLoadRequestDataBuilder()
        mediaLoadRequestDataBuilder.mediaInformation = mediaInfo
        mediaLoadRequestDataBuilder.autoplay = NSNumber(value: localWasPlaying)
        mediaLoadRequestDataBuilder.startTime = playPosition.isFinite ? playPosition : 0
        let request = remoteMediaClient.loadMedia(with: mediaLoadRequestDataBuilder.build())
        request.delegate = self
        mediaLoadRequest = request
    }

    func resumeCastSession(_ session: GCKSession) {
        clearMediaLoadRequest()
        pendingCastCommands.removeAll()
        isLoadingOnCast = false

        guard let remoteMediaClient = session.remoteMediaClient else {
            isLoadedOnCast = false
            stopRemoteMediaObservation()
            return
        }

        observeRemoteMediaClient(remoteMediaClient)
        isLoadedOnCast = isCurrentVideo(remoteMediaClient.mediaStatus?.mediaInformation)
        handleRemoteMediaStatus(remoteMediaClient.mediaStatus)
    }

    func observeRemoteMediaClient(_ remoteMediaClient: GCKRemoteMediaClient) {
        if let observedRemoteMediaClient = observedRemoteMediaClient,
           observedRemoteMediaClient === remoteMediaClient {
            return
        }

        observedRemoteMediaClient?.remove(self)
        remoteMediaClient.add(self)
        observedRemoteMediaClient = remoteMediaClient
    }

    func stopRemoteMediaObservation() {
        observedRemoteMediaClient?.remove(self)
        observedRemoteMediaClient = nil
        lastRemoteIsPlaying = nil
    }

    private func enqueuePendingCastCommand(_ command: PendingCastCommand) -> Bool {
        guard isLoadingOnCast else {
            return false
        }

        pendingCastCommands.append(command)
        if pendingCastCommands.count > 20 {
            pendingCastCommands.removeFirst(pendingCastCommands.count - 20)
        }
        return true
    }

    func flushPendingCastCommands() {
        guard let remoteMediaClient = remoteMediaClient,
              isLoadedOnCast else {
            pendingCastCommands.removeAll()
            return
        }

        let commands = pendingCastCommands
        pendingCastCommands.removeAll()
        for command in commands {
            apply(command, to: remoteMediaClient)
        }
    }

    private func apply(_ command: PendingCastCommand, to remoteMediaClient: GCKRemoteMediaClient) {
        switch command {
        case .play:
            remoteMediaClient.play()
        case .pause:
            remoteMediaClient.pause()
        case .seek(let time):
            let options = GCKMediaSeekOptions()
            options.interval = time
            options.relative = false
            options.resumeState = .unchanged
            remoteMediaClient.seek(with: options)
        case .volume(let volume):
            remoteMediaClient.setStreamVolume(volume)
        case .muted(let muted):
            remoteMediaClient.setStreamMuted(muted)
        case .rate(let rate):
            remoteMediaClient.setPlaybackRate(rate)
        }
    }

    func applyPendingCastCommandsToLocalPlayer() -> Bool {
        var didApplyPlaybackCommand = false
        let commands = pendingCastCommands
        pendingCastCommands.removeAll()
        for command in commands {
            switch command {
            case .play:
                player?.play()
                didApplyPlaybackCommand = true
            case .pause:
                player?.pause()
                didApplyPlaybackCommand = true
            case .seek(let time):
                player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
            case .volume(let volume):
                player?.volume = volume
            case .muted(let muted):
                player?.isMuted = muted
            case .rate(let rate):
                player?.rate = rate
                didApplyPlaybackCommand = true
            }
        }
        return didApplyPlaybackCommand
    }

    func makeMediaInformation() -> GCKMediaInformation? {
        guard let url = URL(string: videoUrl) else {
            return nil
        }

        let metadata = GCKMediaMetadata()
        metadata.setString(title ?? url.lastPathComponent, forKey: kGCKMetadataKeyTitle)
        if let smallTitle = smallTitle, !smallTitle.isEmpty {
            metadata.setString(smallTitle, forKey: kGCKMetadataKeySubtitle)
        }
        if let artwork = artwork,
           let artworkUrl = URL(string: artwork) {
            metadata.addImage(GCKImage(url: artworkUrl, width: 480, height: 360))
        }

        let builder = GCKMediaInformationBuilder(contentURL: url)
        builder.streamType = .buffered
        builder.contentType = contentType(for: url)
        builder.metadata = metadata
        if let duration = player?.currentItem?.duration.seconds,
           duration.isFinite,
           duration > 0 {
            builder.streamDuration = duration
        }
        return builder.build()
    }

    func isCurrentVideo(_ mediaInformation: GCKMediaInformation?) -> Bool {
        guard let mediaInformation = mediaInformation else {
            return false
        }
        if mediaInformation.contentID == videoUrl {
            return true
        }
        guard let expectedUrl = URL(string: videoUrl) else {
            return false
        }
        return mediaInformation.contentURL == expectedUrl
    }

    func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m3u8":
            return "application/x-mpegURL"
        case "mpd":
            return "application/dash+xml"
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"
        case "webm":
            return "video/webm"
        case "mp4":
            return "video/mp4"
        default:
            return "video/mp4"
        }
    }

    func resumeLocalPlayback(from session: GCKSession) {
        guard !isDetached,
              isLoadedOnCast else {
            return
        }

        let remoteMediaClient = session.remoteMediaClient
        let position = remoteMediaClient?.approximateStreamPosition() ?? 0
        let shouldResume = remoteMediaClient?.mediaStatus?.playerState == .playing ||
            remoteMediaClient?.mediaStatus?.playerState == .buffering

        isLoadedOnCast = false
        isLoadingOnCast = false
        stopRemoteMediaObservation()
        clearMediaLoadRequest()
        pendingCastCommands.removeAll()
        let seekTime = CMTime(seconds: position, preferredTimescale: 600)
        player?.seek(to: seekTime) { [weak self] _ in
            if shouldResume {
                self?.player?.play()
            }
        }
    }

    func clearMediaLoadRequest() {
        mediaLoadRequest?.delegate = nil
        mediaLoadRequest = nil
    }

    func completeMediaLoadRequest(_ request: GCKRequest) {
        guard request === mediaLoadRequest else {
            return
        }
        clearMediaLoadRequest()
        isLoadingOnCast = false
        isLoadedOnCast = true
        didNotifyRemoteEnd = false
        DispatchQueue.main.async { [weak self] in
            // Reveal the cast indicator and extend the controls visibility window.
            self?.showOverlayControls()
        }
        flushPendingCastCommands()
    }

    func failMediaLoadRequest(_ request: GCKRequest) {
        guard request === mediaLoadRequest else {
            return
        }
        cancelPendingCastHandoff(resumeLocalIfNeeded: true)
    }

    func cancelPendingCastHandoff(resumeLocalIfNeeded: Bool) {
        clearMediaLoadRequest()
        isLoadingOnCast = false
        isLoadedOnCast = false
        if !pendingCastCommands.isEmpty {
            let didApplyPlaybackCommand = applyPendingCastCommandsToLocalPlayer()
            if localWasPlaying && !didApplyPlaybackCommand {
                player?.play()
            }
            return
        }
        if localWasPlaying {
            player?.play()
        } else if resumeLocalIfNeeded {
            player?.pause()
        }
    }

    func shouldHandleRemoteMediaStatus(_ mediaStatus: GCKMediaStatus) -> Bool {
        if isLoadedOnCast || isLoadingOnCast {
            return true
        }
        guard isCurrentVideo(mediaStatus.mediaInformation) else {
            return false
        }
        isLoadedOnCast = true
        return true
    }

    func handleRemoteMediaStatus(_ mediaStatus: GCKMediaStatus?) {
        guard !isDetached,
              let mediaStatus = mediaStatus,
              shouldHandleRemoteMediaStatus(mediaStatus) else {
            return
        }

        switch mediaStatus.playerState {
        case .playing, .buffering:
            didNotifyRemoteEnd = false
            if lastRemoteIsPlaying != true {
                DispatchQueue.main.async { [weak self] in
                    self?.onPlay?()
                }
            }
            lastRemoteIsPlaying = true
        case .paused:
            if lastRemoteIsPlaying == true {
                DispatchQueue.main.async { [weak self] in
                    self?.onPause?()
                }
            }
            lastRemoteIsPlaying = false
        case .idle:
            if mediaStatus.idleReason == .finished,
               !didNotifyRemoteEnd {
                didNotifyRemoteEnd = true
                DispatchQueue.main.async { [weak self] in
                    self?.onEnd?()
                }
            }
            lastRemoteIsPlaying = false
        default:
            break
        }
    }
}

extension VideoPlayerCastController: GCKSessionManagerListener {
    @objc func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        loadMediaIfCastSessionAvailable()
    }

    @objc func sessionManager(_ sessionManager: GCKSessionManager, didResumeSession session: GCKSession) {
        resumeCastSession(session)
    }

    @objc func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        if isLoadedOnCast {
            resumeLocalPlayback(from: session)
        } else if isLoadingOnCast {
            cancelPendingCastHandoff(resumeLocalIfNeeded: true)
        }
    }

    @objc func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKSession, withError error: Error) {
        cancelPendingCastHandoff(resumeLocalIfNeeded: true)
    }
}

extension VideoPlayerCastController: GCKRequestDelegate {
    @objc func requestDidComplete(_ request: GCKRequest) {
        completeMediaLoadRequest(request)
    }

    @objc func request(_ request: GCKRequest, didFailWithError error: GCKError) {
        failMediaLoadRequest(request)
    }

    @objc func request(_ request: GCKRequest, didAbortWith abortReason: GCKRequestAbortReason) {
        failMediaLoadRequest(request)
    }
}

extension VideoPlayerCastController: GCKRemoteMediaClientListener {
    @objc(remoteMediaClient:didUpdateMediaStatus:)
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
        handleRemoteMediaStatus(mediaStatus)
    }
}

#else

final class VideoPlayerCastController {
    var isCasting: Bool {
        return false
    }

    init(videoUrl: String, title: String?, smallTitle: String?, artwork: String?) {
        _ = videoUrl
        _ = title
        _ = smallTitle
        _ = artwork
    }

    func attach(to playerViewController: AVPlayerViewController, player: AVPlayer) {
        _ = playerViewController
        _ = player
    }

    func detach(stopRemoteMedia: Bool) {
        _ = stopRemoteMedia
    }

    func play() -> Bool { return false }
    func pause() -> Bool { return false }
    func isPlaying() -> Bool { return false }
    func getDuration() -> Double { return 0 }
    func getCurrentTime() -> Double { return 0 }
    func setCurrentTime(_ time: Double) -> Bool {
        _ = time
        return false
    }
    func getVolume() -> Float { return 0 }
    func setVolume(_ volume: Float) -> Bool {
        _ = volume
        return false
    }
    func getMuted() -> Bool { return false }
    func setMuted(_ muted: Bool) -> Bool {
        _ = muted
        return false
    }
    func getRate() -> Float { return 0 }
    func setRate(_ rate: Float) -> Bool {
        _ = rate
        return false
    }
    func restartPlayback() -> Bool { return false }
    func setOnPlay(_ callback: @escaping () -> Void) {
        _ = callback
    }
    func setOnPause(_ callback: @escaping () -> Void) {
        _ = callback
    }
    func setOnEnd(_ callback: @escaping () -> Void) {
        _ = callback
    }
}

#endif
