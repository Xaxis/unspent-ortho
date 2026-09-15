class_name UiPlaceWatch
extends RefCounted
## Crossing into another landscape is an event: the slate pings its name once.
## A border is not a line people walk along exactly, so a new landscape must
## hold under the player's feet for SETTLE seconds before it is announced, and
## the landscape the player starts in is announced once at the start. Keys are
## landscape type ids (BiomeRegistry); the sea is never announced.

const SETTLE := 1.5
const SEA := &"sea"

var announced: StringName = &""
var _candidate: StringName = &""
var _held := 0.0


## Feed the landscape under the player each frame. Returns the one to announce
## now, or &"".
func step(id: StringName, delta: float) -> StringName:
	if id == SEA or id == &"":
		return &""
	if id != _candidate:
		_candidate = id
		_held = 0.0
	else:
		_held += delta
	if _candidate != announced and (_held >= SETTLE or announced == &""):
		announced = _candidate
		return announced
	return &""
