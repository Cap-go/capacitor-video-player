# Hybrid UI architecture

Capgo hybrid-ui coordinates **Web DOM**, **Capacitor WebView**, and **native views** as one logical UI surface. Coordinates are **CSS pixels** relative to the Web viewport unless noted.

## Goals

1. Native and Web content share layout (size, position, rotation, scroll offset).
2. Pointer events (click, touch, hover where supported) route to the correct layer using one hit-testing model.
3. Modals and overlays (native or Web) use a **negotiated z-index stack** validated on the native side.
4. Native elements are first-class stack entries, not only snapshot images.

## Non-goals (spike)

Production rendering, snapshot fallback, and framework integrations are specified but not fully built. See [LIMITATIONS.md](../LIMITATIONS.md).

---

## Compositor model

Think of three planes managed by a **CompositorSession** (one per Capacitor bridge / activity):

```
+----------------------------------------------------------+
|  Native chrome (toolbars, modals, HUD)     z: 900-9999   |
+----------------------------------------------------------+
|  WebView (DOM + internal compositing)      z: 0-899      |
|    +-- slot anchors (empty DOM rects)                    |
|    +-- web modals (DOM, high z-index)                    |
+----------------------------------------------------------+
|  Native slots (live views aligned to slot rects) z: slot   |
+----------------------------------------------------------+
```

**Slot:** A DOM element whose bounding box (plus transform) defines where a native view is placed. The native view is a sibling of the WebView (or child of a root overlay), not inside the DOM.

**Layer entry:** `{ layerId, kind: 'web' | 'native' | 'modal-web' | 'modal-native', zIndex, blocksPointerBelow? }`

Native maintains the **authoritative stack**. Web proposes updates; native accepts or rejects (security).

### Transform tree

Each slot and modal has:

- `frame`: `{ x, y, width, height }` in viewport CSS space
- `transform`: optional `{ rotationDeg, scaleX, scaleY, translateX, translateY }` applied after frame layout
- `clip`: optional rect in slot-local space

Web sends **layout revisions** (`revision: number`) when geometry changes. Native applies the latest revision per slot atomically.

### Scroll groups

A **scroll group** binds one scrollable DOM element to one or more slots:

- Web reports `{ scrollGroupId, contentOffsetX, contentOffsetY, contentWidth, contentHeight, viewport }`.
- Native moves slot frames by the same delta (or recomputes from absolute slot metrics).

Engine-style **scroll placement** (reuse id, clip rect) is compatible; hybrid-ui keeps scroll metadata in `ScrollGroupState` shared types.

---

## Hit-testing

Hit-testing runs on **native** at pointer-down (and optionally move) using the authoritative stack, top to bottom:

1. Modal-native layers with `blocksPointerBelow`
2. Modal-web layers (native validates z-index; WebView may receive event if top web modal)
3. Native slots (live views)
4. WebView content (default WebView hit test)

Algorithm sketch:

```
function routeHit(x, y):
  for layer in sortByZIndexDesc(session.layers):
    region = hitRegion(layer)  // slot frame, modal frame, or viewport for blocking modal-web
    if !region.contains(x, y): continue
    if layer is native or modal-native: return deliverToNative(layer)
    if layer is modal-web: return deliverToWeb(layer)
  return deliverToWeb(default)
```

A blocking `modal-web` without an explicit frame uses the **viewport** as its hit region so touches below its z-index route to Web, while higher-z native slots (for example a HUD) are evaluated first and can still win at overlapping points.

**Web-proposed z-index** is not trusted alone: native stores layers from `presentLayer` and uses that list for hit-test order.

**Cooperative Web hit-test:** Optional `HybridUi.probeWebTarget(x, y)` JS callback returns `{ elementId, effectiveZ }` for ambiguous regions (future).

---

## Event routing

| Event | Web responsibility | Native responsibility |
| ----- | ------------------ | --------------------- |
| Resize / rotate | Measure slot DOM rects, send `updateSlotGeometry` | Apply frames and affine transforms to native views |
| Scroll | Emit scroll group offsets on scroll / rAF batch | Update slot origins and clipping |
| Click / tap | Default for Web targets | Dispatch to native view when hit-test selects native |
| Touch | Same; pass-through cancelled when native wins | Multi-touch to native controls when hit |
| Pointer capture | Web pointer events API for Web-only drags | Native gesture recognizers when native wins |

**Forwarding native to Web:** Native controls may emit `HybridUiNativeEvent` (button pressed, ad clicked) as plugin events to JS.

**Forwarding Web to native:** JS calls `forwardPointerToNative` only in tests; production uses native hit-test only to avoid spoofing.

---

## Modal and z-index protocol

### Present

Web or native calls `presentLayer`:

```ts
presentLayer({
  layerId: 'settings-modal',
  kind: 'web' | 'modal-web' | 'modal-native',
  zIndex: 1000,
  blocksPointerBelow: true,
  frame?: Frame,  // required for modal-native
})
```

Native:

1. Inserts layer into stack at `zIndex` (stable sort by `layerId` on tie).
2. If `kind` is web modal: may set `WebView.isUserInteractionEnabled` regions or use touch delegation (platform-specific).
3. If `kind` is modal-native: presents `UIViewController` / `Dialog` in overlay container with same `zIndex` band.

### Dismiss

`dismissLayer({ layerId })` removes entry and recomputes hit-test order.

### Web modal over native toolbar

Expected behavior (demo):

1. Toolbar native slot at `zIndex: 50`.
2. Web modal DOM at `z-index: 1000`; JS calls `presentLayer({ kind: 'modal-web', zIndex: 1000, blocksPointerBelow: true })`.
3. Native hit-test sends touches to WebView until dismiss; toolbar does not receive touches.
4. Native debug HUD at `zIndex: 2000` still receives touches on its frame.

When live compositing fails (future snapshot mode):

- Fallback to engine-like **cover** with non-interactive snapshot below web modal only.

---

## Wire protocol (Capacitor plugin)

TypeScript definitions live in `src/definitions.ts`. Native plugin methods mirror them:

| Method | Purpose |
| ------ | ------- |
| `createSession` | Init compositor for current WebView |
| `destroySession` | Tear down |
| `registerSlot` | Bind slotId to container element id + native view tag |
| `unregisterSlot` | Remove |
| `updateSlotGeometry` | Batch geometry for slots |
| `bindScrollGroup` | Link scroll element to slots |
| `reportScroll` | Push scroll offsets |
| `presentLayer` / `dismissLayer` | Stack management |
| `getStackSnapshot` | Debug: current layers |
| `hitTest` | Debug: `{ x, y }` to target descriptor |

Events:

- `stackChanged`
- `pointerRouted`
- `geometryApplied`
- `scrollSynced`

---

## Platform notes

### iOS

- Root: `CAPBridgeViewController` webView + `HybridUiOverlayContainerView` sibling.
- Slots: child `UIView` instances positioned with Auto Layout or frame sync from JS metrics.
- Hit-test: override `point(inside:with:)` on overlay container; forward misses to `WKWebView`.
- Web modals: consider `WKWebView` touch handling vs full-screen transparent native shield at z-index just below top web modal (spike TBD).
- Rotation: listen to `viewWillTransition`; Web sends geometry revision after `resize` event.
- Safe area: include in viewport frame sent from JS (`visualViewport`).

### Android

- Root: `BridgeActivity` layout with `WebView` and `HybridUiOverlayLayout` (custom `FrameLayout`).
- Slots: child views with `layout(x, y, w, h)` each geometry pass.
- Hit-test: override `dispatchTouchEvent` on activity or overlay root; call `WebView.hitTest` when stack says Web.
- `SurfaceView`: may need separate stack band or snapshot fallback (open question).
- Keyboard: `WindowInsetsCompat` synced to JS for modal padding (future).

---

## Comparison to webview-native-ui/engine

| Engine concept | hybrid-ui equivalent |
| -------------- | -------------------- |
| `WebProjectionTransport` prepare/cover/restore | Optional **SnapshotFallback** (not in spike) |
| `ScrollPlacement` | `ScrollGroupState` + `reportScroll` |
| `Frame` (CSS pixels) | Same |
| DOM container + native view | `registerSlot` |
| Ionic overlay hooks | Future adapter package |

Engine optimizes for **correct appearance** when Web must win; hybrid-ui optimizes for **correct interaction** while Web and native coexist.

---

## Versioning

Session API includes `protocolVersion: 1`. Breaking stack or hit-test rules bump version and require explicit `createSession({ protocolVersion })`.
