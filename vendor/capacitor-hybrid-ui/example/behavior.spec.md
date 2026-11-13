# Behavior spec (future tests)

Reference scenarios for iOS/Android proof apps.

## scroll.nativeAdFollowsFeed

Given scroll group `feed` bound to slot `ad-1`, when `contentOffsetY` increases by 100, native ad frame origin Y decreases by 100 relative to viewport (or equivalent clip update).

## hit.webPostBelowAd

Given ad slot not under point (x, y), hit-test returns target `web`.

## hit.nativeAd

Given point inside ad slot bounds and no higher modal, hit-test returns target `native` with slotId `ad-1`.

## modal.webBlocksToolbar

Given `modal-web` at zIndex 1000 and toolbar at 50, hit-test on toolbar center returns target `web` (modal or web shield).

## modal.nativeHudAboveWebModal

Given HUD at zIndex 2000 and web modal at 1000, hit-test on HUD center returns target `native`.
