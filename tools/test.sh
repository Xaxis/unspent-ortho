#!/usr/bin/env bash
# Headless test run. Usage: tools/test.sh [filter]
set -euo pipefail
cd "$(dirname "$0")/.."
tools/_import.sh
# TEST_FIXED_FPS=60 runs on a fixed step, as the gate runs its played tests
# (TestCase.stepped_now): every frame one physics step of the same delta.
if [ -n "${TEST_FIXED_FPS:-}" ]; then
  UNSPENT_STEPPED=1 exec godot --headless --fixed-fps "$TEST_FIXED_FPS" --path . -s tests/run.gd -- "${1:-}"
fi
exec godot --headless --path . -s tests/run.gd -- "${1:-}"
