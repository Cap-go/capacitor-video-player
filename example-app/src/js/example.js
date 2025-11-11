import { VideoPlayer } from '@capgo/capacitor-video-player';

const PLAYER_ID = 'embedded-player';
const COMPONENT_SELECTOR = 'main';

const ui = {
  videoUrl: document.getElementById('videoUrl'),
  width: document.getElementById('videoWidth'),
  height: document.getElementById('videoHeight'),
  initialRate: document.getElementById('initialRate'),
  exitOnEnd: document.getElementById('exitOnEnd'),
  loopOnEnd: document.getElementById('loopOnEnd'),
  init: document.getElementById('initButton'),
  destroy: document.getElementById('destroyButton'),
  status: document.getElementById('statusText'),
  controlsCard: document.getElementById('playerControls'),
  play: document.getElementById('playButton'),
  pause: document.getElementById('pauseButton'),
  stop: document.getElementById('stopButton'),
  seekSeconds: document.getElementById('seekSeconds'),
  volumeLevel: document.getElementById('volumeLevel'),
  rateSelect: document.getElementById('rateSelect'),
  seek: document.getElementById('seekButton'),
  setRate: document.getElementById('rateButton'),
  setVolume: document.getElementById('volumeButton'),
  mute: document.getElementById('muteButton'),
  unmute: document.getElementById('unmuteButton'),
  timeInfo: document.getElementById('timeInfoButton'),
  durationInfo: document.getElementById('durationButton'),
  volumeInfo: document.getElementById('volumeInfoButton'),
  rateInfo: document.getElementById('rateInfoButton'),
  log: document.getElementById('logOutput'),
  clearLog: document.getElementById('clearLog'),
  host: document.getElementById(PLAYER_ID),
};

let playerReady = false;
let listenerHandles = [];

const formatDetails = (details) => {
  if (details === undefined) return '';
  if (details === null) return 'null';
  if (details instanceof Error) return `${details.message}\n${details.stack ?? ''}`;
  if (typeof details === 'object') {
    try {
      return JSON.stringify(details, null, 2);
    } catch (err) {
      return String(details);
    }
  }
  return String(details);
};

const log = (message, details) => {
  const now = new Date();
  const timestamp = now.toISOString().split('T')[1].replace('Z', '');
  const detailText = details !== undefined ? `\n${formatDetails(details)}` : '';
  const entry = `[${timestamp}] ${message}${detailText}`;

  if (ui.log.textContent.startsWith('Logs will appear here.')) {
    ui.log.textContent = entry;
  } else {
    ui.log.textContent = `${entry}\n\n${ui.log.textContent}`;
  }

  if (details !== undefined) {
    console.log(message, details); // eslint-disable-line no-console
  } else {
    console.log(message); // eslint-disable-line no-console
  }
};

const setStatus = (text) => {
  ui.status.textContent = `Status: ${text}`;
};

const toggleControls = (enabled) => {
  ui.controlsCard.hidden = !enabled;
  ui.destroy.disabled = !enabled;

  const elements = [
    ui.play,
    ui.pause,
    ui.stop,
    ui.seek,
    ui.seekSeconds,
    ui.setRate,
    ui.rateSelect,
    ui.setVolume,
    ui.volumeLevel,
    ui.mute,
    ui.unmute,
    ui.timeInfo,
    ui.durationInfo,
    ui.volumeInfo,
    ui.rateInfo,
  ];

  elements.forEach((element) => {
    if (!element) return;
    element.disabled = !enabled;
  });
};

const parseNumber = (value, fallback) => {
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const ensureReady = (action) => {
  if (!playerReady) {
    log(`Cannot ${action} before the player is initialised.`);
    return false;
  }
  return true;
};

const resetHost = () => {
  if (!ui.host) return;
  ui.host.innerHTML = '';
};

const registerListeners = async () => {
  const register = async (eventName) => {
    const handle = await VideoPlayer.addListener(eventName, (event) => {
      log(`Event: ${eventName}`, event);
      if (eventName === 'jeepCapVideoPlayerReady') {
        setStatus('ready');
      }
      if (eventName === 'jeepCapVideoPlayerEnded') {
        setStatus('ended');
      }
      if (eventName === 'jeepCapVideoPlayerPlay') {
        setStatus('playing');
      }
      if (eventName === 'jeepCapVideoPlayerPause') {
        setStatus('paused');
      }
      if (eventName === 'jeepCapVideoPlayerExit') {
        setStatus('exited');
      }
    });
    listenerHandles.push(handle);
  };

  await register('jeepCapVideoPlayerReady');
  await register('jeepCapVideoPlayerPlay');
  await register('jeepCapVideoPlayerPause');
  await register('jeepCapVideoPlayerEnded');
  await register('jeepCapVideoPlayerExit');
};

const removeListeners = async () => {
  await Promise.allSettled(listenerHandles.map((handle) => handle.remove()));
  listenerHandles = [];
};

const initialisePlayer = async () => {
  if (playerReady) {
    await destroyPlayer();
  }

  const url = ui.videoUrl.value.trim();
  if (url.length === 0) {
    log('Please provide a video URL before initialising.');
    return;
  }

  const width = Math.max(200, parseNumber(ui.width.value, 640));
  const height = Math.max(150, parseNumber(ui.height.value, 360));
  const rate = parseNumber(ui.initialRate.value, 1);
  const exitOnEnd = ui.exitOnEnd.checked;
  const loopOnEnd = exitOnEnd ? false : ui.loopOnEnd.checked;

  setStatus('initialising...');
  log('Initialising player', { url, width, height, rate, exitOnEnd, loopOnEnd });

  try {
    const result = await VideoPlayer.initPlayer({
      mode: 'embedded',
      url,
      playerId: PLAYER_ID,
      componentTag: COMPONENT_SELECTOR,
      width,
      height,
      rate,
      exitOnEnd,
      loopOnEnd,
    });

    if (!result?.result) {
      setStatus('failed to initialise');
      log('Player initialisation failed.', result);
      return;
    }

    await registerListeners();
    playerReady = true;
    toggleControls(true);
    log('Player initialised successfully.', result);
    setStatus('waiting for ready event');
  } catch (error) {
    setStatus('error');
    log('Error while initialising player', error);
  }
};

const destroyPlayer = async () => {
  if (!playerReady) {
    log('Destroy skipped. Player is not initialised.');
    resetHost();
    toggleControls(false);
    return;
  }

  setStatus('destroying...');
  try {
    await VideoPlayer.stopAllPlayers();
    await VideoPlayer.exitPlayer();
  } catch (error) {
    log('Error while stopping players', error);
  }

  await removeListeners();
  resetHost();
  playerReady = false;
  toggleControls(false);
  setStatus('not initialised');
  log('Player destroyed and listeners removed.');
};

const playVideo = async () => {
  if (!ensureReady('play')) return;
  try {
    const result = await VideoPlayer.play({ playerId: PLAYER_ID });
    log('Play command sent.', result);
  } catch (error) {
    log('Failed to play video', error);
  }
};

const pauseVideo = async () => {
  if (!ensureReady('pause')) return;
  try {
    const result = await VideoPlayer.pause({ playerId: PLAYER_ID });
    log('Pause command sent.', result);
  } catch (error) {
    log('Failed to pause video', error);
  }
};

const stopAll = async () => {
  if (!ensureReady('stop playback')) return;
  try {
    const result = await VideoPlayer.stopAllPlayers();
    log('Stop all requested.', result);
  } catch (error) {
    log('Failed to stop all players', error);
  }
};

const seekTo = async () => {
  if (!ensureReady('seek')) return;
  const seconds = Math.max(0, parseNumber(ui.seekSeconds.value, 0));
  try {
    const result = await VideoPlayer.setCurrentTime({ playerId: PLAYER_ID, seektime: seconds });
    log(`Sought to ${seconds}s.`, result);
  } catch (error) {
    log('Failed to seek video', error);
  }
};

const setPlaybackRate = async () => {
  if (!ensureReady('set playback rate')) return;
  const rate = parseNumber(ui.rateSelect.value, 1);
  try {
    const result = await VideoPlayer.setRate({ playerId: PLAYER_ID, rate });
    log(`Playback rate set to ${rate}x.`, result);
  } catch (error) {
    log('Failed to update playback rate', error);
  }
};

const setVolume = async () => {
  if (!ensureReady('set volume')) return;
  const volume = Math.min(1, Math.max(0, parseNumber(ui.volumeLevel.value, 0.5)));
  try {
    const result = await VideoPlayer.setVolume({ playerId: PLAYER_ID, volume });
    log(`Volume set to ${volume}.`, result);
  } catch (error) {
    log('Failed to update volume', error);
  }
};

const mute = async () => {
  if (!ensureReady('mute')) return;
  try {
    const result = await VideoPlayer.setMuted({ playerId: PLAYER_ID, muted: true });
    log('Mute requested.', result);
  } catch (error) {
    log('Failed to mute video', error);
  }
};

const unmute = async () => {
  if (!ensureReady('unmute')) return;
  try {
    const result = await VideoPlayer.setMuted({ playerId: PLAYER_ID, muted: false });
    log('Unmute requested.', result);
  } catch (error) {
    log('Failed to unmute video', error);
  }
};

const reportCurrentTime = async () => {
  if (!ensureReady('get current time')) return;
  try {
    const result = await VideoPlayer.getCurrentTime({ playerId: PLAYER_ID });
    log('Current playback position', result);
  } catch (error) {
    log('Failed to read current time', error);
  }
};

const reportDuration = async () => {
  if (!ensureReady('get duration')) return;
  try {
    const result = await VideoPlayer.getDuration({ playerId: PLAYER_ID });
    log('Video duration', result);
  } catch (error) {
    log('Failed to read duration', error);
  }
};

const reportVolume = async () => {
  if (!ensureReady('get volume')) return;
  try {
    const result = await VideoPlayer.getVolume({ playerId: PLAYER_ID });
    log('Current volume', result);
  } catch (error) {
    log('Failed to read volume', error);
  }
};

const reportRate = async () => {
  if (!ensureReady('get playback rate')) return;
  try {
    const result = await VideoPlayer.getRate({ playerId: PLAYER_ID });
    log('Current playback rate', result);
  } catch (error) {
    log('Failed to read playback rate', error);
  }
};

ui.init.addEventListener('click', () => {
  initialisePlayer().catch((error) => log('Unexpected error during init', error));
});
ui.destroy.addEventListener('click', () => {
  destroyPlayer().catch((error) => log('Unexpected error during destroy', error));
});
ui.play.addEventListener('click', () => {
  playVideo().catch((error) => log('Unexpected play error', error));
});
ui.pause.addEventListener('click', () => {
  pauseVideo().catch((error) => log('Unexpected pause error', error));
});
ui.stop.addEventListener('click', () => {
  stopAll().catch((error) => log('Unexpected stop error', error));
});
ui.seek.addEventListener('click', () => {
  seekTo().catch((error) => log('Unexpected seek error', error));
});
ui.setRate.addEventListener('click', () => {
  setPlaybackRate().catch((error) => log('Unexpected rate error', error));
});
ui.setVolume.addEventListener('click', () => {
  setVolume().catch((error) => log('Unexpected volume error', error));
});
ui.mute.addEventListener('click', () => {
  mute().catch((error) => log('Unexpected mute error', error));
});
ui.unmute.addEventListener('click', () => {
  unmute().catch((error) => log('Unexpected unmute error', error));
});
ui.timeInfo.addEventListener('click', () => {
  reportCurrentTime().catch((error) => log('Unexpected current time error', error));
});
ui.durationInfo.addEventListener('click', () => {
  reportDuration().catch((error) => log('Unexpected duration error', error));
});
ui.volumeInfo.addEventListener('click', () => {
  reportVolume().catch((error) => log('Unexpected volume info error', error));
});
ui.rateInfo.addEventListener('click', () => {
  reportRate().catch((error) => log('Unexpected rate info error', error));
});
ui.clearLog.addEventListener('click', () => {
  ui.log.textContent = 'Logs cleared.';
});

toggleControls(false);
setStatus('not initialised');
