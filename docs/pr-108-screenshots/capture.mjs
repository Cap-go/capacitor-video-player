import { chromium } from 'playwright';
import { fileURLToPath, pathToFileURL } from 'url';
import path from 'path';

const dir = path.dirname(fileURLToPath(import.meta.url));

async function capture(mode, outfile) {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const file = path.join(dir, 'mock-fullscreen-player.html');
  const url = pathToFileURL(file);
  url.searchParams.set('mode', mode);
  await page.goto(url.href, { waitUntil: 'load' });
  await page.screenshot({ path: path.join(dir, outfile), type: 'png' });
  await browser.close();
}

await capture('before', 'fullscreen-before.png');
await capture('after', 'fullscreen-after.png');
