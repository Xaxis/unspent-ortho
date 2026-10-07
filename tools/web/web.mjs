// Boot an exported web build in headless Chromium and prove it runs. tools/web.sh
// is the everyday entry; this is the part that drives the browser.
//   node tools/web/web.mjs --dir=build/web --out=shots/export/web [options]
//
// Serves --dir with the headers a threaded Godot build needs (COOP/COEP/CORP),
// the wasm MIME type, and the precompressed .br/.gz siblings tools/export.sh
// writes. Opens the page with --probe, shoots the loading page, waits for the
// game's own ready line (main.gd prints `boot ready <scene> <ms>` once the first
// frame of a world is drawn) and shoots then and --after seconds later.
// With --play it presses what a player would (Enter on the title: New game, then
// up to "begin" on the character page and Enter),
// waits for `boot ready game`, walks with the real keys and shoots the game.
//
// FAILS (exit 1) on: a console error, a page error, a request that never
// completes, no ready line within --timeout, a blank canvas, a canvas that is not
// the game drawn at the base's 16:9 shape, the canvas not holding keyboard
// focus, an AudioContext that is not running after the first key, a GL program
// the browser refuses to draw with (named by the .gdshader it came from, its GLSL
// kept beside the shots), and any `web FAIL` line from the in-game probe
// (src/boot/web_probe.gd: systems, focus, audio on the master bus, saves on
// IndexedDB).
//
// Options:
//   --dir=PATH       exported build to serve (default build/web)
//   --out=PREFIX     screenshot prefix (default shots/export/web)
//   --args=A,B       extra boot arguments (the shell passes the query string after --)
//   --after=SECS     second screenshot this long after ready (default 4)
//   --timeout=SECS   each ready line must come within this (default 300: a full new game
//                    raises its island in the page, and on the Linux box's GPU at load 25-43
//                    seed 7's came 100-146 s after Enter, so 90 failed runs that were only slow;
//                    2400 on the CPU, where they came 664 and 790 s at load 85-100, see `software`)
//   --play           start a new game from the title with real keys and shoot it
//   --reload         reload and require user:// (IndexedDB) to have kept the probe's save
//   --resize=WxH     then resize the page and require the scale to stay an exact integer
//   --swiftshader    render on the CPU (hosts with no GPU; a game frame can take seconds).
//                    Always, on Linux: see GPU_OFF below
//   --gpu            draw on the machine's GPU on Linux, which is refused (GPU_OFF)
//   --headed         show the browser
//   --dpr=N          device pixel ratio of the page (default 1; 2 is a Retina screen)
//   --verbose        print every console line
//   --trace          with --tour, print the tour's own step lines too (`tour t=... fps=...`), which
//                    are otherwise only kept in the tour's console.log
//   --serve[=PORT]   only serve --dir (default port 8060) with those headers until killed, for a
//                    person to play in their own browser: dev mode's "play it" (src/dev/dev_jobs.gd)
//   --tour=PATH      play a tour (tours/*.tour) inside the exported build instead of the player's
//                    flow, and keep its frames in --frames (default shots/export/tour/<name>/).
//                    A tour is a tool, so neither the file nor the option can reach a build from
//                    an address: THIS server alone hands the page the tour (Engine.preloadFile)
//                    and the arguments (--args too), and the build it proves is the same bytes a
//                    player downloads. The tour gives each frame to the page as a download
//                    (src/systems/98_tour.gd), at the base's own 1920x1080. `same` needs frames
//                    on disk and is not available to a tour played here.
//   --frames=DIR     where a tour's frames are kept
//   --window=WxH     the page's size in CSS pixels (default 1440x789; a tour defaults to 1920x1080)
//   --snap=RE:SECS   screenshot the page SECS after the first console line matching RE, from
//                    outside the engine (what a player sees while the engine is blocked)
//   --uncapped       let the page draw as fast as it can (no vsync, no frame-rate limit), so a
//                    frame's cost can be read off its interval (perf scale in a tour)
//   --tool-args=A,B  boot options no address may carry (--place, --at, ...), handed to the page by THIS
//                    server as a tour's are, after the address's own; the build is unchanged
//   --dwell=SECS     with --play, stay on the title this long before New game (a player reading it)
//   --use-after=SECS with --play, press use this long after the game is drawn: with --args=--place=shaft
//                    that goes down the shaft, and --crossing times it
//   --raised-before-game=KIND  with --play, fail unless the realm KIND stood (its `realm KIND raised`
//                    line) before the new game's first frame: the title raised it while it was read
//   --crossing=SECS  fail unless every shaft crossing the run makes takes -- from the use
//                    that starts it to the first frame of the realm below, the crossing page's own
//                    `boot stages crossing ... total` -- is at most SECS (streamed worldgen S5's bar)
//   --programs       with --tour, count the GL programs first drawn after each `echo event NAME` in
//                    the tour, by .gdshader and variant: a first-use shader compile is a freeze on the
//                    web, and at an event a player meets (a door, a fire) the count must be zero: any
//                    program first drawn after an event FAILS the run (tours/every-room.tour on CI).
//                    A built-in material is shown with its own uniforms; each program built at an
//                    event is kept as <out>-program-<event>-pN.{vs,fs}.glsl, to read what it was
//   --cold           give every vertex shader a run-unique term that is always zero, so each program
//                    is built as on a first visit: a boot's cold cost (read it off a tour's first
//                    event), without clearing the machine's shared Metal cache. A measure, not a
//                    gate: a 2D program has failed one first draw under it, never without it
//   --heap-log       print every heap sample (every 2 s, seconds since the sampler started), not only
//                    the most it held: when the heap grows says what grew it
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const opt = { dir: 'build/web', out: 'shots/export/web', args: '', after: '4', resize: '', tour: '', frames: '', window: '' };
for (const a of process.argv.slice(2)) {
  const m = a.match(/^--([^=]+)(?:=(.*))?$/);
  if (m) opt[m[1]] = m[2] === undefined ? true : m[2];
}
// NO GPU BROWSER ON LINUX. On 2026-10-03 at 02:11 a web run's headless Chromium,
// drawing through ANGLE on Vulkan (RADV, the RX 6700 XT), page-faulted the GPU
// beside a Godot render; the ring reset failed, the driver reset the whole GPU,
// video memory was lost, and the owner's desktop session went with it. Holding
// this game's heavy slots cannot prevent it: other projects' Godot and Chromium
// share the GPU and take no lock here. So on Linux every run renders on the CPU
// (SwiftShader), which is enough to prove a boot and a title, and too slow to
// raise a full island inside the boot's limit. The owner decides whether a GPU
// web run comes back; until then --gpu says so and stops.
const GPU_OFF = process.platform === 'linux';
if (GPU_OFF && opt.gpu) {
  console.log("web FAILED: GPU web runs are off on this box: a Vulkan Chromium reset the GPU and the owner's session (2026-10-03); the owner decides");
  process.exit(2);
}
const software = Boolean(opt.swiftshader) || GPU_OFF;
// On the CPU every wait is longer, measured: at load 85-100 on the Linux box
// (SwiftShader, 10-06) the title's first frame came 664 s after navigation, the
// new game 790 s after Enter and its warm-up 1003 s after, one frame 15-60 s.
if (opt.timeout === undefined) opt.timeout = software ? '2400' : '300';
// The longest one frame may hold the page before a screenshot, a read or a
// reload counts it as not drawing: a minute on a GPU, fifteen on the CPU, where
// one frame held the main thread 78 s (the title's first, building its programs),
// steady frames 15-60 s at load 75-100, and at load 100-160 a screenshot waited
// past 300 s five times in three runs (10-05/06).
const FRAME_WAIT_S = software ? 900 : 60;
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
// A tour played inside the build: what it is called, where its frames go, and
// the arguments the page is started with in place of the address's.
const touring = typeof opt.tour === 'string' && opt.tour !== '';
const toolArgs = typeof opt['tool-args'] === 'string' && opt['tool-args'] !== '' ? opt['tool-args'].split(',') : [];
const tourName = touring ? path.basename(opt.tour, '.tour') : '';
const tourDir = touring ? path.resolve(opt.frames || path.join('shots/export/tour', tourName)) : '';
if (touring) {
  if (!fs.existsSync(opt.tour)) { console.log(`web FAILED: no tour at ${opt.tour}`); process.exit(1); }
  fs.rmSync(tourDir, { recursive: true, force: true });
  fs.mkdirSync(tourDir, { recursive: true });
}

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
  if (toolArgs.length && !touring && rel === '/index.html') {
    const body = toolShell(fs.readFileSync(path.join(root, 'index.html'), 'utf8'));
    res.writeHead(200, {
      'Content-Type': TYPES['.html'],
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Resource-Policy': 'same-origin',
      'Cache-Control': 'no-store',
      'Content-Length': Buffer.byteLength(body),
    });
    res.end(body);
    return;
  }
  if (touring && (rel === '/index.html' || rel === `/__tour/${tourName}.tour`)) {
    // The page a tour runs in: the build's own shell, told what to play. Nothing
    // in the build changes; only what this server says to it.
    const body = rel === '/index.html' ? tourShell(fs.readFileSync(path.join(root, 'index.html'), 'utf8')) : fs.readFileSync(opt.tour);
    res.writeHead(200, {
      'Content-Type': rel === '/index.html' ? TYPES['.html'] : 'text/plain; charset=utf-8',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Resource-Policy': 'same-origin',
      'Cache-Control': 'no-store',
      'Content-Length': Buffer.byteLength(body),
    });
    res.end(body);
    return;
  }
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
// The shell with a tour in it: the tour file is fetched into the engine's file
// system before main() runs, and the arguments are the tour's rather than the
// address's (the shell's ALLOWED list stays exactly as it ships).
function tourShell(html) {
  const anchor = '  const engine = new Engine(GODOT_CONFIG);';
  if (!html.includes(anchor)) throw new Error('tools/web/web.mjs cannot find where the shell makes its Engine: src/boot/shell.html moved');
  const extra = opt.args ? String(opt.args).split(',') : [];
  const args = ['--', `--tour=/tour/${tourName}.tour`, ...extra];
  return html.replace(anchor, `  GODOT_CONFIG.args = ${JSON.stringify(args)};\n${anchor}\n  engine.preloadFile('__tour/${tourName}.tour', '/tour/${tourName}.tour');`);
}
// The shell with tool arguments added after the address's own (--tool-args).
function toolShell(html) {
  const anchor = '  const engine = new Engine(GODOT_CONFIG);';
  if (!html.includes(anchor)) throw new Error('tools/web/web.mjs cannot find where the shell makes its Engine: src/boot/shell.html moved');
  return html.replace(anchor, `  GODOT_CONFIG.args = (GODOT_CONFIG.args || ['--']).concat(${JSON.stringify(toolArgs)});\n${anchor}`);
}
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
// platform default elsewhere), except on Linux (GPU_OFF). SwiftShader draws a game
// frame in seconds.
const gpuArgs = process.platform === 'darwin' ? ['--use-angle=metal'] : [];
// Audio waits for a gesture, as in a browser a player opens (headless otherwise
// lets a page start sound on its own, and the first-key rule would go untested).
const launchArgs = [...(software
  ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
  : [...gpuArgs, '--ignore-gpu-blocklist', '--enable-gpu']), '--autoplay-policy=user-gesture-required',
  // A page's frames are held to the display's rate, so a frame that costs 4 ms
  // and one that costs 15 both read as 16.7. Measuring cost wants them let go.
  ...(opt.uncapped ? ['--disable-gpu-vsync', '--disable-frame-rate-limit'] : [])];
const browser = await chromium.launch({ headless: !opt.headed, args: launchArgs });
// A HARNESS MUST NEVER BE ABLE TO WAIT FOREVER. Every wait below has its own
// limit, and still a passing run once sat 4.5 hours after printing "web OK":
// nothing called exit, Chromium outlived browser.close(), and the server kept
// its keep-alive sockets, so node's loop never emptied. This is the backstop:
// past --timeout x 12 seconds the run is killed, and it says where it was.
// Unref'd, so the timer itself can never be what keeps a finished run alive.
let phase = 'launching the browser';
const hardCap = Number(opt.timeout) * 12;
setTimeout(() => {
  console.log(`web FAILED: the harness ran past its ${hardCap} s deadline, stuck ${phase}`);
  try { browser.process()?.kill('SIGKILL'); } catch {}
  process.exit(2);
}, hardCap * 1000).unref();
// Not the base's 16:9: the game (and the shell before it) sit in black bars.
const [winW, winH] = (opt.window || (touring ? '1920x1080' : '1440x789')).split('x').map(Number);
const context = await browser.newContext({ viewport: { width: winW, height: winH }, deviceScaleFactor: Number(opt.dpr || 1), acceptDownloads: true });
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
  // THE EARS ARE ON THE AUDIO THREAD. They were analysers read from the page's
  // main thread, and a read only sees the last 43 ms at the moment the main thread
  // is free: on SwiftShader (10-05) one frame held it 18-44 s, the probe's tone
  // played inside such a frame, and every read came back silent. A worklet hears
  // every sample as it is rendered and keeps the loudest moment since the last
  // reset (and the 2048 samples after it, for its pitch), whenever the page reads it.
  const EAR = `class Ear extends AudioWorkletProcessor {
    constructor() {
      super();
      this.buf = new Float32Array(2048); this.at = 0; this.peak = 0; this.wait = -1;
      this.port.onmessage = () => { this.peak = 0; this.wait = -1; };
    }
    process(inputs) {
      const ch = inputs[0] && inputs[0][0];
      if (!ch) return true;
      let p = 0;
      for (let i = 0; i < ch.length; i++) { const v = ch[i]; this.buf[this.at] = v; this.at = (this.at + 1) & 2047; if (Math.abs(v) > p) p = Math.abs(v); }
      if (p >= 0.0005 && p > this.peak * 1.02) { this.peak = p; this.wait = 2048; }
      if (this.wait >= 0) {
        this.wait -= ch.length;
        if (this.wait <= 0) {
          this.wait = -1;
          const w = new Float32Array(2048);
          for (let i = 0; i < 2048; i++) w[i] = this.buf[(this.at + i) & 2047];
          this.port.postMessage({ peak: this.peak, window: w, rate: sampleRate });
        }
      }
      return true;
    }
  }
  registerProcessor('unspent-ear', Ear);`;
  const earUrl = URL.createObjectURL(new Blob([EAR], { type: 'text/javascript' }));
  window.__ear = null;
  const ears = new Map();
  const connect = AudioNode.prototype.connect;
  const earFor = (ctx) => {
    if (!ears.has(ctx)) {
      ears.set(ctx, ctx.audioWorklet.addModule(earUrl).then(() => {
        const ear = new AudioWorkletNode(ctx, 'unspent-ear');
        // Pulled by the graph through a silent gain, so it is rendered and adds nothing.
        const hush = ctx.createGain();
        hush.gain.value = 0;
        connect.call(ear, hush);
        connect.call(hush, ctx.destination);
        ear.port.onmessage = (e) => { if (!window.__ear || e.data.peak >= window.__ear.peak) window.__ear = e.data; };
        window.__taps.push(ear);
        return ear;
      }));
    }
    return ears.get(ctx);
  };
  AudioNode.prototype.connect = function (dest, ...rest) {
    const out = connect.call(this, dest, ...rest);
    if (typeof AudioDestinationNode !== 'undefined' && dest instanceof AudioDestinationNode) {
      earFor(this.context).then((ear) => connect.call(this, ear)).catch((e) => console.warn(`harness ear not made: ${e}`));
    }
    return out;
  };
  window.__earReset = () => {
    window.__ear = null;
    for (const t of window.__taps) t.port.postMessage('reset');
  };
  // The loudest moment heard since the reset: its loudest sample (0..1), and the
  // strongest frequency with the share of all power within 3 bins of it (a pure
  // test tone puts nearly all of it there; a game's mix spreads it), Blackman-
  // windowed as an analyser's spectrum is.
  window.__loudness = () => {
    const h = window.__ear;
    if (!h) return { peak: 0, hz: 0, share: 0 };
    const n = h.window.length;
    const x = h.window.map((v, i) => v * (0.42 - 0.5 * Math.cos(2 * Math.PI * i / n) + 0.08 * Math.cos(4 * Math.PI * i / n)));
    const pow = new Float64Array(n / 2);
    for (let k = 0; k < n / 2; k += 1) {
      let re = 0, im = 0;
      for (let i = 0; i < n; i += 1) { const a = 2 * Math.PI * k * i / n; re += x[i] * Math.cos(a); im -= x[i] * Math.sin(a); }
      pow[k] = re * re + im * im;
    }
    let top = 0, total = 0;
    for (let k = 0; k < pow.length; k += 1) { total += pow[k]; if (pow[k] > pow[top]) top = k; }
    let near = 0;
    for (let k = Math.max(0, top - 3); k <= Math.min(pow.length - 1, top + 3); k += 1) near += pow[k];
    return { peak: h.peak, hz: top * h.rate / n, share: total > 0 ? near / total : 0 };
  };
});

// What reached the speakers since the ears were last reset: the loudest sample
// heard (0..1), and the strongest frequency and its share of the power just
// after that loudest moment.
async function heard() {
  return (await bounded(page.evaluate(() => window.__loudness()), FRAME_WAIT_S * 1000)) || { peak: 0, hz: 0, share: 0 };
}
const resetEars = () => bounded(page.evaluate(() => window.__earReset()), FRAME_WAIT_S * 1000);
// How many GL programs the page has built so far (NaN if it did not answer in --timeout).
const linksBuilt = async () => {
  const n = await bounded(page.evaluate(() => window.__glLinks || 0), Number(opt.timeout) * 1000);
  return typeof n === 'number' ? n : NaN;
};
// What a silence at the speakers IS, since each kind has its own fix: the engine
// never made an AudioContext, the browser still holds one suspended (its clock
// stands still), or it runs and the engine hands it nothing but zeros. The last
// is what a muted master bus looks like from outside, and it was misread once as
// the first. The device itself is never what is heard: headless Chromium runs
// with --mute-audio (Playwright's default), so a run makes no noise on the
// machine and the taps above, which sit inside the page, still hear every sample.
async function silence() {
  const clocks = () => page.evaluate(() => window.__audio.map((a) => ({ state: a.state, t: a.currentTime })));
  const a = await clocks();
  await page.waitForTimeout(300);
  const b = await clocks();
  if (b.length === 0) return 'the engine never made an AudioContext';
  const said = b.map((c) => `${c.state} at ${c.t.toFixed(2)} s`).join(', ');
  if (!b.some((c, i) => c.state === 'running' && a[i] && c.t > a[i].t)) return `no AudioContext is running (${said})`;
  const taps = await page.evaluate(() => window.__taps.length);
  if (taps === 0) return `the AudioContext runs (${said}) but nothing in the page is connected to its output`;
  return `the AudioContext runs (${said}) and the engine sends only silence into ${taps} output(s)`;
}
// The probe's test tone: 440 Hz, alone.
const isTone = (h) => h.peak >= 0.001 && Math.abs(h.hz - 440) < 30 && h.share > 0.8;
const dbfs = (h) => (h.peak > 0 ? (20 * Math.log10(h.peak)).toFixed(1) : '-inf');
// Keep the wasm memory where the harness can read it: the shell's `engine` lives
// inside a function, out of reach, so the instance is caught as it is made and
// whichever Memory it exports is kept on the window. A THREADED build exports
// none: its memory is shared, made in JS and imported, so the constructor is
// caught as well.
await context.addInitScript(() => {
  const RealMemory = WebAssembly.Memory;
  const Memory = function (desc) {
    const m = new RealMemory(desc);
    window.__wasmMemory = m;
    return m;
  };
  Memory.prototype = RealMemory.prototype;
  WebAssembly.Memory = Memory;
  const keep = (r) => {
    const inst = r && (r.instance || r);
    for (const v of Object.values((inst && inst.exports) || {})) {
      if (v instanceof WebAssembly.Memory) window.__wasmMemory = v;
    }
    return r;
  };
  for (const name of ['instantiate', 'instantiateStreaming']) {
    const real = WebAssembly[name];
    if (real) WebAssembly[name] = (...a) => real.apply(WebAssembly, a).then(keep);
  }
});
// --cold: every vertex shader gets a term that is always zero, different each
// run, so no program is found in any cache (the browser's, ANGLE's, the
// system's machine-wide Metal cache) and a boot pays every build as a first
// visit does, without clearing a cache other things on the machine rely on.
if (opt.cold) await context.addInitScript((nonce) => {
  const P = window.WebGL2RenderingContext && WebGL2RenderingContext.prototype;
  if (!P) return;
  const shaderSource = P.shaderSource;
  P.shaderSource = function (s, src) {
    // Not the 2D canvas's own: few, and the same in every build.
    if (this.getShaderParameter(s, this.SHADER_TYPE) === this.VERTEX_SHADER && !/canvas_data|batch_flags|draw_data/.test(src))
    {
      // At main's end (it is the source's last function), into gl_Position, so
      // no translator can drop it as unused and the compiled program changes.
      const end = src.lastIndexOf('}');
      if (/void main\(\)/.test(src) && end > 0) src = `${src.slice(0, end)}\tgl_Position.x += float(gl_VertexID == ${-nonce}) * 1e-30;\n${src.slice(end)}`;
    }
    return shaderSource.call(this, s, src);
  };
}, 1 + Math.floor(Math.random() * 1e9));
// A GL PROGRAM THE BROWSER CANNOT DRAW WITH IS A FAILED RUN. A shader that
// compiles and links can still fail to build its pipeline: ANGLE's Metal backend
// (every browser on a Mac) met an Apple compiler bug in fore.gdshader's depth
// programs and refused every draw, and the only sign was a flat grey layer and a
// console warning after the engine's own lines had scrolled by. So each
// program's first draws are checked with getError, a pipeline refusal repeats
// on every draw, and after three clean draws a program is left alone, so a
// frame's cost is not what this measures.
await context.addInitScript(() => {
  const P = window.WebGL2RenderingContext && WebGL2RenderingContext.prototype;
  if (!P) return;
  const srcOf = new WeakMap();
  let next = 0;
  const failed = {};
  window.__glFailed = failed;
  const shaderSource = P.shaderSource;
  P.shaderSource = function (s, src) { srcOf.set(s, src); return shaderSource.call(this, s, src); };
  const linkProgram = P.linkProgram;
  P.linkProgram = function (p) {
    // Counted for the run's `web programs` line: each is a build the page waits on.
    window.__glLinks = next + 1;
    p.__glId = ++next;
    p.__glChecked = 0;
    p.__glSrc = this.getAttachedShaders(p).map((s) => srcOf.get(s) || '');
    return linkProgram.call(this, p);
  };
  // First draws, and the tour's events, on the page's own clock (--programs).
  window.__glEvents = [];
  const log = console.log;
  console.log = function (...a) {
    const m = /^tour: event (\S+)/.exec(String(a[0] || '') + (a.length > 1 ? String(a[1]) : ''));
    if (m) {
      window.__glEvents.push({ name: m[1], at: performance.now() });
      if (window.__glReport) window.__glReport({ event: m[1], at: performance.now() });
    }
    return log.apply(this, a);
  };
  const useProgram = P.useProgram;
  P.useProgram = function (p) { this.__glProgram = p; return useProgram.call(this, p); };
  for (const name of ['drawArrays', 'drawElements', 'drawArraysInstanced', 'drawElementsInstanced', 'drawRangeElements']) {
    const draw = P[name];
    if (!draw) continue;
    P[name] = function (...a) {
      const p = this.__glProgram;
      if (!p || p.__glChecked >= 3) return draw.apply(this, a);
      this.getError();
      const r = draw.apply(this, a);
      const e = this.getError();
      if (!p.__glFirst) {
        p.__glFirst = true;
        // Only what names it: the fragment's variant header and its user names
        // (Godot keeps them behind an `m_`), never the whole source per program.
        const fs = p.__glSrc[1] || '';
        const ids = [...new Set((p.__glSrc.join('\n').match(/\bm_[a-z][a-z0-9_]*/g) || []))];
        const kind = /canvas_data|batch_flags/.test(fs) ? 'canvas' : /shader_type sky|MODE_QUARTER_RES|MODE_HALF_RES/.test(fs) ? 'sky' : '';
        if (window.__glReport) window.__glReport({ id: p.__glId, at: performance.now(), head: fs.split('\n').slice(0, 60).join('\n'), ids, kind, src: window.__glEvents.length > 0 ? p.__glSrc : null });
      }
      p.__glChecked++;
      if (e) {
        const f = failed[p.__glId] || (failed[p.__glId] = { err: e, draws: 0, src: p.__glSrc });
        f.draws++;
        // Keep checking a program that failed, so the count says every draw.
        p.__glChecked = 0;
      }
      return r;
    };
  }
});
// Which of the game's shaders a failed program was made from: the .gdshader
// whose own uniforms and functions all appear in it (Godot keeps a user name
// behind an `m_`). Includes are shared, so they name nothing.
function shaderOf(src) {
  return shaderOfIds(new Set(src.match(/\bm_[a-z][a-z0-9_]*/g) || []));
}
function shaderOfIds(ids) {
  const files = [];
  const walk = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith('.gdshader')) files.push(p);
    }
  };
  walk('src');
  let best = null;
  let most = 0;
  for (const f of files) {
    const text = fs.readFileSync(f, 'utf8');
    const own = new Set();
    for (const m of text.matchAll(/^\s*uniform\s+[^;]*?\b(\w+)\s*(?:\[[^\]]*\])?\s*(?::[^;=]*)?(?:=[^;]*)?;/gm)) own.add(m[1]);
    for (const m of text.matchAll(/^(?:float|int|bool|void|vec[234]|ivec[234]|mat[34])\s+(\w+)\s*\(/gm)) if (!['vertex', 'fragment', 'light'].includes(m[1])) own.add(m[1]);
    if (own.size === 0) continue;
    const found = [...own].filter((n) => ids.has(`m_${n}`)).length;
    if (found === own.size && found > most) { best = f; most = found; }
  }
  return best;
}
const page = await context.newPage();
let tourEnded = false;
const failures = [];
// A HARNESS MUST NEVER END IN A STACK TRACE. A Playwright call with a limit of
// its own (a locator's 30 s default) threw out of the flow when one frame held
// the page's main thread longer than that (SwiftShader, 10-05: 35-76 s), and node
// died printing it: no `web FAILED` line, no check after it run, the browser left
// to the backstop. Whatever escapes the flow ends the run here, as a failure that
// says where the run was and what was already wrong.
const harnessFailed = (e) => {
  for (const f of [...new Set(failures)]) console.log(`web FAILED: ${f}`);
  console.log(`web FAILED: the harness stopped ${phase}: ${String((e && e.message) || e).split('\n')[0]}`);
  try { browser.process()?.kill('SIGKILL'); } catch {}
  process.exit(1);
};
process.on('uncaughtException', harnessFailed);
process.on('unhandledRejection', harnessFailed);
// The browser's own words for a GL refusal, the first time it says them.
let glReason = '';
page.on('console', (m) => {
  if (!glReason && /GL_INVALID_OPERATION|Metal error/.test(m.text())) glReason = m.text().replace(/^\[[^\]]*\]\s*/, '');
});
const lines = [];
const snapAt = typeof opt.snap === 'string' && opt.snap.includes(':')
  ? { re: new RegExp(opt.snap.slice(0, opt.snap.lastIndexOf(':'))), secs: Number(opt.snap.slice(opt.snap.lastIndexOf(':') + 1)) } : null;
let snapped = false;
let t0 = Date.now();
const since = () => ((Date.now() - t0) / 1000).toFixed(2);
page.on('console', (m) => {
  const text = m.text();
  lines.push({ t: Number(since()), type: m.type(), text });
  // A tour's own findings are its evidence; its per-line trace is not.
  const told = touring && /^tour /.test(text) && (opt.trace || !/^tour (t=|score )/.test(text));
  if (opt.verbose || m.type() === 'error' || /^(boot|web) /.test(text) || told) console.log(`  [${since()}s ${m.type()}] ${text}`);
  if (touring) fs.appendFileSync(path.join(tourDir, 'console.log'), `[${since()}s ${m.type()}] ${text}\n`);
  // Once a tour has said it reached its end, what the engine says on its way out
  // (the ObjectDB leak count a desktop run prints too) is not the tour's evidence.
  if (m.type() === 'error' && !tourEnded) failures.push(`console error: ${text}`);
  if (touring && /^tour .* done ->/.test(text)) tourEnded = true;
  if (/^web FAIL/.test(text)) failures.push(text);
  // --snap=REGEX:SECS: photograph the page from OUTSIDE the engine that long
  // after a console line matches, once. A tour cannot shoot while its own engine
  // is blocked (a world grown in the frame a key was pressed), and what the player
  // sees then is exactly the question; how long the screenshot itself took says
  // whether the page could answer at all.
  if (snapAt && !snapped && snapAt.re.test(text)) {
    snapped = true;
    setTimeout(async () => {
      const asked = Date.now();
      const file = `${opt.out}_snap.png`;
      await page.screenshot({ path: file, timeout: 120000 }).then(
        () => console.log(`web snap ${file} ${snapAt.secs} s after /${snapAt.re.source}/, taken in ${((Date.now() - asked) / 1000).toFixed(1)} s`),
        (e) => console.log(`web snap: the page did not answer for ${((Date.now() - asked) / 1000).toFixed(1)} s (${e.message.split('\n')[0]})`));
    }, snapAt.secs * 1000);
  }
});
// The wasm heap only grows, so the largest size seen is the most the run held,
// and a browser's heap has a ceiling a desktop build never meets: a world that
// cannot be grown here is not a world the game can ship. Sampled while the page
// lives, because a tour quits the engine before the run ends. Read off the
// Memory the init script above keeps.
let heapMost = 0;
const heapStart = Date.now();
const sampleHeap = () => page.evaluate(() => {
  try { return window.__wasmMemory ? window.__wasmMemory.buffer.byteLength : -1; } catch (e) { return -1; }
}).then((n) => {
  heapMost = Math.max(heapMost, n);
  if (opt['heap-log'] && n > 0) console.log(`web heap at ${((Date.now() - heapStart) / 1000).toFixed(0)} s: ${(n / 1048576).toFixed(0)} MB`);
}).catch(() => {});
const heapTimer = setInterval(sampleHeap, 2000);
// A wait on a page that may have stopped answering, bounded: resolves with
// `null` after `ms` instead of never. A tour quits its engine before the run
// closes down, and `page.evaluate` into such a page has no limit of its own --
// the last heap sample after a tour waited on one for 17 minutes, until the
// deadline killed it.
const bounded = (p, ms) => Promise.race([p, new Promise((r) => setTimeout(() => r(null), ms))]);
// The same rule as a console error: once a tour has said it reached its end, the
// engine is tearing itself down after quit() (a wasm fault there was seen once in
// three dev.tour runs), which no player reaches and is not the tour's evidence.
// Headless Chromium grants no pointer lock at all: it rejects every request with
// this, even straight after a real click (measured on a bare canvas). The game
// asks for one whenever the view goes over the shoulder, which the browser-
// defaults step's right click and Alt can do, so whether the run failed was a
// race. A headed browser grants it, so there it still fails a run.
const NO_LOCK_HEADLESS = /not valid for pointer lock/;
page.on('pageerror', (e) => {
  const headlessLock = !opt.headed && NO_LOCK_HEADLESS.test(e.message);
  if (!tourEnded && !headlessLock) failures.push(`page error: ${e.message}`);
  console.log(`  [${since()}s pageerror${tourEnded ? ' after the tour ended' : ''}${headlessLock ? ' (headless has no pointer lock)' : ''}] ${e.message}`);
});
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

// Pixels of the page as shown: blank or not, and what shape the game is drawn at.
//
// This used to check that every game pixel was an exact square block — the
// 640x360 image upscaled by a whole number, nearest. LANTERN took that contract
// out (docs/LOOK.md): the base is 1920x1080 and the image is scaled fractionally,
// so there are no blocks left to be exact and a whole-number scale is not
// expected. What is still worth proving is that the game fills the canvas at its
// own 16:9 shape, in letterbox bars, rather than being stretched or cropped.
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
    // How much of the 1920x1080 base the canvas shows it at, and the shape it
    // came out: 16:9 means nothing was stretched or cropped to fit.
    const scale = w / 1920;
    const aspect = h > 0 ? w / h : 0;
    return { drawn: [x0, y0, w, h], colours: colours.size, scale, aspect };
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
    // The loading page draws in the slate's 640x360 units (UiBase.DESIGN) and is
    // scaled onto the canvas, so this factor is fractional and must be rounded at
    // the point of sampling rather than forced to a whole number.
    const s = w / 640;
    const at = (gx, gy) => rgb(x0 + Math.round(gx * s), y0 + Math.round(gy * s));
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
    await page.screenshot({ path: file, timeout: FRAME_WAIT_S * 1000 });
  } catch (e) {
    failures.push(`${file}: the page drew no frame for ${FRAME_WAIT_S} s (${e.message.split('\n')[0]})`);
    return null;
  }
  const s = await inspect(file);
  console.log(`web shot ${file} at ${since()}s: ${s.colours} colours, ${s.drawn[2]}x${s.drawn[3]} at ${s.drawn[0]},${s.drawn[1]} (${s.scale.toFixed(3)} of the 1920x1080 base, ${s.aspect.toFixed(3)}:1)`);
  if (!still && s.colours < 24) failures.push(`blank canvas in ${file} (${s.colours} colours)`);
  // The loading page is mostly one dark colour, so its bounding box says little.
  if (!still) {
    const [, , w, h] = s.drawn;
    // 16:9, the shape of the base. A pixel of slack each way: the drawn box is
    // found by bounding-box, and a fractional scale can leave the outermost row
    // or column a shade off the letterbox black.
    const want = 1920 / 1080;
    if (Math.abs(s.aspect - want) > 0.01) {
      failures.push(`${file}: drawn ${w}x${h} is ${s.aspect.toFixed(3)}:1, not the base's ${want.toFixed(3)}:1 — the game is stretched or cropped`);
    }
    if (s.scale < 0.1) failures.push(`${file}: drawn ${w}x${h} is a sliver of the base, not a frame`);
  }
  if (expectScale !== null && Math.abs(s.scale - expectScale) > 0.02) {
    failures.push(`${file}: shown at ${s.scale.toFixed(3)} of the base, expected ${expectScale.toFixed(3)}`);
  }
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
console.log(`web ${live ? String(opt.url) : path.relative(process.cwd(), root)} on ${url} (${software ? 'swiftshader' : 'gpu'})`);
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
    await page.screenshot({ path: `${opt.out}_${label}FAILED.png`, timeout: FRAME_WAIT_S * 1000 }).catch(() => {});
  }
  return ready;
}

t0 = Date.now();
// First draws and a tour's events, reported by the page as they happen
// (--programs): asked for at the end, a page whose engine had quit sometimes
// never answered.
const glFirst = [];
const glEvents = [];
if (opt.programs) await page.exposeFunction('__glReport', (r) => { if (r.event) glEvents.push(r); else glFirst.push(r); });
await page.goto(url);
// What the page draws with, so no run's numbers are read off the CPU unawares.
const renderer = await page.evaluate(() => {
  const gl = document.createElement('canvas').getContext('webgl2');
  const info = gl && gl.getExtension('WEBGL_debug_renderer_info');
  return gl ? gl.getParameter(info ? info.UNMASKED_RENDERER_WEBGL : gl.RENDERER) : 'no WebGL2';
}).catch((e) => `unknown (${e})`);
console.log(`web renderer ${renderer}`);
// The shell, while the engine's wasm is held back, then the engine's first page
// frame once the shell has gone: the same rectangle, the same line, never shorter.
phase = 'waiting for the shell to draw';
if (await page.waitForFunction(() => window.unspentShell && window.unspentShell().shown, null, { timeout: 20000 }).catch(() => null)) {
  await page.waitForTimeout(400);
  const shellFile = `${opt.out}_shell.png`;
  await page.screenshot({ path: shellFile, timeout: FRAME_WAIT_S * 1000 });
  const shell = await inspectPage(shellFile);
  const state = await page.evaluate(() => window.unspentShell());
  releaseWasm();
  const gone = await page.waitForFunction(() => !window.unspentShell().shown, null, { timeout: Number(opt.timeout) * 1000 }).catch(() => null);
  const handFile = `${opt.out}_handover.png`;
  await page.screenshot({ path: handFile, timeout: FRAME_WAIT_S * 1000 });
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
phase = 'booting the build';
const first = await boot('', 0);
phase = touring ? `playing the tour ${tourName}` : 'playing the player flow';
if (first && touring) {
  result.first_frame_s = first.t - wasmHeldMs / 1000;
  console.log(`web first frame ${result.first_frame_s.toFixed(2)} s after navigation (${first.text}); playing ${opt.tour}`);
  const kept = [];
  page.on('download', (d) => {
    const file = path.join(tourDir, path.basename(d.suggestedFilename()));
    kept.push(d.saveAs(file).then(() => console.log(`web tour frame ${path.relative(process.cwd(), file)} at ${since()}s`)));
  });
  // A tour's own clock: its lines are timed by the game, so the harness only
  // waits for it to say it reached the end, or that it could not.
  const secs = Number(opt.timeout) * 6;
  const end = await waitLine(/^tour .* (done ->|line \d+: cannot do)/, secs, 0);
  await page.waitForTimeout(1500);
  await Promise.all(kept);
  if (!end) failures.push(`the tour never reached its end within ${secs} s`);
  else if (!/done ->/.test(end.text)) failures.push(end.text);
  else console.log(`web tour done in ${(end.t - first.t).toFixed(1)} s after the first frame, ${kept.length} frames in ${path.relative(process.cwd(), tourDir)}`);

} else if (first) {
  result.links_title = await linksBuilt();
  // The wasm was held while the shell was shot: that wait is not the build's.
  result.first_frame_s = first.t - wasmHeldMs / 1000;
  console.log(`web first frame ${result.first_frame_s.toFixed(2)} s after navigation, not counting ${(wasmHeldMs / 1000).toFixed(2)} s the harness held the wasm (${first.text})`);
}
// --boot-only: judge the boot and nothing past it. On a runner drawing WebGL on
// the CPU a frame takes longer than a screenshot waits and there are no speakers,
// so shots and sound can only fail for the host's reasons there. What such a host
// CAN answer is the thing that shipped broken once (f1ab4dd): does the build come
// up on its renderer without a console error. So it waits for the probe to say
// which renderer drew, gives the page a few seconds to complain, and stops.
if (first && !touring && opt['boot-only']) {
  const drew = await waitLine(/^web ok renderer/, Number(opt.timeout), 0);
  if (!drew) failures.push('the probe never said which renderer drew');
  await page.waitForTimeout(Number(opt.after) * 1000);
} else if (first && !touring) {
  await shoot('ready');
  const focused = await page.evaluate(() => document.activeElement && document.activeElement.id);
  if (focused !== 'canvas') failures.push(`keyboard focus is on '${focused || 'nothing'}', not the canvas`);
  await page.waitForTimeout(Number(opt.after) * 1000);
  await shoot(`ready+${opt.after}s`);

  // Browsers hold audio until a gesture: the first key must start it.
  const before = await page.evaluate(() => window.__audio.map((a) => a.state));
  await resetEars();
  const keyed = lines.length;
  await page.keyboard.press('ArrowDown');
  await page.keyboard.press('ArrowUp');
  await page.waitForTimeout(500);
  const after = await page.evaluate(() => window.__audio.map((a) => a.state));
  console.log(`web audio contexts [${before}] before the first key, [${after}] after`);
  if (before.includes('running')) failures.push('audio was running before any key: the browser held nothing back, so the first-key start is untested');
  if (!after.includes('running')) failures.push(`audio did not start after the first key (contexts: ${after.join(',') || 'none'})`);
  // The probe answers the key with a short tone: it must come out of the page.
  // Heard from the key until the engine's own meter has seen it (the probe says
  // so) and a second past: the tone plays in the engine's first frame after the
  // key, and on SwiftShader (10-05) that frame came 18-44 s later, past a fixed
  // four-second window. A probe that never says is a failure of its own below.
  await waitLine(/^web (ok|FAIL) audio path/, Number(opt.timeout), keyed);
  await page.waitForTimeout(1000);
  const tone = await heard();
  console.log(`web speakers: loudest sample ${dbfs(tone)} dBFS after the first key (${tone.hz.toFixed(0)} Hz, ${(tone.share * 100).toFixed(0)}% of the power there)`);
  if (tone.peak < 0.001) failures.push(`nothing reached the speakers after the first key (the probe plays a tone): ${await silence()}`);
  // The same ears must know the tone, or telling the game from it below means nothing.
  else if (!isTone(tone)) failures.push(`the probe's tone was heard but not recognised as 440 Hz (${tone.hz.toFixed(0)} Hz, ${(tone.share * 100).toFixed(0)}%)`);
  // Bounded by --timeout, not 30 s: the probe's last steps are frames, and a frame
  // here held the main thread 18-44 s (SwiftShader, 10-05).
  if (!(await waitLine(/^web probe done/, Number(opt.timeout), 0))) failures.push('the probe on the first scene never finished');
  const started = lines.find((l) => /^web probe start/.test(l.text));
  if (!started) failures.push('the probe never started');
  else if (/--(shot|give)/.test(started.text)) failures.push(`tool options in the address reached the build: ${started.text}`);
  // A threaded page sizes the engine's worker pool for the machine (src/boot/shell.html).
  // Without it the island is raised on the export's four workers, and nothing else says so.
  else if (/threads true/.test(started.text) && !lines.some((l) => /^boot pool \d+ workers/.test(l.text))) {
    failures.push('the threaded page never sized the engine\'s worker pool (no "boot pool" line from src/boot/shell.html)');
  }

  if (opt.play) {
    const from = lines.length;
    if (opt.dwell) await page.waitForTimeout(Number(opt.dwell) * 1000);
    // New game opens the character page first (who wakes): up from its first row
    // wraps round to "begin", and Enter there starts the game with that body.
    await page.keyboard.press('Enter');
    await page.waitForTimeout(800);
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(300);
    const linksBefore = await linksBuilt();
    const pressed = Date.now();
    await page.keyboard.press('Enter');
    const game = await waitLine(/^boot ready game/, Number(opt.timeout), from);
    if (!game) {
      failures.push('no "boot ready game" line after Enter on the title');
      await page.screenshot({ path: `${opt.out}_FAILED-play.png`, timeout: FRAME_WAIT_S * 1000 }).catch(() => {});
    } else {
      result.new_game_s = (Date.now() - pressed) / 1000;
      console.log(`web new game drawn ${result.new_game_s.toFixed(2)} s after Enter (${game.text})`);
      // From here the speakers carry the game: the ears keep its loudest moment.
      await resetEars();
      await shoot('game');
      if (opt['use-after'] !== undefined) {
        await page.waitForTimeout(Number(opt['use-after']) * 1000);
        await page.keyboard.press('KeyE');
        const crossed = await waitLine(/^boot stages crossing/, Number(opt.timeout) * 3, from);
        if (!crossed) failures.push('use at the shaft started no crossing');
        else await shoot('below');
      }
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
      // Bounded by --timeout for the reason the title's probe is.
      if (!(await waitLine(/^web (ok|FAIL) audio game/, Number(opt.timeout), from))) failures.push('the probe on the game never reported its sound');
      // Heard since the game was drawn, to six seconds past the probe's report: on
      // SwiftShader (10-06, load 88) the engine's meter had the game at -24 dB and
      // the six seconds after its report alone were silent at the speakers, its
      // frames 15-60 s apart and nothing new started between them.
      await page.waitForTimeout(6000);
      const mix = await heard();
      const graph = await page.evaluate(() => ({ taps: window.__taps.length, contexts: window.__audio.map((a) => `${a.state}@${a.currentTime.toFixed(1)}s/${a.sampleRate}`) }));
      console.log(`web speakers: loudest sample ${dbfs(mix)} dBFS in the game (${mix.hz.toFixed(0)} Hz strongest, ${(mix.share * 100).toFixed(0)}% of the power there; ${graph.taps} outputs tapped, contexts ${graph.contexts.join(' ')})`);
      if (mix.peak < 0.001) failures.push(`nothing of the game reached the speakers: ${await silence()}`);
      if (isTone(mix)) failures.push(`what reached the speakers in the game is the probe's 440 Hz test tone, not the game (${dbfs(mix)} dBFS)`);
      if (lines.slice(from).some((l) => /^web ok audio path/.test(l.text))) failures.push('the game\'s probe played its test tone again after the title proved the path');
      if (!(await waitLine(/^web probe done/, Number(opt.timeout), from))) failures.push('the probe on the game never finished');
      // PLAYABLE, not only drawn: until the boot's warm-up (01_warm_lights) has
      // built the programs a first light, door or fire would freeze on, the frames
      // are those builds, and on a slow renderer the page lifts before it ends (the
      // draw stage's deadline). The press-to-playable is the later of the two.
      const warm = await waitLine(/^boot warm lights/, Number(opt.timeout), from);
      if (!warm) failures.push('the new game\'s warm-up never ended (no "boot warm lights" line)');
      else {
        const warmed = (t0 + warm.t * 1000 - pressed) / 1000;
        result.playable_s = Math.max(result.new_game_s, warmed);
        console.log(`web new game playable ${result.playable_s.toFixed(2)} s after Enter (drawn at ${result.new_game_s.toFixed(2)}, warm-up over at ${warmed.toFixed(2)})`);
        const linksNow = await linksBuilt();
        console.log(`web programs: ${result.links_title} built by the title's first frame, ${linksBefore - result.links_title} more on the title, ${linksNow - linksBefore} from Enter to playable`);
      }
    }
  }

  if (opt.resize) {
    const [w, h] = opt.resize.split('x').map(Number);
    await page.setViewportSize({ width: w, height: h });
    await page.waitForTimeout(1500);
    const dpr = Number(opt.dpr || 1);
    // Fractional now: the game fills the viewport on its tighter axis.
    await shoot(`resize-${w}x${h}`, { expectScale: Math.min(w * dpr / 1920, h * dpr / 1080) });
  }

  if (opt.reload) {
    const from = lines.length;
    t0 = Date.now();
    // Bounded as a frame is: the old page has to let go of its main thread first.
    await page.reload({ timeout: FRAME_WAIT_S * 1000 });
    const again = await boot('reload-', from);
    if (again) {
      console.log(`web reload first frame ${again.t.toFixed(2)} s`);
      result.reload_s = again.t;
      if (!(await waitLine(/^web ok save kept/, 20, from))) failures.push('user:// did not keep the save across a reload (IndexedDB)');
      if (!(await waitLine(/^web ok slot kept/, 20, from))) failures.push('a real save slot did not come back whole across a reload (IndexedDB)');
    }
  }
  // LAST, because a click and a key are a gesture: asked before the first-key
  // audio check, they started the audio and shifted every check after them.
  // The browser's own answers to the game's keys (docs/CONTROLS.md, web checks):
  // the right button is the peek and must not open a menu; Tab is carrying and
  // must not move focus off the canvas; Alt is the view over the shoulder and
  // must not be left to raise a menu bar. Pressed for real, then asked of a
  // listener on the window, which hears each event after the engine's own.
  await page.evaluate(() => {
    window.__defaults = {};
    for (const type of ['contextmenu', 'keydown', 'keyup']) {
      window.addEventListener(type, (e) => { window.__defaults[`${type}:${e.key || e.button}`] = e.defaultPrevented; });
    }
  });
  // Asked of the page under the wait a screenshot gets (FRAME_WAIT_S): a
  // locator's own 30 s limit threw out of the run on a frame that held the main
  // thread longer (see harnessFailed), where a page that does not answer is a
  // finding about the page.
  const box = await bounded(page.evaluate(() => {
    const r = document.getElementById('canvas').getBoundingClientRect();
    return { x: r.x, y: r.y, width: r.width, height: r.height };
  }), FRAME_WAIT_S * 1000).catch(() => null);
  if (!box) failures.push(`the page did not answer for ${FRAME_WAIT_S} s when asked where its canvas is`);
  else await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2, { button: 'right' });
  await page.keyboard.press('Tab');
  await page.keyboard.press('Alt');
  await page.waitForTimeout(200);
  const kept = await page.evaluate(() => ({ seen: window.__defaults, focus: document.activeElement && document.activeElement.id }));
  console.log(`web browser defaults: ${JSON.stringify(kept.seen)}, focus on '${kept.focus}'`);
  if (kept.seen['contextmenu:2'] !== true) failures.push('a right click opened (or was not stopped from opening) the browser menu');
  if (kept.seen['keydown:Tab'] !== true || kept.focus !== 'canvas') failures.push(`Tab left the canvas (focus on '${kept.focus}')`);
  if (kept.seen['keyup:Alt'] !== true) failures.push('Alt was left to the browser, which raises a menu bar on Windows');
}

phase = 'closing down';
if (opt.programs && touring) {
  const got = { first: glFirst, events: glEvents.map((e) => ({ name: e.event, at: e.at })) };
  if (got) {
    const flags = (src) => ['MODE_RENDER_DEPTH', 'USE_ADDITIVE_LIGHTING', 'DISABLE_LIGHT_DIRECTIONAL', 'DISABLE_LIGHT_OMNI', 'DISABLE_LIGHT_SPOT', 'USE_INSTANCING', 'BASE_PASS', 'LIGHT_USE_PSSM4', 'USE_SHADOW', 'ADDITIVE_OMNI', 'ADDITIVE_SPOT']
      .filter((d) => new RegExp(`^#define ${d}$`, 'm').test(src)).map((d) => d.toLowerCase()).join(' ');
    const windows = [{ name: 'boot', at: -1 }, ...got.events];
    for (let w = 0; w < windows.length; w++) {
      const lo = windows[w].at;
      const hi = w + 1 < windows.length ? windows[w + 1].at : Infinity;
      const inside = got.first.filter((f) => f.at >= lo && f.at < hi);
      const kinds = {};
      for (const f of inside) {
        const name = shaderOfIds(new Set(f.ids)) || (f.kind ? `(${f.kind})` : '(built-in)');
        const own = name === '(built-in)' && w > 0 ? ` {${f.ids.filter((i) => !/^m_(sky|colossus|world|matter|glint|neon)/.test(i)).slice(0, 12).join(' ')}}` : '';
        const key = `${path.basename(name)} [${flags(f.head)}]${own}`;
        kinds[key] = (kinds[key] || 0) + 1;
      }
      console.log(`web programs ${windows[w].name}: ${inside.length} first drawn${inside.length ? ':' : ''}`);
      for (const f of inside) if (f.src) f.src.forEach((t, i) => fs.writeFileSync(`${opt.out}-program-${windows[w].name}-p${f.id}.${i === 0 ? 'vs' : 'fs'}.glsl`, t));
      for (const [k, n] of Object.entries(kinds).sort((a, b) => b[1] - a[1])) console.log(`  ${n} x ${k}`);
      if (w > 0 && inside.length) failures.push(`${inside.length} program(s) first drawn at event ${windows[w].name}, each a freeze a player meets (${Object.keys(kinds).join('; ')}); the boot builds them (src/systems/01_warm_lights.gd)`);
    }
    if (windows.length === 1) failures.push(`--programs: the tour named no event (echo event NAME), so nothing was checked`);
  }
}
const glFailed = await bounded(page.evaluate(() => window.__glFailed || {}), 10000).catch(() => ({})) || {};
for (const [id, f] of Object.entries(glFailed)) {
  const src = f.src.join('\n');
  const file = shaderOf(src);
  const keep = `${opt.out}-glfail-p${id}`;
  f.src.forEach((t, i) => fs.writeFileSync(`${keep}.${i === 0 ? 'vs' : 'fs'}.glsl`, t));
  failures.push(`GL program ${id} (${file || 'a shader this could not name'}) failed ${f.draws} draw(s), error ${f.err}${glReason ? `: ${glReason}` : ''}; its GLSL is in ${keep}.*.glsl`);
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
// The wasm heap only grows, so its size at the end is the most this run ever
// held, and a browser's heap has a ceiling a desktop build never meets: a world
// that cannot be grown here is not a world the game can ship. Read off the
// shell's own `engine`, which a classic script's top-level const leaves in reach.
if (opt['raised-before-game']) {
  const kind = String(opt['raised-before-game']);
  const raised = lines.find((l) => l.text.startsWith(`realm ${kind} raised`));
  const game = lines.find((l) => /^boot ready game/.test(l.text));
  if (!game) failures.push('--raised-before-game: no game was drawn (it needs --play)');
  else if (!raised) failures.push(`--raised-before-game: the ${kind} never stood`);
  else {
    console.log(`web ${kind} stood at ${raised.t.toFixed(1)} s, the new game drew at ${game.t.toFixed(1)} s (${raised.text})`);
    if (raised.t > game.t) failures.push(`the ${kind} stood ${(raised.t - game.t).toFixed(1)} s after the new game drew: a shaft pressed at once would wait`);
  }
}
if (opt.crossing) {
  const bar = Number(opt.crossing);
  const crossings = lines.filter((l) => /^boot stages crossing/.test(l.text));
  if (crossings.length === 0) failures.push('--crossing: the run crossed no shaft');
  for (const c of crossings) {
    const total = Number((c.text.match(/total (\d+) ms/) || [])[1]);
    console.log(`web crossing ${(total / 1000).toFixed(1)} s from use to the realm below, bar ${bar} s (${c.text})`);
    if (!(total <= bar * 1000)) failures.push(`a crossing took ${(total / 1000).toFixed(1)} s, over the ${bar} s bar`);
  }
}
clearInterval(heapTimer);
await bounded(sampleHeap(), 10000);
console.log(heapMost > 0 ? `web heap ${(heapMost / 1048576).toFixed(0)} MB, the most it held (sampled every 2 s)` : 'web heap: not readable from this page');
await bounded(browser.close(), 15000);
// close() has returned with Chromium still running; make sure it is gone.
try { browser.process()?.kill('SIGKILL'); } catch {}
if (!live) { server.closeAllConnections?.(); server.close(); }
if (failures.length) {
  for (const f of [...new Set(failures)]) console.log(`web FAILED: ${f}`);
  process.exit(1);
}
const parts = [`first frame ${result.first_frame_s.toFixed(2)} s`];
if (touring) parts.push(`tour ${tourName} played`);
if (result.new_game_s !== undefined) parts.push(`new game ${result.new_game_s.toFixed(2)} s after Enter`);
if (result.playable_s !== undefined) parts.push(`playable ${result.playable_s.toFixed(2)} s after Enter`);
if (result.reload_s !== undefined) parts.push(`reload ${result.reload_s.toFixed(2)} s`);
console.log(`web OK: ${parts.join(', ')}`);
// Said, not hoped: a passing run ends here whatever is still holding the loop.
process.exit(0);
