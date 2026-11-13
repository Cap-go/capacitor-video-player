/** CSS pixel rect relative to the Web viewport. */
export interface HybridUiFrame {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface HybridUiTransform {
  rotationDeg?: number;
  scaleX?: number;
  scaleY?: number;
  translateX?: number;
  translateY?: number;
}

export interface HybridUiClipRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export type HybridUiLayerKind = 'web' | 'native' | 'modal-web' | 'modal-native';

export interface HybridUiLayerDescriptor {
  layerId: string;
  kind: HybridUiLayerKind;
  zIndex: number;
  blocksPointerBelow?: boolean;
  frame?: HybridUiFrame;
  slotId?: string;
  nativeViewTag?: string;
}

export interface HybridUiCreateSessionOptions {
  protocolVersion: 1;
}

export interface HybridUiRegisterSlotOptions {
  slotId: string;
  /** DOM element id used as layout anchor (measured in JS). */
  containerElementId: string;
  /** Plugin-specific native view identifier. */
  nativeViewTag: string;
  layer: {
    zIndex: number;
  };
}

export interface HybridUiSlotGeometryUpdate {
  slotId: string;
  revision: number;
  frame: HybridUiFrame;
  transform?: HybridUiTransform;
  clip?: HybridUiClipRect;
}

export interface HybridUiUpdateSlotGeometryOptions {
  updates: HybridUiSlotGeometryUpdate[];
}

export interface HybridUiBindScrollGroupOptions {
  scrollGroupId: string;
  scrollElementId: string;
  slotIds: string[];
}

export interface HybridUiReportScrollOptions {
  scrollGroupId: string;
  contentOffsetX: number;
  contentOffsetY: number;
  contentWidth: number;
  contentHeight: number;
  viewport: HybridUiFrame;
}

export interface HybridUiPresentLayerOptions {
  layerId: string;
  kind: HybridUiLayerKind;
  zIndex: number;
  blocksPointerBelow?: boolean;
  frame?: HybridUiFrame;
  slotId?: string;
  nativeViewTag?: string;
}

export interface HybridUiDismissLayerOptions {
  layerId: string;
}

export interface HybridUiHitTestOptions {
  x: number;
  y: number;
  phase?: 'down' | 'move' | 'up';
}

export type HybridUiHitTargetKind = 'web' | 'native' | 'none';

export interface HybridUiHitTestResult {
  target: HybridUiHitTargetKind;
  layerId?: string;
  slotId?: string;
  zIndex?: number;
}

export interface HybridUiStackSnapshot {
  layers: HybridUiLayerDescriptor[];
}

export interface HybridUiPointerRoutedEvent {
  x: number;
  y: number;
  phase: 'down' | 'move' | 'up';
  target: HybridUiHitTargetKind;
  layerId?: string;
  slotId?: string;
}

export interface HybridUiStackChangedEvent {
  layers: HybridUiLayerDescriptor[];
}

export interface HybridUiGeometryAppliedEvent {
  slotId: string;
  revision: number;
}

export interface HybridUiScrollSyncedEvent {
  scrollGroupId: string;
  contentOffsetX: number;
  contentOffsetY: number;
}

export interface HybridUiPlugin {
  createSession(options: HybridUiCreateSessionOptions): Promise<void>;
  destroySession(): Promise<void>;

  registerSlot(options: HybridUiRegisterSlotOptions): Promise<void>;
  unregisterSlot(options: { slotId: string }): Promise<void>;

  updateSlotGeometry(options: HybridUiUpdateSlotGeometryOptions): Promise<void>;

  bindScrollGroup(options: HybridUiBindScrollGroupOptions): Promise<void>;
  reportScroll(options: HybridUiReportScrollOptions): Promise<void>;

  presentLayer(options: HybridUiPresentLayerOptions): Promise<void>;
  dismissLayer(options: HybridUiDismissLayerOptions): Promise<void>;

  getStackSnapshot(): Promise<HybridUiStackSnapshot>;
  hitTest(options: HybridUiHitTestOptions): Promise<HybridUiHitTestResult>;

  addListener(
    eventName: 'pointerRouted',
    listenerFunc: (event: HybridUiPointerRoutedEvent) => void,
  ): Promise<import('@capacitor/core').PluginListenerHandle>;

  addListener(
    eventName: 'stackChanged',
    listenerFunc: (event: HybridUiStackChangedEvent) => void,
  ): Promise<import('@capacitor/core').PluginListenerHandle>;

  addListener(
    eventName: 'geometryApplied',
    listenerFunc: (event: HybridUiGeometryAppliedEvent) => void,
  ): Promise<import('@capacitor/core').PluginListenerHandle>;

  addListener(
    eventName: 'scrollSynced',
    listenerFunc: (event: HybridUiScrollSyncedEvent) => void,
  ): Promise<import('@capacitor/core').PluginListenerHandle>;
}
