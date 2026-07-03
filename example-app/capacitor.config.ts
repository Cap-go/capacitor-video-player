import type { CapacitorConfig } from '@capacitor/cli';

import pkg from './package.json';

const config: CapacitorConfig = {
  appId: 'app.capgo.video.player',
  appName: '@capgo/capacitor-video-player',
  webDir: 'dist',
  plugins: {
    SplashScreen: {
      launchAutoHide: false,
    },
    CapacitorUpdater: {
      appId: 'app.capgo.video.player',
      autoUpdate: true,
      autoSplashscreen: true,
      directUpdate: 'always',
      version: pkg.version,
    },
  },
};

export default config;
