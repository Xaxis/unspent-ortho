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
set -euo pipefail
command -v xvfb-run >/dev/null || { echo "gpu.sh: xvfb-run is not on PATH" >&2; exit 1; }
exec env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY -u VK_DRIVER_FILES -u VK_ICD_FILENAMES \
  MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1280x720x24 -nolisten tcp" "$@"
