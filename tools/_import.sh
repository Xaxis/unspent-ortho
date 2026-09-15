#!/usr/bin/env bash
# Refresh Godot's import + global class cache if any script/shader is newer
# than it. class_name changes are invisible to a run until this happens.
cd "$(dirname "$0")/.."
# Screenshots live inside the project; without this Godot imports every PNG.
mkdir -p shots && touch shots/.gdignore
cache=.godot/global_script_class_cache.cfg
if [ ! -f "$cache" ] || [ -n "$(find src tests project.godot -newer "$cache" \( -name '*.gd' -o -name '*.gdshader' -o -name 'project.godot' -o -name '*.tscn' \) -print -quit)" ]; then
  godot --headless --import --path . >/dev/null 2>&1
  touch "$cache"
fi
