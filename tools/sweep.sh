#!/usr/bin/env bash
# The matchup sweep over the shoulder (tools/gd/sweep.gd has what it measures).
# A measurement for after every tuning pass, not a gate, and not on CI.
# Usage: tools/sweep.sh [--singles|--crowds] [--crowd=N] [--reader=human[:SEED]] [--weapons=a,b] [--machines=a,b] [--starts=N]
# Bounded: killed after SWEEP_TIMEOUT seconds (default 1800); the whole sweep
# takes about ten minutes on an idle laptop.
set -euo pipefail
cd "$(dirname "$0")/.."
tools/_import.sh
exec perl -e 'alarm shift; exec @ARGV' "${SWEEP_TIMEOUT:-1800}" \
	godot --headless --path . -s tools/gd/sweep.gd -- "$@"
