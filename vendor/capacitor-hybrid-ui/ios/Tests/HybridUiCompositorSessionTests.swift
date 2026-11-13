import XCTest
import HybridUiPlugin

final class HybridUiCompositorSessionTests: XCTestCase {
    func testNativeHudAboveWebModal() {
        let session = HybridUiCompositorSession.shared
        session.reset()
        session.setViewport(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        session.registerSlot(slotId: "hud", zIndex: 2000)
        session.updateSlotFrame(slotId: "hud", frame: CGRect(x: 300, y: 40, width: 80, height: 40))
        session.presentLayer(
            HybridUiCompositorSession.Layer(
                layerId: "settings-modal",
                kind: "modal-web",
                zIndex: 1000,
                blocksPointerBelow: true
            )
        )

        let result = session.hitTest(x: 320, y: 60)
        XCTAssertEqual(result["target"] as? String, "native")
        XCTAssertEqual(result["slotId"] as? String, "hud")
    }

    func testWebModalBlocksToolbar() {
        let session = HybridUiCompositorSession.shared
        session.reset()
        session.setViewport(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        session.presentLayer(
            HybridUiCompositorSession.Layer(
                layerId: "settings-modal",
                kind: "modal-web",
                zIndex: 1000,
                blocksPointerBelow: true
            )
        )
        session.registerSlot(slotId: "toolbar", zIndex: 50)
        session.updateSlotFrame(slotId: "toolbar", frame: CGRect(x: 0, y: 0, width: 390, height: 56))

        let result = session.hitTest(x: 100, y: 28)
        XCTAssertEqual(result["target"] as? String, "web")
        XCTAssertEqual(result["layerId"] as? String, "settings-modal")
    }

    func testScrollOffsetMovesSlotFrame() {
        let session = HybridUiCompositorSession.shared
        session.reset()
        session.registerSlot(slotId: "ad-1", zIndex: 10)
        session.updateSlotFrame(slotId: "ad-1", frame: CGRect(x: 0, y: 200, width: 100, height: 50))
        session.bindScrollGroup(scrollGroupId: "feed", slotIds: ["ad-1"])
        session.reportScroll(scrollGroupId: "feed", offsetX: 0, offsetY: 100)

        let frame = session.frame(forSlot: "ad-1")
        XCTAssertEqual(frame?.origin.y, 100)
    }
}
