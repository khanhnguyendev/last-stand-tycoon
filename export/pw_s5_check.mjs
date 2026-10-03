// Usage: node export/pw_s5_check.mjs <debug_build_url_base> [baseline_file]   (S5 Task 11, spec 9; desktop profile 720x1280)
// 1. ?reset=1, wait 30 s, diff the console against docs/review/media/s5/console_baseline_main.txt after normalising
//    pointers (s/0x[0-9a-f]+/0x?/g) and digit runs; print new lines; FAIL on any new error or warning (or a page error).
// 2. No evaluate before the tap (it would carry a user gesture): the AudioContext states before the tap come from an init
//    script that logs them to the console. Tap the canvas centre, wait 1.5 s, read window.LST_AUDIO states (some running)
//    and window.LST_STATE (unlocked true, music_id "night"; LST_STATE is written once a second by the debug overlay).
// 3. ?mute=1, wait 5 s; reload without flags (same browser context, same localStorage), wait 5 s; LST_STATE.muted is true.
// Chromium with software WebGL; Playwright comes from $LST_PW_DIR (default ~/.cache/lst-playwright).
import { createRequire } from 'node:module';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs';
const [base, baselineArg] = process.argv.slice(2);
if (!base) { console.error('usage: node pw_s5_check.mjs <debug_build_url_base> [baseline_file]'); process.exit(2); }
const baselineFile = baselineArg || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'docs', 'review', 'media', 's5', 'console_baseline_main.txt');
const pwDir = process.env.LST_PW_DIR || path.join(os.homedir(), '.cache', 'lst-playwright');
const { chromium } = createRequire(path.join(pwDir, 'package.json'))('playwright');
const norm = l => l.replace(/0x[0-9a-f]+/g, '0x?').replace(/\d+/g, '#').trim();
const sep = base.includes('?') ? '&' : '?';
const browser = await chromium.launch({ headless: true,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
let failed = false;
const fail = m => { failed = true; console.log('FAIL: ' + m); };
try {
  // ---- 1 and 2: one page
  const ctx1 = await browser.newContext({ viewport: { width: 720, height: 1280 } });
  const page = await ctx1.newPage();
  const lines = [];
  const seen = new Map();
  page.on('console', m => {
    const t = m.text();
    const st = /^LST_CTX \d+ ctx(\d+)=(\w+)/.exec(t);
    if (st) { seen.set(Number(st[1]), st[2]); return; }
    lines.push(`[console.${m.type()}] ${t}`);
  });
  page.on('pageerror', e => { lines.push(`[pageerror] ${e.message}`); fail('page error: ' + e.message); });
  await page.addInitScript(() => {
    const known = new Set();
    const log = (c, i) => console.log('LST_CTX ' + Math.round(performance.now()) + ' ctx' + i + '=' + c.state);
    setInterval(() => {
      (window.LST_AUDIO || []).forEach((c, i) => {
        if (known.has(c)) return;
        known.add(c); log(c, i);
        c.addEventListener('statechange', () => log(c, i));
      });
    }, 10);
  });
  await page.goto(base + sep + 'reset=1', { waitUntil: 'load', timeout: 60000 });
  await page.waitForTimeout(30000);
  const baseline = new Set(fs.readFileSync(baselineFile, 'utf8').split('\n').filter(Boolean).map(norm));
  const fresh = [...new Set(lines.filter(l => !baseline.has(norm(l))))];
  console.log(`console: ${lines.length} lines, ${fresh.length} new distinct (after pointer/number normalisation)`);
  for (const l of fresh) console.log('  NEW ' + l);
  for (const l of fresh) if (/^\[(console\.(error|warning)|pageerror)\]/.test(l)) fail('new error/warning: ' + l);

  const before = [...seen.entries()].sort((a, b) => a[0] - b[0]).map(e => e[1]);
  console.log('audio before tap (console, no evaluate): ' + JSON.stringify(before));
  if (before.length === 0) fail('no AudioContext seen before the tap');
  if (before.includes('running')) fail('an AudioContext was running before the tap');
  const vp = page.viewportSize();
  await page.mouse.click(vp.width / 2, vp.height / 2);
  await page.waitForTimeout(1500);
  const after = await page.evaluate(() => (window.LST_AUDIO || []).map(c => c.state));
  console.log('audio after tap (1.5 s): ' + JSON.stringify(after));
  if (!after.includes('running')) fail('no AudioContext running after the tap');
  let st = null;
  for (let i = 0; i < 6; i++) {
    st = await page.evaluate(() => window.LST_STATE || null);
    if (st && st.unlocked) break;
    await page.waitForTimeout(500);
  }
  console.log('LST_STATE after tap: ' + JSON.stringify(st));
  if (!st || st.unlocked !== true) fail('LST_STATE.unlocked is not true');
  if (!st || st.music_id !== 'night') fail('LST_STATE.music_id is not "night"');
  await ctx1.close();

  // ---- 3: mute persistence
  const ctx2 = await browser.newContext({ viewport: { width: 720, height: 1280 } });
  const p2 = await ctx2.newPage();
  p2.on('pageerror', e => fail('page error (mute): ' + e.message));
  await p2.goto(base + sep + 'mute=1', { waitUntil: 'load', timeout: 60000 });
  await p2.waitForTimeout(5000);
  const m1 = await p2.evaluate(() => window.LST_STATE || null);
  console.log('?mute=1 state: ' + JSON.stringify(m1));
  await p2.goto(base, { waitUntil: 'load', timeout: 60000 });
  await p2.waitForTimeout(5000);
  const m2 = await p2.evaluate(() => window.LST_STATE || null);
  console.log('reload, no flags: ' + JSON.stringify(m2));
  if (!m2 || m2.muted !== true) fail('mute did not persist across the reload');
  await ctx2.close();
} finally { await browser.close(); }
console.log(failed ? 'S5 CHECK: FAIL' : 'S5 CHECK: PASS');
process.exit(failed ? 1 : 0);
