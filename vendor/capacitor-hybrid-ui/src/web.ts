import { WebPlugin } from '@capacitor/core';

import type {
  HybridUiBindScrollGroupOptions,
  HybridUiCreateSessionOptions,
  HybridUiDismissLayerOptions,
  HybridUiFrame,
  HybridUiHitTestOptions,
  HybridUiLayerDescriptor,
  HybridUiPlugin,
  HybridUiPresentLayerOptions,
  HybridUiRegisterSlotOptions,
  HybridUiReportScrollOptions,
  HybridUiStackSnapshot,
  HybridUiUpdateSlotGeometryOptions,
} from './definitions.js';
import { hitTestStack } from './hit-test.js';

const defaultViewport: HybridUiFrame = { x: 0, y: 0, width: 390, height: 844 };

/** Browser/dev: in-memory stack for API exploration. */
export class HybridUiWeb extends WebPlugin implements HybridUiPlugin {
  #layers: HybridUiLayerDescriptor[] = [];
  #slots = new Map<string, HybridUiRegisterSlotOptions>();
  #slotFrames = new Map<string, HybridUiFrame>();
  #viewport: HybridUiFrame = { ...defaultViewport };

  async createSession(_options: HybridUiCreateSessionOptions): Promise<void> {
    this.#layers = [];
    this.#slots.clear();
    this.#slotFrames.clear();
    this.#viewport = { ...defaultViewport };
  }

  async destroySession(): Promise<void> {
    this.#layers = [];
    this.#slots.clear();
    this.#slotFrames.clear();
  }

  async registerSlot(options: HybridUiRegisterSlotOptions): Promise<void> {
    this.#slots.set(options.slotId, options);
    this.#layers = this.#layers.filter((l) => l.slotId !== options.slotId);
    this.#layers.push({
      layerId: `slot:${options.slotId}`,
      kind: 'native',
      zIndex: options.layer.zIndex,
      slotId: options.slotId,
      nativeViewTag: options.nativeViewTag,
    });
    await this.notifyStackChanged();
  }

  async unregisterSlot(options: { slotId: string }): Promise<void> {
    this.#slots.delete(options.slotId);
    this.#slotFrames.delete(options.slotId);
    this.#layers = this.#layers.filter((l) => l.slotId !== options.slotId);
    await this.notifyStackChanged();
  }

  async updateSlotGeometry(options: HybridUiUpdateSlotGeometryOptions): Promise<void> {
    for (const u of options.updates) {
      this.#slotFrames.set(u.slotId, u.frame);
      await this.notifyListeners('geometryApplied', { slotId: u.slotId, revision: u.revision });
    }
  }

  async bindScrollGroup(_options: HybridUiBindScrollGroupOptions): Promise<void> {
    // no-op on web
  }

  async reportScroll(options: HybridUiReportScrollOptions): Promise<void> {
    await this.notifyListeners('scrollSynced', {
      scrollGroupId: options.scrollGroupId,
      contentOffsetX: options.contentOffsetX,
      contentOffsetY: options.contentOffsetY,
    });
  }

  async presentLayer(options: HybridUiPresentLayerOptions): Promise<void> {
    this.#layers = this.#layers.filter((l) => l.layerId !== options.layerId);
    this.#layers.push({
      layerId: options.layerId,
      kind: options.kind,
      zIndex: options.zIndex,
      blocksPointerBelow: options.blocksPointerBelow,
      frame: options.frame,
      slotId: options.slotId,
      nativeViewTag: options.nativeViewTag,
    });
    await this.notifyStackChanged();
  }

  async dismissLayer(options: HybridUiDismissLayerOptions): Promise<void> {
    this.#layers = this.#layers.filter((l) => l.layerId !== options.layerId);
    await this.notifyStackChanged();
  }

  async getStackSnapshot(): Promise<HybridUiStackSnapshot> {
    return { layers: [...this.#layers].sort((a, b) => a.zIndex - b.zIndex) };
  }

  async hitTest(options: HybridUiHitTestOptions): Promise<import('./definitions.js').HybridUiHitTestResult> {
    return hitTestStack(
      {
        layers: this.#layers,
        slotFrames: this.#slotFrames,
        viewport: this.#viewport,
      },
      options.x,
      options.y,
    );
  }

  private async notifyStackChanged(): Promise<void> {
    const snapshot = await this.getStackSnapshot();
    await this.notifyListeners('stackChanged', { layers: snapshot.layers });
  }
}
