import { registerPlugin } from '@capacitor/core';

import type { VideoPlayerPlugin } from './definitions';

const VideoPlayer = registerPlugin<VideoPlayerPlugin>('VideoPlayer', {
  web: () => import('./web').then((m) => new m.VideoPlayerWeb()),
});

export * from './definitions';
export { VideoPlayer };
