import XCTest

final class HybridSlotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWebOverlayAndNativeVideoTouch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_HYBRID")
        app.launch()

        let start = app.buttons["Start hybrid slot"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        let overlayPlay = app.buttons["▶"]
        XCTAssertTrue(overlayPlay.waitForExistence(timeout: 15))
        overlayPlay.tap()

        let log = app.descendants(matching: .any)["hybrid-log"].firstMatch
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        let overlaySeen = NSPredicate(format: "label CONTAINS %@", "overlay-play clicked")
        let overlayExpect = expectation(for: overlaySeen, evaluatedWith: log, handler: nil)
        wait(for: [overlayExpect], timeout: 8)

        let slot = app.otherElements["hybrid-video-slot"]
        XCTAssertTrue(slot.waitForExistence(timeout: 5))
        let coord = slot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coord.tap()

        let nativeSeen = NSPredicate(format: "label CONTAINS %@", "native video tap")
        let nativeExpect = expectation(for: nativeSeen, evaluatedWith: log, handler: nil)
        wait(for: [nativeExpect], timeout: 8)

        let feedScroll = app.otherElements["feed-scroll"]
        XCTAssertTrue(feedScroll.waitForExistence(timeout: 5))
        feedScroll.swipeUp()
        sleep(1)

        XCTAssertTrue(slot.exists)
    }
}
