class_name AutosaveRules
extends RefCounted
## When the autosave slot is written, as data with no nodes. Three things call for
## one: the body slept, the player has come into a landscape not entered before in
## this game (it held under their feet for SETTLE seconds), or EVERY_MINUTES of
## world time have passed since the last. A call waits until the moment is quiet
## (no fight on, nothing hostile close, not held, not at work, no page open) and
## is then taken once. Any save, manual ones too, restarts the hours.
##
## A landscape's call also waits for LAND_GAP seconds of play since the last save:
## each write reads the frame back from the GPU, encodes a PNG and, on the web,
## syncs IndexedDB, and a walk through three small landscapes is one journey.
##
##   var r := AutosaveRules.new(clock_minutes, landscape_id)
##   r.slept()                          on Events.time_skipped(_, &"sleep")
##   r.step_land(landscape_id, delta)   every frame of play (delta in real seconds)
##   r.waiting(clock_minutes) -> bool   a reason is waiting (only then ask whether it is quiet)
##   r.due(clock_minutes, quiet) -> StringName   &"sleep" &"land" &"hours", or &"" (taken = saved)
##   r.entered                          the landscapes come into so far (saved with the game)

const EVERY_MINUTES := 180.0
## What a configuration may change (rules.autosave, docs/DEV.md): the hours between
## saves, and whether the rules ask for one at all. A playtest that wants its own
## slots and nothing else turns this off; nothing else in the game writes them.
var every_minutes := EVERY_MINUTES
var enabled := true
const SETTLE := 2.0
const LAND_GAP := 60.0

## World minute the last save was written (or the game started or was loaded).
var last_minutes := 0.0
## A reason waiting for a calm moment, or &"".
var pending: StringName = &""
var land: StringName = &""
## Landscape id -> true for every landscape this game has stood in.
var entered := {}
## Seconds of play since the last save (or the start).
var since_save := 0.0
var _candidate: StringName = &""
var _held := 0.0


func _init(now_minutes: float = 0.0, start_land: StringName = &"") -> void:
	last_minutes = now_minutes
	land = start_land
	_candidate = start_land
	if start_land != &"":
		entered[start_land] = true


func slept() -> void:
	pending = &"sleep"


func step_land(id: StringName, delta: float) -> void:
	since_save += delta
	if id == &"" or id == &"sea":
		return
	if id != _candidate:
		_candidate = id
		_held = 0.0
		return
	_held += delta
	if _candidate != land and _held >= SETTLE:
		land = _candidate
		if entered.has(land):
			return
		entered[land] = true
		if pending == &"":
			pending = &"land"


func waiting(now_minutes: float) -> bool:
	if not enabled:
		return false
	if pending == &"" and now_minutes - last_minutes >= every_minutes:
		pending = &"hours"
	return pending != &""


## The reason to save now, or &"". Taking a reason marks the save as written.
func due(now_minutes: float, quiet: bool) -> StringName:
	if not waiting(now_minutes) or not quiet:
		return &""
	if pending == &"land" and since_save < LAND_GAP:
		return &""
	var why := pending
	saved(now_minutes)
	return why


## A save was written at `now_minutes` (by the rules or by the player).
func saved(now_minutes: float) -> void:
	pending = &""
	last_minutes = now_minutes
	since_save = 0.0


## The landscapes entered, sorted, for a save; and back.
func entered_list() -> Array:
	var out: Array = []
	for id: StringName in entered:
		out.append(String(id))
	out.sort()
	return out


func enter_all(ids: Variant) -> void:
	if not (ids is Array):
		return
	for id: Variant in ids:
		if id is String and id != "":
			entered[StringName(id)] = true
