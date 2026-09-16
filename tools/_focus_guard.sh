#!/usr/bin/env bash
# Hand the keyboard back, every time, for as long as runs keep starting.
#
# macOS brings an app to the front when it opens a window, and no window flag
# prevents it (see tools/_focus.sh). A run can also be started by a worktree whose
# copy of the tools is older than this one, so guarding each run from inside the
# script that launched it misses exactly the runs that are hardest to reach. This
# watches instead: whenever a godot run holds the keyboard, it goes straight back
# to the app that had it, whichever session started that run.
#
# It remembers the last app that was NOT a godot run, so it always knows where to
# put the keyboard back, and it stands down on its own once the runs have stopped.
# tools/_focus.sh starts one of these when a run begins; a second one refuses to
# start while the first is alive.

QUIET_BEFORE_STOP=720   # ticks of 0.25 s with no godot at all: three minutes

_front() {
	osascript \
		-e 'tell application "System Events" to set p to first application process whose frontmost is true' \
		-e 'tell application "System Events" to return ((unix id of p) as string) & "|" & (name of p)' 2>/dev/null
}

mine=""
quiet=0
while true; do
	f="$(_front)"
	pid="${f%%|*}"
	name="${f##*|}"
	case "$name" in
		godot|Godot)
			if [ -n "$mine" ]; then
				osascript -e "tell application \"System Events\" to set frontmost of (first application process whose unix id is $mine) to true" >/dev/null 2>&1
			fi
			;;
		*)
			[ -n "$pid" ] && mine="$pid"
			;;
	esac
	if pgrep -x godot >/dev/null 2>&1; then
		quiet=0
	else
		quiet=$((quiet + 1))
		[ "$quiet" -ge "$QUIET_BEFORE_STOP" ] && break
	fi
	sleep 0.25
done
