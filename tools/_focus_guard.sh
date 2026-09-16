#!/usr/bin/env bash
# Hand the keyboard back the instant a TOOL run takes it, for as long as runs
# keep happening.
#
# macOS brings an app forward when it opens a window and no window flag prevents
# it (see tools/_focus.sh). A run can also be started by a worktree whose copy of
# the tools is older than this one, or written ad hoc by an agent, so guarding
# from inside the launching script misses the runs hardest to reach.
#
# The waiting is one long-lived osascript that returns the moment a godot run is
# frontmost, rather than a shell loop spawning osascript to ask: spawning a
# process per check cost more than the check and held the gap at a quarter of a
# second, which is long enough to lose a word.
#
# It leaves a SESSION SOMEBODY IS PLAYING alone. A run given --shot or --tour is
# a tool and gets no keyboard; anything else is a person at the game, and taking
# the focus from them would be the same rudeness pointed the other way.

QUIET_BEFORE_STOP=${UNSPENT_GUARD_QUIET:-180}

# Waits (up to `timeout` seconds) for a godot run to hold the keyboard. Prints
# "<godot pid> <pid to give it back to>", or nothing if the wait ran out.
wait_for_theft() {
	osascript <<'APPLESCRIPT' 2>/dev/null
set mine to missing value
repeat 600 times
	try
		tell application "System Events"
			set p to first application process whose frontmost is true
			set n to name of p
			if n is "godot" or n is "Godot" then
				if mine is not missing value then
					return ((unix id of p) as string) & " " & (mine as string)
				end if
			else
				set mine to unix id of p
			end if
		end tell
	end try
	delay 0.05
end repeat
return ""
APPLESCRIPT
}

while true; do
	got="$(wait_for_theft)"
	if [ -n "$got" ]; then
		thief="${got%% *}"
		holder="${got##* }"
		# A run with a job to do gives the keyboard back; a person playing keeps it.
		if ps -p "$thief" -o args= 2>/dev/null | grep -qE '\-\-shot=|\-\-tour='; then
			osascript -e "tell application \"System Events\" to set frontmost of (first application process whose unix id is $holder) to true" >/dev/null 2>&1
		fi
		continue
	fi
	# The wait ran its course with nothing taken: stop once the runs have stopped.
	if ! pgrep -x godot >/dev/null 2>&1; then
		quiet=0
		while [ "$quiet" -lt "$QUIET_BEFORE_STOP" ]; do
			pgrep -x godot >/dev/null 2>&1 && break
			sleep 5
			quiet=$((quiet + 5))
		done
		[ "$quiet" -ge "$QUIET_BEFORE_STOP" ] && break
	fi
done
