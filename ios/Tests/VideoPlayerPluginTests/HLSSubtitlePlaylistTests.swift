import XCTest
@testable import VideoPlayerPlugin

final class HLSSubtitlePlaylistTests: XCTestCase {
    func testMultivariantPlaylistIncludesAllSubtitleLanguages() {
        let videoURL = URL(string: "https://example.com/video.mp4")!
        let tracks = [
            HLSSubtitleTrack(url: URL(string: "https://example.com/en.vtt")!, language: "en"),
            HLSSubtitleTrack(url: URL(string: "https://example.com/fr.vtt")!, language: "fr"),
            HLSSubtitleTrack(url: URL(string: "https://example.com/es.vtt")!, language: "es")
        ]

        let playlist = HLSSubtitleResourceLoader.multivariantPlaylist(
            mediaURI: "capgohls-media://example.com/video.mp4",
            subtitleTracks: tracks,
            videoURL: videoURL
        )

        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("LANGUAGE=\"en\""))
        XCTAssertTrue(playlist.contains("LANGUAGE=\"fr\""))
        XCTAssertTrue(playlist.contains("LANGUAGE=\"es\""))
        XCTAssertTrue(playlist.contains("DEFAULT=YES"))
        XCTAssertTrue(playlist.contains("SUBTITLES=\"capgosubs\""))
        XCTAssertTrue(playlist.contains("capgohls-media://example.com/video.mp4"))
        XCTAssertEqual(playlist.components(separatedBy: "TYPE=SUBTITLES").count - 1, 3)
    }

    func testProgressiveMediaPlaylistPointsAtSourceVideo() {
        let videoURL = URL(string: "https://example.com/movie.mp4")!
        let playlist = HLSSubtitleResourceLoader.progressiveMediaPlaylist(for: videoURL)

        XCTAssertTrue(playlist.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        XCTAssertTrue(playlist.contains(videoURL.absoluteString))
        XCTAssertTrue(playlist.contains("#EXT-X-ENDLIST"))
    }

    func testMakeAssetUsesResourceLoaderForProgressiveSubtitles() {
        let videoURL = URL(string: "https://example.com/movie.mp4")!
        let tracks = [
            VideoSubtitleTrack(url: "https://example.com/en.vtt", language: "en"),
            VideoSubtitleTrack(url: "https://example.com/fr.vtt", language: "fr")
        ]

        let result = HLSVideoAssetFactory.makeAsset(videoURL: videoURL, subtitleTracks: tracks)

        XCTAssertNotNil(result.resourceLoader)
        XCTAssertEqual(result.asset.url.scheme, HLSSubtitleResourceLoader.videoScheme)
    }

    func testMakeAssetSkipsResourceLoaderWithoutSubtitles() {
        let videoURL = URL(string: "https://example.com/movie.mp4")!
        let result = HLSVideoAssetFactory.makeAsset(videoURL: videoURL, subtitleTracks: [])

        XCTAssertNil(result.resourceLoader)
        XCTAssertEqual(result.asset.url, videoURL)
    }
}
