class_name DrawnPace
extends RefCounted
## Where a body the simulation steps is DRAWN: between the places it stood at
## the last few physics ticks, at a time a constant lag behind real time.
##
## The simulation moves bodies in whole slices (FightRules.SLICE_MS, 8 ms) inside
## a physics tick (60 a second), so one tick moves a body 16 ms of the way and
## every twelfth 24 ms, and a frame drawn at another rate gets no tick or two.
## Drawn where its last slice left it, a walking body jumped half again as far
## every twelfth frame, and off sixty frames a second it stepped against a ground
## the camera scrolls smoothly. Drawn here it moves at its own speed every frame.
## The rules read the body's own `pos` as ever: this is the view's.
##
##   note(t_ms, at)     after a tick: where it stands at simulation time t_ms
##   at(t_ms) -> Vector2  where to draw it at t_ms, inside what was noted
##   real_ms(now, carry, frac, tick_ms) static  the time a frame draws at: real
##                      time less a slice and a tick, the most the simulation can owe

## Ticks kept: enough to reach a lag behind the newest at any tick rate.
const KEEP := 4
## A move between two ticks longer than this is a place set, not a walk (a
## teleport, a boarding, a respawn): it is drawn there at once, never slid to.
const JUMP := 1.5

var _t := PackedFloat64Array()
var _p := PackedVector2Array()


## The simulation time a frame draws at: `now` (the end of the last slice), the
## real milliseconds the simulation still owes (`carry`), the fraction `frac` of
## the next physics tick of `tick_ms` this frame falls into, less the lag.
static func real_ms(now: float, carry: float, frac: float, tick_ms: float) -> float:
	return now + carry + frac * tick_ms - (FightRules.SLICE_MS + tick_ms)


func note(t_ms: float, at: Vector2) -> void:
	var n := _t.size()
	if n > 0 and (at.distance_to(_p[n - 1]) > JUMP or t_ms < _t[n - 1]):
		clear()
		n = 0
	if n > 0 and t_ms == _t[n - 1]:
		# No slice ran (a hitstop, a held sim), or the place was set between
		# slices: if it moved, it is drawn there, not slid to from where it was.
		if at != _p[n - 1]:
			clear()
			_t.append(t_ms)
			_p.append(at)
		return
	_t.append(t_ms)
	_p.append(at)
	if _t.size() > KEEP:
		_t.remove_at(0)
		_p.remove_at(0)


## The newest place noted, or INF with none.
func latest() -> Vector2:
	return _p[_p.size() - 1] if not _p.is_empty() else Vector2.INF


func clear() -> void:
	_t.clear()
	_p.clear()


func at(t_ms: float) -> Vector2:
	var n := _t.size()
	if n == 0:
		return Vector2.INF
	if t_ms >= _t[n - 1]:
		return _p[n - 1]
	if t_ms <= _t[0]:
		return _p[0]
	for i in range(n - 1, 0, -1):
		if t_ms >= _t[i - 1]:
			return _p[i - 1].lerp(_p[i], (t_ms - _t[i - 1]) / (_t[i] - _t[i - 1]))
	return _p[0]
