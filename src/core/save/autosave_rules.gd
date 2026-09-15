class_name AutosaveRules
extends RefCounted
## When the autosave slot is written, as data with no nodes. Three things call for
## one: the body slept, the player has come into another landscape (it held under
## their feet for SETTLE seconds, so walking a border does not save twice), or
## EVERY_MINUTES of world time have passed since the last. A call waits until
## the moment is calm (no fight on, nothing hostile close, not held, not at
## work) and is then taken once. Any save, manual ones too, restarts the hours.
##
##   var r := AutosaveRules.new(clock_minutes, landscape_id)
##   r.slept()                          on Events.time_skipped(_, &"sleep")
##   r.step_land(landscape_id, delta)   every frame
##   r.due(clock_minutes, calm) -> StringName   &"sleep" &"land" &"hours", or &"" (call when saved)

const EVERY_MINUTES := 180.0
const SETTLE := 2.0

## World minute the last save was written (or the game started or was loaded).
var last_minutes := 0.0
## A reason waiting for a calm moment, or &"".
var pending: StringName = &""
var land: StringName = &""
var _candidate: StringName = &""
var _held := 0.0


func _init(now_minutes: float = 0.0, start_land: StringName = &"") -> void:
	last_minutes = now_minutes
	land = start_land
	_candidate = start_land


func slept() -> void:
	pending = &"sleep"


func step_land(id: StringName, delta: float) -> void:
	if id == &"" or id == &"sea":
		return
	if id != _candidate:
		_candidate = id
		_held = 0.0
		return
	_held += delta
	if _candidate != land and _held >= SETTLE:
		land = _candidate
		if pending == &"":
			pending = &"land"


## The reason to save now, or &"". Taking a reason marks the save as written.
func due(now_minutes: float, calm: bool) -> StringName:
	if pending == &"" and now_minutes - last_minutes >= EVERY_MINUTES:
		pending = &"hours"
	if pending == &"" or not calm:
		return &""
	var why := pending
	saved(now_minutes)
	return why


## A save was written at `now_minutes` (by the rules or by the player).
func saved(now_minutes: float) -> void:
	pending = &""
	last_minutes = now_minutes
