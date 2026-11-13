# Hybrid-ui experiment artifacts

Screenshots and recording for PR `experiment: hybrid-ui video slot`.

## Capture

1. Build example: `bun run example:build` from repo root.
2. Open native shell `example-app`, load `hybrid.html` on iOS (Capacitor serves from `dist/hybrid.html`).
3. Tap **Start hybrid slot**, scroll the feed, tap web overlay and native video area.

## Files

- `ios-scroll-slot.png` iOS simulator, slot mid-scroll with web title overlay visible.
- `ios-touch-log.png` iOS event log showing `pointerRouted` web vs native.
- `android-blocked.png` Android emulator, start shows overlay not available message.
- `demo-ios.mp4` short iOS screen recording (scroll + tap overlay).
