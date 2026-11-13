import { describe, expect, it } from 'vitest';

import type { HybridUiLayerDescriptor } from './definitions.js';
import { hitTestStack } from './hit-test.js';

const viewport = { x: 0, y: 0, width: 390, height: 844 };

describe('hitTestStack', () => {
  it('modal.nativeHudAboveWebModal', () => {
    const layers: HybridUiLayerDescriptor[] = [
      {
        layerId: 'hud',
        kind: 'native',
        zIndex: 2000,
        slotId: 'hud',
      },
      {
        layerId: 'settings-modal',
        kind: 'modal-web',
        zIndex: 1000,
        blocksPointerBelow: true,
      },
    ];
    const slotFrames = new Map([['hud', { x: 300, y: 40, width: 80, height: 40 }]]);
    const result = hitTestStack({ layers, slotFrames, viewport }, 320, 60);
    expect(result.target).toBe('native');
    expect(result.slotId).toBe('hud');
  });

  it('modal.webBlocksToolbar', () => {
    const layers: HybridUiLayerDescriptor[] = [
      {
        layerId: 'settings-modal',
        kind: 'modal-web',
        zIndex: 1000,
        blocksPointerBelow: true,
      },
      {
        layerId: 'slot:toolbar',
        kind: 'native',
        zIndex: 50,
        slotId: 'toolbar',
      },
    ];
    const slotFrames = new Map([['toolbar', { x: 0, y: 0, width: 390, height: 56 }]]);
    const result = hitTestStack({ layers, slotFrames, viewport }, 100, 28);
    expect(result.target).toBe('web');
    expect(result.layerId).toBe('settings-modal');
  });

  it('hit.nativeAd', () => {
    const layers: HybridUiLayerDescriptor[] = [
      {
        layerId: 'slot:ad-1',
        kind: 'native',
        zIndex: 10,
        slotId: 'ad-1',
      },
    ];
    const slotFrames = new Map([['ad-1', { x: 16, y: 200, width: 358, height: 120 }]]);
    const result = hitTestStack({ layers, slotFrames, viewport }, 100, 250);
    expect(result.target).toBe('native');
    expect(result.slotId).toBe('ad-1');
  });
});
