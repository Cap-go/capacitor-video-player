import UIKit
import WebKit
import Capacitor

/// Full-screen sibling above the WebView. Returns nil from hitTest when the compositor routes to Web.
final class HybridUiPassthroughOverlayView: UIView {
    var onRoutePointer: ((_ pointInWebView: CGPoint, _ phase: String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point) else { return nil }
        let session = HybridUiCompositorSession.shared
        let cssPoint = point
        let result = session.hitTest(x: cssPoint.x, y: cssPoint.y)
        let target = result["target"] as? String ?? "web"

        if target == "native", let slotId = result["slotId"] as? String {
            for sub in subviews.reversed() {
                let matchedSlotId: String?
                if let slot = sub as? HybridUiSlotNativeView {
                    matchedSlotId = slot.slotId
                } else if let container = sub as? HybridUiSlotContainerView {
                    matchedSlotId = container.slotId
                } else {
                    matchedSlotId = nil
                }
                guard matchedSlotId == slotId else { continue }
                let local = convert(point, to: sub)
                if let hit = sub.hitTest(local, with: event) {
                    onRoutePointer?(cssPoint, "down")
                    return hit
                }
            }
        }

        if target == "web" {
            onRoutePointer?(cssPoint, "down")
            return nil
        }

        return nil
    }
}

/// Demo native slot surface (plugins replace with real SDK views).
final class HybridUiSlotNativeView: UIControl {
    let slotId: String

    init(slotId: String) {
        self.slotId = slotId
        super.init(frame: .zero)
        backgroundColor = UIColor.systemOrange.withAlphaComponent(0.35)
        layer.borderColor = UIColor.systemOrange.cgColor
        layer.borderWidth = 1
        isMultipleTouchEnabled = true
        addTarget(HybridUiOverlayHost.shared, action: #selector(HybridUiOverlayHost.shared.slotTapped(_:)), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Attaches overlay, syncs slot frames, forwards pointer routing events to the plugin bridge.
final class HybridUiOverlayHost: NSObject {
    static let shared = HybridUiOverlayHost()

    private weak var plugin: HybridUiPlugin?
    private weak var webView: WKWebView?
    private var overlay: HybridUiPassthroughOverlayView?
    private var slotViews: [String: UIView] = [:]

    static let slotContentProvideNotification = Notification.Name("CapgoHybridUiSlotContentProvide")

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSlotContentProvide(_:)),
            name: HybridUiOverlayHost.slotContentProvideNotification,
            object: nil
        )
    }

    @objc private func handleSlotContentProvide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let slotId = userInfo["slotId"] as? String,
              let view = userInfo["view"] as? UIView else { return }
        HybridUiSlotContentRegistry.shared.provide(slotId: slotId, view: view)
        refreshSlot(slotId: slotId)
    }

    func configure(plugin: HybridUiPlugin) {
        self.plugin = plugin
    }

    func attachIfNeeded(to bridge: CAPBridgeProtocol) {
        DispatchQueue.main.async { [weak self] in
            self?.attach(to: bridge)
        }
    }

    private func attach(to bridge: CAPBridgeProtocol) {
        guard let webView = bridge.webView else { return }
        if self.webView === webView, overlay?.superview != nil { return }
        self.webView = webView
        guard let container = webView.superview else { return }

        overlay?.removeFromSuperview()
        let overlay = HybridUiPassthroughOverlayView(frame: container.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.onRoutePointer = { [weak self] point, phase in
            self?.emitPointerRouted(x: point.x, y: point.y, phase: phase)
        }
        container.addSubview(overlay)
        container.bringSubviewToFront(overlay)
        self.overlay = overlay

        let viewport = CGRect(origin: .zero, size: webView.bounds.size)
        HybridUiCompositorSession.shared.setViewport(frame: viewport)
        syncAllSlotFrames()
    }

    func registerSlot(slotId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let overlay = self.overlay else { return }

            let view: UIView
            if let existing = self.slotViews[slotId] {
                view = existing
            } else if let custom = HybridUiSlotContentRegistry.shared.view(for: slotId) {
                let container = HybridUiSlotContainerView(slotId: slotId)
                custom.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(custom)
                NSLayoutConstraint.activate([
                    custom.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    custom.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    custom.topAnchor.constraint(equalTo: container.topAnchor),
                    custom.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
                view = container
            } else {
                view = HybridUiSlotNativeView(slotId: slotId)
            }

            if view.superview == nil {
                overlay.addSubview(view)
            }
            self.slotViews[slotId] = view
            self.syncSlotFrame(slotId: slotId)
        }
    }

    func unregisterSlot(slotId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.slotViews[slotId]?.removeFromSuperview()
            self?.slotViews.removeValue(forKey: slotId)
        }
    }

    func refreshSlot(slotId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.slotViews[slotId]?.removeFromSuperview()
            self.slotViews.removeValue(forKey: slotId)
            self.registerSlot(slotId: slotId)
        }
    }

    func syncAllSlotFrames() {
        for slotId in slotViews.keys {
            syncSlotFrame(slotId: slotId)
        }
    }

    func syncSlotFrame(slotId: String) {
        guard let frame = HybridUiCompositorSession.shared.frame(forSlot: slotId),
              let slotView = slotViews[slotId] else { return }
        slotView.frame = frame
    }

    @objc func slotTapped(_ sender: HybridUiSlotNativeView) {
        let center = CGPoint(x: sender.bounds.midX, y: sender.bounds.midY)
        let inWeb = sender.convert(center, to: webView)
        emitPointerRouted(x: inWeb.x, y: inWeb.y, phase: "up", target: "native", slotId: sender.slotId)
    }

    private func emitPointerRouted(x: CGFloat, y: CGFloat, phase: String, target: String? = nil, slotId: String? = nil) {
        var data: [String: Any] = ["x": x, "y": y, "phase": phase]
        if let target {
            data["target"] = target
        } else {
            let result = HybridUiCompositorSession.shared.hitTest(x: x, y: y)
            data["target"] = result["target"] ?? "web"
            if let slotId = result["slotId"] as? String {
                data["slotId"] = slotId
            }
        }
        if let slotId { data["slotId"] = slotId }
        plugin?.notifyListeners("pointerRouted", data: data)
    }
}
