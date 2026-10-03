// Usage: node export/pw_check.mjs <url> <out.png> [profile]   (D-138, D-141)
// From S3 on, a plain URL resumes a saved run from localStorage. Add ?reset=1 to debug URLs for a fresh start.
// Release URLs can't be reset; use a fresh browser profile.
// profile: "android" (Playwright "Pixel 7" device: touch, mobile UA, portrait) or "desktop" (720x1280).
// Chromium with software WebGL (SwiftShader). Prints console messages and page errors; exits 1 on a
// page error or when the page never sets window.LST_BUILD. Playwright comes from $LST_PW_DIR.
import { createRequire } from 'node:module';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs';
const [url, out, profile = 'android'] = process.argv.slice(2);
if (!url || !out) { console.error('usage: node pw_check.mjs <url> <out.png> [android|desktop]'); process.exit(2); }
const pwDir = process.env.LST_PW_DIR || path.join(os.homedir(), '.cache', 'lst-playwright');
const { chromium, devices } = createRequire(path.join(pwDir, 'package.json'))('playwright');
const ctxOpts = profile === 'android'
  ? { ...devices['Pixel 7'] }
  : { viewport: { width: 720, height: 1280 } };
const browser = await chromium.launch({ headless: true,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
let failed = false;
try {
  const page = await (await browser.newContext(ctxOpts)).newPage();
  // CONSOLE_OUT=<file>: also append every console and page-error line to that file (S5 Task 1 baseline).
  const consoleOut = process.env.CONSOLE_OUT;
  if (consoleOut) fs.writeFileSync(consoleOut, '');
  const emit = line => { console.log(line); if (consoleOut) fs.appendFileSync(consoleOut, line + '\n'); };
  page.on('console', m => emit(`[console.${m.type()}] ${m.text()}`));
  page.on('pageerror', e => { failed = true; emit(`[pageerror] ${e.message}`); });
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  const build = await page.waitForFunction(() => window.LST_BUILD, null, { timeout: 30000 })
    .then(h => h.jsonValue()).catch(() => null);
  if (!build) { failed = true; console.log('no window.LST_BUILD'); }
  await page.waitForTimeout(Number(process.env.WAIT_S || 15) * 1000);
  await page.screenshot({ path: out });
  console.log(`${profile} (emulated): build=${build} screenshot=${out}`);
} finally { await browser.close(); }
process.exit(failed ? 1 : 0);
