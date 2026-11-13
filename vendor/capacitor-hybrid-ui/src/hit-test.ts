import type { HybridUiFrame, HybridUiHitTestResult, HybridUiLayerDescriptor } from './definitions.js';

export interface HitTestContext {
  layers: HybridUiLayerDescriptor[];
  slotFrames: ReadonlyMap<string, HybridUiFrame>;
  /** Viewport used when modal-web blocks below without an explicit frame. */
  viewport: HybridUiFrame;
}

function frameContains(frame: HybridUiFrame, x: number, y: number): boolean {
  return x >= frame.x && x < frame.x + frame.width && y >= frame.y && y < frame.y + frame.height;
}

function modalWebHitRegion(layer: HybridUiLayerDescriptor, viewport: HybridUiFrame): HybridUiFrame | null {
  if (layer.kind !== 'modal-web') return null;
  if (layer.frame) return layer.frame;
  if (layer.blocksPointerBelow) return viewport;
  return null;
}

function layerHitRegion(
  layer: HybridUiLayerDescriptor,
  slotFrames: ReadonlyMap<string, HybridUiFrame>,
  viewport: HybridUiFrame,
): HybridUiFrame | null {
  if (layer.kind === 'native' && layer.slotId) {
    return slotFrames.get(layer.slotId) ?? null;
  }
  if (layer.kind === 'modal-native' || layer.kind === 'modal-web') {
    return layer.frame ?? modalWebHitRegion(layer, viewport);
  }
  return null;
}

/** Single descending-z pass: first layer whose hit region contains the point wins. */
export function hitTestStack(context: HitTestContext, x: number, y: number): HybridUiHitTestResult {
  const sorted = [...context.layers].sort((a, b) => {
    if (b.zIndex !== a.zIndex) return b.zIndex - a.zIndex;
    return a.layerId.localeCompare(b.layerId);
  });

  for (const layer of sorted) {
    const region = layerHitRegion(layer, context.slotFrames, context.viewport);
    if (!region || !frameContains(region, x, y)) continue;

    if (layer.kind === 'native' || layer.kind === 'modal-native') {
      return {
        target: 'native',
        layerId: layer.layerId,
        slotId: layer.slotId,
        zIndex: layer.zIndex,
      };
    }
    if (layer.kind === 'modal-web') {
      return { target: 'web', layerId: layer.layerId, zIndex: layer.zIndex };
    }
  }

  return { target: 'web' };
}
