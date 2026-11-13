import Foundation
import Capacitor

public struct HybridUiViewport {
    public var frame: CGRect

    public init(frame: CGRect = CGRect(x: 0, y: 0, width: 390, height: 844)) {
        self.frame = frame
    }
}

/// Authoritative layer stack, geometry, and hit-testing.
public final class HybridUiCompositorSession {
    public static let shared = HybridUiCompositorSession()

    public struct Layer: Codable {
        public var layerId: String
        public var kind: String
        public var zIndex: Int
        public var blocksPointerBelow: Bool
        public var slotId: String?
        public var frame: CGRect?

        public init(layerId: String, kind: String, zIndex: Int, blocksPointerBelow: Bool = false, slotId: String? = nil, frame: CGRect? = nil) {
            self.layerId = layerId
            self.kind = kind
            self.zIndex = zIndex
            self.blocksPointerBelow = blocksPointerBelow
            self.slotId = slotId
            self.frame = frame
        }
    }

    public struct ScrollGroupBinding {
        public var scrollGroupId: String
        public var slotIds: [String]
    }

    private var layers: [Layer] = []
    private var slotBaseFrames: [String: CGRect] = [:]
    private var slotFrames: [String: CGRect] = [:]
    private var scrollBindings: [String: ScrollGroupBinding] = [:]
    private var scrollOffsets: [String: CGPoint] = [:]
    public private(set) var viewport = HybridUiViewport()

    private init() {}

    public func reset() {
        layers.removeAll()
        slotBaseFrames.removeAll()
        slotFrames.removeAll()
        scrollBindings.removeAll()
        scrollOffsets.removeAll()
        viewport = HybridUiViewport()
    }

    public func setViewport(frame: CGRect) {
        viewport.frame = frame
    }

    public func registerSlot(slotId: String, zIndex: Int) {
        layers.removeAll { $0.slotId == slotId }
        layers.append(Layer(layerId: "slot:\(slotId)", kind: "native", zIndex: zIndex, slotId: slotId))
        sortLayers()
    }

    public func unregisterSlot(slotId: String) {
        layers.removeAll { $0.slotId == slotId }
        slotBaseFrames.removeValue(forKey: slotId)
        slotFrames.removeValue(forKey: slotId)
    }

    public func updateSlotFrame(slotId: String, frame: CGRect) {
        slotBaseFrames[slotId] = frame
        applyScrollOffset(for: slotId)
    }

    public func bindScrollGroup(scrollGroupId: String, slotIds: [String]) {
        scrollBindings[scrollGroupId] = ScrollGroupBinding(scrollGroupId: scrollGroupId, slotIds: slotIds)
        scrollOffsets[scrollGroupId] = .zero
        for slotId in slotIds {
            applyScrollOffset(for: slotId)
        }
    }

    public func reportScroll(scrollGroupId: String, offsetX: CGFloat, offsetY: CGFloat) {
        scrollOffsets[scrollGroupId] = CGPoint(x: offsetX, y: offsetY)
        guard let binding = scrollBindings[scrollGroupId] else { return }
        for slotId in binding.slotIds {
            applyScrollOffset(for: slotId)
        }
    }

    public func presentLayer(_ layer: Layer) {
        layers.removeAll { $0.layerId == layer.layerId }
        layers.append(layer)
        sortLayers()
    }

    public func dismissLayer(layerId: String) {
        layers.removeAll { $0.layerId == layerId }
    }

    public func snapshot() -> [Layer] {
        layers
    }

    public func frame(forSlot slotId: String) -> CGRect? {
        slotFrames[slotId]
    }

    /// Descending z-index: first layer whose hit region contains the point wins.
    public func hitTest(x: CGFloat, y: CGFloat) -> [String: Any] {
        let point = CGPoint(x: x, y: y)
        let sorted = layers.sorted {
            if $0.zIndex != $1.zIndex { return $0.zIndex > $1.zIndex }
            return $0.layerId < $1.layerId
        }

        for layer in sorted {
            guard let region = hitRegion(for: layer), region.contains(point) else { continue }
            if layer.kind == "native" || layer.kind == "modal-native" {
                var result: [String: Any] = [
                    "target": "native",
                    "layerId": layer.layerId,
                    "zIndex": layer.zIndex
                ]
                if let slotId = layer.slotId { result["slotId"] = slotId }
                return result
            }
            if layer.kind == "modal-web" {
                return [
                    "target": "web",
                    "layerId": layer.layerId,
                    "zIndex": layer.zIndex
                ]
            }
        }
        return ["target": "web"]
    }

    private func hitRegion(for layer: Layer) -> CGRect? {
        if layer.kind == "native", let slotId = layer.slotId {
            return slotFrames[slotId]
        }
        if layer.kind == "modal-native" {
            return layer.frame
        }
        if layer.kind == "modal-web" {
            if let frame = layer.frame { return frame }
            if layer.blocksPointerBelow { return viewport.frame }
        }
        return nil
    }

    private func applyScrollOffset(for slotId: String) {
        guard let base = slotBaseFrames[slotId] else {
            slotFrames.removeValue(forKey: slotId)
            return
        }
        var offset = CGPoint.zero
        for (groupId, binding) in scrollBindings where binding.slotIds.contains(slotId) {
            offset = scrollOffsets[groupId] ?? .zero
            break
        }
        slotFrames[slotId] = base.offsetBy(dx: -offset.x, dy: -offset.y)
    }

    private func sortLayers() {
        layers.sort { lhs, rhs in
            if lhs.zIndex == rhs.zIndex { return lhs.layerId < rhs.layerId }
            return lhs.zIndex < rhs.zIndex
        }
    }
}
