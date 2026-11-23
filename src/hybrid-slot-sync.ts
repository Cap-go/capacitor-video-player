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
};

/**
 * Keeps hybrid-ui slot frames aligned with DOM layout. Frames are content-relative inside the scroll
 * container so native compositors must not subtract scroll offset again.
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
  let scrollRaf = 0;

  const measureContentFrame = (el: HTMLElement) => {
    const rect = el.getBoundingClientRect();
    const scrollRect = scrollEl.getBoundingClientRect();
    return {
      x: rect.left - scrollRect.left + scrollEl.scrollLeft,
      y: rect.top - scrollRect.top + scrollEl.scrollTop,
      width: rect.width,
      height: rect.height,
    };
  };

  const measureViewportFrame = (el: HTMLElement) => {
    const rect = el.getBoundingClientRect();
    return { x: rect.left, y: rect.top, width: rect.width, height: rect.height };
  };

  const pushGeometry = async () => {
    revision += 1;
    await HybridUi.updateSlotGeometry({
      updates: [
        {
          slotId: options.slotId,
          revision,
          frame: measureContentFrame(slotEl),
        },
      ],
    });
  };

  const reportScrollOnce = async () => {
    await HybridUi.reportScroll({
      scrollGroupId: options.scrollGroupId,
      contentOffsetX: scrollEl.scrollLeft,
      contentOffsetY: scrollEl.scrollTop,
      contentWidth: scrollEl.scrollWidth,
      contentHeight: scrollEl.scrollHeight,
      viewport: measureViewportFrame(scrollEl),
    });
  };

  const scheduleScrollReport = () => {
    if (scrollRaf) return;
    scrollRaf = requestAnimationFrame(() => {
      scrollRaf = 0;
      void reportScrollOnce();
    });
  };

  const resizeObserver = new ResizeObserver(() => {
    void pushGeometry();
  });
  resizeObserver.observe(slotEl);
  resizeObserver.observe(scrollEl);

  const scrollHandler = () => {
    scheduleScrollReport();
  };
  const resizeHandler = () => {
    void pushGeometry();
    scheduleScrollReport();
  };

  scrollEl.addEventListener('scroll', scrollHandler, { passive: true });
  window.addEventListener('resize', resizeHandler);

  await pushGeometry();
  await reportScrollOnce();

  return () => {
    if (scrollRaf) {
      cancelAnimationFrame(scrollRaf);
      scrollRaf = 0;
    }
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
