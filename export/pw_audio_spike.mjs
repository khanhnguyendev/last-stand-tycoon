// Usage: node export/pw_audio_spike.mjs <url> [out_prefix] [android|desktop]   (S5 Task 3a, D-212; reused by Task 11)
// Loads the page and never evaluates anything in it before the tap (Playwright's evaluate / waitForFunction carry a user
// gesture, which would unlock audio and hide the real autoplay rule). An init script logs "LST_STATE <ms> ctx<i>=<state>"
// to the console when an AudioContext is created and on every statechange; the "before" states come from those lines.
// Then taps the canvas centre (page.mouse.click is a real user gesture), waits 1 s, evaluates the states, screenshots
// <out_prefix>_before.png and <out_prefix>_after.png, waits RUN_S seconds (default 0) and prints every console line
// containing SPIKE, underrun or Audio (case-insensitive). Exit 1 on a page error, when no context was seen before the
// tap, when any context was "running" before the tap, or when none is "running" 1 s after the tap.
// Chromium with software WebGL; Playwright comes from $LST_PW_DIR (default ~/.cache/lst-playwright).
import { createRequire } from 'node:module';
import path from 'node:path';
import os from 'node:os';
const [url, outPrefix = 'audio_spike', profile = 'desktop'] = process.argv.slice(2);
if (!url) { console.error('usage: node pw_audio_spike.mjs <url> [out_prefix] [android|desktop]'); process.exit(2); }
const pwDir = process.env.LST_PW_DIR || path.join(os.homedir(), '.cache', 'lst-playwright');
const { chromium, devices } = createRequire(path.join(pwDir, 'package.json'))('playwright');
const ctxOpts = profile === 'android' ? { ...devices['Pixel 7'] } : { viewport: { width: 720, height: 1280 } };
const browser = await chromium.launch({ headless: true,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
let failed = false;
const lines = [];
try {
  const page = await (await browser.newContext(ctxOpts)).newPage();
  const seen = new Map();   // ctx index -> latest state, from the LST_STATE console lines
  page.on('console', m => {
    const t = m.text();
    const st = /^LST_STATE \d+ ctx(\d+)=(\w+)/.exec(t);
    if (st) { seen.set(Number(st[1]), st[2]); console.log('[console] ' + t); }
    else if (/spike|underrun|audio/i.test(t)) { lines.push(t); console.log('[console] ' + t); }
  });
  page.on('pageerror', e => { failed = true; console.log('[pageerror] ' + e.message); });
  await page.addInitScript(() => {
    const known = new Set();
    const log = (c, i) => console.log('LST_STATE ' + Math.round(performance.now()) + ' ctx' + i + '=' + c.state);
    setInterval(() => {
      (window.LST_AUDIO || []).forEach((c, i) => {
        if (known.has(c)) return;
        known.add(c); log(c, i);
        c.addEventListener('statechange', () => log(c, i));
      });
    }, 10);
  });
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await page.waitForTimeout(Number(process.env.WAIT_S || 12) * 1000);
  const before = [...seen.entries()].sort((a, b) => a[0] - b[0]).map(e => e[1]);
  console.log('before tap (from console): ' + JSON.stringify(before));
  if (before.length === 0) { failed = true; console.log('FAIL: no AudioContext seen before the tap'); }
  if (before.includes('running')) { failed = true; console.log('FAIL: an AudioContext was running before the tap'); }
  await page.screenshot({ path: `${outPrefix}_before.png` });
  const vp = page.viewportSize();
  await page.mouse.click(vp.width / 2, vp.height / 2);
  await page.waitForTimeout(1000);
  const states = () => page.evaluate(() => (window.LST_AUDIO || []).map(c => c.state));
  const after = await states();
  console.log('after tap (1 s): ' + JSON.stringify(after));
  await page.screenshot({ path: `${outPrefix}_after.png` });
  if (!after.includes('running')) { failed = true; console.log('FAIL: no AudioContext is running 1 s after the tap'); }
  const runS = Number(process.env.RUN_S || 0);
  if (runS > 0) await page.waitForTimeout(runS * 1000);
  console.log('final: ' + JSON.stringify(await states()));
  console.log(`${profile} (emulated): ${lines.length} matching console lines`);
} finally { await browser.close(); }
process.exit(failed ? 1 : 0);
