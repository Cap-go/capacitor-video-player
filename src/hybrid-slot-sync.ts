import type { PluginListenerHandle } from '@capacitor/core';

/** Minimal HybridUi surface used by the example app (full types ship with @capgo/capacitor-hybrid-ui). */
export type HybridUiGeometryClient = {
  updateSlotGeometry(options: {
    updates: {
      slotId: string;
      revision: number;
      frame: { x: number; y: number; width: number; height: number };
    }[];
  }): Promise<void>;
  reportScroll(options: {
    scrollGroupId: string;
    contentOffsetX: number;
    contentOffsetY: number;
    contentWidth: number;
    contentHeight: number;
    viewport: { x: number; y: number; width: number; height: number };
  }): Promise<void>;
  presentLayer(options: {
    layerId: string;
    kind: string;
    zIndex: number;
    blocksPointerBelow?: boolean;
    frame?: { x: number; y: number; width: number; height: number };
  }): Promise<void>;
  addListener(
    eventName: 'pointerRouted',
    listenerFunc: (event: { target: string; slotId?: string; x: number; y: number; phase: string }) => void,
  ): Promise<PluginListenerHandle>;
};

export type HybridSlotGeometrySyncOptions = {
  scrollElementId: string;
  scrollGroupId: string;
  slotId: string;
  slotElementId: string;
  overlayLayerIds?: {
    layerId: string;
    elementId: string;
    zIndex: number;
    blocksPointerBelow?: boolean;
  }[];
};

/**
 * Keeps hybrid-ui slot frames aligned with DOM layout inside a scroll container.
 * Requires @capgo/capacitor-hybrid-ui in the native app.
 */
export async function startHybridSlotGeometrySync(
  HybridUi: HybridUiGeometryClient,
  options: HybridSlotGeometrySyncOptions,
): Promise<() => void> {
  const scrollEl = document.getElementById(options.scrollElementId);
  const slotEl = document.getElementById(options.slotElementId);
  if (!scrollEl || !slotEl) {
    throw new Error('Hybrid slot sync: scroll or slot element not found');
  }

  let revision = 0;
  const measureFrame = (el: HTMLElement) => {
    const rect = el.getBoundingClientRect();
    return {
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
    };
  };

  const pushGeometry = async () => {
    revision += 1;
    await HybridUi.updateSlotGeometry({
      updates: [
        {
          slotId: options.slotId,
          revision,
          frame: measureFrame(slotEl),
        },
      ],
    });

    if (options.overlayLayerIds?.length) {
      for (const overlay of options.overlayLayerIds) {
        const overlayEl = document.getElementById(overlay.elementId);
        if (!overlayEl) continue;
        await HybridUi.presentLayer({
          layerId: overlay.layerId,
          kind: 'modal-web',
          zIndex: overlay.zIndex,
          blocksPointerBelow: overlay.blocksPointerBelow ?? false,
          frame: measureFrame(overlayEl),
        });
      }
    }
  };

  const onScroll = async () => {
    await HybridUi.reportScroll({
      scrollGroupId: options.scrollGroupId,
      contentOffsetX: scrollEl.scrollLeft,
      contentOffsetY: scrollEl.scrollTop,
      contentWidth: scrollEl.scrollWidth,
      contentHeight: scrollEl.scrollHeight,
      viewport: measureFrame(scrollEl),
    });
    await pushGeometry();
  };

  const resizeObserver = new ResizeObserver(() => {
    void pushGeometry();
  });
  resizeObserver.observe(slotEl);
  resizeObserver.observe(scrollEl);
  for (const overlay of options.overlayLayerIds ?? []) {
    const el = document.getElementById(overlay.elementId);
    if (el) resizeObserver.observe(el);
  }

  const scrollHandler = () => {
    void onScroll();
  };
  const resizeHandler = () => {
    void onScroll();
  };

  scrollEl.addEventListener('scroll', scrollHandler, { passive: true });
  window.addEventListener('resize', resizeHandler);

  await pushGeometry();
  await onScroll();

  return () => {
    resizeObserver.disconnect();
    scrollEl.removeEventListener('scroll', scrollHandler);
    window.removeEventListener('resize', resizeHandler);
  };
}

export async function listenHybridUiPointers(
  HybridUi: HybridUiGeometryClient,
  onLog: (line: string) => void,
): Promise<PluginListenerHandle> {
  return HybridUi.addListener('pointerRouted', (event) => {
    const slot = event.slotId ? ` slot=${event.slotId}` : '';
    onLog(`pointerRouted target=${event.target}${slot} (${event.x.toFixed(0)},${event.y.toFixed(0)})`);
  });
}
