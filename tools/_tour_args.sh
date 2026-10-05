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

# The run's own clock from the same first line: its TOUR_TIMEOUT and
# TOUR_FIXED_FPS prefix, one KEY=VALUE per line. tour.sh takes each the shell has
# not set, so a long tour is not cut off at the default 180 s by whoever runs it
# bare (home-coast.tour was, at frame 14).
#
#   tour_header_env tours/x.tour    -> TOUR_TIMEOUT=600 / TOUR_FIXED_FPS=60
# The tours the header's run lines name when none of them is this one: a copy
# of a tour keeps its original's header, and run under its own name it would
# take none of those options and boot bare (seed 1 at 08:00), which reads as the
# tour failing. Three such copies failed that way at line 35 before anyone knew.
#
#   tour_header_others tours/x.tour  -> the other paths, space-joined, or nothing
tour_header_others() {
  local file="$1"
  awk -v base="$(basename "$file")" '
    !/^#/ { exit }
    {
      at = index($0, "tools/tour.sh")
      if (at == 0) next
      n = split(substr($0, at + length("tools/tour.sh")), words, /[ \t]+/)
      for (i = 1; i <= n; i++) {
        if (words[i] !~ /\.tour$/) continue
        k = split(words[i], bits, "/")
        if (bits[k] == base) self = 1
        else other = other (other == "" ? "" : " ") words[i]
      }
    }
    END { if (!self && other != "") print other }
  ' "$file"
}

# Whether a tour is one of this checkout's own (in tours/). A copy elsewhere, a
# builder's probe in a scratchpad, keeps its original's header on purpose and is
# run with a note rather than refused (tools/tour.sh): one refused copy of
# second-keeper cost a 20 min rerun.
#
#   tour_in_tours tours/x.tour       -> status 0; scratch/x.tour -> 1
tour_in_tours() {
  [ "$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" = "$(pwd -P)/tours" ]
}

# Why a tour is not one tools/tour.sh can run, from a `sweep: skip, WHY` line in
# its header (tours/degrade_fit.tour runs on the Compatibility renderer), or
# nothing. tour-sweep.sh passes over it with that reason and tour.sh refuses it
# with it, so neither reads its header's other runs as its own.
#
#   tour_header_skip tours/x.tour    -> the reason
tour_header_skip() {
  awk '
    !/^#/ { exit }
    {
      line = $0
      sub(/^#[ \t]*/, "", line)
      if (line ~ /^sweep: skip/) { sub(/^sweep: skip,?[ \t]*/, "", line); print (line == "" ? "skip" : line); exit }
    }
  ' "$1"
}

tour_header_env() {
  local file="$1"
  local base
  base="$(basename "$file")"
  awk -v base="$base" '
    /^#/ {
      line = $0
      sub(/^#[ \t]*/, "", line)
      at = index(line, "tools/tour.sh")
      if (at == 0) next
      rest = substr(line, at + length("tools/tour.sh"))
      split(rest, words, /[ \t]+/)
      path = ""
      for (w in words) if (words[w] ~ /\.tour$/) path = words[w]
      n = split(path, bits, "/")
      if (n == 0 || bits[n] != base) next
      m = split(substr(line, 1, at - 1), pre, /[ \t]+/)
      for (i = 1; i <= m; i++) if (pre[i] ~ /^TOUR_(TIMEOUT|FIXED_FPS)=[0-9]+$/) print pre[i]
      exit
    }
    !/^#/ { exit }
  ' "$file"
}
