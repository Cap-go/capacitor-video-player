import AVFoundation
import Foundation

enum ProgressiveVideoPlayerItemFactory {
    static func createPlayerItem(
        videoAsset: AVURLAsset,
        subtitleURL: URL,
        subtitleLanguage: String?
    ) async -> AVPlayerItem {
        let subtitleAsset = AVURLAsset(url: subtitleURL)

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

            var subtitleAdded = false
            let subtitleTracks = try await subtitleAsset.loadTracks(withMediaType: .text)
            if let subtitleTrack = subtitleTracks.first {
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
                subtitleAdded = true
            }

            let playerItem = AVPlayerItem(asset: composition)

            if subtitleAdded {
                selectSubtitle(in: playerItem, language: subtitleLanguage)
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
