// Usage: node export/pw_audio_spike.mjs <url> [out_prefix] [android|desktop]   (S5 Task 3a, D-212; reused by Task 11)
// Loads the page, prints window.LST_AUDIO states before any input (expect "suspended"), taps the canvas centre
// (page.mouse.click is a real user gesture), waits 1 s, prints the states again (expect "running"), screenshots
// <out_prefix>_before.png and <out_prefix>_after.png, then waits RUN_S seconds (default 0) and prints every console
// line containing SPIKE, underrun or Audio (case-insensitive). Exit 1 on a page error or when no state reads "running"
// after the tap. Chromium with software WebGL; Playwright comes from $LST_PW_DIR (default ~/.cache/lst-playwright).
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
  page.on('console', m => { if (/spike|underrun|audio/i.test(m.text())) { lines.push(m.text()); console.log('[console] ' + m.text()); } });
  page.on('pageerror', e => { failed = true; console.log('[pageerror] ' + e.message); });
  // Playwright runs page.evaluate / waitForFunction with a user gesture, which would give the page sticky activation and
  // hide the real autoplay rule. So nothing is evaluated before the tap except an init script that logs state changes
  // from inside the page (timestamps are ms since load).
  await page.addInitScript(() => {
    window.LST_LOG = [];
    const seen = new Map();
    setInterval(() => {
      (window.LST_AUDIO || []).forEach((c, i) => {
        if (seen.get(i) !== c.state) { seen.set(i, c.state); window.LST_LOG.push(`${Math.round(performance.now())}ms ctx${i}=${c.state}`); }
      });
    }, 20);
  });
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await page.waitForTimeout(Number(process.env.WAIT_S || 12) * 1000);
  const states = () => page.evaluate(() => (window.LST_AUDIO || []).map(c => c.state));
  const before = await states();
  console.log('before tap: ' + JSON.stringify(before) + ' log=' + JSON.stringify(await page.evaluate(() => window.LST_LOG)));
  await page.screenshot({ path: `${outPrefix}_before.png` });
  const vp = page.viewportSize();
  await page.mouse.click(vp.width / 2, vp.height / 2);
  await page.waitForTimeout(1000);
  const after = await states();
  console.log('after tap: ' + JSON.stringify(after) + ' log=' + JSON.stringify(await page.evaluate(() => window.LST_LOG)));
  await page.screenshot({ path: `${outPrefix}_after.png` });
  if (!after.includes('running')) { failed = true; console.log('FAIL: no AudioContext is running after the tap'); }
  const runS = Number(process.env.RUN_S || 0);
  if (runS > 0) await page.waitForTimeout(runS * 1000);
  console.log('final: ' + JSON.stringify(await states()));
  console.log(`${profile} (emulated): ${lines.length} matching console lines`);
} finally { await browser.close(); }
process.exit(failed ? 1 : 0);
