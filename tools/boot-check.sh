#!/usr/bin/env bash
# Boot an exported desktop build to its title, headless, and fail unless it says it is up.
#   tools/boot-check.sh build/linux/UNSPENT.x86_64 [--timeout=SECS]
#   tools/boot-check.sh build/windows/UNSPENT.exe
#   tools/boot-check.sh build/mac/UNSPENT.app
# The build is launched as a player launches it, with no game arguments, so it
# opens on the title, plus --headless: no window and no GPU, which a release
# runner does not have. It passes on the game's own ready line (src/main.gd),
# printed once the title's coast is up:
#   boot ready title 4846 ms (engine 7478 ms, main at 1467 ms)   (ubuntu runner, run 37495906351)
# and fails on any SCRIPT ERROR, on the build ending first, or on no ready line
# within --timeout (default 600 s: a hang guard, not a speed bar). The log is
# read from --log-file as well as stdout: a Windows build is a GUI program with
# no console, and a release template prints a line as it comes only because
# project.godot says so (run/flush_stdout_on_print.pc). Its user data is a fresh
# folder (XDG_DATA_HOME, on Linux), so a boot on someone's machine never reads
# or writes their saves. Prints `boot-check ok ...` or `boot-check FAILED: ...`.
set -uo pipefail
build="${1:-}"
timeout=600
for a in "${@:2}"; do
  case "$a" in
    --timeout=*) timeout="${a#--timeout=}" ;;
    *) echo "boot-check FAILED: unknown option $a"; exit 2 ;;
  esac
done
[[ "$timeout" =~ ^[0-9]+$ ]] || { echo "boot-check FAILED: --timeout takes whole seconds, not '$timeout'"; exit 2; }
bin="$build"
case "$build" in
  *.app|*.app/) bin="${build%/}/Contents/MacOS/$(basename "${build%/}" .app)" ;;
esac
[ -f "$bin" ] || { echo "boot-check FAILED: no build at ${bin:-(none given)}"; echo "usage: tools/boot-check.sh BUILD [--timeout=SECS]"; exit 2; }
[ -x "$bin" ] || chmod +x "$bin" 2>/dev/null

work="$(mktemp -d)"
log="$work/boot.log"
out="$work/out.log"
export XDG_DATA_HOME="$work/data"
mkdir -p "$XDG_DATA_HOME"
"$bin" --headless --log-file "$log" >"$out" 2>&1 &
pid=$!
stop() {
  kill "$pid" 2>/dev/null
  # Git Bash on Windows: a native program it started may need its own kill.
  [ -r "/proc/$pid/winpid" ] && taskkill //F //PID "$(cat "/proc/$pid/winpid")" >/dev/null 2>&1
  wait "$pid" 2>/dev/null
}
trap 'stop; rm -rf "$work"' EXIT

t0=$(date +%s)
verdict=""
while :; do
  ready="$(grep -h -m1 '^boot ready title' "$log" "$out" 2>/dev/null | head -1)"
  if grep -q 'SCRIPT ERROR' "$log" "$out" 2>/dev/null; then verdict=error; break; fi
  [ -n "$ready" ] && { verdict=ok; break; }
  kill -0 "$pid" 2>/dev/null || { verdict=ended; break; }
  [ $(( $(date +%s) - t0 )) -ge "$timeout" ] && { verdict=timeout; break; }
  sleep 2
done
secs=$(( $(date +%s) - t0 ))
# A moment more, so an error printed just after the ready line is caught too.
[ "$verdict" = ok ] && sleep 3 && grep -q 'SCRIPT ERROR' "$log" "$out" 2>/dev/null && verdict=error
stop

errors() { grep -hvE '^\s*at: ' "$log" "$out" 2>/dev/null | grep -iE 'error|failed|cannot' | sort -u | head -n 20; }
last() { cat "$log" "$out" 2>/dev/null | grep -vE '^\s*at: ' | tail -n "$1"; }
case "$verdict" in
  ok) echo "boot-check ok $(basename "$bin") in ${secs} s: $ready" ;;
  error) errors; echo "boot-check FAILED: SCRIPT ERROR booting $(basename "$bin")"; exit 1 ;;
  ended) last 20; echo "boot-check FAILED: $(basename "$bin") ended before its ready line"; exit 1 ;;
  timeout) errors; last 5; echo "boot-check FAILED: no 'boot ready title' from $(basename "$bin") in ${timeout} s"; exit 1 ;;
esac
