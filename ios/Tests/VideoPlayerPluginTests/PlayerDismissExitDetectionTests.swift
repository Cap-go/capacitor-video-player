import XCTest
@testable import VideoPlayerPlugin

final class PlayerDismissExitDetectionTests: XCTestCase {
    func testReportsExitWhenBeingDismissed() {
        XCTAssertTrue(
            PlayerDismissExitDetection.shouldReportExit(
                isBeingDismissed: true,
                isMovingFromParent: false,
                presentingViewController: UIViewController(),
                viewWindow: UIWindow()
            )
        )
    }

    func testReportsExitWhenMovingFromParent() {
        XCTAssertTrue(
            PlayerDismissExitDetection.shouldReportExit(
                isBeingDismissed: false,
                isMovingFromParent: true,
                presentingViewController: UIViewController(),
                viewWindow: UIWindow()
            )
        )
    }

    func testReportsExitWhenModalHierarchyIsGoneWithoutBeingDismissedFlag() {
        XCTAssertTrue(
            PlayerDismissExitDetection.shouldReportExit(
                isBeingDismissed: false,
                isMovingFromParent: false,
                presentingViewController: nil,
                viewWindow: nil
            )
        )
    }

    func testDoesNotReportExitWhenCoveredByAnotherViewController() {
        XCTAssertFalse(
            PlayerDismissExitDetection.shouldReportExit(
                isBeingDismissed: false,
                isMovingFromParent: false,
                presentingViewController: UIViewController(),
                viewWindow: UIWindow()
            )
        )
    }

    func testDoesNotReportExitWhenOnlyPresenterIsNil() {
        XCTAssertFalse(
            PlayerDismissExitDetection.shouldReportExit(
                isBeingDismissed: false,
                isMovingFromParent: false,
                presentingViewController: nil,
                viewWindow: UIWindow()
            )
        )
    }

    func testDoesNotReportExitWhenOnlyWindowIsNil() {
        XCTAssertFalse(
            PlayerDismissExitDetection.shouldReportExit(
                isBeingDismissed: false,
                isMovingFromParent: false,
                presentingViewController: UIViewController(),
                viewWindow: nil
            )
        )
    }
}
