#!/usr/bin/env bash
# Run a game tool on the GPU in a private virtual display, so it needs no desktop
# session and opens nothing on the owner's screen:
#   tools/heavy.sh tools/gpu.sh tools/tour.sh tours/x.tour ...
#   tools/gpu.sh tools/tour-sweep.sh --smoke
# Xvfb cannot hand a GPU driver a buffer to present (no DRI3), so Godot would fall
# back to the CPU without a word; MESA_VK_WSI_DEBUG=sw has Mesa copy each frame to
# the X server instead, and RADV renders (slate.tour: 88 s, against a failed run at
# 1-2 fps on lavapipe). Why: a shell's inherited DISPLAY/XAUTHORITY can point at a
# dead session (10-03: ten hours of "no display" with the desktop up all along).
# Linux with a Mesa GPU driver only.
# The GPU is the box's, one job at a time: claude-core's bin/gpu holds its lease for
# the whole command and sets GODOT_GPU=1, without which the box's `godot` wrapper
# renders on llvmpipe (every tour from 10-07 to 10-09 did, at 1 fps). Two amdgpu
# hangs took the desktop down while several programs were on the GPU at once.
# bin/gpu exits 3 when it refuses (quarantine after a GPU fault: `gpu --status`),
# 5 when a long job never touched the GPU (it landed on software after all).
set -euo pipefail
# Already inside: a sweep run under gpu.sh whose tours each ask for it again.
[ -n "${UNSPENT_GPU:-}" ] && exec "$@"
command -v xvfb-run >/dev/null || { echo "gpu.sh: xvfb-run is not on PATH" >&2; exit 1; }
lease="$HOME/.claude/claude-core/bin/gpu"
[ -x "$lease" ] || { echo "gpu.sh: $lease (the box's GPU lease) is missing: install claude-core" >&2; exit 1; }
# UNSPENT_GPU tells a tool that draws on its own (tools/shaders.sh) it is already here.
exec "$lease" env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY -u VK_DRIVER_FILES -u VK_ICD_FILENAMES \
  MESA_VK_WSI_DEBUG=sw UNSPENT_GPU=1 xvfb-run -a -s "-screen 0 1280x720x24 -nolisten tcp" "$@"
