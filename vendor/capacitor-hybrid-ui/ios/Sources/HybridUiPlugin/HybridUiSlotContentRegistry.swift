import UIKit

/// Allows plugins to register a custom `UIView` for a hybrid-ui slot before `registerSlot` runs.
public final class HybridUiSlotContentRegistry {
    public static let shared = HybridUiSlotContentRegistry()

    private var pendingViews: [String: UIView] = [:]
    private let lock = NSLock()

    private init() {}

    public func provide(slotId: String, view: UIView) {
        lock.lock()
        defer { lock.unlock() }
        pendingViews[slotId] = view
    }

    public func view(for slotId: String) -> UIView? {
        lock.lock()
        defer { lock.unlock() }
        return pendingViews[slotId]
    }
}

/// Container for plugin-supplied slot content; exposes `slotId` for overlay hit-testing.
final class HybridUiSlotContainerView: UIView {
    let slotId: String

    init(slotId: String) {
        self.slotId = slotId
        super.init(frame: .zero)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
