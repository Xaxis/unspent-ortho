class_name Story
## What the player has found out, and what it adds up to (owner, 2026-09-17).
##
## The story is docs/STORY.md, and it is binding on every line anybody writes:
## Elias Marr, a 2029 AI researcher and CIA spy whose mind became the machines,
## wakes in 2098 and learns, a piece at a time, what he did and what he hid.
##
## This file is the state and nothing else: which fragments have been read, which
## beats have landed and when, what the player chose when somebody asked, who he
## has met, and what the world saw him do. The text lives in `src/content/story/`
## (StoryContent), the places live with whoever places them (landmarks, works,
## scatter, StoryCasting), and the drawing lives in the UI.
##
##   Story.read(id)           mark a fragment read; true the FIRST time
##   Story.knows(id)          has it been read
##   Story.choose(id, pick)   remember what the player said
##   Story.chose(id)          what they said, or &""
##   Story.beat(id)           mark a beat of an arc landed, now
##   Story.landed_at(id)      the world minute it landed (StoryPacing reads it)
##   Story.at(arc)            how far along an arc is, 0..1
##
## Saved under key `story` (49_story registers it). A flag here never changes
## what a world IS, so it is outside `WorldStamp`: a save made before a beat
## landed still opens, it just knows less.

## Fragments read, in the order they were read (the journal's own order).
static var _read: Array[StringName] = []
## Beat id -> the world minute it landed (`now` then).
static var _beats: Dictionary = {}
## Where a question was asked -> what the player said.
static var _choices: Dictionary = {}
## Named people he has spoken to, in the order he met them (StoryCast).
static var _met: Array[StringName] = []
## What a region has already asked him, and what it has already thanked him for
## (StorySubarc): ids of the form "REGION:goal". Whether a thing is DONE is read
## off the world, so only the telling is remembered.
static var _heard: Array[StringName] = []
## What the world has seen him do, for whoever writes it down (StoryLedger):
## {act, land, at} in the order it happened.
static var _ledger: Array[Dictionary] = []
## Whether the first morning has been said (StoryContent.OPENING). Saved, so a
## game that is loaded does not open by telling him again where he came from.
static var began := false
## The world clock as the story last saw it, in minutes. What "a while ago" is
## measured from: 49_story writes it every frame, a test writes it by hand.
static var now := 0.0


static func forget() -> void:
	_read.clear()
	_beats.clear()
	_choices.clear()
	_met.clear()
	_heard.clear()
	_ledger.clear()
	began = false
	now = 0.0


# --- what has been found -----------------------------------------------------

## The player has read it. True the first time only, so a caller can say
## something about it once and never again.
static func read(id: StringName) -> bool:
	if id == &"" or _read.has(id):
		return false
	_read.append(id)
	_land_beats_for(id)
	Events.story_found.emit(id)
	return true


static func knows(id: StringName) -> bool:
	return _read.has(id)


## Everything read, oldest first: what the journal shows.
static func found() -> Array[StringName]:
	return _read.duplicate()


static func found_count() -> int:
	return _read.size()


# --- what was said -----------------------------------------------------------

## Remember what the player said when `id` was asked. A choice is a fact about
## the player, not about the world: it is what later lines read to know who they
## have been talking to.
static func choose(id: StringName, pick: StringName) -> void:
	if id == &"":
		return
	_choices[id] = pick
	Events.story_chose.emit(id, pick)
	_land_beats_for(id)


## He has spoken to this named person. True the first time only.
static func meet(id: StringName) -> bool:
	if id == &"" or _met.has(id):
		return false
	_met.append(id)
	return true


static func met(id: StringName) -> bool:
	return _met.has(id)


## Somebody has said this to him. True the first time only.
static func hear(id: StringName) -> bool:
	if id == &"" or _heard.has(id):
		return false
	_heard.append(id)
	return true


static func heard(id: StringName) -> bool:
	return _heard.has(id)


## What a telling was ABOUT, remembered with the telling itself. A sub-arc is
## answered by the world CHANGING — the cache is opened, the yard goes dark — so
## afterwards the thing it was about can no longer be found by looking for one
## that is still waiting, and somebody who thanks him has to be able to name it.
## Kept in the same list as the telling, and so saved and forgotten with it.
static func hear_about(id: StringName, about: String) -> void:
	if id == &"" or about == "":
		return
	var mark := StringName("at.%s|%s" % [id, about])
	if not _heard.has(mark):
		_heard.append(mark)


## What that telling was about, or "".
static func heard_about(id: StringName) -> String:
	var head := "at.%s|" % id
	for m: StringName in _heard:
		var s := String(m)
		if s.begins_with(head):
			return s.substr(head.length())
	return ""


## Something the world saw him do. Only what could have been OBSERVED belongs
## here (docs/DESIGN.md), and the same act in the same land inside an hour
## is one thing seen, not two.
static func note(act: StringName, land: StringName, minutes: float) -> void:
	if act == &"":
		return
	for e: Dictionary in _ledger:
		if e.act == act and e.land == land and absf(float(e.at) - minutes) < 60.0:
			return
	_ledger.append({"act": act, "land": land, "at": minutes})


static func ledger() -> Array[Dictionary]:
	return _ledger.duplicate()


static func chose(id: StringName) -> StringName:
	return _choices.get(id, &"")


static func asked(id: StringName) -> bool:
	return _choices.has(id)


static func choices() -> Dictionary:
	return _choices.duplicate()


# --- arcs and beats ----------------------------------------------------------

## A beat has landed: the player now knows this much of that arc. `at` is the
## world minute it landed, `now` unless somebody is staging a story that happened
## long ago (`--beats`, dev mode), which passes -INF: landed, and long since felt.
static func beat(id: StringName, at := NAN) -> bool:
	if id == &"" or _beats.has(id):
		return false
	_beats[id] = now if is_nan(at) else at
	Events.story_beat.emit(id)
	return true


## Take a beat back (dev mode only: a writer moving about in the arc).
static func forget_beat(id: StringName) -> void:
	_beats.erase(id)


static func landed(id: StringName) -> bool:
	return _beats.has(id)


## The world minute a beat landed, or INF when it has not.
static func landed_at(id: StringName) -> float:
	return float(_beats.get(id, INF))


## Every beat landed, in no promised order.
static func landed_beats() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _beats:
		out.append(id)
	return out


## How far along an arc is, 0..1, by how many of its beats have landed.
static func at(arc: StringName) -> float:
	var beats: Array = StoryContent.arc_beats(arc)
	if beats.is_empty():
		return 0.0
	var n := 0
	for b: StringName in beats:
		if _beats.has(b):
			n += 1
	return float(n) / float(beats.size())


## The next beat of an arc that has not landed, or &"" when it is finished.
static func next_of(arc: StringName) -> StringName:
	for b: StringName in StoryContent.arc_beats(arc):
		if not _beats.has(b):
			return b
	return &""


## Beats a fragment or a choice carries with it: reading the thing IS the beat.
static func _land_beats_for(id: StringName) -> void:
	for b: StringName in StoryContent.beats_from(id):
		beat(b)


# --- saving ------------------------------------------------------------------

static func save_state() -> Dictionary:
	var read := PackedStringArray()
	for id: StringName in _read:
		read.append(String(id))
	var choices := {}
	for id: StringName in _choices:
		choices[String(id)] = String(_choices[id])
	var beats := PackedStringArray()
	var beat_at := {}
	for id: StringName in _beats:
		beats.append(String(id))
		# JSON has no infinity: a beat staged as long ago is saved as long ago.
		beat_at[String(id)] = maxf(float(_beats[id]), -1.0e9)
	var met := PackedStringArray()
	for id: StringName in _met:
		met.append(String(id))
	var heard := PackedStringArray()
	for id: StringName in _heard:
		heard.append(String(id))
	var seen: Array = []
	for e: Dictionary in _ledger:
		seen.append({"act": String(e.act), "land": String(e.land), "at": float(e.at)})
	return {"read": read, "beats": beats, "beat_at": beat_at, "choices": choices, "met": met, "heard": heard, "ledger": seen, "began": began}


static func load_state(d: Dictionary) -> void:
	forget()
	for s: String in d.get("read", []):
		_read.append(StringName(s))
	# A save from before beats kept their minute knows only that they landed:
	# long ago, and long since felt.
	var beat_at: Dictionary = d.get("beat_at", {})
	for s: String in d.get("beats", []):
		_beats[StringName(s)] = float(beat_at.get(s, -1.0e9))
	var choices: Dictionary = d.get("choices", {})
	for k: Variant in choices:
		_choices[StringName(str(k))] = StringName(str(choices[k]))
	for s: String in d.get("met", []):
		_met.append(StringName(s))
	for s: String in d.get("heard", []):
		_heard.append(StringName(s))
	began = bool(d.get("began", false))
	for e: Variant in d.get("ledger", []):
		if e is Dictionary:
			var row: Dictionary = e
			_ledger.append({"act": StringName(str(row.get("act", ""))), "land": StringName(str(row.get("land", ""))), "at": float(row.get("at", 0.0))})
