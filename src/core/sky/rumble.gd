extends RefCounted
## WHAT A FAR EVENT SENDS THE PLAYER, STILL ON ITS WAY: a queue of things that
## arrive after a delay in REAL seconds -- what a body perceives, not the world
## clock -- each carried at its own speed: the ground's shake and thump at
## 3 km/s, the boom through the air at 343 m/s. A colossus's footfall (19_colossi)
## and a fall's boom (21_falls) ride it; what an arrival DOES is the sender's.
##
## Pure and headless: `arrive(delta)` says what has come, in the order it was
## sent, and nothing here touches the camera or the sound.
##
## No class_name (reached by path).

const GROUND_SPEED := 3000.0
const AIR_SPEED := 343.0

## [real seconds left, what, where it happened, how far that is (metres)].
var _coming: Array = []


## Real seconds for something `d` metres off to reach the player through the
## ground, and through the air.
static func ground_delay(d: float) -> float:
	return d / GROUND_SPEED


static func air_delay(d: float) -> float:
	return d / AIR_SPEED


func send(secs: float, what: StringName, at: Vector3, d: float) -> void:
	_coming.append([secs, what, at, d])


## A footfall's three: the quake and the thump through the ground, the boom
## through the air.
func landing(at: Vector3, d: float) -> void:
	send(ground_delay(d), &"quake", at, d)
	send(ground_delay(d), &"thump", at, d)
	send(air_delay(d), &"boom", at, d)


## What has arrived after `delta` more real seconds: [{what, at, d}], in the
## order it was sent.
func arrive(delta: float) -> Array:
	var out: Array = []
	var i := 0
	while i < _coming.size():
		var c: Array = _coming[i]
		c[0] = float(c[0]) - delta
		if float(c[0]) > 0.0:
			i += 1
			continue
		_coming.remove_at(i)
		out.append({"what": c[1], "at": c[2], "d": c[3]})
	return out


## Seconds until the soonest thing arrives (INF when nothing is on its way).
func soonest() -> float:
	var s := INF
	for c: Array in _coming:
		s = minf(s, float(c[0]))
	return s


func size() -> int:
	return _coming.size()


func clear() -> void:
	_coming.clear()
