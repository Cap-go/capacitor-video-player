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
        XCTAssertFalse(
            VideoPlayerCastSeekSync.shouldForwardLocalSeek(localTime: .nan, lastForwardedTime: 10)
        )
        XCTAssertFalse(
            VideoPlayerCastSeekSync.shouldForwardLocalSeek(localTime: .infinity, lastForwardedTime: 10)
        )
        XCTAssertTrue(
            VideoPlayerCastSeekSync.shouldForwardLocalSeek(localTime: 10.25, lastForwardedTime: 10)
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
}
