#!/usr/bin/env bash
# Keep a run of the game from taking the keyboard away from whoever is using the
# machine. Two things have to happen, because macOS does two things:
#
#   project.godot sets display/window/size/no_focus, so the window itself can
#   never become key and can never swallow what is being typed elsewhere;
#
#   and macOS still brings the app forward when it opens a window (Godot asks it
#   to, whatever the window's flags say), so the helpers here remember who had
#   the keyboard and hand it straight back, usually within about a tenth of a
#   second. A shot or a tour draws exactly the same unfocused.
#
# Set UNSPENT_KEEP_FOCUS=1 to let a run come to the front, to watch it play.
#
#   . tools/_focus.sh
#   holder="$(focus_holder)"
#   godot ... & pid=$!
#   focus_return "$holder" "$pid"

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
	_focus_front
}


## Watch for the run coming to the front and give the keyboard back to `holder`.
## Returns at once; the watching happens in the background and gives up after
## five seconds or when the run ends, whichever comes first.
focus_return() {
	local holder="${1:-}" run="${2:-}"
	[ -n "$holder" ] || return 0
	[ -n "$run" ] || return 0
	(
		for _ in $(seq 1 50); do
			kill -0 "$run" 2>/dev/null || break
			if [ "$(_focus_front)" = "$run" ]; then
				osascript -e "tell application \"System Events\" to set frontmost of (first application process whose unix id is $holder) to true" >/dev/null 2>&1
				break
			fi
			sleep 0.1
		done
	) >/dev/null 2>&1 &
}
