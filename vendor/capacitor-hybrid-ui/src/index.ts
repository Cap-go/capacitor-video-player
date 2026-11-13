import { registerPlugin } from '@capacitor/core';

import type { HybridUiPlugin } from './definitions.js';

export * from './definitions.js';

export const HybridUi = registerPlugin<HybridUiPlugin>('HybridUi', {
  web: () => import('./web.js').then((m) => new m.HybridUiWeb()),
});
