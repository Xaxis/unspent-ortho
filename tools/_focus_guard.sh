#!/usr/bin/env bash
# Hand the keyboard back the instant a run takes it, for as long as runs happen.
#
# macOS brings an app forward when it opens a window and no window flag prevents
# it (see tools/_focus.sh). A run can also be started by a worktree whose copy of
# the tools is older than this one, so guarding from inside the launching script
# misses exactly the runs hardest to reach. This watches instead.
#
# The watching is one long-lived osascript, not a shell loop calling osascript:
# spawning a process per check costs more than the check and held the gap at a
# quarter of a second, which is long enough to lose a word. Inside one script the
# loop runs twenty times a second, so the keyboard comes back before a hand has
# finished the letter it was typing.
#
# It remembers the last app that was NOT a run, so it always knows where to put
# the keyboard back, and it stands down once the runs have stopped.

QUIET_BEFORE_STOP=${UNSPENT_GUARD_QUIET:-180}   # seconds with no godot at all

# Kept alive for as long as runs keep happening; each pass runs for a minute and
# the shell decides whether to go round again, so standing down is prompt.
while true; do
	osascript <<'APPLESCRIPT' >/dev/null 2>&1
on holderOf(p)
	tell application "System Events" to return unix id of p
end holderOf

set mine to missing value
repeat 1200 times
	try
		tell application "System Events"
			set p to first application process whose frontmost is true
			set n to name of p
			if n is "godot" or n is "Godot" then
				if mine is not missing value then
					try
						set frontmost of (first application process whose unix id is mine) to true
					end try
				end if
			else
				set mine to unix id of p
			end if
		end tell
	end try
	delay 0.05
end repeat
APPLESCRIPT
	# Runs still happening? Go round again; otherwise wait out the quiet and stop.
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
