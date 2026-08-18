import AVKit
import UIKit

final class DismissObservingPlayerViewController: AVPlayerViewController {
    var onDismiss: (() -> Void)?
    var shouldReportDismiss: (() -> Bool)?
    weak var adaptivePresentationDelegate: UIAdaptivePresentationControllerDelegate?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presentationController?.delegate = adaptivePresentationDelegate
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed else { return }
        guard shouldReportDismiss?() ?? true else { return }
        onDismiss?()
    }
}
