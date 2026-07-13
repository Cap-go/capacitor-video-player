import XCTest
@testable import VideoPlayerPlugin

class VideoPlayerTests: XCTestCase {
    func testEcho() {
        let implementation = VideoPlayer()
        let value = "Hello, World!"
        let result = implementation.echo(value)
        XCTAssertEqual(value, result)
    }

    func testSubtitleTrackParserPrefersSubtitlesArray() {
        let tracks = VideoSubtitleTrackParser.parse(
            from: [
                ["subtitle": "https://example.com/en.vtt", "language": "en"],
                ["subtitle": "https://example.com/fr.vtt", "language": "fr"]
            ],
            legacySubtitle: "https://example.com/legacy.vtt",
            legacyLanguage: "de"
        )

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks[0].url, "https://example.com/en.vtt")
        XCTAssertEqual(tracks[0].language, "en")
        XCTAssertEqual(tracks[1].language, "fr")
    }
}
