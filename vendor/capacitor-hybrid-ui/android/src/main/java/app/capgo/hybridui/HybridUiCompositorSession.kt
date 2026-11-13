package app.capgo.hybridui

import android.graphics.RectF

/**
 * In-memory compositor state, geometry, scroll offsets, and hit-testing.
 */
class HybridUiCompositorSession private constructor() {
    data class Layer(
        val layerId: String,
        val kind: String,
        val zIndex: Int,
        val blocksPointerBelow: Boolean = false,
        val slotId: String? = null,
        val frame: RectF? = null,
    )

    data class ScrollGroupBinding(
        val scrollGroupId: String,
        val slotIds: List<String>,
    )

    private val layers = mutableListOf<Layer>()
    private val slotBaseFrames = mutableMapOf<String, RectF>()
    private val slotFrames = mutableMapOf<String, RectF>()
    private val scrollBindings = mutableMapOf<String, ScrollGroupBinding>()
    private val scrollOffsets = mutableMapOf<String, Pair<Float, Float>>()
    var viewport = RectF(0f, 0f, 390f, 844f)

    fun reset() {
        layers.clear()
        slotBaseFrames.clear()
        slotFrames.clear()
        scrollBindings.clear()
        scrollOffsets.clear()
        viewport = RectF(0f, 0f, 390f, 844f)
    }

    fun setViewport(frame: RectF) {
        viewport = RectF(frame)
    }

    fun registerSlot(slotId: String, zIndex: Int) {
        layers.removeAll { it.slotId == slotId }
        layers.add(Layer("slot:$slotId", "native", zIndex, slotId = slotId))
        sortLayers()
    }

    fun unregisterSlot(slotId: String) {
        layers.removeAll { it.slotId == slotId }
        slotBaseFrames.remove(slotId)
        slotFrames.remove(slotId)
    }

    fun updateSlotFrame(slotId: String, frame: RectF) {
        slotBaseFrames[slotId] = RectF(frame)
        applyScrollOffset(slotId)
    }

    fun bindScrollGroup(scrollGroupId: String, slotIds: List<String>) {
        scrollBindings[scrollGroupId] = ScrollGroupBinding(scrollGroupId, slotIds)
        scrollOffsets[scrollGroupId] = 0f to 0f
        slotIds.forEach { applyScrollOffset(it) }
    }

    fun reportScroll(scrollGroupId: String, offsetX: Float, offsetY: Float) {
        scrollOffsets[scrollGroupId] = offsetX to offsetY
        scrollBindings[scrollGroupId]?.slotIds?.forEach { applyScrollOffset(it) }
    }

    fun frameForSlot(slotId: String): RectF? = slotFrames[slotId]

    fun presentLayer(layer: Layer) {
        layers.removeAll { it.layerId == layer.layerId }
        layers.add(layer)
        sortLayers()
    }

    fun dismissLayer(layerId: String) {
        layers.removeAll { it.layerId == layerId }
    }

    fun snapshot(): List<Layer> = layers.toList()

    fun hitTest(x: Float, y: Float): HitTestResult {
        val sorted = layers.sortedWith(
            compareByDescending<Layer> { it.zIndex }.thenBy { it.layerId },
        )
        for (layer in sorted) {
            val region = hitRegion(layer) ?: continue
            if (!region.contains(x, y)) continue
            when (layer.kind) {
                "native", "modal-native" ->
                    return HitTestResult(
                        target = "native",
                        layerId = layer.layerId,
                        slotId = layer.slotId,
                        zIndex = layer.zIndex,
                    )
                "modal-web" ->
                    return HitTestResult(
                        target = "web",
                        layerId = layer.layerId,
                        zIndex = layer.zIndex,
                    )
            }
        }
        return HitTestResult(target = "web")
    }

    data class HitTestResult(
        val target: String,
        val layerId: String? = null,
        val slotId: String? = null,
        val zIndex: Int? = null,
    )

    private fun hitRegion(layer: Layer): RectF? {
        if (layer.kind == "native") {
            val slotId = layer.slotId ?: return null
            return slotFrames[slotId]
        }
        if (layer.kind == "modal-native") return layer.frame
        if (layer.kind == "modal-web") {
            if (layer.frame != null) return layer.frame
            if (layer.blocksPointerBelow) return RectF(viewport)
        }
        return null
    }

    private fun applyScrollOffset(slotId: String) {
        val base = slotBaseFrames[slotId]
        if (base == null) {
            slotFrames.remove(slotId)
            return
        }
        val binding = scrollBindings.values.firstOrNull { slotId in it.slotIds }
        val (offsetX, offsetY) = binding?.scrollGroupId?.let { scrollOffsets[it] } ?: (0f to 0f)
        slotFrames[slotId] = RectF(
            base.left - offsetX,
            base.top - offsetY,
            base.right - offsetX,
            base.bottom - offsetY,
        )
    }

    private fun sortLayers() {
        layers.sortWith(compareBy({ it.zIndex }, { it.layerId }))
    }

    companion object {
        val shared = HybridUiCompositorSession()
    }
}
