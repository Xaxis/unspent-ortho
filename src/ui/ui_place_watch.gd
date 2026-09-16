class_name UiPlaceWatch
extends RefCounted
## Crossing into another landscape is an event: the slate pings its name once.
## A border is not a line people walk along exactly, so a new landscape must
## hold under the player's feet for SETTLE seconds before it is announced, and
## the landscape the player starts in is announced once at the start. Keys are
## landscape type ids (BiomeRegistry); the sea is never announced.
##
## SETTLE is for a walked border only. A player who did not walk there — a
## teleport, a load, a portal — is somewhere else at once, and the name is said
## at once with them: a caption that still reads COAST over the snowfield is a
## lie, and the slate's type must be exact (docs/ART.md §9).

const SETTLE := 1.5
const SEA := &"sea"
## Tiles crossed in one step that no walk could cross: not a border, a jump.
const JUMP := 6.0

var announced: StringName = &""
var _candidate: StringName = &""
var _held := 0.0


## Feed the landscape under the player each frame. `jumped`: the player did not
## walk here. Returns the one to announce now, or &"".
func step(id: StringName, delta: float, jumped: bool = false) -> StringName:
	if id == SEA or id == &"":
		return &""
	if id != _candidate:
		_candidate = id
		_held = 0.0
	else:
		_held += delta
	if jumped:
		_held = SETTLE
	if _candidate != announced and (_held >= SETTLE or announced == &""):
		announced = _candidate
		return announced
	return &""


## True when `from` to `to` in one step was a jump, not a walk.
static func jumped(from: Vector2, to: Vector2) -> bool:
	return from.distance_to(to) > JUMP
