// Usage: node export/pw_perf.mjs <base_url> <out_dir>   (S4 Task 5, emulated Pixel 7, D-141)
// base_url serves the profile build plus seed_save.html and fixtures/ (export/perf_night3.sh copies them in).
// Opens seed_save.html?f=night3_start&to=<path>, waits 100 s (the overlay freezes its night reading at 62 s into the phase), screenshots night3_80s_emulated.png and prints the
// console `PERF phase=NIGHT ...` line (frozen by the perf overlay 62 s into the phase). Exit 1 on page errors or no line.
import { createRequire } from 'node:module';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs';
const [base, outDir] = process.argv.slice(2);
if (!base || !outDir) { console.error('usage: node pw_perf.mjs <base_url> <out_dir>'); process.exit(2); }
fs.mkdirSync(outDir, { recursive: true });
const pwDir = process.env.LST_PW_DIR || path.join(os.homedir(), '.cache', 'lst-playwright');
const { chromium, devices } = createRequire(path.join(pwDir, 'package.json'))('playwright');
const browser = await chromium.launch({ headless: true,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const perf = [];
let errors = 0;
try {
  const u = new URL(base);
  const gamePath = u.pathname.endsWith('/') ? u.pathname : u.pathname + '/';
  const page = await (await browser.newContext({ ...devices['Pixel 7'] })).newPage();
  page.on('console', m => { if (m.text().includes('PERF')) perf.push(m.text()); });
  page.on('pageerror', e => { errors++; console.log('pageerror: ' + e.message); });
  await page.goto(`${u.origin}${gamePath}seed_save.html?f=night3_start&to=${encodeURIComponent(gamePath)}`,
    { waitUntil: 'load', timeout: 60000 });
  await page.waitForTimeout(100000);
  await page.screenshot({ path: path.join(outDir, 'night3_80s_emulated.png') });
} finally { await browser.close(); }
console.log(`android (emulated): out=${outDir}`);
const night = perf.filter(l => l.includes('phase=NIGHT'));
for (const l of night) console.log(l);
if (night.length === 0) { console.log('(no phase=NIGHT PERF line)'); process.exitCode = 1; }
console.log(`page errors: ${errors}`);
if (errors > 0) process.exitCode = 1;
