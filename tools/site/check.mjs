// The landing page, loaded in a real browser:
//   node tools/site/check.mjs URL [--out=DIR]
// Fails on a console error, a request that failed or answered 400+, a page that
// is not lettered in the game's face, a frame that did not load, or a Play link
// that does not lead to a build. Saves what a desktop and a phone saw to DIR
// (default shots/site). tools/deploy.sh runs it against the deployed URL; run it
// on a local copy with `python3 -m http.server -d site` while working on site/.
import { chromium } from '../web/node_modules/playwright/index.mjs';
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const url = args.find((a) => !a.startsWith('--'));
const out = (args.find((a) => a.startsWith('--out=')) || '--out=shots/site').slice(6);
if (!url) { console.error('usage: node tools/site/check.mjs URL [--out=DIR]'); process.exit(2); }
fs.mkdirSync(out, { recursive: true });

const browser = await chromium.launch();
const bad = [];
for (const [name, view] of [['desktop', { width: 1600, height: 1000 }], ['phone', { width: 390, height: 844 }]]) {
  const page = await browser.newPage({ viewport: view, deviceScaleFactor: name === 'phone' ? 3 : 1 });
  // A failed load is judged by its response below, which knows which URL it was.
  page.on('console', (m) => { if (m.type() === 'error' && !m.text().startsWith('Failed to load resource')) bad.push(`${name} console: ${m.text()}`); });
  page.on('pageerror', (e) => bad.push(`${name} script: ${e.message}`));
  page.on('requestfailed', (r) => bad.push(`${name} failed: ${r.url()} ${r.failure()?.errorText}`));
  page.on('response', (r) => {
    // latest.json is allowed to be missing: no release has been published yet.
    if (r.status() >= 400 && !r.url().endsWith('/releases/latest.json')) bad.push(`${name} HTTP ${r.status()}: ${r.url()}`);
  });
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  const face = await page.evaluate(() => document.fonts.check('20px "UNSPENT 5x7"'));
  if (!face) bad.push(`${name}: the game's face did not load`);
  const frames = await page.$$eval('img', (imgs) => imgs.map((i) => ({ src: i.currentSrc || i.src, ok: i.complete && i.naturalWidth > 0, lazy: i.loading === 'lazy' })));
  // Lazy frames below the fold load as the page scrolls; scroll them in and look again.
  await page.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 600) { window.scrollTo(0, y); await new Promise((r) => setTimeout(r, 60)); } window.scrollTo(0, 0); });
  await page.waitForLoadState('networkidle');
  const loaded = await page.$$eval('img', (imgs) => imgs.map((i) => ({ src: i.currentSrc || i.src, ok: i.complete && i.naturalWidth > 0 })));
  for (const f of loaded) if (!f.ok) bad.push(`${name}: frame did not load: ${f.src}`);
  const play = await page.$eval('a.btn.primary', (a) => a.getAttribute('href'));
  if (play !== '/play') bad.push(`${name}: the first button goes to ${play}, not /play`);
  await page.screenshot({ path: path.join(out, `${name}.png`), fullPage: true });
  await page.screenshot({ path: path.join(out, `${name}-top.png`) });
  console.log(`site ${name}: ${frames.length} frames, face ${face ? 'ok' : 'MISSING'}`);
  await page.close();
}
await browser.close();
if (bad.length) { for (const b of bad) console.log(`site FAILED: ${b}`); process.exit(1); }
console.log(`site ok ${url} (shots in ${out})`);
