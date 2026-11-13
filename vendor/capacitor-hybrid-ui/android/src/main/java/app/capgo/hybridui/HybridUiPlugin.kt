package app.capgo.hybridui

import android.graphics.RectF
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin

@CapacitorPlugin(name = "HybridUi")
class HybridUiPlugin : Plugin() {

    private val session = HybridUiCompositorSession.shared

    @PluginMethod
    fun createSession(call: PluginCall) {
        if (call.getInt("protocolVersion") != 1) {
            call.reject("Unsupported protocolVersion")
            return
        }
        session.reset()
        call.resolve()
    }

    @PluginMethod
    fun destroySession(call: PluginCall) {
        session.reset()
        call.resolve()
    }

    @PluginMethod
    fun registerSlot(call: PluginCall) {
        val slotId = call.getString("slotId") ?: return call.reject("Missing slotId")
        val layer = call.getObject("layer") ?: return call.reject("Missing layer")
        val zIndex = layer.getInteger("zIndex") ?: return call.reject("Missing zIndex")
        session.registerSlot(slotId, zIndex)
        notifyStackChanged()
        call.resolve()
    }

    @PluginMethod
    fun unregisterSlot(call: PluginCall) {
        val slotId = call.getString("slotId") ?: return call.reject("Missing slotId")
        session.unregisterSlot(slotId)
        notifyStackChanged()
        call.resolve()
    }

    @PluginMethod
    fun updateSlotGeometry(call: PluginCall) {
        val updates = call.getArray("updates") ?: return call.reject("Missing updates")
        bridge.webView?.let { webView ->
            session.setViewport(RectF(0f, 0f, webView.width.toFloat(), webView.height.toFloat()))
        }
        for (i in 0 until updates.length()) {
            val entry = updates.getJSONObject(i) ?: continue
            val slotId = entry.getString("slotId") ?: continue
            val frameObj = entry.getJSONObject("frame") ?: continue
            val frame = RectF(
                frameObj.getDouble("x").toFloat(),
                frameObj.getDouble("y").toFloat(),
                (frameObj.getDouble("x") + frameObj.getDouble("width")).toFloat(),
                (frameObj.getDouble("y") + frameObj.getDouble("height")).toFloat(),
            )
            val revision = entry.getInt("revision")
            session.updateSlotFrame(slotId, frame)
            val ev = JSObject().apply {
                put("slotId", slotId)
                put("revision", revision)
            }
            notifyListeners("geometryApplied", ev)
        }
        call.resolve()
    }

    @PluginMethod
    fun bindScrollGroup(call: PluginCall) {
        val scrollGroupId = call.getString("scrollGroupId") ?: return call.reject("Missing scrollGroupId")
        val slotIdsArray = call.getArray("slotIds") ?: return call.reject("Missing slotIds")
        val slotIds = mutableListOf<String>()
        for (i in 0 until slotIdsArray.length()) {
            slotIdsArray.optString(i)?.takeIf { it.isNotEmpty() }?.let { slotIds.add(it) }
        }
        session.bindScrollGroup(scrollGroupId, slotIds)
        call.resolve()
    }

    @PluginMethod
    fun reportScroll(call: PluginCall) {
        val scrollGroupId = call.getString("scrollGroupId") ?: return call.reject("Missing scrollGroupId")
        val offsetX = (call.getDouble("contentOffsetX") ?: 0.0).toFloat()
        val offsetY = (call.getDouble("contentOffsetY") ?: 0.0).toFloat()
        session.reportScroll(scrollGroupId, offsetX, offsetY)
        val ev = JSObject().apply {
            put("scrollGroupId", scrollGroupId)
            put("contentOffsetX", offsetX.toDouble())
            put("contentOffsetY", offsetY.toDouble())
        }
        notifyListeners("scrollSynced", ev)
        call.resolve()
    }

    @PluginMethod
    fun presentLayer(call: PluginCall) {
        val layerId = call.getString("layerId") ?: return call.reject("Missing layerId")
        val kind = call.getString("kind") ?: return call.reject("Missing kind")
        val zIndex = call.getInt("zIndex") ?: return call.reject("Missing zIndex")
        val blocks = call.getBoolean("blocksPointerBelow") ?: false
        var frame: RectF? = null
        call.getObject("frame")?.let { frameObj ->
            frame = RectF(
                frameObj.getDouble("x").toFloat(),
                frameObj.getDouble("y").toFloat(),
                (frameObj.getDouble("x") + frameObj.getDouble("width")).toFloat(),
                (frameObj.getDouble("y") + frameObj.getDouble("height")).toFloat(),
            )
        }
        val layer = HybridUiCompositorSession.Layer(
            layerId = layerId,
            kind = kind,
            zIndex = zIndex,
            blocksPointerBelow = blocks,
            slotId = call.getString("slotId"),
            frame = frame,
        )
        session.presentLayer(layer)
        notifyStackChanged()
        call.resolve()
    }

    @PluginMethod
    fun dismissLayer(call: PluginCall) {
        val layerId = call.getString("layerId") ?: return call.reject("Missing layerId")
        session.dismissLayer(layerId)
        notifyStackChanged()
        call.resolve()
    }

    @PluginMethod
    fun getStackSnapshot(call: PluginCall) {
        val arr = JSArray()
        for (layer in session.snapshot()) {
            arr.put(
                JSObject().apply {
                    put("layerId", layer.layerId)
                    put("kind", layer.kind)
                    put("zIndex", layer.zIndex)
                    put("blocksPointerBelow", layer.blocksPointerBelow)
                    layer.slotId?.let { put("slotId", it) }
                },
            )
        }
        call.resolve(JSObject().put("layers", arr))
    }

    @PluginMethod
    fun hitTest(call: PluginCall) {
        val x = call.getDouble("x")?.toFloat() ?: return call.reject("Missing x")
        val y = call.getDouble("y")?.toFloat() ?: return call.reject("Missing y")
        val result = session.hitTest(x, y)
        val payload = JSObject().apply {
            put("target", result.target)
            result.layerId?.let { put("layerId", it) }
            result.slotId?.let { put("slotId", it) }
            result.zIndex?.let { put("zIndex", it) }
        }
        call.resolve(payload)
        call.getString("phase")?.let { phase ->
            val routed = JSObject().apply {
                put("x", x.toDouble())
                put("y", y.toDouble())
                put("phase", phase)
                put("target", result.target)
                result.slotId?.let { put("slotId", it) }
            }
            notifyListeners("pointerRouted", routed)
        }
    }

    private fun notifyStackChanged() {
        val arr = JSArray()
        for (layer in session.snapshot()) {
            arr.put(
                JSObject().apply {
                    put("layerId", layer.layerId)
                    put("kind", layer.kind)
                    put("zIndex", layer.zIndex)
                    put("blocksPointerBelow", layer.blocksPointerBelow)
                },
            )
        }
        notifyListeners("stackChanged", JSObject().put("layers", arr))
    }
}
