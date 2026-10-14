class_name FirstSteps
extends RefCounted
## THE FIRST STEPS (owner, 2026-10-13: "the beginning of the story doesn't have
## enough guidance or clear direction and clear learning tasks simplified to get
## the user directed along the lines of game mechanics and the world they will
## soon explore"). Maren's errand cut into steps of one mechanic each, which the
## slate shows as a card (Hud) and the world points at (UiStepMark): a plain
## imperative, a count where there is one, the key that does it, and what in the
## world it is about. The last steps open the survey and send him to the crew's
## camp, out into the island.
##
##   FirstSteps.list(game, done) -> [{key, text, have, need, act, target, done}]
##   FirstSteps.current(rows)    -> index of the first not done, or -1 once all are
##
## `done` is the asker's (58_guide): steps it has seen done, and the ones only an
## act shows (`carry`, `survey`: a page opened). A step once done stays done, and
## a step is done once any after it is: a body that walked on from its fire has
## still laid one, and a player who went their own way is never sent back for a
## lesson they did not need.

## Each step in plain words: what to do, where, and with what (owner, 2026-10-14:
## the suggestions were "completely incoherent"). The world's own names stay
## where a prompt on the glass uses them (the tip, a rebar slab), so the card
## and the key row never disagree.
const STEPS: Array[Dictionary] = [
	{"key": &"talk", "text": "Talk to Maren", "act": &"use", "target": &"maren"},
	{"key": &"driftwood", "text": "Gather driftwood on the beach", "need": 3, "act": &"use", "target": &"driftwood"},
	{"key": &"stones", "text": "Gather stones from a boulder", "need": 2, "act": &"use", "target": &"stone"},
	{"key": &"fire", "text": "Build a campfire on open ground", "act": &"use", "target": &""},
	{"key": &"wood", "text": "Gather more wood to burn into charcoal", "need": 4, "act": &"use", "target": &"driftwood"},
	{"key": &"charcoal", "text": "Burn the wood into charcoal at your fire", "act": &"craft", "target": &"fire"},
	{"key": &"haft", "text": "Carve a handle at your fire", "act": &"craft", "target": &"fire"},
	{"key": &"plate", "text": "Pull scrap metal out of the scrap heap", "act": &"use", "target": &"tip"},
	{"key": &"pick", "text": "Make a pickaxe at your fire", "act": &"craft", "target": &"fire"},
	{"key": &"carry", "text": "Check your pack: the pickaxe is in it", "act": &"inventory", "target": &""},
	{"key": &"iron", "text": "Break iron out of a rebar slab with the pickaxe", "act": &"use", "target": &"slab"},
	{"key": &"survey", "text": "Open the map: the crew's camp is marked", "act": &"map", "target": &""},
	{"key": &"camp", "text": "Take the iron to the crew's camp", "act": &"", "target": &"camp"},
]

## The steps only an act shows, which the asker latches (a page opened).
const ACTS: Array[StringName] = [&"carry", &"survey"]

## The guide's lesson each step teaches (Guide.HINTS), retired once the step is
## done so it is never taught again over a thing already learned.
const LESSON := {
	&"driftwood": &"take", &"stones": &"take", &"wood": &"take", &"plate": &"take", &"iron": &"take",
	&"fire": &"fire", &"charcoal": &"make", &"haft": &"make", &"pick": &"make",
	&"carry": &"carry", &"survey": &"map",
}

## The goals the card stands for (Guide.last_goal_key): while the steps run, the
## goal line says nothing these do not (an empty key is the goal before her lead).
const COVERS: Array[StringName] = [&"", &"fire_gather", &"fire_lay", &"charcoal_gather", &"charcoal_set",
	&"haft", &"plate", &"pick", &"ore", &"camp"]

## The word a target is called by where the mark stands over it.
const WORD := {
	&"maren": "Maren", &"driftwood": "driftwood", &"stone": "boulder", &"tip": "scrap heap",
	&"slab": "rebar slab", &"fire": "your fire", &"camp": "the crew's camp",
}

## What each target is in the world (UiStepMark finds the nearest of them).
const TARGET_KINDS := {
	&"driftwood": [PropKind.DRIFTWOOD],
	&"stone": [PropKind.BOULDER, PropKind.STONE_ORE],
	&"tip": [PropKind.TIP],
	&"slab": [PropKind.REBAR_SLAB],
}


static func list(game: Game, done: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for s: Dictionary in STEPS:
		var row := s.duplicate()
		row.need = int(s.get("need", 0))
		row.have = mini(_have(game, s.key), row.need) if row.need > 0 else 0
		row.done = done.has(s.key) or _done_now(game, s.key)
		rows.append(row)
	# Done once any step after it is, by what he has or has done in the world:
	# a page opened early (`carry`, `survey`) says nothing of the steps before it.
	var later := false
	for i in range(rows.size() - 1, -1, -1):
		if later:
			rows[i].done = true
		later = later or (bool(rows[i].done) and not ACTS.has(rows[i].key))
	for r: Dictionary in rows:
		if r.done:
			done[r.key] = true
			r.have = r.need
	return rows


static func current(rows: Array[Dictionary]) -> int:
	for i in rows.size():
		if not rows[i].done:
			return i
	return -1


static func _have(game: Game, key: StringName) -> int:
	var inv := game.inventory
	match key:
		&"driftwood":
			return inv.count(&"driftwood")
		&"stones":
			return inv.count(&"stone")
		&"wood":
			return inv.count(&"driftwood") + inv.count(&"deadwood")
	return 0


static func _done_now(game: Game, key: StringName) -> bool:
	var inv := game.inventory
	match key:
		&"talk":
			return Story.landed(Guide.LEAD_BEAT)
		&"driftwood":
			return _his_fire(game) or inv.count(&"driftwood") >= 3
		&"stones":
			return _his_fire(game) or inv.count(&"stone") >= 2
		&"fire":
			return _his_fire(game)
		&"wood":
			# More wood is for the charcoal his fire will burn: wood in hand before
			# there is a fire is the first step's, and counted there.
			return Guide._cooking_or_has(game, &"charcoal") or (_his_fire(game) and _have(game, &"wood") >= 4)
		&"charcoal":
			return Guide._cooking_or_has(game, &"charcoal")
		&"haft":
			return inv.has(&"haft") or Guide.has_pick(inv)
		&"plate":
			return inv.count(&"scrap") > 0 or Guide.has_pick(inv)
		&"pick":
			return Guide.has_pick(inv)
		&"iron":
			return inv.has(&"rebar") or inv.has(&"iron") or _paid()
		&"camp":
			return _paid()
	# `carry` and `survey` are done by an act the asker sees (a page opened).
	return false


## A fire he laid himself: the lesson is laying one, and a village's will not
## teach it.
static func _his_fire(game: Game) -> bool:
	for q in SurvivalState.of(game).built:
		if q.kind == PropKind.FIRE and not game.world.depleted.has(q.id):
			return true
	return false


static func _paid() -> bool:
	return Story.chose(Guide.CAMP_PAID) == StringName(StoryContent.PAID[Guide.CAMP_PAID].pick)


## Where the step's target is, tile space, or INF: the nearest of its kind in
## REACH, his fire, Maren, the camp (`placed` is 49_cast's slots).
const REACH := 48.0


static func target_at(game: Game, row: Dictionary, placed: Dictionary, maren: Vector2) -> Vector2:
	var t: StringName = row.get("target", &"")
	match t:
		&"":
			return Vector2.INF
		&"maren":
			return maren
		&"fire":
			var f := Guide._fire(game)
			return f.pos if f != null else Vector2.INF
		&"camp":
			return (placed[&"the_camp"] as Dictionary).get("pos", Vector2.INF) if placed.has(&"the_camp") else Vector2.INF
	# The nearest still there to take: a picked-over boulder or a strand already
	# taken stands in the world, and pointing at it sends him to nothing.
	var kinds: Array = TARGET_KINDS.get(t, [])
	if game.query == null:
		return Vector2.INF
	var p := game.player.pos
	var best := Vector2.INF
	for q in game.query.props_near(p, REACH):
		if not kinds.has(q.kind) or q.picked or game.world.depleted.has(q.id):
			continue
		if q.pos.distance_squared_to(p) < best.distance_squared_to(p):
			best = q.pos
	return best
