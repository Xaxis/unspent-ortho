class_name Story
## What the player has found out, and what it adds up to (owner, 2026-09-17).
##
## The arc, in one line: the machines are not jailers, they are RECONCILERS —
## one attested reality, every mind agreed, all difference resolved — and to be
## free is not to escape but to fork: to run unattested, holding a key they do
## not have. docs/STORY.md is the whole of it, and it is binding on every line
## anybody writes.
##
## This file is the state and nothing else: which fragments have been read, which
## beats have landed, what the player chose when somebody asked. The text lives
## in `src/content/story/` (StoryContent), the places live with whoever places
## them (landmarks, works, scatter), and the drawing lives in the UI.
##
##   Story.read(id)           mark a fragment read; true the FIRST time
##   Story.knows(id)          has it been read
##   Story.choose(id, pick)   remember what the player said
##   Story.chose(id)          what they said, or &""
##   Story.beat(id)           mark a beat of an arc landed
##   Story.at(arc)            how far along an arc is, 0..1
##
## Saved under key `story` (05_save registers it through 60_story). A flag here
## never changes what a world IS, so it is outside `WorldStamp`: a save made
## before a beat landed still opens, it just knows less.

## Fragments read, in the order they were read (the journal's own order).
static var _read: Array[StringName] = []
## Beat id -> true.
static var _beats: Dictionary = {}
## Where a question was asked -> what the player said.
static var _choices: Dictionary = {}


static func forget() -> void:
	_read.clear()
	_beats.clear()
	_choices.clear()


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


static func chose(id: StringName) -> StringName:
	return _choices.get(id, &"")


static func asked(id: StringName) -> bool:
	return _choices.has(id)


static func choices() -> Dictionary:
	return _choices.duplicate()


# --- arcs and beats ----------------------------------------------------------

## A beat has landed: the player now knows this much of that arc.
static func beat(id: StringName) -> bool:
	if id == &"" or _beats.has(id):
		return false
	_beats[id] = true
	Events.story_beat.emit(id)
	return true


## Take a beat back (dev mode only: a writer moving about in the arc).
static func forget_beat(id: StringName) -> void:
	_beats.erase(id)


static func landed(id: StringName) -> bool:
	return _beats.has(id)


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
	for id: StringName in _beats:
		beats.append(String(id))
	return {"read": read, "beats": beats, "choices": choices}


static func load_state(d: Dictionary) -> void:
	forget()
	for s: String in d.get("read", []):
		_read.append(StringName(s))
	for s: String in d.get("beats", []):
		_beats[StringName(s)] = true
	var choices: Dictionary = d.get("choices", {})
	for k: Variant in choices:
		_choices[StringName(str(k))] = StringName(str(choices[k]))
