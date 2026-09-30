// Usage: node export/pw_resume.mjs <debug_url_base> <out_dir> [android|desktop]   (S3 Task 9)
// Resume smoke in ONE browser context (so localStorage persists between steps):
//   1. <base>?cards=tank:1&scene=cardpick   -> 1_pick.png
//   2. <base> (plain URL, must resume the saved run) -> 2_resumed_pick.png
//   3. press 1, wait, reload                -> 3_resumed_day.png
// Then prints the localStorage keys starting with "lst:" (with value lengths), the build id, and
// console/page errors. Exits 1 on any page error. Playwright comes from $LST_PW_DIR.
import { createRequire } from 'node:module';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs';
const [base, outDir, profile = 'android'] = process.argv.slice(2);
if (!base || !outDir) { console.error('usage: node pw_resume.mjs <debug_url_base> <out_dir> [android|desktop]'); process.exit(2); }
fs.mkdirSync(outDir, { recursive: true });
const pwDir = process.env.LST_PW_DIR || path.join(os.homedir(), '.cache', 'lst-playwright');
const { chromium, devices } = createRequire(path.join(pwDir, 'package.json'))('playwright');
const ctxOpts = profile === 'android'
  ? { ...devices['Pixel 7'] }
  : { viewport: { width: 720, height: 1280 } };
const browser = await chromium.launch({ headless: true,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
let failed = false;
const pageErrors = [];
const consoleErrors = [];
try {
  const page = await (await browser.newContext(ctxOpts)).newPage();
  page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('pageerror', e => { failed = true; pageErrors.push(e.message); });
  const sep = base.includes('?') ? '&' : '?';
  const shot = name => page.screenshot({ path: path.join(outDir, name) });

  await page.goto(`${base}${sep}cards=tank:1&scene=cardpick`, { waitUntil: 'load', timeout: 60000 });
  const build = await page.waitForFunction(() => window.LST_BUILD, null, { timeout: 30000 })
    .then(h => h.jsonValue()).catch(() => null);
  if (!build) { failed = true; console.log('no window.LST_BUILD'); }
  await page.waitForTimeout(12000);
  await shot('1_pick.png');

  await page.goto(base, { waitUntil: 'load', timeout: 60000 });
  await page.waitForTimeout(12000);
  await shot('2_resumed_pick.png');

  await page.keyboard.press('1');
  await page.waitForTimeout(5000);
  await page.reload({ waitUntil: 'load', timeout: 60000 });
  await page.waitForTimeout(12000);
  await shot('3_resumed_day.png');

  const keys = await page.evaluate(() => Object.keys(localStorage)
    .filter(k => k.startsWith('lst:')).map(k => [k, (localStorage.getItem(k) || '').length]));
  console.log(`${profile} (emulated): build=${build} out=${outDir}`);
  console.log('localStorage lst:* keys:');
  if (keys.length === 0) console.log('  (none)');
  for (const [k, n] of keys) console.log(`  ${k}: ${n} chars`);
} finally { await browser.close(); }
console.log(`page errors: ${pageErrors.length}`);
for (const e of pageErrors) console.log(`  [pageerror] ${e}`);
console.log(`console errors: ${consoleErrors.length}`);
for (const e of consoleErrors) console.log(`  [console.error] ${e}`);
process.exit(failed ? 1 : 0);
