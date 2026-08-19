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
    private var reanchorWorkItem: DispatchWorkItem?
    private var hiddenObservation: NSKeyValueObservation?
    private var alphaObservation: NSKeyValueObservation?
    private var lastReportedVisible: Bool?
    private var remainingInstallAttempts = 30
    private var isActive = false

    private static let reanchorInterval: TimeInterval = 0.25

    deinit {
        stop()
    }

    func start(
        observing playerViewController: AVPlayerViewController,
        onChange: @escaping (Bool) -> Void
    ) {
        stop()
        isActive = true
        self.playerViewController = playerViewController
        self.onVisibilityChange = onChange
        remainingInstallAttempts = 30
        installObserverIfPossible()
        scheduleReanchorCheck()
    }

    func stop() {
        isActive = false
        retryWorkItem?.cancel()
        retryWorkItem = nil
        reanchorWorkItem?.cancel()
        reanchorWorkItem = nil
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

    static func shouldReanchor(
        monitoredView: UIView?,
        currentControlsView: UIView?
    ) -> Bool {
        guard let monitoredView else {
            return currentControlsView != nil
        }
        guard let currentControlsView else {
            return true
        }
        if monitoredView !== currentControlsView {
            return true
        }
        return monitoredView.superview == nil && monitoredView.window == nil
    }

    private func installObserverIfPossible() {
        guard isActive else {
            return
        }

        guard let playerView = playerViewController?.view else {
            scheduleRetry()
            return
        }

        guard let controlsView = Self.controlsContainer(in: playerView) else {
            scheduleRetry()
            return
        }

        if monitoredView === controlsView {
            reportVisibilityIfNeeded(for: controlsView)
            return
        }

        removeMonitoredViewObserver()
        attachObserver(to: controlsView)
    }

    private func attachObserver(to controlsView: UIView) {
        monitoredView = controlsView
        hiddenObservation = controlsView.observe(\.isHidden, options: [.new]) { [weak self] view, _ in
            self?.reportVisibilityIfNeeded(for: view)
        }
        alphaObservation = controlsView.observe(\.alpha, options: [.new]) { [weak self] view, _ in
            self?.reportVisibilityIfNeeded(for: view)
        }
        reportVisibilityIfNeeded(for: controlsView)
    }

    private func reanchorIfNeeded() {
        guard isActive else {
            return
        }

        guard let playerView = playerViewController?.view else {
            if monitoredView != nil {
                removeMonitoredViewObserver()
            }
            scheduleRetry()
            return
        }

        let currentControlsView = Self.controlsContainer(in: playerView)
        guard Self.shouldReanchor(
            monitoredView: monitoredView,
            currentControlsView: currentControlsView
        ) else {
            if let monitoredView {
                reportVisibilityIfNeeded(for: monitoredView)
            }
            return
        }

        removeMonitoredViewObserver()
        if let currentControlsView {
            remainingInstallAttempts = 30
            attachObserver(to: currentControlsView)
        } else {
            scheduleRetry()
        }
    }

    private func scheduleReanchorCheck() {
        reanchorWorkItem?.cancel()
        guard isActive else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isActive else {
                return
            }
            self.reanchorIfNeeded()
            self.scheduleReanchorCheck()
        }
        reanchorWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reanchorInterval, execute: workItem)
    }

    private func scheduleRetry() {
        guard isActive else {
            return
        }

        retryWorkItem?.cancel()
        guard remainingInstallAttempts > 0 else {
            lastReportedVisible = true
            onVisibilityChange?(true)
            return
        }
        remainingInstallAttempts -= 1

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isActive else {
                return
            }
            self.installObserverIfPossible()
        }
        retryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    private func removeMonitoredViewObserver() {
        hiddenObservation = nil
        alphaObservation = nil
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
