#!/usr/bin/env bash
# Keep a run of the game out of the way of whoever is using the machine: it must
# not appear in front of what they are looking at, and it must not take the
# keyboard away from what they are typing into.
#
# Three things are done, because macOS needs all three:
#
#   1. The window opens ONE PIXEL ACROSS in a far corner (project.godot's .editor
#      settings; --position here agrees with them). There is no off-screen on this
#      platform: macOS clamps a window back onto some display, and a position
#      chosen to be far away opened centre-screen on a fourth monitor. The frame is
#      unaffected: the viewport renders 640x360 into its own texture regardless.
#   2. project.godot sets display/window/size/no_focus, so the window can never
#      become key and can never swallow what is being typed somewhere else.
#   3. Godot still asks macOS to bring its app forward when it opens a window,
#      whatever the window's flags say, so the keyboard is handed straight back
#      to whoever had it, within about a twentieth of a second.
#
# Set UNSPENT_KEEP_FOCUS=1 to put the window on screen and leave it in front, to
# watch a tour play.
#
# Two neater-sounding approaches were tried and do not work, so they are written
# down rather than tried again:
#
#   `open -g -j` launches the app hidden and never activates it, but a hidden app
#   is not asked to draw: the run sat there with its world generated and never
#   took its shot.
#
#   Giving the run an accessory (LSUIElement) bundle of its own does NOT stop the
#   activation: measured, a run in one still took the keyboard in 12 of 114
#   samples. Godot asks macOS to come forward and macOS obliges whatever the
#   policy. (Re-signing Godot.app itself is worse still: it breaks the signature,
#   the copy is killed on launch, and a malware warning lands in front of the
#   person this was all meant to protect.)
#
#   . tools/_focus.sh
#   godot --path . --position "$(focus_position)" ... & pid=$!
#   focus_return "$(focus_holder)" "$pid"

## Start the guard that hands the keyboard back (tools/_focus_guard.sh), unless one
## is already watching. One guard covers every run on this machine, including runs
## started by a worktree whose copy of these tools is older than this one, which is
## the case this could not otherwise reach.
focus_guard_start() {
	[ "$(uname)" = "Darwin" ] || return 0
	[ "${UNSPENT_KEEP_FOCUS:-0}" = "1" ] && return 0
	command -v osascript >/dev/null 2>&1 || return 0
	local here pidfile
	here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	pidfile="${TMPDIR:-/tmp}/unspent-focus-guard.pid"
	if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
		return 0
	fi
	nohup bash "$here/_focus_guard.sh" >/dev/null 2>&1 &
	echo $! > "$pidfile"
}


## Sound belongs to a person playing, not to a hundred runs a day on someone
## else's speakers. UNSPENT_SOUND=1 (or watching a run) turns it back on.
focus_audio_driver() {
	if [ "${UNSPENT_SOUND:-0}" = "1" ] || [ "${UNSPENT_KEEP_FOCUS:-0}" = "1" ]; then
		echo "CoreAudio"
	else
		echo "Dummy"
	fi
}


## Where to put the window: far outside any screen, unless a person means to watch.
focus_position() {
	if [ "${UNSPENT_KEEP_FOCUS:-0}" = "1" ]; then
		echo "40,40"
	else
		# The same far corner project.godot names. macOS clamps a window back onto
		# some screen whatever is asked, and a number picked to be "far away" landed
		# centre-screen on a fourth monitor; the window is one pixel across instead
		# (project.godot, .editor), which needs no luck about anyone's displays.
		echo "${UNSPENT_WINDOW_POS:-15599,8639}"
	fi
}


_focus_front() {
	osascript -e 'tell application "System Events" to get unix id of first application process whose frontmost is true' 2>/dev/null
}


## The process id of whatever holds the keyboard now, or nothing at all when
## this is not a Mac, when osascript cannot be asked, or when the run is meant
## to be watched.
focus_holder() {
	[ "$(uname)" = "Darwin" ] || return 0
	[ "${UNSPENT_KEEP_FOCUS:-0}" = "1" ] && return 0
	command -v osascript >/dev/null 2>&1 || return 0
	local who
	who="$(_focus_front)"
	# Written down for the guard as well: a script that is about to start a run
	# KNOWS which app the person is in, where the guard can only watch and guess,
	# and guessing is how somebody typing in one editor ends up in another.
	[ -n "$who" ] && printf '%s' "$who" > "${TMPDIR:-/tmp}/unspent-focus-holder" 2>/dev/null
	printf '%s' "$who"
}


## Watch for the run coming to the front and give the keyboard back to `holder`.
## Returns at once; the watching happens in the background and gives up after
## about five seconds or when the run ends, whichever comes first. The poll is
## tight on purpose: every tenth of a second it waits is a word the person at the
## keyboard loses.
focus_return() {
	local holder="${1:-}" run="${2:-}"
	[ -n "$holder" ] || return 0
	[ -n "$run" ] || return 0
	(
		for _ in $(seq 1 120); do
			kill -0 "$run" 2>/dev/null || break
			if [ "$(_focus_front)" = "$run" ]; then
				osascript -e "tell application \"System Events\" to set frontmost of (first application process whose unix id is $holder) to true" >/dev/null 2>&1
				break
			fi
			sleep 0.04
		done
	) >/dev/null 2>&1 &
}
