import Foundation
import Capacitor

@objc(HybridUiPlugin)
public class HybridUiPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "HybridUiPlugin"
    public let jsName = "HybridUi"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "createSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "destroySession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "registerSlot", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "unregisterSlot", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateSlotGeometry", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "bindScrollGroup", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reportScroll", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentLayer", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "dismissLayer", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getStackSnapshot", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hitTest", returnType: CAPPluginReturnPromise)
    ]

    private let session = HybridUiCompositorSession.shared
    private let overlayHost = HybridUiOverlayHost.shared

    public override func load() {
        overlayHost.configure(plugin: self)
        if let bridge = bridge {
            overlayHost.attachIfNeeded(to: bridge)
        }
    }

    @objc func createSession(_ call: CAPPluginCall) {
        guard call.getInt("protocolVersion") == 1 else {
            call.reject("Unsupported protocolVersion")
            return
        }
        session.reset()
        if let bridge = bridge {
            overlayHost.attachIfNeeded(to: bridge)
        }
        call.resolve()
    }

    @objc func destroySession(_ call: CAPPluginCall) {
        session.reset()
        call.resolve()
    }

    @objc func registerSlot(_ call: CAPPluginCall) {
        guard let slotId = call.getString("slotId"),
              let layer = call.getObject("layer"),
              let zIndex = layer["zIndex"] as? Int else {
            call.reject("Invalid registerSlot payload")
            return
        }
        session.registerSlot(slotId: slotId, zIndex: zIndex)
        overlayHost.registerSlot(slotId: slotId)
        notifyStackChanged()
        call.resolve()
    }

    @objc func unregisterSlot(_ call: CAPPluginCall) {
        guard let slotId = call.getString("slotId") else {
            call.reject("Missing slotId")
            return
        }
        session.unregisterSlot(slotId: slotId)
        overlayHost.unregisterSlot(slotId: slotId)
        notifyStackChanged()
        call.resolve()
    }

    @objc func updateSlotGeometry(_ call: CAPPluginCall) {
        guard let updates = call.getArray("updates", [String: Any].self) else {
            call.reject("Missing updates")
            return
        }
        if let bridge = bridge, let webView = bridge.webView {
            session.setViewport(frame: CGRect(origin: .zero, size: webView.bounds.size))
        }
        for case let entry as [String: Any] in updates {
            guard let slotId = entry["slotId"] as? String,
                  let frameObj = entry["frame"] as? [String: Any],
                  let x = frameObj["x"] as? Double,
                  let y = frameObj["y"] as? Double,
                  let width = frameObj["width"] as? Double,
                  let height = frameObj["height"] as? Double,
                  let revision = entry["revision"] as? Int else { continue }
            let frame = CGRect(x: x, y: y, width: width, height: height)
            session.updateSlotFrame(slotId: slotId, frame: frame)
            overlayHost.syncSlotFrame(slotId: slotId)
            notifyListeners("geometryApplied", data: ["slotId": slotId, "revision": revision])
        }
        call.resolve()
    }

    @objc func bindScrollGroup(_ call: CAPPluginCall) {
        guard let scrollGroupId = call.getString("scrollGroupId"),
              let slotIds = call.getArray("slotIds", String.self) else {
            call.reject("Invalid bindScrollGroup payload")
            return
        }
        session.bindScrollGroup(scrollGroupId: scrollGroupId, slotIds: slotIds)
        call.resolve()
    }

    @objc func reportScroll(_ call: CAPPluginCall) {
        guard let scrollGroupId = call.getString("scrollGroupId") else {
            call.reject("Missing scrollGroupId")
            return
        }
        let offsetX = call.getDouble("contentOffsetX") ?? 0
        let offsetY = call.getDouble("contentOffsetY") ?? 0
        session.reportScroll(scrollGroupId: scrollGroupId, offsetX: CGFloat(offsetX), offsetY: CGFloat(offsetY))
        overlayHost.syncAllSlotFrames()
        notifyListeners("scrollSynced", data: [
            "scrollGroupId": scrollGroupId,
            "contentOffsetX": offsetX,
            "contentOffsetY": offsetY
        ])
        call.resolve()
    }

    @objc func presentLayer(_ call: CAPPluginCall) {
        guard let layerId = call.getString("layerId"),
              let kind = call.getString("kind"),
              let zIndex = call.getInt("zIndex") else {
            call.reject("Invalid presentLayer payload")
            return
        }
        let blocks = call.getBool("blocksPointerBelow") ?? false
        var frame: CGRect?
        if let frameObj = call.getObject("frame"),
           let x = frameObj["x"] as? Double,
           let y = frameObj["y"] as? Double,
           let width = frameObj["width"] as? Double,
           let height = frameObj["height"] as? Double {
            frame = CGRect(x: x, y: y, width: width, height: height)
        }
        let layer = HybridUiCompositorSession.Layer(
            layerId: layerId,
            kind: kind,
            zIndex: zIndex,
            blocksPointerBelow: blocks,
            slotId: call.getString("slotId"),
            frame: frame
        )
        session.presentLayer(layer)
        notifyStackChanged()
        call.resolve()
    }

    @objc func dismissLayer(_ call: CAPPluginCall) {
        guard let layerId = call.getString("layerId") else {
            call.reject("Missing layerId")
            return
        }
        session.dismissLayer(layerId: layerId)
        notifyStackChanged()
        call.resolve()
    }

    @objc func getStackSnapshot(_ call: CAPPluginCall) {
        let layers = session.snapshot().map { layer -> [String: Any] in
            var dict: [String: Any] = [
                "layerId": layer.layerId,
                "kind": layer.kind,
                "zIndex": layer.zIndex,
                "blocksPointerBelow": layer.blocksPointerBelow
            ]
            if let slotId = layer.slotId { dict["slotId"] = slotId }
            return dict
        }
        call.resolve(["layers": layers])
    }

    @objc func hitTest(_ call: CAPPluginCall) {
        guard let x = call.getDouble("x"), let y = call.getDouble("y") else {
            call.reject("Missing x/y")
            return
        }
        let result = session.hitTest(x: CGFloat(x), y: CGFloat(y))
        call.resolve(result)
        if let phase = call.getString("phase") {
            notifyListeners("pointerRouted", data: [
                "x": x,
                "y": y,
                "phase": phase,
                "target": result["target"] ?? "web"
            ])
        }
    }

    private func notifyStackChanged() {
        let layers = session.snapshot().map { layer -> [String: Any] in
            [
                "layerId": layer.layerId,
                "kind": layer.kind,
                "zIndex": layer.zIndex,
                "blocksPointerBelow": layer.blocksPointerBelow
            ]
        }
        notifyListeners("stackChanged", data: ["layers": layers])
    }
}
