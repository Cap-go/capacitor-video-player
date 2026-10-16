import XCTest
@testable import VideoPlayerPlugin

final class VideoPlayerAudioSessionCategoryPolicyTests: XCTestCase {
    func testPerPlayerCategoryUsesExplicitCategoryWhenSet() {
        let needs = VideoPlayerAudioSessionNeeds(
            explicitCategory: "moviePlayback",
            needsBackgroundOrPipPlayback: false
        )
        XCTAssertEqual(VideoPlayerAudioSessionCategoryPolicy.category(for: needs), "moviePlayback")
    }

    func testPerPlayerCategoryUsesPlaybackForBackgroundOrPip() {
        let needs = VideoPlayerAudioSessionNeeds(
            explicitCategory: nil,
            needsBackgroundOrPipPlayback: true
        )
        XCTAssertEqual(VideoPlayerAudioSessionCategoryPolicy.category(for: needs), "playback")
    }

    func testUnionCategoryStaysAmbientWhenNoPlayerNeedsPlayback() {
        let ambient = VideoPlayerAudioSessionNeeds(
            explicitCategory: nil,
            needsBackgroundOrPipPlayback: false
        )
        XCTAssertEqual(VideoPlayerAudioSessionCategoryPolicy.unionCategory(for: [ambient, ambient]), "ambient")
    }

    func testUnionCategoryUpgradesToPlaybackWhenAnyPlayerNeedsBackgroundOrPip() {
        let ambient = VideoPlayerAudioSessionNeeds(
            explicitCategory: nil,
            needsBackgroundOrPipPlayback: false
        )
        let pip = VideoPlayerAudioSessionNeeds(
            explicitCategory: nil,
            needsBackgroundOrPipPlayback: true
        )
        XCTAssertEqual(VideoPlayerAudioSessionCategoryPolicy.unionCategory(for: [ambient, pip]), "playback")
    }

    func testUnionCategoryPrefersMoviePlaybackOverPlayback() {
        let movie = VideoPlayerAudioSessionNeeds(
            explicitCategory: "moviePlayback",
            needsBackgroundOrPipPlayback: false
        )
        let pip = VideoPlayerAudioSessionNeeds(
            explicitCategory: nil,
            needsBackgroundOrPipPlayback: true
        )
        XCTAssertEqual(VideoPlayerAudioSessionCategoryPolicy.unionCategory(for: [movie, pip]), "moviePlayback")
    }
}
