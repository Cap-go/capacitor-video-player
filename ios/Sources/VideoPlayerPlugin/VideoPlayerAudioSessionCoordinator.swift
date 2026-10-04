import AVFoundation
import Foundation

struct VideoPlayerAudioSessionNeeds: Equatable {
    let explicitCategory: String?
    let needsBackgroundOrPipPlayback: Bool
}

enum VideoPlayerAudioSessionCategoryPolicy {
    static func category(for needs: VideoPlayerAudioSessionNeeds) -> String {
        if let explicitCategory = needs.explicitCategory {
            let trimmed = explicitCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        if needs.needsBackgroundOrPipPlayback {
            return "playback"
        }
        return "ambient"
    }

    static func unionCategory(for players: [VideoPlayerAudioSessionNeeds]) -> String {
        guard !players.isEmpty else {
            return "ambient"
        }
        let categories = players.map(category(for:))
        if categories.contains("moviePlayback") {
            return "moviePlayback"
        }
        if categories.contains("playback") {
            return "playback"
        }
        return "ambient"
    }
}

enum VideoPlayerAudioSessionCoordinator {
    private static let lock = NSLock()
    private static var activeRegistrations: [UUID: VideoPlayerAudioSessionNeeds] = [:]

    static func acquire(registrationId: UUID, needs: VideoPlayerAudioSessionNeeds) throws {
        lock.lock()
        defer { lock.unlock() }

        let wasEmpty = activeRegistrations.isEmpty
        var stagedRegistrations = activeRegistrations
        stagedRegistrations[registrationId] = needs

        try applyCategory(for: stagedRegistrations.values)
        if wasEmpty {
            try AVAudioSession.sharedInstance().setActive(true)
        }
        activeRegistrations = stagedRegistrations
    }

    static func release(registrationId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        activeRegistrations.removeValue(forKey: registrationId)
        if activeRegistrations.isEmpty {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                print("Error deactivating AVAudioSession: \(error)")
            }
            return
        }

        do {
            try applyCategory(for: activeRegistrations.values)
        } catch {
            print("Error reconfiguring AVAudioSession after player exit: \(error)")
        }
    }

    private static func applyCategory(for players: some Collection<VideoPlayerAudioSessionNeeds>) throws {
        let resolvedCategory = VideoPlayerAudioSessionCategoryPolicy.unionCategory(for: Array(players))
        let session = AVAudioSession.sharedInstance()
        switch resolvedCategory {
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
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        }
    }
}
