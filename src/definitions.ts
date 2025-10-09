export interface VideoPlayerPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
