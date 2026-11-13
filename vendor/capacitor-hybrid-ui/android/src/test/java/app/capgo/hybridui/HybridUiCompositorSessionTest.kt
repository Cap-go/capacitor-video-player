package app.capgo.hybridui

import android.graphics.RectF
import org.junit.Assert.assertEquals
import org.junit.Test

class HybridUiCompositorSessionTest {
    @Test
    fun nativeHudAboveWebModal() {
        val session = HybridUiCompositorSession.shared
        session.reset()
        session.setViewport(RectF(0f, 0f, 390f, 844f))
        session.registerSlot("hud", 2000)
        session.updateSlotFrame("hud", RectF(300f, 40f, 380f, 80f))
        session.presentLayer(
            HybridUiCompositorSession.Layer(
                layerId = "settings-modal",
                kind = "modal-web",
                zIndex = 1000,
                blocksPointerBelow = true,
            ),
        )

        val result = session.hitTest(320f, 60f)
        assertEquals("native", result.target)
        assertEquals("hud", result.slotId)
    }

    @Test
    fun webModalBlocksToolbar() {
        val session = HybridUiCompositorSession.shared
        session.reset()
        session.setViewport(RectF(0f, 0f, 390f, 844f))
        session.presentLayer(
            HybridUiCompositorSession.Layer(
                layerId = "settings-modal",
                kind = "modal-web",
                zIndex = 1000,
                blocksPointerBelow = true,
            ),
        )
        session.registerSlot("toolbar", 50)
        session.updateSlotFrame("toolbar", RectF(0f, 0f, 390f, 56f))

        val result = session.hitTest(100f, 28f)
        assertEquals("web", result.target)
        assertEquals("settings-modal", result.layerId)
    }
}
