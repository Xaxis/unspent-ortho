class_name StoryCast
## Every named person, found the way landscapes are found (docs/STORY_SYSTEM.md §3):
## one file under src/content/story/cast/, each with `static func make() ->
## StoryCharacter`. Adding a character is adding a file, and two writers only ever
## collide if they wrote the same person.

const DIR := "res://src/content/story/cast"

static var _by_id: Dictionary = {}


static func all() -> Array[StoryCharacter]:
	_ensure()
	var out: Array[StoryCharacter] = []
	for id: StringName in _by_id:
		out.append(_by_id[id])
	return out


static func get_def(id: StringName) -> StoryCharacter:
	_ensure()
	return _by_id.get(id, null)


## The character whose conversation this is, or null for a trade's.
static func speaker_of(talk: StringName) -> StoryCharacter:
	for c: StoryCharacter in all():
		if c.talk == talk:
			return c
	return null


## Everything wrong with the cast, in words a writer can act on.
static func problems() -> Array[String]:
	var out: Array[String] = []
	var spine := {}
	for s: StorySlot in StoryPlan.slots():
		spine[s.id] = true
	for c: StoryCharacter in all():
		if c.name == "" or c.title == "":
			out.append("%s has no name or no title" % c.id)
		if not spine.has(c.at):
			out.append("%s stands at %s, which is not a spine slot" % [c.id, c.at])
		var t: Dictionary = StoryContent.TALKS.get(c.talk, {})
		if t.is_empty():
			out.append("%s talks through %s, which is not written" % [c.id, c.talk])
		elif StringName(str(t.get("cast", &""))) != c.id:
			out.append("%s's talk %s does not say it is theirs (cast = %s)" % [c.id, c.talk, c.id])
		if not PersonLook.TRADES.has(c.trade):
			out.append("%s is dressed as %s, which is not a trade" % [c.id, c.trade])
		for b: StringName in [c.appears_when, c.gone_when]:
			if b != &"" and not StoryContent.BEATS.has(b):
				out.append("%s waits on %s, which is not a beat" % [c.id, b])
	for talk: StringName in StoryContent.TALKS:
		var who := StringName(str(StoryContent.TALKS[talk].get("cast", &"")))
		if who != &"" and get_def(who) == null:
			out.append("%s belongs to %s, who is not in the cast" % [talk, who])
	return out


static func _ensure() -> void:
	if not _by_id.is_empty():
		return
	var made := {}
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_error("StoryCast: no %s" % DIR)
		return
	var files := PackedStringArray()
	for f in dir.get_files():
		# Exported builds serve .gd as .gd; the editor may list .gd.remap.
		if f.ends_with(".gd.remap"):
			f = f.trim_suffix(".remap")
		if f.ends_with(".gd"):
			files.append(DIR + "/" + f)
	files.sort()
	for path: String in files:
		var script: GDScript = load(path)
		if script == null or not script.has_method(&"make"):
			continue
		var c: StoryCharacter = script.call(&"make")
		if c != null and c.id != &"":
			made[c.id] = c
	_by_id = made
