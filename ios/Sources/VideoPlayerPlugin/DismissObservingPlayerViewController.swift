import AVKit
import UIKit

final class DismissObservingPlayerViewController: AVPlayerViewController {
    var onDismiss: (() -> Void)?
    var shouldReportDismiss: (() -> Bool)?
    weak var adaptivePresentationDelegate: UIAdaptivePresentationControllerDelegate?
    private var wasVisibleInHierarchy = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presentationController?.delegate = adaptivePresentationDelegate
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        wasVisibleInHierarchy = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        reportDismissIfNeeded()
    }

    override func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: animated) { [weak self] in
            self?.reportDismissIfNeeded()
            completion?()
        }
    }

    private func reportDismissIfNeeded() {
        guard wasVisibleInHierarchy else { return }
        guard PlayerDismissExitDetection.shouldReportExit(
            presentingViewController: presentingViewController,
            viewWindow: view.window
        ) else {
            return
        }
        guard shouldReportDismiss?() ?? true else { return }
        onDismiss?()
    }
}
