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
//   --dpr=N          device pixel ratio of the page (default 1; 2 is a Retina screen)
//   --verbose        print every console line
//   --serve[=PORT]   only serve --dir (default port 8060) with those headers until killed, for a
//                    person to play in their own browser: dev mode's "play it" (src/dev/dev_jobs.gd)
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const opt = { dir: 'build/web', out: 'shots/export/web', args: '', after: '4', timeout: '90', resize: '' };
for (const a of process.argv.slice(2)) {
  const m = a.match(/^--([^=]+)(?:=(.*))?$/);
  if (m) opt[m[1]] = m[2] === undefined ? true : m[2];
}
// --url= proves a build that is already on the internet (tools/deploy.sh) with
// the same checks a local one gets: the host sends the headers, not us, so a
// deploy that forgets cross-origin isolation or the wasm type fails here.
const live = typeof opt.url === 'string' && opt.url !== '';
const root = path.resolve(opt.dir);
if (!live && !fs.existsSync(path.join(root, 'index.html'))) {
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
// The first load's wasm is held back until the shell has been shot, so the page
// the shell draws while the engine downloads can be seen and compared.
let releaseWasm = () => {};
let wasmHeldAt = 0;
let wasmHeldMs = 0;
const wasmGate = new Promise((r) => { releaseWasm = () => { if (wasmHeldAt) wasmHeldMs = Date.now() - wasmHeldAt; r(); }; });
const server = http.createServer(async (req, res) => {
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
  if (file.endsWith('.wasm')) {
    if (!wasmHeldAt) wasmHeldAt = Date.now();
    await wasmGate;
  }
  const accept = String(req.headers['accept-encoding'] || '');
  let body = file;
  if (/\bbr\b/.test(accept) && fs.existsSync(file + '.br')) { body = file + '.br'; headers['Content-Encoding'] = 'br'; }
  else if (/\bgzip\b/.test(accept) && fs.existsSync(file + '.gz')) { body = file + '.gz'; headers['Content-Encoding'] = 'gzip'; }
  headers['Content-Length'] = fs.statSync(body).size;
  served.set(rel, { bytes: headers['Content-Length'], encoding: headers['Content-Encoding'] || 'identity' });
  res.writeHead(200, headers);
  fs.createReadStream(body).pipe(res);
});
let port = 0;
if (!live) {
  const want = opt.serve ? Number(opt.serve === true ? 8060 : opt.serve) : 0;
  const listen = (p) => new Promise((ok, no) => { server.once('error', no); server.listen(p, '127.0.0.1', ok); });
  // A port still held (a server another run left) gives way to any free one.
  try { await listen(want); } catch (e) { if (e.code !== 'EADDRINUSE' || !want) throw e; await listen(0); }
  port = server.address().port;
}
if (opt.serve) {
  // Nothing to shoot: the wasm goes out at once, and the server stays up until killed.
  releaseWasm();
  console.log(`web serving http://127.0.0.1:${port}/ (${path.relative(process.cwd(), root)})`);
  // Started by a game (dev mode's "play it"), it goes when that game does, however
  // it ended: an orphan is handed to another parent.
  const parent = process.ppid;
  setInterval(() => { if (process.ppid !== parent) process.exit(0); }, 2000);
  await new Promise(() => {});
}
// Loaded here, not at the top, so serving needs no browser installed.
const { chromium } = await import('playwright');

// ---- browser --------------------------------------------------------------
// Headless Chromium on the machine's GPU (Metal through ANGLE on macOS, the
// platform default elsewhere). SwiftShader draws a game frame in seconds.
const gpuArgs = process.platform === 'darwin' ? ['--use-angle=metal'] : [];
// Audio waits for a gesture, as in a browser a player opens (headless otherwise
// lets a page start sound on its own, and the first-key rule would go untested).
const launchArgs = [...(opt.swiftshader
  ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
  : [...gpuArgs, '--ignore-gpu-blocklist', '--enable-gpu']), '--autoplay-policy=user-gesture-required'];
const browser = await chromium.launch({ headless: !opt.headed, args: launchArgs });
// Not a whole multiple of 640x360: the game (and the shell before it) sit in black bars.
const context = await browser.newContext({ viewport: { width: 1440, height: 789 }, deviceScaleFactor: Number(opt.dpr || 1) });
// Record every AudioContext the engine makes, so the check can see it start, and
// tap whatever the engine connects to the speakers, so it can hear the result.
// Playwright's Chromium lets any page play sound and reports a gesture from the
// start, so the browser's rule is put back here: until a real (trusted) key or
// click, a context is suspended, resume() does nothing, and
// navigator.userActivation says no gesture yet. The engine must start its sound
// after the first key by itself.
await context.addInitScript(() => {
  window.__audio = [];
  window.__taps = [];
  window.__gestured = false;
  const mark = (e) => { if (e.isTrusted) window.__gestured = true; };
  for (const type of ['keydown', 'mousedown', 'pointerdown', 'touchstart']) window.addEventListener(type, mark, true);
  try {
    Object.defineProperty(Navigator.prototype, 'userActivation', {
      configurable: true,
      get: () => ({ hasBeenActive: window.__gestured, isActive: window.__gestured }),
    });
  } catch (e) { /* the real one stays */ }
  const Real = window.AudioContext;
  if (Real) {
    window.AudioContext = class extends Real {
      constructor(...a) {
        super(...a);
        window.__audio.push(this);
        if (!window.__gestured) Real.prototype.suspend.call(this);
      }
      resume() {
        return window.__gestured ? Real.prototype.resume.call(this) : new Promise(() => {});
      }
    };
  }
  const connect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (dest, ...rest) {
    const out = connect.call(this, dest, ...rest);
    if (typeof AudioDestinationNode !== 'undefined' && dest instanceof AudioDestinationNode) {
      const tap = this.context.createAnalyser();
      tap.fftSize = 2048;
      tap.smoothingTimeConstant = 0;
      connect.call(this, tap);
      window.__taps.push(tap);
    }
    return out;
  };
  // What reaches the speakers right now: the loudest sample (0..1), and the
  // strongest frequency with the share of all power within 3 bins of it (a pure
  // test tone puts nearly all of it there; a game's mix spreads it).
  window.__loudness = () => {
    let peak = 0;
    let best = null;
    for (const t of window.__taps) {
      const buf = new Float32Array(t.fftSize);
      t.getFloatTimeDomainData(buf);
      let p = 0;
      for (const v of buf) p = Math.max(p, Math.abs(v));
      peak = Math.max(peak, p);
      if (p < 0.001) continue;
      const spec = new Float32Array(t.frequencyBinCount);
      t.getFloatFrequencyData(spec);
      let top = 0, total = 0;
      const pow = spec.map((db) => Math.pow(10, db / 10));
      for (let i = 0; i < pow.length; i += 1) { total += pow[i]; if (pow[i] > pow[top]) top = i; }
      let near = 0;
      for (let i = Math.max(0, top - 3); i <= Math.min(pow.length - 1, top + 3); i += 1) near += pow[i];
      const hz = top * t.context.sampleRate / t.fftSize;
      if (!best || p > best.peak) best = { peak: p, hz, share: total > 0 ? near / total : 0 };
    }
    return { peak, hz: best ? best.hz : 0, share: best ? best.share : 0 };
  };
});

// Listen at the speakers for up to `secs` (or `until` the first sound, when
// asked): the loudest sample heard (0..1), and the strongest frequency and its
// share of the power at that loudest moment.
async function listen(secs, { until = true } = {}) {
  let heard = { peak: 0, hz: 0, share: 0 };
  let end = Date.now() + secs * 1000;
  let caught = false;
  while (Date.now() < end) {
    const now = await page.evaluate(() => window.__loudness());
    if (now.peak > heard.peak) heard = now;
    // Once something is heard, a second more: the loudest moment of a sound, not its first edge.
    if (until && !caught && heard.peak >= 0.001) { caught = true; end = Math.min(end, Date.now() + 1000); }
    await page.waitForTimeout(40);
  }
  return heard;
}
// The probe's test tone: 440 Hz, alone.
const isTone = (h) => h.peak >= 0.001 && Math.abs(h.hz - 440) < 30 && h.share > 0.8;
const dbfs = (h) => (h.peak > 0 ? (20 * Math.log10(h.peak)).toFixed(1) : '-inf');
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
  // Serving a live build, the host is the one being judged: what it actually put
  // on the wire, and how it encoded it, comes from the response itself.
  if (live && r.status() < 400) {
    const h = r.headers();
    const size = Number(h['content-length'] || 0);
    if (size > 0) served.set(new URL(r.url()).pathname, { bytes: size, encoding: h['content-encoding'] || 'identity' });
  }
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

// Where BootPage draws its progress line, read from the page's own source rather
// than copied here: when the line moved to make room for the bezel this probe was
// the one copy that did not follow, and `tools/web.sh` failed on a page that was
// correct. src/boot/shell.html is held to the same constants by
// tests/export/test_export.gd, so all three can only ever say one thing.
const PAGE_LINE = (() => {
  const src = fs.readFileSync(new URL('../../src/boot/boot_page.gd', import.meta.url), 'utf8');
  const num = (name) => {
    const m = src.match(new RegExp(`^const ${name} := (-?\\d+)$`, 'm'));
    if (!m) throw new Error(`tools/web/web.mjs cannot find BootPage.${name}: the loading page moved`);
    return Number(m[1]);
  };
  return { y: num('LINE_Y'), x0: num('LINE_X0'), x1: num('LINE_X1') };
})();

// The loading page in a frame (the shell's or the engine's): the glass rectangle,
// how far the line is lit (in game pixels from its start) and the ink of the words.
async function inspectPage(pngPath) {
  const b64 = fs.readFileSync(pngPath).toString('base64');
  return page.evaluate(async ([data, line]) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + data;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const px = g.getImageData(0, 0, c.width, c.height).data;
    const rgb = (x, y) => { const i = (y * c.width + x) * 4; return [px[i], px[i + 1], px[i + 2]]; };
    let x0 = c.width, y0 = c.height, x1 = -1, y1 = -1;
    for (let y = 0; y < c.height; y += 1) for (let x = 0; x < c.width; x += 1) {
      const [r, gg, b] = rgb(x, y);
      if (r + gg + b > 0) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    }
    const w = x1 - x0 + 1, h = y1 - y0 + 1;
    const s = Math.max(1, Math.round(w / 640));
    const at = (gx, gy) => rgb(x0 + gx * s, y0 + gy * s);
    // By brightness, not by one channel: the page is drawn in the slate's phosphor.
    const lum = ([r, gg, b]) => 0.2126 * r + 0.7152 * gg + 0.0722 * b;
    let lit = -1;
    for (let gx = line.x0; gx <= line.x1; gx += 1) if (lum(at(gx, line.y)) > 96) lit = gx - line.x0;
    // The words stand one line above the rail (BootPage: LINE_Y - 16), so they
    // occupy rows LINE_Y-15 .. LINE_Y-7 of the first hundred pixels of the span.
    let ink = 0;
    for (let gy = line.y - 15; gy < line.y - 6; gy += 1) for (let gx = line.x0; gx < line.x0 + 104; gx += 1) if (lum(at(gx, gy)) > 64) ink += 1;
    return { rect: [x0, y0, w, h], scale: s, lit, ink };
  }, [b64, PAGE_LINE]);
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
// Tool options in the address must never reach the build (the shell drops them):
// a --shot here would quit the game after one frame, a --give would cheat.
const args = ['--probe', ...(extra.some((a) => a.startsWith('--scene')) ? [] : ['--scene=title']), '--shot=web-must-not-quit.png', '--give=scrap:99', ...extra];
const query = '?' + args.map((a) => {
  const [k, ...v] = a.split('=');
  return v.length ? `${encodeURIComponent(k)}=${encodeURIComponent(v.join('='))}` : encodeURIComponent(k);
}).join('&');
const url = live ? `${String(opt.url).replace(/\/$/, '')}/${query}` : `http://127.0.0.1:${port}/index.html${query}`;
console.log(`web ${live ? String(opt.url) : path.relative(process.cwd(), root)} on ${url} (${opt.swiftshader ? 'swiftshader' : 'gpu'})`);
const result = {};

async function boot(label, from = lines.length) {
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
// The shell, while the engine's wasm is held back, then the engine's first page
// frame once the shell has gone: the same rectangle, the same line, never shorter.
if (await page.waitForFunction(() => window.unspentShell && window.unspentShell().shown, null, { timeout: 20000 }).catch(() => null)) {
  await page.waitForTimeout(400);
  const shellFile = `${opt.out}_shell.png`;
  await page.screenshot({ path: shellFile });
  const shell = await inspectPage(shellFile);
  const state = await page.evaluate(() => window.unspentShell());
  releaseWasm();
  const gone = await page.waitForFunction(() => !window.unspentShell().shown, null, { timeout: Number(opt.timeout) * 1000 }).catch(() => null);
  const handFile = `${opt.out}_handover.png`;
  await page.screenshot({ path: handFile });
  const hand = await inspectPage(handFile);
  console.log(`web shell ${shellFile}: glass ${shell.rect.join(',')} x${shell.scale}, line lit ${shell.lit} px, words ${shell.ink} px ('${state.words}', ${(state.progress * 100).toFixed(0)}%)`);
  console.log(`web handover ${handFile}: glass ${hand.rect.join(',')} x${hand.scale}, line lit ${hand.lit} px, words ${hand.ink} px`);
  const want = [state.rect.x, state.rect.y, state.rect.w, state.rect.h];
  if (!gone) failures.push('the engine\'s loading page never took over from the shell');
  if (shell.rect.join() !== want.join()) failures.push(`the shell's glass ${shell.rect.join(',')} is not where the game will be drawn (${want.join(',')})`);
  if (hand.rect.join() !== shell.rect.join()) failures.push(`the glass moved at the hand-over: shell ${shell.rect.join(',')}, engine ${hand.rect.join(',')}`);
  if (shell.ink === 0 || hand.ink === 0) failures.push(`the words are missing (shell ${shell.ink} px, engine ${hand.ink} px)`);
  if (hand.lit < shell.lit) failures.push(`the line went back at the hand-over: shell lit ${shell.lit} px, engine ${hand.lit} px`);
} else {
  releaseWasm();
  failures.push('the shell never drew its page');
}
const first = await boot('', 0);
if (first) {
  // The wasm was held while the shell was shot: that wait is not the build's.
  result.first_frame_s = first.t - wasmHeldMs / 1000;
  console.log(`web first frame ${result.first_frame_s.toFixed(2)} s after navigation, not counting ${(wasmHeldMs / 1000).toFixed(2)} s the harness held the wasm (${first.text})`);
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
  if (before.includes('running')) failures.push('audio was running before any key: the browser held nothing back, so the first-key start is untested');
  if (!after.includes('running')) failures.push(`audio did not start after the first key (contexts: ${after.join(',') || 'none'})`);
  // The probe answers the key with a short tone: it must come out of the page.
  const tone = await listen(4);
  console.log(`web speakers: loudest sample ${dbfs(tone)} dBFS after the first key (${tone.hz.toFixed(0)} Hz, ${(tone.share * 100).toFixed(0)}% of the power there)`);
  if (tone.peak < 0.001) failures.push('nothing reached the speakers after the first key (the probe plays a tone)');
  // The same ears must know the tone, or telling the game from it below means nothing.
  else if (!isTone(tone)) failures.push(`the probe's tone was heard but not recognised as 440 Hz (${tone.hz.toFixed(0)} Hz, ${(tone.share * 100).toFixed(0)}%)`);
  if (!(await waitLine(/^web probe done/, 30, 0))) failures.push('the probe on the first scene never finished');
  const started = lines.find((l) => /^web probe start/.test(l.text));
  if (!started) failures.push('the probe never started');
  else if (/--(shot|give)/.test(started.text)) failures.push(`tool options in the address reached the build: ${started.text}`);

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
      // The game's probe plays no tone (the title proved the path): once it has
      // heard the game on the bus, what the speakers carry is the game.
      if (!(await waitLine(/^web (ok|FAIL) audio game/, 40, from))) failures.push('the probe on the game never reported its sound');
      const heard = await listen(6, { until: false });
      const graph = await page.evaluate(() => ({ taps: window.__taps.length, contexts: window.__audio.map((a) => `${a.state}@${a.currentTime.toFixed(1)}s/${a.sampleRate}`) }));
      console.log(`web speakers: loudest sample ${dbfs(heard)} dBFS in the game over 6 s (${heard.hz.toFixed(0)} Hz strongest, ${(heard.share * 100).toFixed(0)}% of the power there; ${graph.taps} outputs tapped, contexts ${graph.contexts.join(' ')})`);
      if (heard.peak < 0.001) failures.push('nothing reached the speakers in 6 s of the game');
      if (isTone(heard)) failures.push(`what reached the speakers in the game is the probe's 440 Hz test tone, not the game (${dbfs(heard)} dBFS)`);
      if (lines.slice(from).some((l) => /^web ok audio path/.test(l.text))) failures.push('the game\'s probe played its test tone again after the title proved the path');
      if (!(await waitLine(/^web probe done/, 40, from))) failures.push('the probe on the game never finished');
    }
  }

  if (opt.resize) {
    const [w, h] = opt.resize.split('x').map(Number);
    await page.setViewportSize({ width: w, height: h });
    await page.waitForTimeout(1500);
    const dpr = Number(opt.dpr || 1);
    await shoot(`resize-${w}x${h}`, { expectScale: Math.max(1, Math.min(Math.floor(w * dpr / 640), Math.floor(h * dpr / 360))) });
  }

  if (opt.reload) {
    const from = lines.length;
    t0 = Date.now();
    await page.reload();
    const again = await boot('reload-', from);
    if (again) {
      console.log(`web reload first frame ${again.t.toFixed(2)} s`);
      result.reload_s = again.t;
      if (!(await waitLine(/^web ok save kept/, 20, from))) failures.push('user:// did not keep the save across a reload (IndexedDB)');
      if (!(await waitLine(/^web ok slot kept/, 20, from))) failures.push('a real save slot did not come back whole across a reload (IndexedDB)');
    }
  }
}

for (const [u, why] of aborted) if (!answered.has(u)) failures.push(`request never answered: ${u} (${why})`);
let wire = 0;
for (const r of served.values()) wire += r.bytes;
const big = [...served.entries()].filter(([p]) => /\.(wasm|pck)$/.test(p)).map(([p, r]) => `${path.basename(p)} ${(r.bytes / 1048576).toFixed(1)} MB ${r.encoding}`);
// A host that streams a compressed body sends no length, so say nothing rather
// than report zero megabytes as if the game arrived out of thin air.
if (live && wire === 0) console.log('web served: the host did not say how much (compressed, no content-length)');
else
console.log(`web served ${(wire / 1048576).toFixed(1)} MB over the wire (${big.join(', ')})`);
await browser.close();
if (!live) server.close();
if (failures.length) {
  for (const f of [...new Set(failures)]) console.log(`web FAILED: ${f}`);
  process.exit(1);
}
const parts = [`first frame ${result.first_frame_s.toFixed(2)} s`];
if (result.new_game_s !== undefined) parts.push(`new game ${result.new_game_s.toFixed(2)} s after Enter`);
if (result.reload_s !== undefined) parts.push(`reload ${result.reload_s.toFixed(2)} s`);
console.log(`web OK: ${parts.join(', ')}`);
