import UIKit

enum PlayerDismissExitDetection {
    /// Returns true when a player view controller has left the visible hierarchy
    /// because it was dismissed, not merely covered by another view controller.
    static func shouldReportExit(
        isBeingDismissed: Bool,
        isMovingFromParent: Bool,
        presentingViewController: UIViewController?,
        viewWindow: UIWindow?
    ) -> Bool {
        if isBeingDismissed || isMovingFromParent {
            return true
        }

        // iOS 18+/26: AVKit Done/X can dismiss a modal AVPlayerViewController without
        // setting isBeingDismissed or calling presentationControllerDidDismiss.
        if presentingViewController == nil && viewWindow == nil {
            return true
        }

        return false
    }
}
