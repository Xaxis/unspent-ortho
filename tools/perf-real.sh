#!/usr/bin/env bash
# The frames a player's own play makes, measured on a tour: every stretch of real
# input (await, wait, press, tap, key, walk, walkto, choose, until, climb, drive) is
# one `perf stats` window, and everything staged (shot, at, near, place, hour, a
# spawn, a try's edges) is left out, since a teleport's streaming or a shot's
# claims are frames no player sees. Prints one row per window and the systems that
# cost a slow frame over 20 ms.
#   tools/perf-real.sh tours/holdfast.tour [boot options]
# Runs through tools/heavy.sh and, on Linux, tools/gpu.sh, with the tour header's
# options and clock unless options are given, plus --stats. The measured copy, the
# run's log, a GPU-busy and load sample every 2 s, and the table are kept in
# shots/perf-real/NAME/.
# Why: perf budgets are judged on the slice paths a player walks (owner, 10-06),
# and the windows used to be hand-written into copies of the tours.
set -u
cd "$(dirname "$0")/.."
src=${1:?usage: tools/perf-real.sh tours/NAME.tour [boot options]}
shift
name=$(basename "$src" .tour)
out=shots/perf-real/$name
mkdir -p "$out"
real=$out/$name-real.tour
python3 - "$src" "$name" > "$real" <<'EOF'
import sys
src, name = sys.argv[1], sys.argv[2]
REAL = {"await", "wait", "press", "tap", "key", "walk", "walkto", "choose", "until", "climb", "drive", "echo", "same"}
lines = open(src).read().splitlines()
# Before the game exists a perf command is refused, so a tour that boots to the
# title opens its first window once `await game` has passed.
armed = not any(l.split()[:2] == ["await", "game"] for l in lines)
open_, n = False, 0
for l in lines:
    words = l.split()
    cmd = words[0] if words and not words[0].startswith("#") else ""
    if cmd and cmd not in REAL and open_:
        print(f"perf stats end {name}-{n} raw")
        open_ = False
    if cmd in REAL and armed and not open_:
        n += 1
        print("perf stats begin")
        open_ = True
    print(l)
    if words[:2] == ["await", "game"]:
        armed = True
if open_:
    print(f"perf stats end {name}-{n} raw")
EOF
. tools/_tour_args.sh
if [ $# -eq 0 ]; then
  while IFS= read -r a; do set -- "$@" "$a"; done < <(tour_header_args "$src")
fi
while IFS= read -r kv; do
  k=${kv%%=*}; [ -z "${!k:-}" ] && export "$kv"
done < <(tour_header_env "$src")
# Windows add frames to print, not time to play: the header's timeout, doubled.
export TOUR_TIMEOUT=$(( ${TOUR_TIMEOUT:-180} * 2 ))
gpu=""; [ "$(uname)" = Linux ] && gpu=tools/gpu.sh
busy=$(ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
( while :; do
    echo "$(date +%s) gpu=$( [ -n "$busy" ] && cat "$busy" ) load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || sysctl -n vm.loadavg | awk '{print $2}')"
    sleep 2
  done ) > "$out/sample.log" 2>&1 &
smp=$!
trap 'kill $smp 2>/dev/null' EXIT
echo "perf-real: $name with ${*:-(no options)} --stats; TOUR_TIMEOUT=$TOUR_TIMEOUT${TOUR_FIXED_FPS:+ TOUR_FIXED_FPS=$TOUR_FIXED_FPS}"
tools/heavy.sh $gpu tools/tour.sh "$real" "$@" --stats > "$out/tour.out" 2>&1; code=$?
cp "shots/tour/$name-real/run.log" "$out/run.log" 2>/dev/null
grep -m1 -oE "(Vulkan [0-9.]+|OpenGL API [0-9.]+).*Using Device[^(]*" "$out/run.log" 2>/dev/null
python3 - "$out/run.log" "$out/sample.log" <<'EOF' | tee "$out/table.txt"
import re, sys, collections
rows = collections.OrderedDict(); spikes = collections.Counter(); worst = collections.defaultdict(float)
for l in open(sys.argv[1], errors="replace").read().splitlines():
    m = re.match(r'tour (\S+) \| world frames: n (\d+) .*?p50 ([\d.]+) ms, p95 ([\d.]+), p99 ([\d.]+), worst ([\d.]+)', l)
    if m: rows.setdefault(m[1], {}).update(n=int(m[2]), p50=float(m[3]), p95=float(m[4]), p99=float(m[5]), worst=float(m[6]))
    m = re.match(r'tour (\S+) \| world window: .*draw calls (\d+).*primitives (\d+).*gpu p50 ([\d.]+) p95 ([\d.]+) ms', l)
    if m: rows.setdefault(m[1], {}).update(draws=int(m[2]), kprim=int(m[3]) // 1000, gpu50=float(m[4]), gpu95=float(m[5]))
    m = re.match(r'tour (\S+) \| world slow frames by cost: (.*)', l)
    if m:
        for f in re.finditer(r'\d+:\d+\(driven \d+: ([^;]*);', m[2]):
            for s in re.finditer(r'(\S+) (\d+)', f[1]):
                if int(s[2]) >= 20: spikes[s[1]] += 1; worst[s[1]] = max(worst[s[1]], int(s[2]))
print(f"{'window':28} {'n':>5} {'p50':>6} {'p95':>6} {'p99':>6} {'worst':>7} {'gpu50':>6} {'gpu95':>6} {'draws':>5} {'kprim':>6}")
for k, r in rows.items():
    print(f"{k[:28]:28} {r.get('n', 0):5} {r.get('p50', 0):6.1f} {r.get('p95', 0):6.1f} {r.get('p99', 0):6.1f} {r.get('worst', 0):7.0f} {r.get('gpu50', 0):6.1f} {r.get('gpu95', 0):6.1f} {r.get('draws', 0):5} {r.get('kprim', 0):6}")
if not rows: print("no windows measured (see run.log)")
print("systems over 20 ms in a slow frame (frames, worst ms):")
for s, c in spikes.most_common(12): print(f"  {s:22} {c:4} {worst[s]:6.0f}")
g = [int(x) for x in re.findall(r'gpu=(\d+)', open(sys.argv[2]).read())]
ld = [float(x) for x in re.findall(r'load=([\d.]+)', open(sys.argv[2]).read())]
if g: print(f"gpu busy p50 {sorted(g)[len(g)//2]}%, max {max(g)}%")
if ld: print(f"load p50 {sorted(ld)[len(ld)//2]:.0f}, max {max(ld):.0f}")
EOF
[ "$code" -eq 0 ] || echo "perf-real: the tour FAILED (exit $code): $out/tour.out"
exit "$code"
