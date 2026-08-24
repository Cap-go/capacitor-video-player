import UIKit

enum PlayerDismissExitDetection {
    /// Returns true when a player view controller has left the visible hierarchy
    /// because it was dismissed, not merely covered by another view controller.
    static func shouldReportExit(
        presentingViewController: UIViewController?,
        viewWindow: UIWindow?
    ) -> Bool {
        // iOS 18+/26: AVKit Done/X can dismiss a modal AVPlayerViewController without
        // setting isBeingDismissed or calling presentationControllerDidDismiss.
        // Require both presenter and window to be nil so parent dismissals that only
        // transiently set isBeingDismissed/isMovingFromParent do not emit exit.
        presentingViewController == nil && viewWindow == nil
    }
}
