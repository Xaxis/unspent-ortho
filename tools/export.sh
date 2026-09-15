#!/usr/bin/env bash
# Export a build with the presets in export_presets.cfg, then print its sizes.
#   tools/export.sh web             build/web/            threads (needs COOP/COEP: tools/web.sh serves them)
#   tools/export.sh web-nothreads   build/web-nothreads/  for hosts that cannot send those headers
#   tools/export.sh mac             build/mac/UNSPENT.app universal, ad-hoc signed, for this machine
#   tools/export.sh all
# Add --debug for a debug template. Web builds get .br and .gz siblings of the
# big files so a server can send them precompressed (tools/web.sh does).
set -uo pipefail
cd "$(dirname "$0")/.."
target="${1:-web}"; shift || true
mode=release
for a in "$@"; do [ "$a" = "--debug" ] && mode=debug; done

# Fail up front, in one line, on anything this script runs that is missing: a
# missing brotli used to fail silently in a background job and leave wrong sizes.
need() {
  local missing=() t
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "export FAILED: not on PATH: ${missing[*]}"; exit 1
  fi
}

human() { awk -v b="$1" 'BEGIN { if (b >= 1048576) printf "%.1f MB", b / 1048576; else printf "%.0f KB", b / 1024 }'; }
bytes() { stat -f %z "$1" 2>/dev/null || stat -c %s "$1"; }

export_one() {
  local preset="$1" out="$2"
  local dir; dir="$(dirname "$out")"
  rm -rf "$dir"; mkdir -p "$dir"
  local log; log="$(mktemp -t unspent-export)"
  local t0; t0=$(python3 -c 'import time; print(time.time())')
  godot --headless --path . "--export-$mode" "$preset" "$out" >"$log" 2>&1
  local code=$?
  local t1; t1=$(python3 -c 'import time; print(time.time())')
  if [ $code -ne 0 ] || [ ! -e "$out" ] || grep -qE 'SCRIPT ERROR|Parse Error|Compile Error' "$log"; then
    grep -vE '^\s*at: ' "$log" | grep -iE 'error|cannot|failed' | head -30
    echo "export FAILED: $preset -> $out"; rm -f "$log"; return 1
  fi
  rm -f "$log"
  printf "export %s -> %s in %.1f s\n" "$preset" "$dir" "$(echo "$t1 - $t0" | bc)"
}

# Precompressed siblings: the wasm is ~40 MB raw and ~9 MB as brotli.
compress_web() {
  local dir="$1" pids=() f p
  for f in "$dir"/*.wasm "$dir"/*.pck "$dir"/*.js "$dir"/*.html; do
    [ -f "$f" ] || continue
    brotli -f -q 9 -o "$f.br" "$f" & pids+=($!)
    gzip -9 -k -f "$f" & pids+=($!)
  done
  for p in "${pids[@]}"; do
    wait "$p" || { echo "export FAILED: compressing $dir"; return 1; }
  done
  for f in "$dir/index.wasm" "$dir/index.pck"; do
    [ -f "$f.br" ] && [ -f "$f.gz" ] || { echo "export FAILED: no .br/.gz beside $f"; return 1; }
  done
}

report_web() {
  local dir="$1"
  local wasm="$dir/index.wasm" pck="$dir/index.pck"
  printf "  wasm %-9s br %-9s gz %s\n" "$(human "$(bytes "$wasm")")" "$(human "$(bytes "$wasm.br")")" "$(human "$(bytes "$wasm.gz")")"
  printf "  pck  %-9s br %-9s gz %s\n" "$(human "$(bytes "$pck")")" "$(human "$(bytes "$pck.br")")" "$(human "$(bytes "$pck.gz")")"
  local total=0 f
  for f in "$dir"/*; do
    case "$f" in *.br|*.gz) continue ;; esac
    if [ -f "$f.br" ]; then total=$(( total + $(bytes "$f.br") )); else total=$(( total + $(bytes "$f") )); fi
  done
  printf "  over the wire (brotli where it helps): %s\n" "$(human $total)"
}

build_web() {
  local preset="$1" dir="$2"
  export_one "$preset" "$dir/index.html" || return 1
  compress_web "$dir" || return 1
  report_web "$dir"
}

build_mac() {
  export_one "macOS" "build/mac/UNSPENT.app" || return 1
  local app=build/mac/UNSPENT.app
  printf "  app %s (pck %s)\n" "$(du -sh "$app" | cut -f1)" "$(human "$(bytes "$app/Contents/Resources/UNSPENT.pck")")"
}

case "$target" in
  web|web-nothreads|all) need godot python3 bc brotli gzip ;;
  *) need godot python3 bc ;;
esac
mkdir -p build && touch build/.gdignore
tools/_import.sh
case "$target" in
  web) build_web "Web" build/web ;;
  web-nothreads) build_web "Web (no threads)" build/web-nothreads ;;
  mac) build_mac ;;
  all) build_web "Web" build/web && build_web "Web (no threads)" build/web-nothreads && build_mac ;;
  *) echo "usage: tools/export.sh web|web-nothreads|mac|all [--debug]"; exit 2 ;;
esac
