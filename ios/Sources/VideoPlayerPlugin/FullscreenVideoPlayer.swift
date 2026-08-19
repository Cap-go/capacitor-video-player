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
    private var didEmitReady: Bool = false
    private var exitEmission = ExitEmissionGuard()
    private var isTransitioningToPictureInPicture = false
    private var suppressDismissExit = false
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
    private var subtitleButton: UIButton?
    private var subtitleSelectionObserver: NSObjectProtocol?
    private var nonHlsSubtitleModeEnabled: Bool = false
    private var selectedNonHlsSubtitleIndex: Int? = nil
    private var nonHlsBootstrapLoadId: UUID?

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
        guard let url = Self.resolveMediaURL(videoUrl) else {
            completion()
            return
        }

        configureAudioSession()

        let resolvedTracks = subtitleTracks.compactMap { track -> (URL, String?)? in
            guard let subtitleURL = track.resolvedURL else { return nil }
            return (subtitleURL, track.language)
        }
        let isLikelyHlsSource = Self.isLikelyHLS(videoUrl)

        guard !resolvedTracks.isEmpty else {
            nonHlsSubtitleModeEnabled = false
            selectedNonHlsSubtitleIndex = nil
            nonHlsBootstrapLoadId = nil
            let asset = makeVideoAsset(url: url, subtitleTracks: [])
            configurePlayer(with: AVPlayerItem(asset: asset))
            completion()
            return
        }

        // For non-HLS media (e.g. MP4 + sidecar subtitles), initialize with only the
        // first usable subtitle track and switch tracks later via the custom subtitle button.
        if !isLikelyHlsSource {
            nonHlsSubtitleModeEnabled = true
            let firstValidIndex = validNonHlsSubtitleTracks.first?.index
            selectedNonHlsSubtitleIndex = firstValidIndex
            let baseAsset = makeVideoAsset(url: url, subtitleTracks: [])
            configurePlayer(with: AVPlayerItem(asset: baseAsset))
            completion()

            guard let firstValidIndex else {
                return
            }

            let bootstrapLoadId = UUID()
            nonHlsBootstrapLoadId = bootstrapLoadId

            Task { [weak self] in
                guard let self else { return }
                let initialTrack = [self.subtitleTracks[firstValidIndex]]
                let item = await ProgressiveVideoPlayerItemFactory.createPlayerItem(
                    videoAsset: baseAsset,
                    subtitleTracks: initialTrack
                )
                await MainActor.run {
                    guard self.nonHlsSubtitleModeEnabled,
                          self.nonHlsBootstrapLoadId == bootstrapLoadId,
                          self.selectedNonHlsSubtitleIndex == firstValidIndex else {
                        return
                    }
                    self.replaceCurrentItemPreservingPlayback(with: item)
                    self.refreshSubtitleButton()
                }
            }
            return
        }

        nonHlsSubtitleModeEnabled = false
        selectedNonHlsSubtitleIndex = nil
        nonHlsBootstrapLoadId = nil

        // Prefer the resource-loader path when makeAsset can safely wrap the stream
        // (HLS / remote progressive). Local progressive file:// sources return a nil
        // loader and must use composition so playback still starts (#78).
        let assetResult = HLSVideoAssetFactory.makeAsset(
            videoURL: url,
            subtitleTracks: subtitleTracks
        )
        hlsResourceLoader = assetResult.resourceLoader
        if assetResult.resourceLoader != nil {
            let asset = applyFairPlayIfNeeded(to: assetResult.asset)
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

    private static func resolveMediaURL(_ raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        if let parsed = URL(string: raw), parsed.scheme != nil {
            return parsed
        }
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw)
        }
        return URL(string: raw)
    }

    private func makeVideoAsset(url: URL, subtitleTracks: [VideoSubtitleTrack]) -> AVURLAsset {
        let result = HLSVideoAssetFactory.makeAsset(
            videoURL: url,
            subtitleTracks: subtitleTracks
        )
        hlsResourceLoader = result.resourceLoader
        return applyFairPlayIfNeeded(to: result.asset)
    }

    private func applyFairPlayIfNeeded(to asset: AVURLAsset) -> AVURLAsset {
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

        let playerVC = DismissObservingPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = showControls
        playerVC.allowsPictureInPicturePlayback = pipEnabled
        playerVC.delegate = self
        playerVC.shouldReportDismiss = { [weak self] in
            guard let self else { return true }
            return !self.isTransitioningToPictureInPicture && !self.suppressDismissExit
        }
        playerVC.onDismiss = { [weak self] in
            self?.emitExitIfNeeded()
        }
        playerVC.adaptivePresentationDelegate = self
        playerViewController = playerVC

        setupChromecast()
        setupObservers()
        setupSubtitleSelectionObserver()
    }

    private func setupSubtitleSelectionObserver() {
        guard subtitleSelectionObserver == nil, let playerItem else { return }
        subtitleSelectionObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.mediaSelectionDidChangeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.refreshSubtitleButton()
        }
    }

    private static func isLikelyHLS(_ value: String) -> Bool {
        guard let url = resolveMediaURL(value) else { return false }
        return HLSVideoAssetFactory.isHLSStream(url)
    }

    private var validNonHlsSubtitleTracks: [(index: Int, track: VideoSubtitleTrack)] {
        subtitleTracks.enumerated().compactMap { index, track in
            guard track.resolvedURL != nil else { return nil }
            return (index, track)
        }
    }

    private func shouldShowCustomSubtitleButton() -> Bool {
        guard showControls else { return false }
        // HLS usually has native subtitle selection UI; this custom button targets MP4 + sidecar subtitles.
        return !Self.isLikelyHLS(videoUrl)
    }

    private func shouldShowNonHlsSubtitleButton() -> Bool {
        return nonHlsSubtitleModeEnabled && validNonHlsSubtitleTracks.count > 1 && shouldShowCustomSubtitleButton()
    }

    private func refreshSubtitleButton() {
        DispatchQueue.main.async { [weak self] in
            self?.installOrUpdateSubtitleButtonIfNeeded()
        }
    }

    private func installOrUpdateSubtitleButtonIfNeeded() {
        guard shouldShowCustomSubtitleButton(),
              let playerVC = playerViewController else {
            subtitleButton?.removeFromSuperview()
            subtitleButton = nil
            return
        }

        if subtitleButton == nil {
            guard let overlayView = playerVC.contentOverlayView else {
                return
            }
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            if #available(iOS 13.0, *) {
                button.setImage(UIImage(systemName: "captions.bubble"), for: .normal)
            } else {
                button.setTitle("Sub", for: .normal)
            }
            button.tintColor = .white
            button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            button.layer.cornerRadius = 22
            button.clipsToBounds = true
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center

            if #available(iOS 14.0, *) {
                button.showsMenuAsPrimaryAction = true
            } else {
                button.addTarget(self, action: #selector(showSubtitleActionSheet), for: .touchUpInside)
            }

            overlayView.addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 60),
                button.leadingAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                button.widthAnchor.constraint(equalToConstant: 44),
                button.heightAnchor.constraint(equalToConstant: 44)
            ])
            subtitleButton = button
        }
        subtitleButton?.isHidden = false
        subtitleButton?.alpha = 1

        if shouldShowNonHlsSubtitleButton() {
            if #available(iOS 14.0, *) {
                subtitleButton?.menu = buildNonHlsSubtitleMenu()
            }
            updateNonHlsSubtitleButtonAccessibility()
            return
        }

        guard let playerItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible),
              !group.options.isEmpty else {
            subtitleButton?.removeFromSuperview()
            subtitleButton = nil
            return
        }

        if #available(iOS 14.0, *) {
            subtitleButton?.menu = buildSubtitleMenu(group: group)
        }
        updateSubtitleButtonAccessibility(group: group)
    }

    private func updateSubtitleButtonAccessibility(group: AVMediaSelectionGroup) {
        let selectedOption = playerItem?.selectedMediaOption(in: group)
        let currentTitle = selectedOption.map(Self.subtitleDisplayName) ?? "Off"
        subtitleButton?.accessibilityLabel = "Subtitles"
        subtitleButton?.accessibilityValue = currentTitle
    }

    @available(iOS 14.0, *)
    private func buildSubtitleMenu(group: AVMediaSelectionGroup) -> UIMenu {
        let selectedOption = playerItem?.selectedMediaOption(in: group)

        let offAction = UIAction(
            title: "Off",
            state: selectedOption == nil ? .on : .off
        ) { [weak self] _ in
            guard let self, let playerItem = self.playerItem else { return }
            playerItem.select(nil, in: group)
            self.refreshSubtitleButton()
        }

        let trackActions = group.options.map { option in
            UIAction(
                title: Self.subtitleDisplayName(option),
                state: option == selectedOption ? .on : .off
            ) { [weak self] _ in
                guard let self, let playerItem = self.playerItem else { return }
                playerItem.select(option, in: group)
                self.refreshSubtitleButton()
            }
        }

        return UIMenu(title: "Subtitles", children: [offAction] + trackActions)
    }

    @available(iOS 14.0, *)
    private func buildNonHlsSubtitleMenu() -> UIMenu {
        let offAction = UIAction(
            title: "Off",
            state: selectedNonHlsSubtitleIndex == nil ? .on : .off
        ) { [weak self] _ in
            self?.switchNonHlsSubtitleTrack(index: nil)
        }

        let trackActions = validNonHlsSubtitleTracks.map { index, track in
            UIAction(
                title: Self.nonHlsSubtitleDisplayName(track: track, index: index),
                state: selectedNonHlsSubtitleIndex == index ? .on : .off
            ) { [weak self] _ in
                self?.switchNonHlsSubtitleTrack(index: index)
            }
        }

        return UIMenu(title: "Subtitles", children: [offAction] + trackActions)
    }

    @objc
    private func showSubtitleActionSheet() {
        if shouldShowNonHlsSubtitleButton() {
            showNonHlsSubtitleActionSheet()
            return
        }

        guard let playerVC = playerViewController,
              let playerItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible),
              !group.options.isEmpty else {
            return
        }

        let sheet = UIAlertController(title: "Subtitles", message: nil, preferredStyle: .actionSheet)
        let selectedOption = playerItem.selectedMediaOption(in: group)

        let offTitle = selectedOption == nil ? "Off ✓" : "Off"
        sheet.addAction(UIAlertAction(title: offTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            playerItem.select(nil, in: group)
            self.refreshSubtitleButton()
        })

        for option in group.options {
            let isSelected = option == selectedOption
            let title = isSelected ? "\(Self.subtitleDisplayName(option)) ✓" : Self.subtitleDisplayName(option)
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self else { return }
                playerItem.select(option, in: group)
                self.refreshSubtitleButton()
            })
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController,
           let subtitleButton {
            popover.sourceView = subtitleButton
            popover.sourceRect = subtitleButton.bounds
        }
        playerVC.present(sheet, animated: true)
    }

    private func showNonHlsSubtitleActionSheet() {
        guard let playerVC = playerViewController else { return }

        let sheet = UIAlertController(title: "Subtitles", message: nil, preferredStyle: .actionSheet)
        let offTitle = selectedNonHlsSubtitleIndex == nil ? "Off ✓" : "Off"
        sheet.addAction(UIAlertAction(title: offTitle, style: .default) { [weak self] _ in
            self?.switchNonHlsSubtitleTrack(index: nil)
        })

        for (index, track) in validNonHlsSubtitleTracks {
            let isSelected = selectedNonHlsSubtitleIndex == index
            let label = Self.nonHlsSubtitleDisplayName(track: track, index: index)
            let title = isSelected ? "\(label) ✓" : label
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.switchNonHlsSubtitleTrack(index: index)
            })
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController,
           let subtitleButton {
            popover.sourceView = subtitleButton
            popover.sourceRect = subtitleButton.bounds
        }
        playerVC.present(sheet, animated: true)
    }

    private static func subtitleDisplayName(_ option: AVMediaSelectionOption) -> String {
        let optionDisplayName = option.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !optionDisplayName.isEmpty {
            return localizedLanguageName(from: optionDisplayName) ?? optionDisplayName
        }
        if let tag = option.extendedLanguageTag, !tag.isEmpty {
            return localizedLanguageName(from: tag) ?? tag
        }
        if let localeId = option.locale?.identifier, !localeId.isEmpty {
            return localizedLanguageName(from: localeId) ?? localeId
        }
        return "Unknown"
    }

    private static func nonHlsSubtitleDisplayName(track: VideoSubtitleTrack, index: Int) -> String {
        if let language = track.language?.trimmingCharacters(in: .whitespacesAndNewlines),
           !language.isEmpty {
            return localizedLanguageName(from: language) ?? language
        }
        return "Subtitle \(index + 1)"
    }

    private static func localizedLanguageName(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: "_", with: "-")

        if let identifierName = Locale.current.localizedString(forIdentifier: normalized),
           !identifierName.isEmpty,
           identifierName.caseInsensitiveCompare(trimmed) != .orderedSame {
            return identifierName
        }

        if let languageCodeName = Locale.current.localizedString(forLanguageCode: normalized.lowercased()),
           !languageCodeName.isEmpty,
           languageCodeName.caseInsensitiveCompare(trimmed) != .orderedSame {
            return languageCodeName
        }

        return nil
    }

    private func updateNonHlsSubtitleButtonAccessibility() {
        let title: String
        if let index = selectedNonHlsSubtitleIndex,
           subtitleTracks.indices.contains(index) {
            title = Self.nonHlsSubtitleDisplayName(track: subtitleTracks[index], index: index)
        } else {
            title = "Off"
        }
        subtitleButton?.accessibilityLabel = "Subtitles"
        subtitleButton?.accessibilityValue = title
    }

    private func switchNonHlsSubtitleTrack(index: Int?) {
        guard nonHlsSubtitleModeEnabled,
              selectedNonHlsSubtitleIndex != index else {
            refreshSubtitleButton()
            return
        }
        guard let videoURL = Self.resolveMediaURL(videoUrl) else { return }

        if let index, !validNonHlsSubtitleTracks.contains(where: { $0.index == index }) {
            return
        }

        selectedNonHlsSubtitleIndex = index
        nonHlsBootstrapLoadId = nil

        Task {
            let baseAsset = makeVideoAsset(url: videoURL, subtitleTracks: [])
            let trackSelection: [VideoSubtitleTrack]
            if let index {
                trackSelection = [subtitleTracks[index]]
            } else {
                trackSelection = []
            }

            let newItem = await ProgressiveVideoPlayerItemFactory.createPlayerItem(
                videoAsset: baseAsset,
                subtitleTracks: trackSelection
            )

            await MainActor.run {
                guard self.nonHlsSubtitleModeEnabled,
                      self.selectedNonHlsSubtitleIndex == index else {
                    return
                }
                self.replaceCurrentItemPreservingPlayback(with: newItem)
                self.refreshSubtitleButton()
            }
        }
    }

    private func replaceCurrentItemPreservingPlayback(with newItem: AVPlayerItem) {
        guard let player else { return }

        let previousTime = player.currentTime()
        let wasPlaying = player.rate > 0
        let targetRate = rate

        let oldItem = playerItem
        removePlayerItemObservers(oldItem)
        playerItem = newItem
        player.replaceCurrentItem(with: newItem)
        addPlayerItemObservers(newItem)
        setupSubtitleSelectionObserver()

        player.seek(to: previousTime) { _ in
            if wasPlaying {
                player.play()
                player.rate = targetRate
            }
        }
    }

    private func addPlayerItemObservers(_ item: AVPlayerItem) {
        item.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    private func removePlayerItemObservers(_ item: AVPlayerItem?) {
        guard let item else { return }
        item.removeObserver(self, forKeyPath: "status")
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        if let subtitleSelectionObserver {
            NotificationCenter.default.removeObserver(subtitleSelectionObserver)
            self.subtitleSelectionObserver = nil
        }
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

        if let playerItem {
            addPlayerItemObservers(playerItem)
        }

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
                    refreshSubtitleButton()
                    emitReadyIfNeeded()
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
            self.refreshSubtitleButton()
            self.castController?.installOverlayIfNeeded()
            self.play()
            completion()
        }
        configurePresentationDelegate(for: playerVC)
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
            completion()
        }
        configurePresentationDelegate(for: playerVC)
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
        suppressDismissExit = true
        playerVC.dismiss(animated: true) { [weak self] in
            self?.suppressDismissExit = false
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
        nonHlsBootstrapLoadId = nil
        castController?.detach(stopRemoteMedia: stopRemoteMedia)
        castController = nil
        if let subtitleSelectionObserver {
            NotificationCenter.default.removeObserver(subtitleSelectionObserver)
            self.subtitleSelectionObserver = nil
        }
        subtitleButton?.removeFromSuperview()
        subtitleButton = nil
        contentKeySession?.setDelegate(nil, queue: nil)
        contentKeySession = nil
        hlsResourceLoader = nil
        if let observer = timeObserver {
            player?.removeObserver(self, forKeyPath: "rate")
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        removePlayerItemObservers(playerItem)
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

    private func configurePresentationDelegate(for playerVC: UIViewController) {
        playerVC.presentationController?.delegate = self
    }

    private func emitExitIfNeeded(currentTime: Double? = nil) {
        exitEmission.emitIfNeeded {
            let time = currentTime ?? getCurrentTime()
            cleanup(stopRemoteMedia: true)
            onExit?(time)
        }
    }

    private func emitReadyIfNeeded() {
        guard !didEmitReady, let onReady else { return }
        didEmitReady = true
        onReady()
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
        if playerItem?.status == .readyToPlay {
            emitReadyIfNeeded()
        }
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

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isTransitioningToPictureInPicture = true
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isTransitioningToPictureInPicture = false
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
