// node load_time.mjs <url> <runs> : navigation -> first rendered game frame on Chromium (Playwright Pixel 7 profile, software GL), fresh context per run.
// The release build prints nothing to the console, so the page is instrumented: an init script forces preserveDrawingBuffer on the WebGL
// context and a requestAnimationFrame loop reads a 9x9 grid of pixels each frame (performance.now() relative to navigationStart).
// t_load = 'load' event; t_engine = #status splash overlay removed (Godot started); t_first_px = first frame whose grid mean is > 3/255 (boot fade
// begins to lift = first visible game frame); t_full = first frame with mean >= 90% of the final reading (boot fade done). Wall times from node.
import { createRequire } from 'node:module';
import path from 'node:path'; import os from 'node:os';
const [url, runs = '3'] = process.argv.slice(2);
const { chromium, devices } = createRequire(path.join(os.homedir(), '.cache', 'lst-playwright', 'package.json'))('playwright');
const browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const init = () => {
  window.__lst = { samples: [] };
  const orig = HTMLCanvasElement.prototype.getContext;
  HTMLCanvasElement.prototype.getContext = function (type, attrs) {
    const c = orig.call(this, type, type && type.startsWith('webgl') ? { ...(attrs || {}), preserveDrawingBuffer: true } : attrs);
    if (c && type.startsWith('webgl') && this.id === 'canvas' && !window.__lst.gl) {  // the engine's feature probe uses a detached canvas
      window.__lst.gl = c; const cv = this; const px = new Uint8Array(4);
      const loop = () => {
        const w = c.drawingBufferWidth, h = c.drawingBufferHeight; let sum = 0, n = 0;
        if (w > 0) for (let i = 1; i < 10; i++) for (let j = 1; j < 10; j++) {
          c.readPixels(Math.floor(w * i / 10), Math.floor(h * j / 10), 1, 1, c.RGBA, c.UNSIGNED_BYTE, px); sum += px[0] + px[1] + px[2]; n += 3; }
        window.__lst.samples.push([performance.now(), n ? sum / n : 0]);
        if (performance.now() < 25000) requestAnimationFrame(loop);
      };
      requestAnimationFrame(loop);
    }
    return c;
  };
};
for (let i = 1; i <= Number(runs); i++) {
  const ctx = await browser.newContext({ ...devices['Pixel 7'] });
  const page = await ctx.newPage(); await page.addInitScript(init);
  const r = {}; const t0 = Date.now();
  page.goto(url, { waitUntil: 'load', timeout: 60000 }).then(() => { r.t_load = Date.now() - t0; });
  page.waitForSelector('#status', { state: 'detached', timeout: 60000 }).then(() => { r.t_engine = Date.now() - t0; }).catch(() => {});
  await page.waitForTimeout(26000);
  const s = await page.evaluate(() => window.__lst.samples);
  const fin = s.slice(-20).reduce((a, x) => a + x[1], 0) / Math.max(1, s.slice(-20).length);
  const first = s.find(x => x[1] > 3), full = s.find(x => x[1] >= 0.9 * fin);
  r.t_first_px = first && Math.round(first[0]); r.t_full = full && Math.round(full[0]); r.final_mean = Math.round(fin * 10) / 10; r.frames = s.length;
  console.log(`run ${i}: ` + JSON.stringify(r));
  console.log('  first samples (ms:mean) ' + s.filter((x, k) => k % 15 == 0).slice(0, 25).map(x => `${Math.round(x[0])}:${Math.round(x[1])}`).join(' '));
  await ctx.close();
}
await browser.close();
