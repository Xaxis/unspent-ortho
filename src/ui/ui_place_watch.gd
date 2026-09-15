class_name UiPlaceWatch
extends RefCounted
## Crossing into another country is an event: the HUD letters its name once.
## A border is not a line people walk along exactly, so a new country must hold
## under the player's feet for SETTLE seconds before it is announced, and the
## country the player starts in is announced once at the start.

const SETTLE := 1.5

var announced := -1
var _candidate := -1
var _held := 0.0


## Feed the country under the player each frame. Returns the country to
## announce now, or -1.
func step(country: int, delta: float) -> int:
	if country == Country.SEA:
		return -1
	if country != _candidate:
		_candidate = country
		_held = 0.0
	else:
		_held += delta
	if _candidate != announced and (_held >= SETTLE or announced == -1):
		announced = _candidate
		return announced
	return -1
