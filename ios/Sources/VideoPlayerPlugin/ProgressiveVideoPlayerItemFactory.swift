import AVFoundation
import Foundation

enum ProgressiveVideoPlayerItemFactory {
    static func createPlayerItem(
        videoAsset: AVURLAsset,
        subtitleTracks: [VideoSubtitleTrack]
    ) async -> AVPlayerItem {
        let resolvedTracks = subtitleTracks.compactMap { track -> (URL, String?)? in
            guard let url = track.resolvedURL else { return nil }
            return (url, track.language)
        }

        guard !resolvedTracks.isEmpty else {
            return AVPlayerItem(asset: videoAsset)
        }

        do {
            let videoDuration = try await videoAsset.load(.duration)
            let composition = AVMutableComposition()

            try await insertTracks(
                from: videoAsset,
                mediaTypes: [.video, .audio],
                duration: videoDuration,
                into: composition
            )

            let hasPlayableTracks = composition.tracks.contains {
                $0.mediaType == .video || $0.mediaType == .audio
            }
            if !hasPlayableTracks {
                return AVPlayerItem(asset: videoAsset)
            }

            var preferredLanguage: String?
            var subtitleAdded = false

            for (index, track) in resolvedTracks.enumerated() {
                let subtitleAsset = AVURLAsset(url: track.0)
                let subtitleMediaTracks = try await subtitleAsset.loadTracks(withMediaType: .text)
                guard let subtitleTrack = subtitleMediaTracks.first else { continue }

                let compositionTrack = composition.addMutableTrack(
                    withMediaType: .text,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                let subtitleDuration = try await subtitleAsset.load(.duration)
                let duration = CMTimeCompare(subtitleDuration, videoDuration) < 0 ? subtitleDuration : videoDuration
                try compositionTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: subtitleTrack,
                    at: CMTime.zero
                )

                if let language = track.1, !language.isEmpty {
                    compositionTrack?.extendedLanguageTag = language
                    if preferredLanguage == nil {
                        preferredLanguage = language
                    }
                }

                // Keep first track as default selection preference
                if index == 0, preferredLanguage == nil {
                    preferredLanguage = track.1
                }
                subtitleAdded = true
            }

            let playerItem = AVPlayerItem(asset: composition)

            if subtitleAdded {
                selectSubtitle(in: playerItem, language: preferredLanguage)
            }

            return playerItem
        } catch {
            return AVPlayerItem(asset: videoAsset)
        }
    }

    private static func selectSubtitle(in playerItem: AVPlayerItem, language: String?) {
        guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return
        }

        let selectedOption = selectSubtitleOption(in: group, language: language)
            ?? group.defaultOption
            ?? group.options.first

        if let selectedOption {
            playerItem.select(selectedOption, in: group)
        }
    }

    private static func insertTracks(
        from asset: AVURLAsset,
        mediaTypes: [AVMediaType],
        duration: CMTime,
        into composition: AVMutableComposition
    ) async throws {
        for mediaType in mediaTypes {
            let tracks = try await asset.loadTracks(withMediaType: mediaType)
            guard let sourceTrack = tracks.first else { continue }

            let compositionTrack = composition.addMutableTrack(
                withMediaType: mediaType,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try compositionTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: sourceTrack,
                at: .zero
            )
        }
    }

    private static func selectSubtitleOption(in group: AVMediaSelectionGroup, language: String?) -> AVMediaSelectionOption? {
        guard let language, !language.isEmpty else { return nil }

        return group.options.first { option in
            option.extendedLanguageTag == language
                || option.locale?.identifier == language
                || option.locale?.languageCode == language
        }
    }
}
