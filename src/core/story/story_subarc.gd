class_name StorySubarc
## What a region asks of him (docs/VISION.md §2, §10.4). A chapter with three
## demands and no stories in it is a checklist, so each region raises its own
## story out of its own state: the plan's yard still running, a cache nobody
## went back for, a place nobody has walked to since.
##
## PURE, and derived from a `StorySubarcLook` the system fills in, so the same
## region raises the same thing every time that world is grown and a save opens
## on the one it closed on. Only what the player has HEARD is remembered
## (`Story.hear`); whether it is ANSWERED is read off the world, because the
## answer is a works gone dark or a cache opened, and the world already knows.
##
## Not a beat: beats are authored and finite, and these are one per region in a
## world with dozens (the journal, the dev page and `every beat has a door` all
## read the authored list). A sub-arc may land an authored beat where it touches
## the spine, which is what keeps them one story.

## In the order a region offers them: somebody the plan is holding first, because
## a yard stops being a number the moment a neighbour is inside it; then the yard
## itself taking the place apart; then what its own people have lost; then what
## nobody has been to see.
##
## Rescue and sabotage are ONE ACT and two askings on purpose (`src/core/taken/`,
## unspent-ortho-cb). Putting the yard dark is what frees them, so a region that
## is holding somebody never asks about the ground: it asks about the person, and
## the ground is what he has to walk over to answer. The escort is what is left
## when the yard is dark and somebody is stood at its gate who will not come down
## the road alone.
const GOALS: Array[StringName] = [&"rescue", &"escort", &"sabotage", &"recover", &"discover"]


## What a region says has three moods and they are not its demands (owner's §10,
## unspent-ortho-cb): BEFORE, the place is quiet and something is wrong with it;
## DURING, they have noticed him and a warning lands better than an ask; AFTER,
## the plan has lost the place, and it is the first time anybody here is safe.
static func mood(look: StorySubarcLook) -> StringName:
	if look.answered:
		return &"done"
	if look.lost():
		return &"after"
	return &"during" if look.roused() else &"before"


## What this region is asking, or {} when it asks nothing: {id, goal, place, pos}.
##
## A goal the world has ANSWERED outranks the next thing the region wants, until
## somebody has thanked him for it. Without that the thanks could never be said:
## the one act that answers a goal is the act that stops it being raised, so the
## moment the yard went dark the region began asking for a cache instead, and the
## person he did it for met him with an errand. The thanks was written and
## unreachable for the whole life of the package.
static func raised(look: StorySubarcLook) -> Dictionary:
	if look == null or look.region < 0:
		return {}
	var owed := _owed(look)
	return owed if not owed.is_empty() else _asking(look)


## A goal he was told about, has answered, and nobody has thanked him for. What
## it was ABOUT comes from the telling (`Story.heard_about`) rather than from the
## world, because the world answered it by changing: the cache he opened is no
## longer one that is waiting to be opened.
static func _owed(look: StorySubarcLook) -> Dictionary:
	for goal: StringName in GOALS:
		var id := StringName("%d:%s" % [look.region, goal])
		if not Story.heard(id) or Story.heard(StringName("%s:said" % id)):
			continue
		var place := Story.heard_about(id)
		if answered(look, goal, place) or failed(look, goal, place):
			return {"id": id, "goal": goal, "place": place, "pos": _where(look, goal, place)}
	return {}


## Whether the world has ENDED what the region asked for without it being done.
## Only the walk can: a yard can wait and a cache can wait, and a person cannot.
## It is not a grade and nothing anywhere calls it a failure — it is a fact about
## somebody, and what a village does with it is say what it knows and leave.
static func failed(look: StorySubarcLook, goal: StringName, place: String) -> bool:
	return goal == &"escort" and look.lost_on_road.has(place)


## What the region wants now, or {}.
static func _asking(look: StorySubarcLook) -> Dictionary:
	# Only ever asked where there is a yard to put dark, because that is the one
	# act that lets anybody out of it: a region with nobody to break has no way
	# to answer, and a sub-arc nobody can answer is a cruelty, not a story.
	if not look.held.is_empty() and look.works != Vector2.INF:
		return _one(look, &"rescue", look.held[0], look.works)
	# Out of the yard and not down the road. Asked for one at a time, by name,
	# because two people walked at once is a column and not a rescue.
	if not look.waiting.is_empty():
		return _one(look, &"escort", look.waiting[0], look.works)
	if look.works != Vector2.INF and not look.works_dark:
		return _one(look, &"sabotage", look.works_name, look.works)
	var cache := look.any(true, false)
	if not cache.is_empty():
		return _one(look, &"recover", str(cache.name), cache.pos as Vector2)
	var unseen := look.any(false, false)
	if not unseen.is_empty():
		return _one(look, &"discover", str(unseen.name), unseen.pos as Vector2)
	return {}


## Where the thing a goal is about stands, for whoever shows it.
static func _where(look: StorySubarcLook, goal: StringName, place: String) -> Vector2:
	if goal == &"rescue" or goal == &"sabotage" or goal == &"escort":
		return look.works
	for l: Dictionary in look.landmarks:
		if str(l.name) == place:
			return l.pos as Vector2
	return Vector2.INF


## Whether what the region asked for has been done. Read off the world, never
## counted: nobody is held there any more, or the yard is dark, or the cache is
## open, or the place has been found.
static func answered(look: StorySubarcLook, goal: StringName, place: String) -> bool:
	match goal:
		&"rescue":
			return look.held.is_empty()
		&"escort":
			return look.arrived.has(place)
		&"sabotage":
			return look.works_dark
		&"recover":
			for l: Dictionary in look.landmarks:
				if str(l.name) == place:
					return bool(l.opened)
		&"discover":
			for l: Dictionary in look.landmarks:
				if str(l.name) == place:
					return bool(l.found)
	return false


## The conversation somebody of this region has with him about it: the asking
## while it stands, and the thanks once it is done. A made talk, in the shape
## `StoryContent.TALKS` uses, because what it says is about THIS region.
static func talk(look: StorySubarcLook, said: Dictionary) -> Dictionary:
	if look == null or look.region < 0:
		return {}
	# A region with nothing to ask still has a mood: what a place is like once
	# they are hunting him through it, or once the plan has lost it.
	var words: Dictionary = StoryContent.SUBARCS.get(said.get("goal", &""), {}) if not said.is_empty() else {}
	if words.is_empty():
		return _mood_page(look, said)
	# What he did for THEM comes first, because it is the most specific thing
	# anybody here has to say to him, and it is said once.
	var done := answered(look, said.goal, str(said.place))
	var heard := Story.heard(said.id)
	var last_word := not Story.heard(StringName("%s:said" % said.id))
	# THE THIRD ENDING, ahead of everything, because it is the heaviest thing
	# anybody here has to say to him and nothing else may be said first. What
	# took them decides which of the two it is: a village carries the cold and
	# the water differently to being come back for.
	if heard and last_word and failed(look, said.goal, str(said.place)):
		var took := StringName(str(look.lost_to.get(str(said.place), &"")))
		var ending: Array = words.lost_to if took != &"" and words.has("lost_to") else words.lost
		return _page(said, ending, StringName("%s:said" % said.id), "[leave]")
	if done and heard and last_word:
		# What they say is different if he said he would, and then did.
		var lines: Array = words.kept if promised(said) and words.has("kept") else words.thanks
		return _page(said, lines, StringName("%s:said" % said.id), "[leave]")
	# Then what the region itself is doing: they are hunting him through it, or
	# the plan has lost it. Either outranks what the region wanted. Said once.
	var by_mood := _mood_page(look, said)
	if not by_mood.is_empty():
		return by_mood
	if done or heard:
		return {}
	# Saying nothing is always one of the answers (docs/STORY.md §13), and saying
	# he will is remembered, so what they say after is about what he said.
	return _page(said, words.ask, said.id, str(words.get("answer", "[say nothing]")), true)


## What the region itself has to say, or {}: said once per mood.
static func _mood_page(look: StorySubarcLook, said: Dictionary) -> Dictionary:
	var here := mood(look)
	if here == &"before":
		return {}
	var mark := StringName("%d:%s" % [look.region, here])
	if Story.heard(mark):
		return {}
	return _page(said, StoryContent.MOODS[here], mark, "[leave]")


## Whether he told them he would.
static func promised(said: Dictionary) -> bool:
	return Story.chose(StringName("ask.%s" % said.get("id", &""))) == &"will"


static func _page(said: Dictionary, lines: Array, mark: StringName, last: String, asking := false) -> Dictionary:
	var says := PackedStringArray()
	for l: String in lines:
		says.append(l % str(said.get("place", "")) if l.contains("%s") else l)
	var replies: Array = [{"text": last, "to": &""}]
	if asking:
		replies = [
			{"text": last, "pick": &"will", "to": &""},
			{"text": "[say nothing]", "pick": &"nothing", "to": &""},
		]
	var page := {
		"made": true, "mark": mark, "title": "somebody who lives here", "start": &"open",
		"nodes": {&"open": {"says": says, "pick_at": StringName("ask.%s" % said.get("id", &"")), "replies": replies}},
	}
	# An ASKING remembers what it was about, so the thanks can name it after the
	# world has changed (`Story.hear_about`, read back by `_owed`).
	if asking:
		page["about"] = str(said.get("place", ""))
	return page


static func _one(look: StorySubarcLook, goal: StringName, place: String, pos: Vector2) -> Dictionary:
	return {"id": StringName("%d:%s" % [look.region, goal]), "goal": goal, "place": place, "pos": pos}
