import Foundation

struct VideoSubtitleTrack {
    let url: String
    let language: String?

    var resolvedURL: URL? {
        guard !url.isEmpty else { return nil }
        return URL(string: url)
    }
}

enum VideoSubtitleTrackParser {
    static func parse(from callSubtitles: [[String: Any]]?, legacySubtitle: String?, legacyLanguage: String?) -> [VideoSubtitleTrack] {
        if let callSubtitles, !callSubtitles.isEmpty {
            return callSubtitles.compactMap { entry in
                guard let subtitle = entry["subtitle"] as? String, !subtitle.isEmpty else {
                    return nil
                }
                let language = entry["language"] as? String
                return VideoSubtitleTrack(url: subtitle, language: language)
            }
        }

        guard let legacySubtitle, !legacySubtitle.isEmpty else {
            return []
        }

        return [VideoSubtitleTrack(url: legacySubtitle, language: legacyLanguage)]
    }
}
