import AVFoundation
import Foundation
import UniformTypeIdentifiers

enum HLSVideoAssetFactory {
    static func isHLSStream(_ url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        let path = url.path.lowercased()

        return path.hasSuffix(".m3u8")
            || urlString.contains(".m3u8")
            || urlString.contains("mpegurl")
            || urlString.contains("hls_playlist")
            || urlString.contains("hls_manifest")
    }

    static func makeAsset(
        videoURL: URL,
        subtitleTracks: [VideoSubtitleTrack]
    ) -> (asset: AVURLAsset, resourceLoader: HLSSubtitleResourceLoader?) {
        var resolvedTracks: [(url: URL, language: String)] = []
        for track in subtitleTracks {
            guard let subtitleURL = track.resolvedURL else { continue }
            resolvedTracks.append((url: subtitleURL, language: track.language ?? "en"))
        }

        // Use the resource loader whenever sidecar subtitles are present so
        // AVPlayerViewController can expose a native multi-language picker.
        // AVMutableComposition can play one track but does not reliably expose
        // selectable legible media-selection options.
        guard !resolvedTracks.isEmpty else {
            return (AVURLAsset(url: videoURL), nil)
        }

        let resourceLoader = HLSSubtitleResourceLoader(
            videoURL: videoURL,
            subtitleTracks: resolvedTracks.map { HLSSubtitleTrack(url: $0.url, language: $0.language) },
            isProgressive: !isHLSStream(videoURL)
        )
        guard let assetURL = HLSSubtitleResourceLoader.assetURL(for: videoURL) else {
            return (AVURLAsset(url: videoURL), nil)
        }

        let asset = AVURLAsset(url: assetURL)
        asset.resourceLoader.setDelegate(resourceLoader, queue: DispatchQueue.global(qos: .userInitiated))
        return (asset, resourceLoader)
    }
}

struct HLSSubtitleTrack {
    let url: URL
    let language: String
}

/// Injects external WebVTT subtitles into playlists via AVAssetResourceLoaderDelegate.
///
/// - HLS multivariant playlists: inject `#EXT-X-MEDIA` subtitle tags.
/// - HLS media playlists: wrap in a synthetic multivariant playlist that references the media playlist.
/// - Progressive MP4/WebM: synthesize a multivariant + media playlist so multiple sidecar
///   tracks appear in AVPlayerViewController's subtitle options.
final class HLSSubtitleResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    static let videoScheme = "capgohls"
    static let mediaPlaylistScheme = "capgohls-media"
    static let subtitlePlaylistScheme = "capgohls-sub"
    private static let subtitleGroupID = "capgosubs"
    private static let mpegURLContentType = UTType.m3uPlaylist.identifier
    private static let progressiveSegmentDuration = 86400.0

    private let originalVideoURL: URL
    private let subtitleTracks: [HLSSubtitleTrack]
    private let isProgressive: Bool

    private struct LoadedResource {
        let data: Data
        let contentType: String?
    }

    init(videoURL: URL, subtitleTracks: [HLSSubtitleTrack], isProgressive: Bool = false) {
        self.originalVideoURL = videoURL
        self.subtitleTracks = subtitleTracks
        self.isProgressive = isProgressive
    }

    static func assetURL(for videoURL: URL) -> URL? {
        guard var components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = videoScheme
        return components.url
    }

    static func mediaPlaylistURL(for videoURL: URL) -> URL? {
        guard var components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = mediaPlaylistScheme
        return components.url
    }

    static func subtitlePlaylistURL(for videoURL: URL, index: Int) -> URL? {
        guard var components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = subtitlePlaylistScheme
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "capgoSubIndex", value: String(index)))
        components.queryItems = queryItems
        return components.url
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let requestURL = loadingRequest.request.url else {
            return false
        }

        Task {
            do {
                let resource = try await loadData(for: requestURL)
                fulfill(loadingRequest, with: resource)
            } catch {
                loadingRequest.finishLoading(with: error)
            }
        }

        return true
    }

    private func loadData(for requestURL: URL) async throws -> LoadedResource {
        if requestURL.scheme == Self.subtitlePlaylistScheme {
            let index = subtitleIndex(from: requestURL) ?? 0
            let track = subtitleTracks[min(max(index, 0), subtitleTracks.count - 1)]
            let data = Data(Self.subtitleMediaPlaylist(for: track.url).utf8)
            return LoadedResource(data: data, contentType: Self.mpegURLContentType)
        }

        if requestURL.scheme == Self.mediaPlaylistScheme {
            let data = Data(Self.progressiveMediaPlaylist(for: originalVideoURL).utf8)
            return LoadedResource(data: data, contentType: Self.mpegURLContentType)
        }

        if isProgressive {
            let playlist = Self.multivariantPlaylist(
                mediaURI: Self.mediaPlaylistURL(for: originalVideoURL)?.absoluteString
                    ?? originalVideoURL.absoluteString,
                subtitleTracks: subtitleTracks,
                videoURL: originalVideoURL
            )
            return LoadedResource(data: Data(playlist.utf8), contentType: Self.mpegURLContentType)
        }

        let fetchURL = originalURL(for: requestURL)
        let (data, response) = try await URLSession.shared.data(from: fetchURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let manifest = String(data: data, encoding: .utf8) ?? ""

        if hasStreamInfTags(manifest) {
            let modified = injectSubtitles(
                into: manifest,
                baseURL: response.url ?? fetchURL
            )
            return LoadedResource(data: Data(modified.utf8), contentType: Self.mpegURLContentType)
        }

        // Media playlist (no variants): wrap in a multivariant playlist so subtitle tags are selectable.
        let mediaURI = (response.url ?? fetchURL).absoluteString
        let playlist = Self.multivariantPlaylist(
            mediaURI: mediaURI,
            subtitleTracks: subtitleTracks,
            videoURL: originalVideoURL
        )
        return LoadedResource(data: Data(playlist.utf8), contentType: Self.mpegURLContentType)
    }

    private func subtitleIndex(from requestURL: URL) -> Int? {
        guard let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "capgoSubIndex" })?.value else {
            return nil
        }
        return Int(value)
    }

    private func originalURL(for requestURL: URL) -> URL {
        guard var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              components.scheme == Self.videoScheme else {
            return requestURL
        }

        components.scheme = originalVideoURL.scheme ?? "https"
        return components.url ?? originalVideoURL
    }

    private func hasStreamInfTags(_ manifest: String) -> Bool {
        manifest.contains("#EXT-X-STREAM-INF")
    }

    private func absoluteURI(for uri: String, relativeTo baseURL: URL) -> String {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL else {
            return trimmed
        }
        return url.absoluteString
    }

    static func multivariantPlaylist(
        mediaURI: String,
        subtitleTracks: [HLSSubtitleTrack],
        videoURL: URL
    ) -> String {
        var lines: [String] = ["#EXTM3U", "#EXT-X-VERSION:3"]
        lines.append(contentsOf: subtitleMediaTags(subtitleTracks: subtitleTracks, videoURL: videoURL))
        lines.append("#EXT-X-STREAM-INF:BANDWIDTH=2500000,SUBTITLES=\"\(subtitleGroupID)\"")
        lines.append(mediaURI)
        return lines.joined(separator: "\n") + "\n"
    }

    static func progressiveMediaPlaylist(for videoURL: URL) -> String {
        """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:\(Int(progressiveSegmentDuration))
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:\(progressiveSegmentDuration),
        \(videoURL.absoluteString)
        #EXT-X-ENDLIST
        """
    }

    static func subtitleMediaPlaylist(for subtitleURL: URL) -> String {
        """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:600
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:600.0,
        \(subtitleURL.absoluteString)
        #EXT-X-ENDLIST
        """
    }

    static func subtitleMediaTags(subtitleTracks: [HLSSubtitleTrack], videoURL: URL) -> [String] {
        subtitleTracks.enumerated().compactMap { index, track -> String? in
            guard let subtitlePlaylistURI = subtitlePlaylistURL(for: videoURL, index: index)?.absoluteString else {
                return nil
            }
            let isDefault = index == 0 ? "YES" : "NO"
            let displayName = Locale(identifier: track.language).localizedString(forLanguageCode: track.language)
                ?? track.language
            return """
            #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="\(subtitleGroupID)",NAME="\(displayName)",DEFAULT=\(isDefault),AUTOSELECT=YES,FORCED=NO,LANGUAGE="\(track.language)",URI="\(subtitlePlaylistURI)"
            """
        }
    }

    private func injectSubtitles(into manifest: String, baseURL: URL) -> String {
        let mediaTags = Self.subtitleMediaTags(subtitleTracks: subtitleTracks, videoURL: originalVideoURL)

        guard !mediaTags.isEmpty else {
            return manifest
        }

        var result: [String] = []
        var insertedMediaTag = false
        var expectingVariantURI = false

        for line in manifest.components(separatedBy: .newlines) {
            if line.hasPrefix("#EXT-X-STREAM-INF") || line.hasPrefix("#EXT-X-I-FRAME-STREAM-INF") {
                if !insertedMediaTag {
                    result.append(contentsOf: mediaTags)
                    insertedMediaTag = true
                }

                if line.contains("SUBTITLES=") {
                    result.append(line)
                } else {
                    result.append("\(line),SUBTITLES=\"\(Self.subtitleGroupID)\"")
                }
                expectingVariantURI = true
                continue
            }

            if expectingVariantURI, !line.hasPrefix("#"), !line.isEmpty {
                result.append(absoluteURI(for: line, relativeTo: baseURL))
                expectingVariantURI = false
                continue
            }

            expectingVariantURI = false
            result.append(line)
        }

        if !insertedMediaTag, let extm3uIndex = result.firstIndex(where: { $0.hasPrefix("#EXTM3U") }) {
            result.insert(contentsOf: mediaTags, at: extm3uIndex + 1)
        }

        return result.joined(separator: "\n")
    }

    private func fulfill(_ loadingRequest: AVAssetResourceLoadingRequest, with resource: LoadedResource) {
        if let contentRequest = loadingRequest.contentInformationRequest {
            if let contentType = resource.contentType {
                contentRequest.contentType = contentType
            }
            contentRequest.contentLength = Int64(resource.data.count)
            contentRequest.isByteRangeAccessSupported = false
        }

        loadingRequest.dataRequest?.respond(with: resource.data)
        loadingRequest.finishLoading()
    }
}
