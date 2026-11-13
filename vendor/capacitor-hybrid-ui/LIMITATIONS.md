# Limitations (spike)

This document lists what **this repository does not do yet** and what milestone 1 **did** prove.

## Proven in this PR (milestone 1, iOS-focused)

- **Shared hit-test z-order** on iOS, Android session code, and TypeScript (`src/hit-test.ts`): one descending-z pass; higher native HUD wins over blocking web modals; blocking `modal-web` routes to Web below its layer (see tests).
- **iOS overlay + WKWebView pass-through:** `HybridUiPassthroughOverlayView` returns `nil` for Web-routed points so `WKWebView` receives touches; native slot subviews receive native-routed points.
- **Slot geometry + scroll offset math** in compositor session (applied to iOS slot `UIView` frames on `updateSlotGeometry` / `reportScroll`).
- **Contract tests:** Vitest (`src/hit-test.test.ts`), Android JVM (`HybridUiCompositorSessionTest`), iOS XCTest (`HybridUiCompositorSessionTests`).

See [example/ios-proof.md](example/ios-proof.md).

## Not implemented yet

- **Android live overlay / WebView dispatch.** Session and unit tests only; no `HybridUiOverlayLayout` on device.
- **DOM measurement loop.** No bundled `ResizeObserver` bridge; apps must call `updateSlotGeometry`.
- **Continuous scroll binding.** Apps must call `reportScroll`; no native scroll observer.
- **Rotation polish.** Geometry comes from JS on `resize`; no native `viewWillTransition` hook in plugin.
- **Snapshot fallback path.** No engine-style cover/restore when live compositing fails.
- **Plugin consumer SDK.** No helper to register another plugin's `UIView` / `View` by handle.
- **Runnable Capacitor demo app** in repo (manual steps documented only).
- **Ionic / Vue / React adapters.**

## Known hard problems (open)

| Topic | Question |
| ----- | -------- |
| Liquid Glass (iOS 26+) | Can live native chrome stay visually correct under Web overlays without snapshots? |
| Video / GL / SurfaceView | How do we composite without breaking `AVPlayerLayer` or `SurfaceView` z-order? |
| Accessibility | Who owns VoiceOver / TalkBack focus when focus moves Web to native and back? |
| Performance | Cost of per-frame geometry sync vs diff-on-scroll-only for long feeds |
| Keyboard | Shared inset and which layer receives `input` focus |
| Multi-WebView | Multiple Capacitor WebViews in one activity |
| Foldables | Split geometry and independent scroll groups per pane |
| Security | Clickjacking if Web layer spoofed z-index without native validation |
| Device pixel ratio | CSS px vs native points on high-DPI layouts |

## What would falsify the architecture

- Platform forbids reliable hit-testing across WebView and sibling native views with one shared z-order model.
- iOS requires snapshots for any Web modal over transparent native regions (regression to engine model only).
- Android `SurfaceView` cannot participate in a single touch dispatch graph with the WebView.

## Next proof milestones

1. ~~iOS: one `UIView` in a scroll-synced slot; Web modal at higher negotiated z-index blocks touches to native below.~~ **Done (overlay + tests; manual app check documented).**
2. Android: `FrameLayout` overlay and `dispatchTouchEvent` proof matching iOS behavior.
3. Measure frame sync error (px) under scroll for 1000px feed in a real Capacitor example app.
