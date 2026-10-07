#!/usr/bin/env bash
# Fit every walled prop kind's walls to its models and write the core table
# (tools/gd/prop_walls_bake.gd -> src/core/prop_walls_table.gd). Run it after a
# model of a walled kind changes; tests/render/test_prop_footprint.gd says when.
set -euo pipefail
cd "$(dirname "$0")/.."
tools/_import.sh
godot --headless --path . -s tools/gd/bake_walls.gd
