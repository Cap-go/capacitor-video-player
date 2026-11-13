# @capgo/capacitor-hybrid-ui

True mixed native and Web UI in one Capacitor surface: shared geometry, scroll, pointer input, and z-order.

## Problem

Capacitor apps render most UI in a WebView. Native views (ads, maps, toolbars, SDK widgets) are often placed above or beside the WebView. They do not share the DOM, so they do not scroll, clip, rotate, or stack with Web content the way CSS expects.

[WebView Native UI Engine](https://github.com/webview-native-ui/engine) (MIT) is a useful reference. It projects native appearance into Web layout and uses **snapshot handoff** when the Web layer must own presentation (for example a Web modal over native chrome). Snapshots are intentional: they are not interactive and do not replace live native hit-testing.

**Capgo hybrid-ui** targets the next step:

| Concern | webview-native-ui/engine (today) | hybrid-ui (goal) |
| ------- | ---------------------------------- | ---------------- |
| Scroll with Web feed | Supported via scroll placement | Same contract, live native views |
| Web modal over native toolbar | Snapshot cover, then restore | Shared z-index stack; Web modal can sit above live or snapshot fallback |
| Clicks / touch on native in layout | Native when uncovered; snapshot when covered | Unified hit-testing for both layers at all times |
| Resize / rotate with container | Geometry sync to native frame | Shared transform tree (CSS pixels + native affine) |
| Native modal vs Web content | Handoff via cover/restore | One stacking model for native and Web modals |

This repository is a **spike**: architecture, TypeScript contracts, and native stubs. It does not yet ship a production compositor.

## Package layout

```
src/                 TypeScript plugin API and web fallbacks
ios/                 iOS plugin and compositor stubs
android/             Android plugin and compositor stubs
docs/ARCHITECTURE.md Compositor, events, modals
example/             Demo scenario (feed + native ad + web modal)
LIMITATIONS.md       Honest scope gaps and open questions
```

## Install (future)

When published:

```bash
bun add @capgo/capacitor-hybrid-ui
npx cap sync
```

Peer dependency: `@capacitor/core` 6+.

## Minimal API sketch

```ts
import { HybridUi } from '@capgo/capacitor-hybrid-ui'

await HybridUi.registerSlot({
  slotId: 'feed-ad-1',
  containerElementId: 'ad-slot',
  layer: { kind: 'native', viewTag: 'AdNativeView#1', zIndex: 10 },
})

await HybridUi.bindScrollGroup({
  scrollGroupId: 'main-feed',
  scrollElementId: 'feed-scroll',
  slots: ['feed-ad-1'],
})

await HybridUi.presentLayer({
  layerId: 'settings-modal',
  kind: 'web',
  zIndex: 1000,
  blocksPointerBelow: true,
})

HybridUi.addListener('pointerRouted', (ev) => {
  // ev.target: 'web' | 'native', ev.slotId?, ev.modalLayerId?
})
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full protocol.

## Demo scenario

[example/README.md](example/README.md) describes a feed with a native ad slot, Web posts, a native toolbar, and a Web settings modal that must cover the toolbar while staying below a native debug HUD.

## License

MIT. See [LICENSE](LICENSE).

## Related work

- [webview-native-ui/engine](https://github.com/webview-native-ui/engine/) (MIT): snapshot projection and scroll placement; inspiration, not a fork.
