class_name DodgeInput
extends RefCounted
## Shift is both run and dodge. K always dodges at once. Shift:
##   in a fight, a press dodges at once and holding on runs after it (a step
##   out of the way that turns into running away);
##   out of one, a tap (released within TAP_MS) dodges on release, and a hold
##   only runs, so walking about never spends wind.

const TAP_MS := 180

var _down_at := -1.0
var _spent := false


## Shift went down at `now_ms`. Returns true if that is a dodge now.
func shift_pressed(now_ms: float, in_fight: bool) -> bool:
	_down_at = now_ms
	_spent = in_fight
	return in_fight


## Shift came up at `now_ms`. Returns true if that is a dodge now.
func shift_released(now_ms: float) -> bool:
	if _down_at < 0.0:
		return false
	var tap := not _spent and now_ms - _down_at <= TAP_MS
	_down_at = -1.0
	_spent = false
	return tap
