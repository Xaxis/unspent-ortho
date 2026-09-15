#!/usr/bin/env bash
# Headless test run. Usage: tools/test.sh [filter]
set -euo pipefail
cd "$(dirname "$0")/.."
tools/_import.sh
exec godot --headless --path . -s tests/run.gd -- "${1:-}"
