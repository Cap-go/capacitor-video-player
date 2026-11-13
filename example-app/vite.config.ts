import path from 'node:path';
import { defineConfig } from 'vite';

export default defineConfig({
  root: './src',
  build: {
    outDir: '../dist',
    minify: false,
    emptyOutDir: true,
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, 'src/index.html'),
        hybrid: path.resolve(__dirname, 'src/hybrid.html'),
      },
    },
  },
});
