// Usage: node export/pw_audio_swap_check.mjs <url>   (S5 Task 3b, D-212)
// Checks that music "swap" mode frees the old track's Web Audio buffer (Godot 4.7.2 has no unregister_stream_as_sample, so the
// director drops every reference instead). An init script wraps AudioContext.createBuffer and logs LST_BUF_NEW <id> <bytes>
// <channels> <length> <rate>; a FinalizationRegistry logs LST_BUF_FREED <id> <bytes> when the AudioBuffer is collected.
// Nothing is evaluated before the tap. Flow: ?reset=1 (NIGHT 1) -> tap -> J (day) -> gc -> N (night) -> gc.
// Exit 0 when live music buffers (> 1 MiB) total at most the largest single music buffer seen after the J + gc and N + gc steps, else 1.
// Chromium with software WebGL and --js-flags=--expose-gc; Playwright comes from $LST_PW_DIR (default ~/.cache/lst-playwright).
import { createRequire } from 'node:module';
import path from 'node:path';
import os from 'node:os';
const [url0] = process.argv.slice(2);
if (!url0) { console.error('usage: node pw_audio_swap_check.mjs <url>'); process.exit(2); }
const url = url0 + (url0.includes('?') ? '&' : '?') + 'reset=1';
const pwDir = process.env.LST_PW_DIR || path.join(os.homedir(), '.cache', 'lst-playwright');
const { chromium } = createRequire(path.join(pwDir, 'package.json'))('playwright');
const MUSIC_MIN = 1024 * 1024;
const browser = await chromium.launch({ headless: true,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--js-flags=--expose-gc'] });
let failed = false;
const live = new Map();   // id -> bytes
let created = 0, freed = 0;
const music = () => [...live.values()].filter(b => b >= MUSIC_MIN);
const musicBytes = () => music().reduce((a, b) => a + b, 0);
let maxMusic = 0;   // the largest single music buffer seen = one track
const summary = (step) => {
  const m = music();
  const line = `SUMMARY ${step}: created=${created} freed=${freed} live_buffers=${live.size} live_bytes=${[...live.values()].reduce((a, b) => a + b, 0)} live_music_buffers=${m.length} live_music_bytes=${m.reduce((a, b) => a + b, 0)}`;
  console.log(line);
};
try {
  const page = await (await browser.newContext({ viewport: { width: 720, height: 1280 } })).newPage();
  page.on('console', m => {
    const t = m.text();
    let x;
    if ((x = /^LST_BUF_NEW (\d+) (\d+)/.exec(t))) { created++; live.set(x[1], Number(x[2])); if (Number(x[2]) >= MUSIC_MIN) maxMusic = Math.max(maxMusic, Number(x[2])); console.log('[console] ' + t); }
    else if ((x = /^LST_BUF_FREED (\d+) (\d+)/.exec(t))) { freed++; live.delete(x[1]); console.log('[console] ' + t); }
    else if (/^LST_STATE/.test(t)) console.log('[console] ' + t);
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
    let nextId = 1;
    const reg = new FinalizationRegistry(([id, bytes]) => console.log('LST_BUF_FREED ' + id + ' ' + bytes));
    for (const name of ['AudioContext', 'webkitAudioContext']) {
      const C = window[name];
      if (!C || !C.prototype.createBuffer) continue;
      const orig = C.prototype.createBuffer;
      C.prototype.createBuffer = function (channels, length, rate) {
        const b = orig.apply(this, arguments);
        const id = nextId++, bytes = channels * length * 4;
        reg.register(b, [id, bytes]);
        console.log('LST_BUF_NEW ' + id + ' ' + bytes + ' ' + channels + ' ' + length + ' ' + rate);
        return b;
      };
    }
  });
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await page.waitForTimeout(Number(process.env.WAIT_S || 12) * 1000);
  const vp = page.viewportSize();
  await page.mouse.click(vp.width / 2, vp.height / 2);
  await page.waitForTimeout(4000);
  const gc = async () => { for (let i = 0; i < 4; i++) { await page.evaluate(() => gc()); await page.waitForTimeout(300); } await page.waitForTimeout(2000);
    for (let i = 0; i < 4; i++) { await page.evaluate(() => gc()); await page.waitForTimeout(300); } await page.waitForTimeout(1000); };
  summary('1 after tap (night track, before gc; Godot makes a temporary second copy)');
  await gc();
  summary('1b after tap + gc');
  await page.keyboard.press('j');
  await page.waitForTimeout(3000);
  summary('2 after J (day, before gc)');
  await gc();
  summary('3 after J + gc');
  if (musicBytes() > maxMusic) { failed = true; console.log('FAIL: more than one track of music buffers live after J + gc (old buffer not freed)'); }
  const afterJ = created;
  await page.keyboard.press('n');
  await page.waitForTimeout(3000);
  summary('4 after N (night, before gc)');
  await gc();
  summary('5 after N + gc');
  console.log(`night re-registered after N: ${created > afterJ ? 'yes (new buffer created)' : 'no (no new buffer)'}`);
  if (musicBytes() > maxMusic) { failed = true; console.log('FAIL: more than one track of music buffers live after N + gc (old buffer not freed)'); }
} finally { await browser.close(); }
console.log(failed ? 'RESULT FAIL' : 'RESULT OK');
process.exit(failed ? 1 : 0);
