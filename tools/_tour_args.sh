# The boot options a tour's own header says to run it with (sourced by tour.sh).
#
# A tour's header shows how it is run:
#   #   tools/tour.sh tours/<name>.tour --seed=4 --hour=11 --weather=clear:0
# and a tour staged on that seed and hour means nothing on any other. Run bare,
# a tour booted seed 1 at 08:00 and failed on a world it was never written for,
# twice, in the assembly gate. So tour.sh takes these when it is given none.
#
#   tour_header_args tours/x.tour   -> the --options of the header's FIRST line
#                                      running this tour, one per line
#
# Only `--` tokens are taken: an environment prefix (TOUR_TIMEOUT=400), the tour
# path and a trailing "(note)" are not boot options. A line ending in `\` goes
# on in the next comment line. A tour whose header names no run gives nothing.
tour_header_args() {
  local file="$1"
  local base
  base="$(basename "$file")"
  awk -v base="$base" '
    function flush(line,   n, i, t, parts) {
      n = split(line, parts, /[ \t]+/)
      for (i = 1; i <= n; i++) {
        t = parts[i]
        if (t ~ /^--/) print t
      }
    }
    !/^#/ { if (joining) { joining = 0; flush(acc); exit } ; next }
    {
      line = $0
      sub(/^#[ \t]*/, "", line)
      if (joining) {
        acc = acc " " line
      } else {
        at = index(line, "tools/tour.sh")
        if (at == 0) next
        rest = substr(line, at + length("tools/tour.sh"))
        split(rest, words, /[ \t]+/)
        path = ""
        for (w in words) if (words[w] ~ /\.tour$/) path = words[w]
        n = split(path, bits, "/")
        if (n == 0 || bits[n] != base) next
        acc = rest
      }
      if (acc ~ /\\[ \t]*$/) { sub(/\\[ \t]*$/, "", acc); joining = 1; next }
      joining = 0
      flush(acc)
      exit
    }
    END { if (joining) flush(acc) }
  ' "$file"
}


# The simulated frame rate a tour's header asks to be run at, or nothing:
#   #   TOUR_FIXED_FPS=60 tools/tour.sh tours/<name>.tour --seed=4 ...
# A tour that only has to come out the same as itself (a room's layout, a
# frame read for how it looks) says so here, so every run of it steps the world
# in simulated time and not on however busy the machine is (tools/tour.sh,
# TOUR_FIXED_FPS). A tour that proves timing leaves it off.
tour_header_fixed_fps() {
  awk '
    !/^#/ { exit }
    {
      at = index($0, "tools/tour.sh")
      if (at == 0) next
      pre = substr($0, 1, at - 1)
      if (match(pre, /TOUR_FIXED_FPS=[0-9]+/)) print substr(pre, RSTART + 15, RLENGTH - 15)
      exit
    }
  ' "$1"
}
