import { Capacitor } from '@capacitor/core';
import { HybridUi } from '@capgo/capacitor-hybrid-ui';
import {
  VideoPlayer,
  startHybridSlotGeometrySync,
  listenHybridUiPointers,
} from '@capgo/capacitor-video-player';

const SLOT_ID = 'video-slot-1';
const SCROLL_GROUP = 'main-feed';
const PLAYER_ID = 'hybrid-video-player';
const VIDEO_URL = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

const ui = {
  start: document.getElementById('startHybrid'),
  toggle: document.getElementById('togglePlay'),
  destroy: document.getElementById('destroyHybrid'),
  log: document.getElementById('log'),
  overlayPlay: document.getElementById('overlay-play'),
  overlayTap: document.getElementById('overlay-tap'),
};

let teardownSync = null;
let pointerHandle = null;
let hybridReady = false;
let isPlaying = false;

const log = (line) => {
  const stamp = new Date().toISOString().split('T')[1].replace('Z', '');
  ui.log.textContent = `[${stamp}] ${line}\n${ui.log.textContent}`;
};

const ensureNative = () => {
  if (!Capacitor.isNativePlatform()) {
    log('hybridSlot demo requires iOS or Android native shell');
    return false;
  }
  if (Capacitor.getPlatform() === 'android') {
    log('Android: hybrid-ui live overlay not shipped. Open on iOS for this experiment.');
    return false;
  }
  return true;
};

const startHybrid = async () => {
  if (!ensureNative()) return;

  ui.start.disabled = true;
  try {
    await HybridUi.createSession({ protocolVersion: 1 });
    await HybridUi.registerSlot({
      slotId: SLOT_ID,
      containerElementId: 'hybrid-video-slot',
      nativeViewTag: PLAYER_ID,
      layer: { zIndex: 10 },
    });
    await HybridUi.bindScrollGroup({
      scrollGroupId: SCROLL_GROUP,
      scrollElementId: 'feed-scroll',
      slotIds: [SLOT_ID],
    });

    const init = await VideoPlayer.initPlayer({
      mode: 'hybridSlot',
      playerId: PLAYER_ID,
      hybridSlotId: SLOT_ID,
      url: VIDEO_URL,
      showControls: false,
      chromecast: false,
      pipEnabled: false,
    });
    if (!init.result) {
      throw new Error(init.message ?? 'initPlayer failed');
    }

    teardownSync = await startHybridSlotGeometrySync(HybridUi, {
      scrollElementId: 'feed-scroll',
      scrollGroupId: SCROLL_GROUP,
      slotId: SLOT_ID,
      slotElementId: 'hybrid-video-slot',
      overlayLayerIds: [
        { layerId: 'overlay-title', elementId: 'overlay-title', zIndex: 100 },
        { layerId: 'overlay-play', elementId: 'overlay-play', zIndex: 110 },
        { layerId: 'overlay-tap', elementId: 'overlay-tap', zIndex: 105 },
      ],
    });

  pointerHandle = await listenHybridUiPointers(HybridUi, log);

    hybridReady = true;
    ui.toggle.disabled = false;
    ui.destroy.disabled = false;
    log('hybridSlot ready');
  } catch (err) {
    log(String(err));
    ui.start.disabled = false;
  }
};

const destroyHybrid = async () => {
  await VideoPlayer.stopAllPlayers();
  if (teardownSync) teardownSync();
  teardownSync = null;
  if (pointerHandle) {
    await pointerHandle.remove();
    pointerHandle = null;
  }
  await HybridUi.destroySession();
  hybridReady = false;
  isPlaying = false;
  ui.start.disabled = false;
  ui.toggle.disabled = true;
  ui.destroy.disabled = true;
  log('destroyed');
};

const togglePlay = async () => {
  if (!hybridReady) return;
  if (isPlaying) {
    await VideoPlayer.pause({ playerId: PLAYER_ID });
    isPlaying = false;
    log('paused (API)');
  } else {
    await VideoPlayer.play({ playerId: PLAYER_ID });
    isPlaying = true;
    log('playing (API)');
  }
};

ui.start.addEventListener('click', () => {
  void startHybrid();
});
ui.destroy.addEventListener('click', () => {
  void destroyHybrid();
});
ui.toggle.addEventListener('click', () => {
  void togglePlay();
});

ui.overlayPlay.addEventListener('click', () => {
  log('overlay-play clicked (web)');
  void togglePlay();
});
ui.overlayTap.addEventListener('click', () => {
  log('overlay-tap clicked (web)');
});

const ciParams = new URLSearchParams(globalThis.location.search);
if (ciParams.get('ci') === '1' && ensureNative()) {
  void startHybrid();
  const feedScroll = document.getElementById('feed-scroll');
  globalThis.setTimeout(() => {
    feedScroll?.scrollTo({ top: 360, behavior: 'smooth' });
  }, 3500);
}
