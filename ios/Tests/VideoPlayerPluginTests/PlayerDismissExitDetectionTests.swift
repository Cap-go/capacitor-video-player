import XCTest
@testable import VideoPlayerPlugin

final class PlayerDismissExitDetectionTests: XCTestCase {
    func testReportsExitWhenModalHierarchyIsGone() {
        XCTAssertTrue(
            PlayerDismissExitDetection.shouldReportExit(
                presentingViewController: nil,
                viewWindow: nil
            )
        )
    }

    func testDoesNotReportExitWhenBeingDismissedButStillInHierarchy() {
        XCTAssertFalse(
            PlayerDismissExitDetection.shouldReportExit(
                presentingViewController: UIViewController(),
                viewWindow: UIWindow()
            )
        )
    }

    func testDoesNotReportExitWhenCoveredByAnotherViewController() {
        XCTAssertFalse(
            PlayerDismissExitDetection.shouldReportExit(
                presentingViewController: UIViewController(),
                viewWindow: UIWindow()
            )
        )
    }

    func testDoesNotReportExitWhenOnlyPresenterIsNil() {
        XCTAssertFalse(
            PlayerDismissExitDetection.shouldReportExit(
                presentingViewController: nil,
                viewWindow: UIWindow()
            )
        )
    }

    func testDoesNotReportExitWhenOnlyWindowIsNil() {
        XCTAssertFalse(
            PlayerDismissExitDetection.shouldReportExit(
                presentingViewController: UIViewController(),
                viewWindow: nil
            )
        )
    }
}
