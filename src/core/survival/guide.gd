class_name Guide
## The first hour's guide, as pure rules over a running game: the one-line
## goal (what to want next) and the key hints, each with the moment it applies
## and the use that retires it. The guide system (58_guide) says them on the
## teaching channel (`Events.hint`), which is dropped rather than queued: a
## lesson is said in its moment or not at all, so 58_guide says nothing while
## the glass is hushed, and holds a lesson whose moment is "the fight is over"
## until it lifts. The slate shows `goal` standing on the HUD and the hint on
## its key row (90_ui).
##
##   goal(game) -> String                     the want now: a fire, charcoal, a haft, plate, a pick,
##                                            food, light; or the ore once there is a pick;
##                                            then the next elite material and where it is
##   hint_for(game, retired) -> Dictionary    the first hint that applies and is not retired:
##                                            {id: StringName, line: String, keys: Array} or {}
##   HINTS                                    id -> [line template, action names] for every hint
##
## Hints retire on use (58_guide marks them): walk (moved), take (took), fire
## (a fire made), make (something made at a station), carry (the carrying page
## opened), dodge (a dodge), side (a blow reached a working part), lamp (lit),
## runner/worker (said once when one is first in view).

## The four that are one lesson: shown joined, so they read as "WASD" while they
## are W, A, S and D and as whatever they become if somebody rebinds them.
const MOVE: Array[StringName] = [&"move_up", &"move_left", &"move_down", &"move_right"]

## id -> [line, actions]. The line carries `%s` where a KEY belongs and the
## actions say which, in order; a line with no `%s` still names its action so the
## slate's key row has something to draw.
##
## **THE KEY IS NAMED, NEVER SPELLED.** These lines used to carry the letters:
## "E takes what is in front of you", with "e" beside it for the key row. A
## player may rebind every action on the settings page, and `PlayerSettings` is
## careful that a PAGE can never drift from the live `InputMap` -- and then the
## first thing the game ever teaches them said E while their key was Q, in the
## first hour, to somebody with no way of knowing which to believe. The one place
## a lie like that costs the most is the one place it was.
const HINTS := {
	&"walk": ["%s walks, %s runs.", [MOVE, &"run"]],
	&"take": ["%s takes what is in front of you.", [&"use"]],
	&"fire": ["%s twice on open ground lays a fire.", [&"use"]],
	&"make": ["%s makes things at the fire. Long work cooks while you go.", [&"craft"]],
	&"carry": ["%s shows what you carry. Leave what you do not need.", [&"inventory"]],
	&"lamp": ["Night. %s lights the lamp.", [&"lamp"]],
	# **THE CORE VERB OF AN ACTION GAME, AND IT WAS NEVER NAMED.** `side` is the
	# only lesson that carries `swing`, it is the HELD lesson delivered after
	# plate has already rung, and its words ("strike the side that is lit")
	# assume you have been striking all along. Nothing anywhere told you which
	# key does it. Said as a machine comes on, ahead of the dodge, because a
	# player who cannot strike cannot end the fight they are being taught to
	# survive.
	&"fight": ["%s swings what is in your hands. Wait out its blow, then answer.", [&"swing"]],
	&"dodge": ["It winds up before it strikes: %s gets you out of the way.", [&"dodge"]],
	# **THE VERB THE GAME NEVER TAUGHT.** A player can press 27 things and the
	# guide named 11 of them; targeting was one of the sixteen it did not, which
	# means the whole read -- what a machine is, what it is doing, where its
	# plate is thin, whether it has noticed you -- was reachable only by somebody
	# who pressed an unmentioned key. Taught when the first machine is in view,
	# ahead of the lines that describe a runner and a worker, because it is how
	# you would find those out for yourself.
	&"target": ["%s holds the slate on it: what it is, what it is doing, where its plate is thin.", [&"target"]],
	# The other verb nobody was told about, and this one is INNATE: no gear
	# grants it and nothing takes it away, so a player who never learns it is
	# walking round ledges the game meant them to go over. Said standing at one,
	# because a movement lesson given on flat ground is a sentence about nothing.
	&"jump": ["%s clears it: up two, across two, down three, and no further.", [&"jump"]],
	# The third of the sixteen, and the one the world's own size argues for: a
	# 1300-tile island is not a place you hold in your head. Said once the wake
	# is out of sight behind you, because a survey of ground you can see is a
	# picture of nothing.
	&"map": ["%s opens the survey: where you have walked, and what the machines have been doing to it.", [&"map"]],
	# The fourth, and the pair to `target`: you have learned to look at a machine,
	# now learn not to be looked at. Said with one in view that has NOT noticed
	# you, because that is the only moment crouching is a choice rather than a
	# regret.
	&"crouch": ["%s keeps you low and quiet. It has not seen you yet.", [&"crouch"]],
	# The fifth, and a whole pillar of the game nobody was told about (VISION
	# §9): a player can put a place up, keep it, and have the machines come for
	# it. Said the first time the creel actually holds enough for a piece --
	# before that it is an advertisement, and after the first piece goes up it
	# has taught itself.
	&"holding": ["%s puts a piece up out of the creel. What you build, the plan eventually hears.", [&"holding"]],
	# **THE SIXTH, AND THE WHOLE GEAR PILLAR WAS BEHIND AN UNMENTIONED KEY.**
	# Fitting a wing or a line or a stolen lens grants an ACTION, and nothing in
	# the game ever named it -- the same gap `target` was, and worse, because a
	# player went and found the piece, chose it, put it in a slot, and still had
	# no way to know what to press. One lesson per ability rather than one about
	# abilities: each names its own key and says what that key is FOR, because
	# "you have an ability" teaches nobody anything.
	&"ability_dash": ["%s throws you clear of what is coming. It costs breath.", [&"ability_dash"]],
	&"ability_glide": ["%s opens the wing. Step off something high and ride it down.", [&"ability_glide"]],
	&"ability_scan": ["%s reads every working part near you, and what each machine makes of you.", [&"ability_scan"]],
	&"ability_grapple": ["%s throws a line at what you face and pulls you to it, ledges included.", [&"ability_grapple"]],
	&"ability_spoof": ["%s answers their challenge in their own language. They read you as one of theirs.", [&"ability_spoof"]],
	# The seventh, and the only app the guide never named. Everything found is
	# already being written down -- pages read, beats landed, answers given -- and
	# a player who is never told carries the whole story in their head or loses
	# it. Offered only once there IS something in it: a lesson that opens an
	# empty book teaches that the book is empty.
	&"journal": ["%s opens what you have found: what you read, what you were told, what you said back.", [&"journal"]],
	# **THE SAFE HAVEN, SAID WHEN YOU ARE STANDING IN ONE** (owner: "the game
	# needs guided narratives to start it, safe havens like towns to
	# systematically teach players the game"). The ground round a village really
	# is the safest in the game -- sixteen of nineteen roster rows keep a
	# `green_min` off it, which `Haven` writes down and a test holds -- and
	# nothing ever told the player so. A safety the player cannot know about
	# buys them nothing.
	&"haven": ["People live here, and nothing of the plan comes this close. Rest, make, and ask them things.", []],
	# **WHAT THE ROAD OUT WILL ASK FOR** (docs/DESIGN.md §Safe havens: "each haven
	# teaches what the road out of it will ask for"). The plan stands on the road
	# out of an unanswered chapter, and VISION §10.3 is emphatic that this is not
	# a lock -- there are three ways past and all three are real. A player who is
	# told none of them meets a barricade and reads it as a wall, which is the
	# message saying no that §10.3 forbids, wearing a model.
	&"road": ["The plan is standing on the road out. Cut it with a steel edge (%s), answer the place, or leave the road.", [&"use"]],
	&"side": ["Plate rings. Strike the side that is lit, while it is spent.", [&"swing"]],
	&"runner": ["A runner. It hunts. Its drive is at its back: let it bite past you, then strike behind.", []],
	&"worker": ["A worker on its round. Keep out of its path and it leaves you be.", []],
}

## Load over this share of the creel asks for the carrying page.
const CARRY_SHARE := 0.6
## Nightfall past which the lamp is asked for.
const LAMP_NIGHTFALL := 0.4
## Tiles within which a body counts as seen for its hint (the camera shows about 13 across).
const SIGHT := 13.0

## How far from the wake the survey earns itself. The camera shows about 27
## tiles of ground, so this is a little over two screens: far enough that the way
## back is no longer a thing you can see, which is the first moment a map is
## worth opening rather than a picture of what is already in front of you.
const MAP_FAR := 60.0

## How near a held road has to be before it is worth naming. A little over twice
## what the camera shows, so the lesson lands while walking toward the barricade
## rather than when it is already filling the frame and reading as a wall.
const ROAD_NEAR := 60.0


static func goal(game: Game) -> String:
	var inv := game.inventory
	var now := game.clock.minutes
	if game.body.hunger_level(now) >= 2:
		return "Eat something: mussels off the rocks, or berries."
	if FightRules.nightfall(game.clock.hour()) >= LAMP_NIGHTFALL and not game.body.lamp_lit and inv.has(&"lamp"):
		return "Light the lamp against the dark."
	if inv.has(&"pick"):
		if not inv.has(&"iron_ore") and not inv.has(&"iron"):
			return "Take the pick to the ore in the rock."
		# Past the first tools, the long game: the next elite material, and where
		# -- and a part a room keeps, once the material it follows is held.
		var part := next_part(game)
		if part != &"":
			return part_goal(part)
		var want := next_elite(game)
		if want != &"":
			return elite_goal(game, want)
		return "Take the pick to the ore in the rock."
	var fire := _fire(game)
	if fire == null:
		if Survival._makeable_build(game, &"fire").is_empty():
			return "A fire before dark: three driftwood and two stones."
		return "A fire before dark: lay it on open ground."
	var at := fire_name(game, fire)
	if not _cooking_or_has(game, &"charcoal"):
		if inv.count(&"driftwood") < 4 and inv.count(&"deadwood") < 4:
			return "Charcoal for a pick: four driftwood or dead wood, burnt at %s." % at
		# **NO KEY IN A GOAL LINE.** This said "(c)" -- a letter typed into CORE,
		# which this file states two screens down may not read a key at all, and
		# which is wrong for anybody who rebinds `craft`. The goal says what to
		# WANT; the `make` lesson says which key, in the player's own keys, and
		# it is offered at exactly this moment.
		return "Charcoal for a pick: set it going at %s." % at
	if not inv.has(&"haft"):
		return "A haft, whittled from wood."
	if inv.count(&"scrap") == 0:
		return "Plate for a pick: turn over the tip."
	return "A pick, made at %s." % at


## The elite material wanted next (EliteStock): the first the bag holds none of
## that the world has a way to (Sources.reachable), and of those, one the land
## underfoot gives before any other, so the long game starts where the player
## stands. &"" once every one has been held.
static func next_elite(game: Game) -> StringName:
	var here := _land_here(game)
	var first := &""
	for id: Variant in EliteStock.ids():
		var sid := StringName(id)
		if game.inventory.has(sid) or not Sources.reachable(sid):
			continue
		if _elite_lands(sid).has(here):
			return sid
		if first == &"":
			first = sid
	return first


## THE PARTS A ROOM KEEPS, in the long game: a thing kept in one kind of room
## (Interiors.LOOT), wanted once the elite material it `follows` is held -- the
## burning's glass first, then what the burning's foundry casts, which is what a
## cast lance is built on (recipes `lance_cast`).
const PARTS := {
	&"lance_casting": {"room": &"foundry", "follows": &"cinder_glass"},
}


## The part wanted next: one the bag lacks whose material it holds. &"" for none.
static func next_part(game: Game) -> StringName:
	for id: Variant in PARTS:
		var row: Dictionary = PARTS[id]
		if not game.inventory.has(StringName(id)) and game.inventory.has(StringName(row.follows)):
			return StringName(id)
	return &""


## Where a part is kept, said as the long game's goals say it: "Lance casting:
## kept in the foundry, in the burning."
static func part_goal(id: StringName) -> String:
	var row: Dictionary = PARTS[id]
	var name := String(Items.def(id).get("name", String(id).replace("_", " ")))
	var lands := Interiors.lands_of(StringName(row.room))
	var where := ", %s" % _land_said(lands[0]) if not lands.is_empty() else ""
	return "%s: kept in the %s%s." % [name.left(1).to_upper() + name.substr(1), String(row.room).replace("_", " "), where]


## The landscapes an elite material comes from: its own, or the lands its one
## machine keeps to.
static func _elite_lands(id: StringName) -> Array[StringName]:
	var land := EliteStock.land_of(id)
	if land != &"":
		return [land] as Array[StringName]
	var kind := EliteStock.kind_of(id)
	return Sources.lands_of_kind(kind) if kind != &"" else [] as Array[StringName]


static func _land_here(game: Game) -> StringName:
	var p: Vector2 = game.player.pos if game.player != null else game.world.spawn
	return BiomeRegistry.by_index(game.world.country_at(floori(p.x), floori(p.y))).id


## The late goal's words: what it is, how it is had, and where. One line on
## the glass's goal window, which stands left of the place name at the top, so
## it is kept to the length of the first hour's goals and says no more.
static func elite_goal(game: Game, id: StringName) -> String:
	var def := EliteStock.material(id)
	var name := String(Items.def(id).get("name", String(id).replace("_", " ")))
	# Where: here, if the land underfoot gives it; else the first land that does.
	var all := _elite_lands(id)
	var here := _land_here(game)
	var where := ""
	if all.has(here):
		where = "here %s" % _land_said(here)
	elif not all.is_empty():
		where = _land_said(all[0])
	var kind := EliteStock.kind_of(id)
	var how := ""
	if kind != &"":
		how = "cut out of a %s, %s" % [String(kind).replace(".", " "), where]
	else:
		how = "%s at a %s, %s" % [String(def.get("raw", "")).replace("_", " "), String(def.get("at", "fire")), where]
	return "%s: %s." % [name.left(1).to_upper() + name.substr(1), how.strip_edges()]


## A landscape as the goal says someone is in it: its own words (BiomeDef.spoken_in).
static func _land_said(id: StringName) -> String:
	var b := BiomeRegistry.get_def(id)
	return b.spoken_in if b != null and b.spoken_in != "" else "in the %s" % String(id).replace("_", " ")


## The first lesson that fits and has not been spent. `keyed_only` asks for the
## first that NAMES A KEY, which is what the slate's key row wants: several
## lessons carry no key of their own (`runner`, `worker`, `haven` -- they are
## things to know, not things to press), and the row is drawn from whatever this
## answers, so a keyless lesson standing at the front of the list blanked the row
## until the guide got round to saying it. Two different questions, one door.
static func hint_for(game: Game, retired: Dictionary, keyed_only := false) -> Dictionary:
	for id: StringName in _applicable(game):
		if keyed_only and (HINTS[id][1] as Array).is_empty():
			continue
		if not retired.has(id):
			# The line is a TEMPLATE and the actions are names: whoever says it
			# resolves them against the live keys (58_guide), because a key label
			# is the settings package's to answer and core does not read it.
			return {"id": id, "line": HINTS[id][0], "keys": HINTS[id][1]}
	return {}


## The hints that fit the moment, most pressing first.
## Whether the plan is standing on a road the player could walk to from here.
## Asked of whoever KEEPS the holds rather than derived again: `RoadHold.sites`
## walks every road in the world, and a lesson is not worth that on any frame.
static func _road_is_held(game: Game) -> bool:
	if game == null or game.player == null:
		return false
	for sys in game.systems:
		if sys.has_method(&"held_road_near"):
			return bool(sys.call(&"held_road_near", game.player.pos, ROAD_NEAR))
	return false


## The gear system's ability book, found BY WHAT IT KEEPS and never by its name
## -- the idiom `Chapters` uses, and the reason renumbering a system file has
## never broken anything. Null in a fixture with no systems, which is correct:
## nothing has been fitted there.
static func ability_book(game: Game) -> AbilityBook:
	if game == null:
		return null
	for sys: GameSystem in game.systems:
		var book: Variant = sys.get(&"book")
		if book is AbilityBook:
			return book
	return null


## Every ability the GEAR has granted -- innate ones left out, because the jump
## has its own lesson and is not a thing the player chose.
static func granted(game: Game) -> Array[StringName]:
	var out: Array[StringName] = []
	var book := ability_book(game)
	if book == null:
		return out
	for id: StringName in book.fitted:
		if not Abilities.INNATE.has(id):
			out.append(id)
	return out


## Whether anything has been written down yet: a page read, a beat landed, or an
## answer given. The journal only ever READS what already happened, so this asks
## `Story` -- who WROTE IT DOWN -- rather than looking for evidence in the live
## world, which is the rule this file's own lessons are built on.
static func _journal_holds_something() -> bool:
	return Story.found_count() > 0 or not Story.landed_beats().is_empty() or not Story.choices().is_empty()


## Whether the creel holds enough for any piece somebody has learnt to build.
## Asked of `SettlementBuild.can_make`, which is the same question the holding
## page answers, so the lesson cannot offer a key that would refuse.
static func _can_build(game: Game) -> bool:
	if game.inventory == null:
		return false
	for kind: int in StructureKind.BUILDABLE:
		if SettlementBuild.can_make(game.inventory, kind):
			return true
	return false


## Whether a jump from where the player stands, the way they face, would CLEAR
## something -- a ledge up or a gap across. Asked of `Jump.plan`, which works the
## whole arc out, so the lesson cannot promise a jump the body could not make:
## the same answer the key itself will give when it is pressed.
static func _at_a_ledge(game: Game) -> bool:
	var sim := game.player.sim if game.player != null else null
	if sim == null or game.query == null or sim.hero.airborne:
		return false
	# `Jump.CARRY`, which is the speed `Jump.find` plans at -- the game's own
	# idea of a jump taken at a walk. Planning at a STANDING speed instead was
	# the first version and it answered "hop" at ledges the finder calls a
	# climb, so the lesson was never said anywhere: the moment and the thing
	# that defines a ledge have to ask the same question.
	var p := Jump.plan(game.world, game.query, sim.hero.pos,
		Vector2.from_angle(sim.hero.facing), Jump.CARRY)
	return p != null and (p.kind == Jump.UP or p.kind == Jump.ACROSS)


static func _applicable(game: Game) -> Array[StringName]:
	var out: Array[StringName] = []
	var sim := game.player.sim if game.player != null else null
	if sim != null:
		for m in sim.mobs:
			if not m.alive or m.removed:
				continue
			# Said as a hunter first comes on, before it is close enough to hush the page
			# (a line said in a fight waits until it is over, out of its moment).
			if m.machine and not m.indifferent() and m.roused() and Senses.chebyshev(m.pos, sim.hero.pos) > Survival.THREAT_RADIUS:
				out.append(&"fight")
				out.append(&"dodge")
			var seen := m.pos.distance_to(sim.hero.pos) <= SIGHT
			if seen and m.machine:
				out.append(&"target")
			if seen and m.machine and not m.roused() and not game.body.crouched:
				out.append(&"crouch")
			if seen and m.first_meeting and not m.roused():
				out.append(&"runner")
			if seen and m.patrol and m.indifferent():
				out.append(&"worker")
	if FightRules.nightfall(game.clock.hour()) >= LAMP_NIGHTFALL and not game.body.lamp_lit and game.inventory.has(&"lamp"):
		out.append(&"lamp")
	if game.inventory.bulk() > game.inventory.creel() * CARRY_SHARE:
		out.append(&"carry")
	for id: StringName in granted(game):
		out.append(StringName("ability_%s" % id))
	if _can_build(game):
		out.append(&"holding")
	if game.world != null and game.player != null and Haven.holds(game.world, game.player.pos):
		out.append(&"haven")
	if _road_is_held(game):
		out.append(&"road")
	if _journal_holds_something():
		out.append(&"journal")
	if game.world != null and game.player != null \
			and game.player.pos.distance_to(game.world.spawn) > MAP_FAR:
		out.append(&"map")
	if _at_a_ledge(game):
		out.append(&"jump")
	if Survival.use_target(game) != null:
		out.append(&"take")
	if _fire(game) == null and not Survival._makeable_build(game, &"fire").is_empty():
		out.append(&"fire")
	if Survival.station_near(game) != &"":
		out.append(&"make")
	out.append(&"walk")
	return out


## The fire the goal means: the nearest of the fires the player built and any
## fire within FIRE_NEAR tiles (a village's), or null.
const FIRE_NEAR := 12.0


static func _fire(game: Game) -> WorldProp:
	var best := Survival.fire_near(game, FIRE_NEAR)
	var p := game.player.pos
	for q in SurvivalState.of(game).built:
		if q.kind != PropKind.FIRE or game.world.depleted.has(q.id):
			continue
		if best == null or q.pos.distance_to(p) < best.pos.distance_to(p):
			best = q
	return best


## Where the goal sends the player, by name: "the village fire" (a fire in a
## village), "your fire" (one the player laid), else "the fire".
static func fire_name(game: Game, fire: WorldProp) -> String:
	if fire == null:
		return "a fire"
	if Haven.holds(game.world, fire.pos):
		return "the village fire"
	if SurvivalState.of(game).built.has(fire):
		return "your fire"
	return "the fire"


static func _cooking_or_has(game: Game, id: StringName) -> bool:
	if game.inventory.has(id):
		return true
	for job in Survival.cooking(game):
		if (job.makes as Dictionary).has(id):
			return true
	return false
