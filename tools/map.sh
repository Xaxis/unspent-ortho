#!/usr/bin/env bash
# Top-down map of a seed + where villages and each country are. Usage: tools/map.sh [--seed=N] [--out=shots/map.png]
set -euo pipefail
cd "$(dirname "$0")/.."
tools/_import.sh
godot --headless --path . -s tools/gd/map.gd -- "$@" 2>&1 | grep -E '^(village|spawn|country|map)|ERROR'
