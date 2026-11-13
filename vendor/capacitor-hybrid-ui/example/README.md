# Example: feed with native ad, toolbar, and web modal

This folder describes intended behavior for a manual demo app (not a runnable app in this spike).

## Screen layout

```
+----------------------------------+
| Native toolbar (slot: toolbar)   |  zIndex 50
+----------------------------------+
| Web scroll: #feed-scroll         |
|   Post card (web)                |
|   +---------------------------+  |
|   | Native ad (slot: ad-1)    |  |  zIndex 10 inside scroll group
|   +---------------------------+  |
|   Post card (web)                |
+----------------------------------+
| Native tab bar (optional)        |  zIndex 50
+----------------------------------+
```

Overlay: Web modal `#settings-modal` at DOM z-index 1000, registered with `presentLayer({ kind: 'modal-web', zIndex: 1000 })`.

Optional: Native debug HUD (small native view) at `zIndex 2000` top-right.

## Setup sequence (pseudo-code)

```ts
await HybridUi.createSession({ protocolVersion: 1 })

await HybridUi.registerSlot({
  slotId: 'toolbar',
  containerElementId: 'native-toolbar-anchor',
  nativeViewTag: 'MainToolbar',
  layer: { zIndex: 50 },
})

await HybridUi.registerSlot({
  slotId: 'ad-1',
  containerElementId: 'ad-slot-1',
  nativeViewTag: 'AdView_001',
  layer: { zIndex: 10 },
})

await HybridUi.bindScrollGroup({
  scrollGroupId: 'feed',
  scrollElementId: 'feed-scroll',
  slotIds: ['ad-1'],
})

// On scroll (rAF batched):
await HybridUi.reportScroll({
  scrollGroupId: 'feed',
  contentOffsetX: 0,
  contentOffsetY: scrollTop,
  contentWidth: scrollWidth,
  contentHeight: scrollHeight,
  viewport: { x: 0, y: toolbarHeight, width, height: feedHeight },
})

// Open web settings modal
await HybridUi.presentLayer({
  layerId: 'settings-modal',
  kind: 'modal-web',
  zIndex: 1000,
  blocksPointerBelow: true,
})
```

## Expected behavior checklist

| Action | Expected |
| ------ | -------- |
| Scroll feed | Ad slot moves with web posts; native ad view tracks slot rect |
| Tap web post | Web receives click |
| Tap native ad | Native ad SDK receives touch (not WebView) |
| Tap toolbar button | Native toolbar handles touch |
| Open settings modal | Modal visible; toolbar and ad do not receive touches beneath |
| Tap modal backdrop | Web handler runs |
| Close modal | Toolbar and ad interactive again |
| Native HUD visible | HUD still tappable above modal when zIndex 2000 registered |

## Geometry

On `resize` and `orientationchange`, app calls `updateSlotGeometry` with fresh `getBoundingClientRect()` for each slot anchor (and transform from computed style if rotated).

## What this spike provides

Only [example/behavior.spec.md](./behavior.spec.md) encodes the checklist for future automated tests. No Vite app is checked in yet.
