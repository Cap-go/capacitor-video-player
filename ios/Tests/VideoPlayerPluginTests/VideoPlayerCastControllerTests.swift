import AVKit
import XCTest
@testable import VideoPlayerPlugin

final class VideoPlayerCastControllerTests: XCTestCase {
    func testCastOverlayTargetsContentOverlayView() {
        let playerViewController = AVPlayerViewController()
        playerViewController.loadViewIfNeeded()

        let overlayView = VideoPlayerCastOverlayLayout.overlayView(for: playerViewController)

        XCTAssertNotNil(overlayView)
        XCTAssertIdentical(overlayView, playerViewController.contentOverlayView)
    }

    func testSeekSyncRequiresBaselineAndMeaningfulDelta() {
        XCTAssertFalse(
            VideoPlayerCastSeekSync.shouldForwardLocalSeek(localTime: 42, lastForwardedTime: nil)
        )
        XCTAssertFalse(
            VideoPlayerCastSeekSync.shouldForwardLocalSeek(localTime: 10.1, lastForwardedTime: 10)
        )
        XCTAssertTrue(
            VideoPlayerCastSeekSync.shouldForwardLocalSeek(localTime: 10.5, lastForwardedTime: 10)
        )
    }

    func testControlsVisibilityReflectsHiddenAndAlpha() {
        let controlsView = UIView()
        controlsView.isHidden = false
        controlsView.alpha = 1

        XCTAssertTrue(AVPlayerControlsVisibilityObserver.areControlsVisible(in: controlsView))

        controlsView.isHidden = true
        XCTAssertFalse(AVPlayerControlsVisibilityObserver.areControlsVisible(in: controlsView))

        controlsView.isHidden = false
        controlsView.alpha = 0
        XCTAssertFalse(AVPlayerControlsVisibilityObserver.areControlsVisible(in: controlsView))
    }

    func testControlsContainerLocatorFindsLastSubviewInFirstContainer() {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let container = UIView(frame: rootView.bounds)
        let contentView = UIView(frame: rootView.bounds)
        let controlsView = UIView(frame: CGRect(x: 0, y: 180, width: 320, height: 60))

        rootView.addSubview(container)
        container.addSubview(contentView)
        container.addSubview(controlsView)

        XCTAssertIdentical(
            AVPlayerControlsVisibilityObserver.controlsContainer(in: rootView),
            controlsView
        )
    }

    func testControlsVisibilityObserverReportsChanges() {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let container = UIView(frame: rootView.bounds)
        let controlsView = UIView(frame: CGRect(x: 0, y: 180, width: 320, height: 60))
        rootView.addSubview(container)
        container.addSubview(controlsView)

        let playerViewController = AVPlayerViewController()
        playerViewController.view.addSubview(rootView)

        let observer = AVPlayerControlsVisibilityObserver()
        let expectation = expectation(description: "controls hidden")
        var reportedValues: [Bool] = []

        observer.start(observing: playerViewController) { visible in
            reportedValues.append(visible)
            if visible == false {
                expectation.fulfill()
            }
        }

        controlsView.isHidden = true
        waitForExpectations(timeout: 1)
        observer.stop()

        XCTAssertTrue(reportedValues.contains(false))
    }
}
