import XCTest
@testable import VideoPlayerPlugin

class VideoChapterTests: XCTestCase {
    func testRejectsBooleanStartTime() {
        XCTAssertNil(VideoChapter(dictionary: [
            "title": "Intro",
            "startTime": NSNumber(value: true)
        ]))
        XCTAssertNil(VideoChapter(dictionary: [
            "title": "Intro",
            "startTime": NSNumber(value: false)
        ]))
    }

    func testAcceptsNumericStartTime() {
        let chapter = VideoChapter(dictionary: [
            "title": "Intro",
            "startTime": NSNumber(value: 12.5)
        ])
        XCTAssertEqual(chapter?.startTime, 12.5)
    }

    func testRejectsStartTimeAtOrAboveIntMaxDouble() {
        XCTAssertNil(VideoChapter(dictionary: [
            "title": "Edge",
            "startTime": Double(Int.max)
        ]))
    }
}
