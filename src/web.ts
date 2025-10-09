import { WebPlugin } from '@capacitor/core';

import type { VideoPlayerPlugin } from './definitions';

export class VideoPlayerWeb extends WebPlugin implements VideoPlayerPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
