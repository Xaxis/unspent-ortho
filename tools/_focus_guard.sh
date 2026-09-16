#!/usr/bin/env bash
# Put the keyboard back where it was, the instant a tool run takes it.
#
# Godot asks macOS to bring its app forward when it opens a window. Nothing
# prevents that: not the window's no-focus flag, not launching with `open -g`,
# not giving the run an accessory (LSUIElement) bundle of its own — each was
# measured, and each still took the keyboard. So the only thing left that
# matters is giving it back, immediately and TO THE RIGHT PLACE.
#
# Two things make that work, and both were wrong before:
#
#   The memory has to survive. An earlier version restarted its watcher after
#   every restore, so it forgot where the person had been and re-learned from
#   whatever macOS had auto-focused when the last run exited — which is how
#   somebody typing in one editor kept being dropped into another one. The
#   remembered app now lives inside the loop and is only ever replaced by an app
#   that genuinely held the keyboard.
#
#   A person playing must be left alone. A run with a job to do (--shot, --tour)
#   is tooling; anything else is somebody at the game, and snatching that away
#   would be the same rudeness pointed the other way. src/main.gd leaves a mark
#   while a play session is up, which costs nothing to check because it is only
#   read in the rare moment a run is frontmost.

QUIET_BEFORE_STOP=${UNSPENT_GUARD_QUIET:-180}
PLAYING_MARK=${UNSPENT_PLAY_MARK:-/tmp/unspent-playing}
# Where a launching script writes the app it took the run from (tools/_focus.sh).
NOTED_HOLDER=${TMPDIR:-/tmp}/unspent-focus-holder

while true; do
	osascript - "$PLAYING_MARK" "$NOTED_HOLDER" <<'APPLESCRIPT' >/dev/null 2>&1
on run argv
	set mark to item 1 of argv
	set noted to item 2 of argv
	set mine to missing value
	repeat 2400 times
		try
			tell application "System Events"
				set p to first application process whose frontmost is true
				set n to name of p
				if n is "godot" or n is "Godot" then
					-- What a launching script wrote down beats what this loop guessed:
					-- it knew which app the person was in when it started the run.
					set target to my noted_holder(noted)
					if target is missing value then set target to mine
					if target is not missing value then
						-- Only a run with a job to do; a person playing keeps the keys.
						if not (my playing(mark)) then
							try
								set frontmost of (first application process whose unix id is target) to true
							end try
						end if
					end if
				else
					set mine to unix id of p
				end if
			end tell
		end try
		delay 0.05
	end repeat
end run

on noted_holder(noted)
	try
		-- Only if it was written in the last ten seconds: an old note is a guess again.
		do shell script "test -f " & quoted form of noted & " && test $(( $(date +%s) - $(stat -f %m " & quoted form of noted & ") )) -lt 10 && cat " & quoted form of noted
		return (result as string) as integer
	on error
		return missing value
	end try
end noted_holder

on playing(mark)
	try
		do shell script "test -f " & quoted form of mark
		return true
	on error
		return false
	end try
end playing
APPLESCRIPT
	# Two minutes of watching done. Keep going while runs are still happening.
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
