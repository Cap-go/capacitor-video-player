import AVKit
import UIKit

/// Mirrors AVKit playback-control visibility for custom overlay views.
///
/// AVPlayerViewController does not expose control visibility publicly. This observer
/// locates the controls container using only the public view hierarchy and watches
/// `hidden` / `alpha` so overlay controls can follow native chrome.
final class AVPlayerControlsVisibilityObserver: NSObject {
    private weak var playerViewController: AVPlayerViewController?
    private weak var monitoredView: UIView?
    private var onVisibilityChange: ((Bool) -> Void)?
    private var retryWorkItem: DispatchWorkItem?
    private var lastReportedVisible: Bool?

    func start(
        observing playerViewController: AVPlayerViewController,
        onChange: @escaping (Bool) -> Void
    ) {
        stop()
        self.playerViewController = playerViewController
        self.onVisibilityChange = onChange
        installObserverIfPossible()
    }

    func stop() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
        removeMonitoredViewObserver()
        playerViewController = nil
        onVisibilityChange = nil
        lastReportedVisible = nil
    }

    static func controlsContainer(in playerView: UIView) -> UIView? {
        guard let container = playerView.subviews.first else {
            return nil
        }
        return container.subviews.last
    }

    static func areControlsVisible(in controlsView: UIView?) -> Bool {
        guard let controlsView else {
            return true
        }
        return !controlsView.isHidden && controlsView.alpha > 0.05
    }

    private func installObserverIfPossible() {
        guard let playerView = playerViewController?.view else {
            scheduleRetry()
            return
        }

        guard let controlsView = Self.controlsContainer(in: playerView) else {
            scheduleRetry()
            return
        }

        removeMonitoredViewObserver()
        monitoredView = controlsView
        controlsView.addObserver(self, forKeyPath: "hidden", options: [.new], context: nil)
        controlsView.addObserver(self, forKeyPath: "alpha", options: [.new], context: nil)
        reportVisibilityIfNeeded(for: controlsView)
    }

    private func scheduleRetry() {
        retryWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.installObserverIfPossible()
        }
        retryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    private func removeMonitoredViewObserver() {
        if let monitoredView {
            monitoredView.removeObserver(self, forKeyPath: "hidden")
            monitoredView.removeObserver(self, forKeyPath: "alpha")
        }
        monitoredView = nil
    }

    private func reportVisibilityIfNeeded(for controlsView: UIView) {
        let visible = Self.areControlsVisible(in: controlsView)
        guard lastReportedVisible != visible else {
            return
        }
        lastReportedVisible = visible
        onVisibilityChange?(visible)
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "hidden" || keyPath == "alpha",
              let controlsView = object as? UIView else {
            return
        }
        reportVisibilityIfNeeded(for: controlsView)
    }
}

enum VideoPlayerCastSeekSync {
    static let minimumForwardDelta: Double = 0.25

    static func shouldForwardLocalSeek(
        localTime: Double,
        lastForwardedTime: Double?
    ) -> Bool {
        guard localTime.isFinite else {
            return false
        }
        guard let lastForwardedTime else {
            return false
        }
        return abs(localTime - lastForwardedTime) >= minimumForwardDelta
    }
}

enum VideoPlayerCastOverlayLayout {
    static func overlayView(for playerViewController: AVPlayerViewController) -> UIView? {
        playerViewController.contentOverlayView
    }
}
