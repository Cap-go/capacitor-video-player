import { mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const here = path.dirname(fileURLToPath(import.meta.url));
const hybridHtml = path.resolve(here, '../../example-app/dist/hybrid.html');

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
await page.goto(`file://${hybridHtml}`);

await mkdir(here, { recursive: true });
await page.screenshot({ path: path.join(here, 'ios-scroll-slot.png'), fullPage: false });
await page.evaluate(() => document.getElementById('feed-scroll')?.scrollTo(0, 260));
await page.waitForTimeout(200);
await page.screenshot({ path: path.join(here, 'ios-touch-log.png'), fullPage: false });

const androidPage = await browser.newPage({ viewport: { width: 412, height: 915 } });
await androidPage.goto(`file://${hybridHtml}`);
await androidPage.click('#startHybrid');
await androidPage.waitForTimeout(400);
await androidPage.screenshot({ path: path.join(here, 'android-blocked.png'), fullPage: false });

const videoPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
await videoPage.goto(`file://${hybridHtml}`);
const context = await browser.newContext({
  recordVideo: { dir: here, size: { width: 390, height: 844 } },
  viewport: { width: 390, height: 844 },
});
const recordPage = await context.newPage();
await recordPage.goto(`file://${hybridHtml}`);
await recordPage.evaluate(() => document.getElementById('feed-scroll')?.scrollTo({ top: 0, behavior: 'smooth' }));
await recordPage.waitForTimeout(300);
await recordPage.evaluate(() => document.getElementById('feed-scroll')?.scrollTo({ top: 320, behavior: 'smooth' }));
await recordPage.waitForTimeout(600);
await recordPage.click('#overlay-tap');
await recordPage.waitForTimeout(400);
await context.close();

const videoFile = (await import('node:fs/promises')).readdir(here);
for (const name of await videoFile) {
  if (name.endsWith('.webm')) {
    await (await import('node:fs/promises')).rename(
      path.join(here, name),
      path.join(here, 'demo-ios.webm'),
    );
    break;
  }
}

await browser.close();
