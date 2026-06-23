import AVFoundation
import Foundation

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
        subtitleURL: URL?,
        language: String
    ) -> (asset: AVURLAsset, resourceLoader: HLSSubtitleResourceLoader?) {
        guard let subtitleURL, isHLSStream(videoURL) else {
            return (AVURLAsset(url: videoURL), nil)
        }

        let resourceLoader = HLSSubtitleResourceLoader(
            videoURL: videoURL,
            subtitleURL: subtitleURL,
            language: language
        )
        guard let assetURL = HLSSubtitleResourceLoader.assetURL(for: videoURL) else {
            return (AVURLAsset(url: videoURL), nil)
        }

        let asset = AVURLAsset(url: assetURL)
        asset.resourceLoader.setDelegate(resourceLoader, queue: DispatchQueue.global(qos: .userInitiated))
        return (asset, resourceLoader)
    }
}

/// Injects external WebVTT subtitles into HLS master playlists via AVAssetResourceLoaderDelegate.
/// AVMutableComposition cannot demux HLS tracks, so sidecar subtitles must be wired through the manifest.
final class HLSSubtitleResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    static let videoScheme = "capgohls"
    static let subtitlePlaylistScheme = "capgohls-sub"
    private static let subtitleGroupID = "capgosubs"

    private let originalVideoURL: URL
    private let subtitleURL: URL
    private let language: String

    init(videoURL: URL, subtitleURL: URL, language: String) {
        self.originalVideoURL = videoURL
        self.subtitleURL = subtitleURL
        self.language = language
    }

    static func assetURL(for videoURL: URL) -> URL? {
        guard var components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = videoScheme
        return components.url
    }

    static func subtitlePlaylistURL(for videoURL: URL) -> URL? {
        guard var components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = subtitlePlaylistScheme
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
                let data = try await loadData(for: requestURL)
                fulfill(loadingRequest, with: data)
            } catch {
                loadingRequest.finishLoading(with: error)
            }
        }

        return true
    }

    private func loadData(for requestURL: URL) async throws -> Data {
        if requestURL.scheme == Self.subtitlePlaylistScheme {
            return Data(subtitleMediaPlaylist().utf8)
        }

        let fetchURL = originalURL(for: requestURL)
        let (data, _) = try await URLSession.shared.data(from: fetchURL)
        let manifest = String(data: data, encoding: .utf8) ?? ""

        guard hasStreamInfTags(manifest) else {
            return data
        }

        guard let subtitlePlaylistURI = Self.subtitlePlaylistURL(for: originalVideoURL)?.absoluteString else {
            return data
        }

        let modified = injectSubtitle(into: manifest, subtitlePlaylistURI: subtitlePlaylistURI)
        return Data(modified.utf8)
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

    private func injectSubtitle(into manifest: String, subtitlePlaylistURI: String) -> String {
        let mediaTag = """
        #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="\(Self.subtitleGroupID)",NAME="Subtitles",DEFAULT=YES,AUTOSELECT=YES,FORCED=NO,LANGUAGE="\(language)",URI="\(subtitlePlaylistURI)"
        """

        var lines = manifest.components(separatedBy: .newlines)
        var result: [String] = []
        var insertedMediaTag = false

        for line in lines {
            if line.hasPrefix("#EXT-X-STREAM-INF") {
                if !insertedMediaTag {
                    result.append(mediaTag)
                    insertedMediaTag = true
                }

                if line.contains("SUBTITLES=") {
                    result.append(line)
                } else {
                    result.append("\(line),SUBTITLES=\"\(Self.subtitleGroupID)\"")
                }
                continue
            }

            result.append(line)
        }

        if !insertedMediaTag, let extm3uIndex = result.firstIndex(where: { $0.hasPrefix("#EXTM3U") }) {
            result.insert(mediaTag, at: extm3uIndex + 1)
        }

        return result.joined(separator: "\n")
    }

    private func subtitleMediaPlaylist() -> String {
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

    private func fulfill(_ loadingRequest: AVAssetResourceLoadingRequest, with data: Data) {
        if let contentRequest = loadingRequest.contentInformationRequest {
            contentRequest.contentType = "application/vnd.apple.mpegurl"
            contentRequest.contentLength = Int64(data.count)
            contentRequest.isByteRangeAccessSupported = false
        }

        loadingRequest.dataRequest?.respond(with: data)
        loadingRequest.finishLoading()
    }
}
