# Hybrid-ui experiment artifacts

Screenshots and recording for PR `experiment: hybrid-ui video slot`.

## Capture

1. Build example: `bun run example:build` from repo root.
2. Open native shell `example-app`, load `hybrid.html` on iOS (Capacitor serves from `dist/hybrid.html`).
3. Tap **Start hybrid slot**, scroll the feed, tap web overlay and native video area.

## Files

Simulator (from workflow `experiment hybrid ui ios capture`):
- `sim-ios-unscrolled.png`, `sim-ios-scrolled.png`, `sim-ios-scroll.mov` (artifacts on the workflow run).

Layout mockups only (Chromium, not native compositing):
- `layout-mockup-scroll-slot.png`
- `layout-mockup-touch-log.png`
- `layout-mockup-android-blocked.png`
- `layout-mockup-demo.mp4`
