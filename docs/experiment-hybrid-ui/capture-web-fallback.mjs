import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = here;

const html = `<!DOCTYPE html>
<html><head><meta charset="utf-8"/><style>
body{margin:0;font-family:system-ui;background:#0f172a;color:#f8fafc}
.toolbar{padding:12px;background:#1e293b}
.feed{height:90vh;overflow:auto;padding:16px}
.slot{width:min(100%,640px);margin:24px auto;aspect-ratio:16/9;background:#000;border-radius:12px;position:relative}
.overlay{position:absolute;left:12px;top:12px;padding:6px 10px;background:rgba(15,23,42,.8);border-radius:8px}
.log{font-size:12px;background:#020617;padding:10px;border-radius:8px}
</style></head>
<body>
<div class="toolbar">experiment: hybrid slot (web layout reference)</div>
<div class="feed"><p>Filler</p><div class="slot"><motion class="overlay">Big Buck Bunny</motion></div><pre class="log">pointerRouted target=web (native route in iOS shell only)</pre><p style="height:600px">scroll tail</p></div>
</body></html>`;

await mkdir(outDir, { recursive: true });
await writeFile(path.join(outDir, 'layout-reference.html'), html);
