// Boot an exported web build in headless Chromium and prove it runs. tools/web.sh
// is the everyday entry; this is the part that drives the browser.
//   node tools/web/web.mjs --dir=build/web --out=shots/export/web [options]
//
// Serves --dir with the headers a threaded Godot build needs (COOP/COEP/CORP),
// the wasm MIME type, and the precompressed .br/.gz siblings tools/export.sh
// writes. Opens the page with --probe, shoots the loading page, waits for the
// game's own ready line (main.gd prints `boot ready <scene> <ms>` once the first
// frame of a world is drawn) and shoots then and --after seconds later.
// With --play it presses what a player would (Enter on the title: New game),
// waits for `boot ready game`, walks with the real keys and shoots the game.
//
// FAILS (exit 1) on: a console error, a page error, a request that never
// completes, no ready line within --timeout, a blank canvas, a canvas that is not
// an exact integer nearest upscale of 640x360, the canvas not holding keyboard
// focus, an AudioContext that is not running after the first key, and any
// `web FAIL` line from the in-game probe (src/boot/web_probe.gd: systems, focus,
// audio on the master bus, saves on IndexedDB).
//
// Options:
//   --dir=PATH       exported build to serve (default build/web)
//   --out=PREFIX     screenshot prefix (default shots/export/web)
//   --args=A,B       extra boot arguments (the shell passes the query string after --)
//   --after=SECS     second screenshot this long after ready (default 4)
//   --timeout=SECS   each ready line must come within this (default 90)
//   --play           start a new game from the title with real keys and shoot it
//   --reload         reload and require user:// (IndexedDB) to have kept the probe's save
//   --resize=WxH     then resize the page and require the scale to stay an exact integer
//   --swiftshader    render on the CPU (hosts with no GPU; a game frame can take seconds)
//   --headed         show the browser
//   --verbose        print every console line
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const opt = { dir: 'build/web', out: 'shots/export/web', args: '', after: '4', timeout: '90', resize: '' };
for (const a of process.argv.slice(2)) {
  const m = a.match(/^--([^=]+)(?:=(.*))?$/);
  if (m) opt[m[1]] = m[2] === undefined ? true : m[2];
}
const root = path.resolve(opt.dir);
if (!fs.existsSync(path.join(root, 'index.html'))) {
  console.log(`web FAILED: no build at ${root} (tools/export.sh web)`);
  process.exit(1);
}
fs.mkdirSync(path.dirname(path.resolve(opt.out)), { recursive: true });

// ---- server ---------------------------------------------------------------
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json', '.svg': 'image/svg+xml',
};
const served = new Map();
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  const rel = url.pathname === '/' ? '/index.html' : decodeURIComponent(url.pathname);
  const file = path.join(root, path.normalize(rel));
  if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404); res.end(); return;
  }
  const headers = {
    'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cross-Origin-Resource-Policy': 'same-origin',
    'Cache-Control': 'no-store',
    'Vary': 'Accept-Encoding',
  };
  const accept = String(req.headers['accept-encoding'] || '');
  let body = file;
  if (/\bbr\b/.test(accept) && fs.existsSync(file + '.br')) { body = file + '.br'; headers['Content-Encoding'] = 'br'; }
  else if (/\bgzip\b/.test(accept) && fs.existsSync(file + '.gz')) { body = file + '.gz'; headers['Content-Encoding'] = 'gzip'; }
  headers['Content-Length'] = fs.statSync(body).size;
  served.set(rel, { bytes: headers['Content-Length'], encoding: headers['Content-Encoding'] || 'identity' });
  res.writeHead(200, headers);
  fs.createReadStream(body).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

// ---- browser --------------------------------------------------------------
// Headless Chromium on the machine's GPU (Metal through ANGLE on macOS, the
// platform default elsewhere). SwiftShader draws a game frame in seconds.
const gpuArgs = process.platform === 'darwin' ? ['--use-angle=metal'] : [];
const launchArgs = opt.swiftshader
  ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
  : [...gpuArgs, '--ignore-gpu-blocklist', '--enable-gpu'];
const browser = await chromium.launch({ headless: !opt.headed, args: launchArgs });
const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
// Record every AudioContext the engine makes, so the check can see it start, and
// tap whatever the engine connects to the speakers, so it can hear the result.
await context.addInitScript(() => {
  window.__audio = [];
  window.__taps = [];
  const Real = window.AudioContext;
  if (Real) {
    window.AudioContext = class extends Real {
      constructor(...a) { super(...a); window.__audio.push(this); }
    };
  }
  const connect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (dest, ...rest) {
    const out = connect.call(this, dest, ...rest);
    if (typeof AudioDestinationNode !== 'undefined' && dest instanceof AudioDestinationNode) {
      const tap = this.context.createAnalyser();
      tap.fftSize = 2048;
      connect.call(this, tap);
      window.__taps.push(tap);
    }
    return out;
  };
  // Loudest sample (0..1) reaching the speakers right now.
  window.__loudness = () => {
    let peak = 0;
    for (const t of window.__taps) {
      const buf = new Float32Array(t.fftSize);
      t.getFloatTimeDomainData(buf);
      for (const v of buf) peak = Math.max(peak, Math.abs(v));
    }
    return peak;
  };
});

// Listen at the speakers for up to `secs`: the loudest sample heard (0..1).
async function listen(secs) {
  let peak = 0;
  const end = Date.now() + secs * 1000;
  while (Date.now() < end && peak < 0.001) {
    peak = Math.max(peak, await page.evaluate(() => window.__loudness()));
    await page.waitForTimeout(100);
  }
  return peak;
}
const page = await context.newPage();
const failures = [];
const lines = [];
let t0 = Date.now();
const since = () => ((Date.now() - t0) / 1000).toFixed(2);
page.on('console', (m) => {
  const text = m.text();
  lines.push({ t: Number(since()), type: m.type(), text });
  if (opt.verbose || m.type() === 'error' || /^(boot|web) /.test(text)) console.log(`  [${since()}s ${m.type()}] ${text}`);
  if (m.type() === 'error') failures.push(`console error: ${text}`);
  if (/^web FAIL/.test(text)) failures.push(text);
});
page.on('pageerror', (e) => { failures.push(`page error: ${e.message}`); console.log(`  [${since()}s pageerror] ${e.message}`); });
// The engine's loader cancels its first fetch of the wasm once it has the bytes
// streaming: a cancelled request only fails the run if that URL never answered.
const aborted = new Map();
const answered = new Set();
page.on('requestfailed', (r) => aborted.set(r.url(), r.failure()?.errorText));
page.on('response', (r) => {
  if (r.status() >= 400) failures.push(`HTTP ${r.status()}: ${r.url()}`);
  else answered.add(r.url());
});

function waitLine(re, secs, from = 0) {
  return new Promise((resolve) => {
    const deadline = Date.now() + secs * 1000;
    const tick = () => {
      const hit = lines.slice(from).find((l) => re.test(l.text));
      if (hit) return resolve(hit);
      if (Date.now() > deadline || failures.some((f) => f.startsWith('page error'))) return resolve(null);
      setTimeout(tick, 25);
    };
    tick();
  });
}

// Pixels of the page as shown: blank or not, and whether every game pixel is an
// exact square block (the 640x360 image upscaled by a whole number, nearest).
async function inspect(pngPath) {
  const b64 = fs.readFileSync(pngPath).toString('base64');
  return page.evaluate(async (data) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + data;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const px = g.getImageData(0, 0, c.width, c.height).data;
    const at = (x, y) => { const i = (y * c.width + x) * 4; return (px[i] << 16) | (px[i + 1] << 8) | px[i + 2]; };
    // The drawn area: the bounding box of pixels that are not the letterbox black.
    let x0 = c.width, y0 = c.height, x1 = -1, y1 = -1;
    for (let y = 0; y < c.height; y += 1) for (let x = 0; x < c.width; x += 1) {
      if (at(x, y) !== 0) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    }
    const colours = new Set();
    for (let y = 0; y < c.height; y += 5) for (let x = 0; x < c.width; x += 5) colours.add(at(x, y));
    const w = x1 - x0 + 1, h = y1 - y0 + 1;
    const scale = Math.max(1, Math.round(w / 640));
    let blocks = 0, uniform = 0;
    for (let by = 0; by < 360; by += 3) for (let bx = 0; bx < 640; bx += 3) {
      const ox = x0 + bx * scale, oy = y0 + by * scale;
      if (ox + scale > c.width || oy + scale > c.height) continue;
      const v = at(ox, oy);
      let same = true;
      for (let dy = 0; dy < scale && same; dy += 1) for (let dx = 0; dx < scale; dx += 1) if (at(ox + dx, oy + dy) !== v) { same = false; break; }
      blocks += 1; if (same) uniform += 1;
    }
    return { drawn: [x0, y0, w, h], colours: colours.size, scale, uniform: blocks ? uniform / blocks : 0 };
  }, b64);
}

async function shoot(name, { expectScale = null, still = false } = {}) {
  const file = `${opt.out}_${name}.png`;
  try {
    await page.screenshot({ path: file, timeout: 60000 });
  } catch (e) {
    failures.push(`${file}: the page drew no frame for a minute (${e.message.split('\n')[0]})`);
    return null;
  }
  const s = await inspect(file);
  console.log(`web shot ${file} at ${since()}s: ${s.colours} colours, ${s.drawn[2]}x${s.drawn[3]} at ${s.drawn[0]},${s.drawn[1]} (x${s.scale}, ${(s.uniform * 100).toFixed(1)}% blocks exact)`);
  if (!still && s.colours < 24) failures.push(`blank canvas in ${file} (${s.colours} colours)`);
  // The loading page is mostly one dark colour, so its bounding box says little.
  if (!still) {
    const [, , w, h] = s.drawn;
    if (w !== 640 * s.scale || h !== 360 * s.scale) failures.push(`${file}: drawn ${w}x${h} is not a whole multiple of 640x360`);
    if (s.uniform < 0.995) failures.push(`${file}: only ${(s.uniform * 100).toFixed(1)}% of pixel blocks are exact (not a nearest whole-number upscale)`);
  }
  if (expectScale !== null && s.scale !== expectScale) failures.push(`${file}: scale x${s.scale}, expected x${expectScale}`);
  return s;
}

// A player's start is the title; the probe makes the query non-empty, so say so.
const extra = opt.args ? opt.args.split(',') : [];
const args = ['--probe', ...(extra.some((a) => a.startsWith('--scene')) ? [] : ['--scene=title']), ...extra];
const query = '?' + args.map((a) => {
  const [k, ...v] = a.split('=');
  return v.length ? `${encodeURIComponent(k)}=${encodeURIComponent(v.join('='))}` : encodeURIComponent(k);
}).join('&');
const url = `http://127.0.0.1:${port}/index.html${query}`;
console.log(`web ${path.relative(process.cwd(), root)} on ${url} (${opt.swiftshader ? 'swiftshader' : 'gpu'})`);
const result = {};

async function boot(label) {
  const from = lines.length;
  // The loading page, once it has sketched the island and before the world shows.
  const sketch = await waitLine(/^boot sketch/, Number(opt.timeout), from);
  if (sketch) {
    await page.waitForTimeout(250);
    if (!lines.slice(from).some((l) => /^boot ready/.test(l.text))) await shoot(`${label}loading`, { still: true });
  }
  const ready = await waitLine(/^boot ready/, Number(opt.timeout), from);
  if (!ready) {
    failures.push(`no "boot ready" line within ${opt.timeout} s`);
    await page.screenshot({ path: `${opt.out}_${label}FAILED.png` });
  }
  return ready;
}

t0 = Date.now();
await page.goto(url);
const first = await boot('');
if (first) {
  console.log(`web first frame ${first.t.toFixed(2)} s after navigation (${first.text})`);
  result.first_frame_s = first.t;
  await shoot('ready');
  const focused = await page.evaluate(() => document.activeElement && document.activeElement.id);
  if (focused !== 'canvas') failures.push(`keyboard focus is on '${focused || 'nothing'}', not the canvas`);
  await page.waitForTimeout(Number(opt.after) * 1000);
  await shoot(`ready+${opt.after}s`);

  // Browsers hold audio until a gesture: the first key must start it.
  const before = await page.evaluate(() => window.__audio.map((a) => a.state));
  await page.keyboard.press('ArrowDown');
  await page.keyboard.press('ArrowUp');
  await page.waitForTimeout(500);
  const after = await page.evaluate(() => window.__audio.map((a) => a.state));
  console.log(`web audio contexts [${before}] before the first key, [${after}] after`);
  if (!after.includes('running')) failures.push(`audio did not start after the first key (contexts: ${after.join(',') || 'none'})`);
  // The probe answers the key with a short tone: it must come out of the page.
  const tone = await listen(4);
  console.log(`web speakers: loudest sample ${tone > 0 ? (20 * Math.log10(tone)).toFixed(1) : '-inf'} dBFS after the first key`);
  if (tone < 0.001) failures.push('nothing reached the speakers after the first key (the probe plays a tone)');
  if (!(await waitLine(/^web probe done/, 30, 0))) failures.push('the probe on the first scene never finished');

  if (opt.play) {
    const from = lines.length;
    const pressed = Date.now();
    await page.keyboard.press('Enter');
    const game = await waitLine(/^boot ready game/, Number(opt.timeout), from);
    if (!game) {
      failures.push('no "boot ready game" line after Enter on the title');
      await page.screenshot({ path: `${opt.out}_FAILED-play.png` });
    } else {
      result.new_game_s = (Date.now() - pressed) / 1000;
      console.log(`web new game drawn ${result.new_game_s.toFixed(2)} s after Enter (${game.text})`);
      await shoot('game');
      // Walk with the real keys: the probe hears this key and listens for the game.
      await page.keyboard.down('KeyD');
      await page.waitForTimeout(1500);
      await page.keyboard.up('KeyD');
      await page.keyboard.down('KeyS');
      await page.waitForTimeout(900);
      await page.keyboard.up('KeyS');
      await page.waitForTimeout(Number(opt.after) * 1000);
      await shoot(`game+${opt.after}s`);
      const heard = await listen(30);
      const db = heard > 0 ? 20 * Math.log10(heard) : -Infinity;
      const graph = await page.evaluate(() => ({ taps: window.__taps.length, contexts: window.__audio.map((a) => `${a.state}@${a.currentTime.toFixed(1)}s/${a.sampleRate}`) }));
      console.log(`web speakers: loudest sample ${db.toFixed(1)} dBFS in the game (${graph.taps} outputs tapped, contexts ${graph.contexts.join(' ')})`);
      if (heard < 0.001) failures.push('nothing reached the speakers in 30 s of the game');
      if (!(await waitLine(/^web probe done/, 40, from))) failures.push('the probe on the game never finished');
    }
  }

  if (opt.resize) {
    const [w, h] = opt.resize.split('x').map(Number);
    await page.setViewportSize({ width: w, height: h });
    await page.waitForTimeout(1500);
    await shoot(`resize-${w}x${h}`, { expectScale: Math.max(1, Math.min(Math.floor(w / 640), Math.floor(h / 360))) });
  }

  if (opt.reload) {
    const from = lines.length;
    t0 = Date.now();
    await page.reload();
    const again = await boot('reload-');
    if (again) {
      console.log(`web reload first frame ${again.t.toFixed(2)} s`);
      result.reload_s = again.t;
      if (!(await waitLine(/^web ok save kept/, 20, from))) failures.push('user:// did not keep the save across a reload (IndexedDB)');
    }
  }
}

for (const [u, why] of aborted) if (!answered.has(u)) failures.push(`request never answered: ${u} (${why})`);
let wire = 0;
for (const r of served.values()) wire += r.bytes;
const big = [...served.entries()].filter(([p]) => /\.(wasm|pck)$/.test(p)).map(([p, r]) => `${path.basename(p)} ${(r.bytes / 1048576).toFixed(1)} MB ${r.encoding}`);
console.log(`web served ${(wire / 1048576).toFixed(1)} MB over the wire (${big.join(', ')})`);
await browser.close();
server.close();
if (failures.length) {
  for (const f of [...new Set(failures)]) console.log(`web FAILED: ${f}`);
  process.exit(1);
}
const parts = [`first frame ${result.first_frame_s.toFixed(2)} s`];
if (result.new_game_s !== undefined) parts.push(`new game ${result.new_game_s.toFixed(2)} s after Enter`);
if (result.reload_s !== undefined) parts.push(`reload ${result.reload_s.toFixed(2)} s`);
console.log(`web OK: ${parts.join(', ')}`);
