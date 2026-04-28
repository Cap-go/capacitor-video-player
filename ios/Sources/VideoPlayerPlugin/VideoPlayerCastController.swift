import AVFoundation
import AVKit
import Foundation
import UIKit

#if canImport(GoogleCast)
import GoogleCast

final class VideoPlayerCastController: NSObject {
    private let receiverAppId: String?
    private let videoUrl: String
    private let title: String?
    private let smallTitle: String?
    private let artwork: String?

    private weak var player: AVPlayer?
    private weak var playerViewController: AVPlayerViewController?
    private weak var castButton: GCKUICastButton?
    private var mediaLoadRequest: GCKRequest?
    private var isLoadedOnCast = false
    private var isLoadingOnCast = false
    private var localWasPlaying = false
    private var isDetached = false

    var isCasting: Bool {
        return remoteMediaClient != nil && isLoadedOnCast
    }

    private var remoteMediaClient: GCKRemoteMediaClient? {
        guard GCKCastContext.isSharedInstanceInitialized() else {
            return nil
        }
        return GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient
    }

    init(receiverAppId: String?, videoUrl: String, title: String?, smallTitle: String?, artwork: String?) {
        self.receiverAppId = receiverAppId
        self.videoUrl = videoUrl
        self.title = title
        self.smallTitle = smallTitle
        self.artwork = artwork
        super.init()
    }

    func attach(to playerViewController: AVPlayerViewController, player: AVPlayer) {
        self.playerViewController = playerViewController
        self.player = player

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  Self.configureCastContext(receiverAppId: self.receiverAppId) else {
                return
            }

            GCKCastContext.sharedInstance().sessionManager.add(self)
            self.addCastButton(to: playerViewController)
            self.loadMediaIfCastSessionAvailable()
        }
    }

    func detach(stopRemoteMedia: Bool) {
        guard !isDetached else {
            return
        }
        isDetached = true
        clearMediaLoadRequest()

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  GCKCastContext.isSharedInstanceInitialized() else {
                return
            }

            if stopRemoteMedia {
                self.remoteMediaClient?.stop()
            }

            GCKCastContext.sharedInstance().sessionManager.remove(self)
            self.castButton?.removeFromSuperview()
            self.castButton = nil
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
            return isLoadingOnCast
        }
        remoteMediaClient.play()
        return true
    }

    func pause() -> Bool {
        guard let remoteMediaClient = remoteMediaClient else {
            return false
        }
        guard isLoadedOnCast else {
            return isLoadingOnCast
        }
        remoteMediaClient.pause()
        return true
    }

    func setCurrentTime(_ time: Double) -> Bool {
        guard let remoteMediaClient = remoteMediaClient, isLoadedOnCast else {
            return isLoadingOnCast
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
        guard let remoteMediaClient = remoteMediaClient, isLoadedOnCast else {
            return isLoadingOnCast
        }
        remoteMediaClient.setStreamVolume(volume)
        return true
    }

    func getMuted() -> Bool {
        return remoteMediaClient?.mediaStatus?.isMuted ?? false
    }

    func setMuted(_ muted: Bool) -> Bool {
        guard let remoteMediaClient = remoteMediaClient, isLoadedOnCast else {
            return isLoadingOnCast
        }
        remoteMediaClient.setStreamMuted(muted)
        return true
    }

    func getRate() -> Float {
        return remoteMediaClient?.mediaStatus?.playbackRate ?? 0
    }

    func setRate(_ rate: Float) -> Bool {
        guard let remoteMediaClient = remoteMediaClient, isLoadedOnCast else {
            return isLoadingOnCast
        }
        remoteMediaClient.setPlaybackRate(rate)
        return true
    }

    private static func configureCastContext(receiverAppId: String?) -> Bool {
        guard Thread.isMainThread else {
            return false
        }

        if GCKCastContext.isSharedInstanceInitialized() {
            return configuredReceiverAppId == resolvedReceiverAppId(receiverAppId)
        }

        let appId = resolvedReceiverAppId(receiverAppId)

        let criteria = GCKDiscoveryCriteria(applicationID: appId)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        var error: GCKError?
        let configured = GCKCastContext.setSharedInstanceWith(options, error: &error)
        if configured {
            configuredReceiverAppId = appId
        }
        return configured
    }

    private static var configuredReceiverAppId: String?

    private static func resolvedReceiverAppId(_ receiverAppId: String?) -> String {
        let trimmedReceiverAppId = receiverAppId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedReceiverAppId = trimmedReceiverAppId, !trimmedReceiverAppId.isEmpty {
            return trimmedReceiverAppId
        }
        return kGCKDefaultMediaReceiverApplicationID
    }

    private func addCastButton(to playerViewController: AVPlayerViewController) {
        guard castButton == nil,
              let overlayView = playerViewController.contentOverlayView else {
            return
        }

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
            button.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])

        castButton = button
    }

    private func loadMediaIfCastSessionAvailable() {
        guard let remoteMediaClient = remoteMediaClient,
              let mediaInfo = makeMediaInformation() else {
            return
        }

        let playPosition = player?.currentTime().seconds ?? 0
        localWasPlaying = (player?.rate ?? 0) > 0
        player?.pause()
        isLoadedOnCast = false
        isLoadingOnCast = true
        clearMediaLoadRequest()

        let mediaLoadRequestDataBuilder = GCKMediaLoadRequestDataBuilder()
        mediaLoadRequestDataBuilder.mediaInformation = mediaInfo
        mediaLoadRequestDataBuilder.autoplay = NSNumber(value: localWasPlaying)
        mediaLoadRequestDataBuilder.startTime = playPosition.isFinite ? playPosition : 0
        let request = remoteMediaClient.loadMedia(with: mediaLoadRequestDataBuilder.build())
        request.delegate = self
        mediaLoadRequest = request
    }

    private func makeMediaInformation() -> GCKMediaInformation? {
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

    private func contentType(for url: URL) -> String {
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

    private func resumeLocalPlayback(from session: GCKSession) {
        guard !isDetached,
              isLoadedOnCast else {
            return
        }

        let remoteMediaClient = session.remoteMediaClient
        let position = remoteMediaClient?.approximateStreamPosition() ?? 0
        let shouldResume = remoteMediaClient?.mediaStatus?.playerState == .playing ||
            remoteMediaClient?.mediaStatus?.playerState == .buffering

        isLoadedOnCast = false
        let seekTime = CMTime(seconds: position, preferredTimescale: 600)
        player?.seek(to: seekTime) { [weak self] _ in
            if shouldResume || self?.localWasPlaying == true {
                self?.player?.play()
            }
        }
    }

    private func clearMediaLoadRequest() {
        mediaLoadRequest?.delegate = nil
        mediaLoadRequest = nil
    }

    private func completeMediaLoadRequest(_ request: GCKRequest) {
        guard request === mediaLoadRequest else {
            return
        }
        clearMediaLoadRequest()
        isLoadingOnCast = false
        isLoadedOnCast = true
    }

    private func failMediaLoadRequest(_ request: GCKRequest) {
        guard request === mediaLoadRequest else {
            return
        }
        clearMediaLoadRequest()
        isLoadingOnCast = false
        isLoadedOnCast = false
        if localWasPlaying {
            player?.play()
        }
    }
}

extension VideoPlayerCastController: GCKSessionManagerListener {
    @objc func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        loadMediaIfCastSessionAvailable()
    }

    @objc func sessionManager(_ sessionManager: GCKSessionManager, didResumeSession session: GCKSession) {
        loadMediaIfCastSessionAvailable()
    }

    @objc func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        resumeLocalPlayback(from: session)
    }

    @objc func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKSession, withError error: Error) {
        isLoadedOnCast = false
        if localWasPlaying {
            player?.play()
        }
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

#else

final class VideoPlayerCastController {
    var isCasting: Bool {
        return false
    }

    init(receiverAppId: String?, videoUrl: String, title: String?, smallTitle: String?, artwork: String?) {
        _ = receiverAppId
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
}

#endif
