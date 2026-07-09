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
        let resolvedTracks = subtitleTracks.compactMap { track -> (url: URL, language: String) in
            guard let subtitleURL = track.resolvedURL else { return nil }
            return (subtitleURL, track.language ?? "en")
        }

        guard !resolvedTracks.isEmpty, isHLSStream(videoURL) else {
            return (AVURLAsset(url: videoURL), nil)
        }

        let resourceLoader = HLSSubtitleResourceLoader(
            videoURL: videoURL,
            subtitleTracks: resolvedTracks.map { HLSSubtitleTrack(url: $0.url, language: $0.language) }
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

/// Injects external WebVTT subtitles into HLS master playlists via AVAssetResourceLoaderDelegate.
/// AVMutableComposition cannot demux HLS tracks, so sidecar subtitles must be wired through the manifest.
final class HLSSubtitleResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    static let videoScheme = "capgohls"
    static let subtitlePlaylistScheme = "capgohls-sub"
    private static let subtitleGroupID = "capgosubs"
    private static let mpegURLContentType = UTType.m3uPlaylist.identifier

    private let originalVideoURL: URL
    private let subtitleTracks: [HLSSubtitleTrack]

    private struct LoadedResource {
        let data: Data
        let contentType: String?
    }

    init(videoURL: URL, subtitleTracks: [HLSSubtitleTrack]) {
        self.originalVideoURL = videoURL
        self.subtitleTracks = subtitleTracks
    }

    static func assetURL(for videoURL: URL) -> URL? {
        guard var components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = videoScheme
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
            let data = Data(subtitleMediaPlaylist(for: track.url).utf8)
            return LoadedResource(data: data, contentType: Self.mpegURLContentType)
        }

        let fetchURL = originalURL(for: requestURL)
        let (data, response) = try await URLSession.shared.data(from: fetchURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let manifest = String(data: data, encoding: .utf8) ?? ""

        guard hasStreamInfTags(manifest) else {
            let contentType = Self.contentTypeIdentifier(from: response)
            return LoadedResource(data: data, contentType: contentType)
        }

        let modified = injectSubtitles(
            into: manifest,
            baseURL: response.url ?? fetchURL
        )
        return LoadedResource(data: Data(modified.utf8), contentType: Self.mpegURLContentType)
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

    private static func contentTypeIdentifier(from response: URLResponse) -> String? {
        guard let mimeType = (response as? HTTPURLResponse)?.mimeType else {
            return nil
        }
        return UTType(mimeType: mimeType)?.identifier
    }

    private func absoluteURI(for uri: String, relativeTo baseURL: URL) -> String {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL else {
            return trimmed
        }
        return url.absoluteString
    }

    private func injectSubtitles(into manifest: String, baseURL: URL) -> String {
        let mediaTags = subtitleTracks.enumerated().compactMap { index, track -> String? in
            guard let subtitlePlaylistURI = Self.subtitlePlaylistURL(for: originalVideoURL, index: index)?.absoluteString else {
                return nil
            }
            let isDefault = index == 0 ? "YES" : "NO"
            let displayName = Locale(identifier: track.language).localizedString(forLanguageCode: track.language)
                ?? track.language
            return """
            #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="\(Self.subtitleGroupID)",NAME="\(displayName)",DEFAULT=\(isDefault),AUTOSELECT=YES,FORCED=NO,LANGUAGE="\(track.language)",URI="\(subtitlePlaylistURI)"
            """
        }

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

    private func subtitleMediaPlaylist(for subtitleURL: URL) -> String {
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
