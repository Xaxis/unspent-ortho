extends GameSystem
## The named people, standing where the story put them (docs/DESIGN.md).
##
## Each character in StoryCast is anchored to a spine slot (StoryPlan), cast into
## THIS world by StoryCasting, and stood a few paces off it on ground a body can
## stand on. They are drawn only while the player is near, like villagers, but they
## are not villagers: 35_folk streams bodies that nobody may count on meeting twice,
## and a named person has to be there again when he comes back. Their persistence is
## the place; their development is beats (StoryCharacter.present).
##
## 49_story reads `people` beside 35_folk's rows, so the one `use` key answers a
## named person exactly as it answers anyone else, and StoryProps.talk_for gives
## them their own words.

## How far off a named person is drawn. A little past a villager's reach, so the
## fire-keeper is standing at her fire before he is close enough to see her face.
const STREAM := 28.0
## Nearer than this, they turn to watch him come.
const WATCH := 6.0
## How often who is there is asked again: beats land on the scale of a conversation,
## never a frame.
const RECHECK := 0.5

## One row per placed character: {character, pos, facing, state, trade, model,
## made}. The shape 49_story already reads for a villager, plus `character`;
## `model` is the figure while it stands in the world (null while they are away),
## `made` the figure itself, built once when they are cast.
var people: Array[Dictionary] = []

var _since := 0.0


func setup(g: Game) -> void:
	game = g


func started() -> void:
	_cast()


## Through a door: the outside is kept as it stood (20_realms says why).
func indoors(inside: bool) -> void:
	sleep_indoors(inside)


func realm_changed(_from: StringName, _to: StringName) -> void:
	_cast()


func _exit_tree() -> void:
	_clear()


func _process(delta: float) -> void:
	if game == null or game.world == null or game.player == null:
		return
	_since += delta
	var from: Vector2 = game.player.pos
	# BETWEEN CHECKS THERE IS NOTHING TO DECIDE, and asking anyway was 8.1 ms in
	# the worst frame of a walking run. `RECHECK` (0.5 s) is the declaration that
	# streaming a character in or out is a twice-a-second question; the old loop
	# still paid `StoryCast.get_def` and `present()` for every character EVERY
	# frame to compute `here`, then threw the answer away unless the timer had
	# come round. At 17 cast and 120 fps that is ~2,000 `present()` calls a second
	# -- each one through `StoryPacing.felt` and `Story.landed` -- to answer a
	# question worth asking twice.
	#
	# So the cheap frame does only what must be true every frame: a dressed
	# figure stands where they stand and faces what they face. Whether they
	# SHOULD be dressed is settled below, on the timer that exists to settle it.
	# Same bug as `Chapters.of` read per frame per hold (#122), in a second file.
	if _since < RECHECK:
		for row: Dictionary in people:
			if row.model != null:
				_watch(row, from)
		return
	_since = 0.0
	for row: Dictionary in people:
		var c := StoryCast.get_def(row.character)
		var here: bool = (row.pos as Vector2).distance_to(from) <= STREAM and (c == null or c.present())
		if here and row.model == null and row.made != null:
			add_child(row.made)
			row.model = row.made
		elif not here and row.model != null:
			remove_child(row.model)
			row.model = null
		_watch(row, from)


## Where each character stands in this world. Recomputed, never saved: the world
## grows the same from its seed, so the casting does too.
func _cast() -> void:
	_clear()
	if game == null or game.world == null:
		return
	var placed := StoryPlan.cast(game.world)
	for c: StoryCharacter in StoryCast.all():
		if not placed.has(c.at):
			continue
		var at: Vector2 = placed[c.at].pos
		var pos := _stand_near(at, c.id)
		var row := {
			"character": c.id, "pos": pos, "facing": (at - pos).angle(),
			"state": &"out", "trade": c.trade, "model": null, "made": null,
		}
		# THE FIGURE IS MADE HERE, WITH THE WORLD, and not the moment he walks up:
		# a person's rig is 19 ms to build, and building it on the frame they came
		# into reach was the worst frame of a shoulder walk (49_cast 24.6 ms,
		# 2026-09-26). Walking up now only puts the made figure in the tree.
		_dress(row, c)
		people.append(row)


func _clear() -> void:
	for row: Dictionary in people:
		if row.made != null and is_instance_valid(row.made):
			(row.made as Node).queue_free()
	people.clear()


## A standable tile a few paces off the slot, at a bearing of their own, and
## never within APART of somebody already cast, so two people cast at one place
## do not stand in each other — and out of reach of anything with words on it,
## or the one `use` key reads the post beside them instead of speaking to them (a
## works yard is full of the plan's terminals). THE FALLBACK HONOURS APART TOO:
## at the Holdfast's camp every spot is near a terminal, the fallback was the
## first standable tile off the slot, and Vera, Sabine and Teague all stood on
## the same one, so `use` at Vera opened whoever the list met first.
func _stand_near(at: Vector2, id: StringName) -> Vector2:
	var turn := Rng.hash01(game.world.seed_value, absi(int(id.hash())), 0, 0xCA57) * TAU
	# Where nowhere near is clear (a stand of scrap trees), the clearest spot:
	# the one whose nearest thing the hand takes from is furthest off.
	var fallback := Vector2.INF
	var fallback_clear := -INF
	for r: float in [2.5, 3.5, 1.5, 4.5, 5.5, 6.5, 8.0]:
		for i in 12:
			var p := at + Vector2.from_angle(turn + TAU * i / 12.0) * r
			# Dry ground: the shallows are standable, and a named person waiting
			# knee-deep in the sea off their own camp is nobody's idea of waiting.
			if not game.query.standable(floori(p.x), floori(p.y)) or Ground.is_water(game.world.ground_at(floori(p.x), floori(p.y))):
				continue
			var spot := Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)
			if _taken(spot):
				continue
			if not _near_words(spot):
				return spot
			var clear := _clearance(spot)
			if clear > fallback_clear:
				fallback_clear = clear
				fallback = spot
	return fallback if fallback != Vector2.INF else at


## How far the nearest thing with words, or that the hand takes from, is from
## `p` (edge to edge).
func _clearance(p: Vector2) -> float:
	var best := INF
	for q: WorldProp in game.query.props_near(p, StoryProps.REACH + 2.0):
		if (StoryProps.readable(q.kind) or Takes.workable(q.kind)) and not game.world.depleted.has(q.id):
			best = minf(best, q.pos.distance_to(p) - q.solid)
	return best


## How far apart two cast people stand at the least: more than a tile, so the key
## can be put nearer one of them than any other (StoryProps.CLOSE).
const APART := 1.9


func _taken(spot: Vector2) -> bool:
	for row: Dictionary in people:
		if (row.pos as Vector2).distance_to(spot) < APART:
			return true
	return false


## Whether a thing somebody could read stands within the key's reach of `p`, or
## a thing the hand takes from stands within the hand's (Survival.REACH): either
## would answer `use` before the person standing there (49_story
## `_open_what_is_in_front`). Sefa, cast in a stand of scrap trees at the
## Tether's foot, could only ever be asked for a turn of the tree beside her.
func _near_words(p: Vector2) -> bool:
	for q: WorldProp in game.query.props_near(p, StoryProps.REACH + 2.0):
		var edge := q.pos.distance_to(p) - q.solid
		if StoryProps.readable(q.kind) and edge <= StoryProps.REACH:
			return true
		if Takes.workable(q.kind) and not game.world.depleted.has(q.id) and edge <= Survival.REACH + 0.6:
			return true
	return false


func _dress(row: Dictionary, c: StoryCharacter) -> void:
	if c == null:
		return
	var seed_v := absi(int(c.id.hash()))
	var look := PersonLook.random(seed_v)
	for k: Variant in c.look:
		look[k] = c.look[k]
	var hazards := BiomeRegistry.at(game.world, row.pos).hazards
	look = PersonLook.dress(look, hazards, c.trade, seed_v)
	# What the writer said about how they look outlasts what their trade dressed.
	for k: Variant in c.look:
		look[k] = c.look[k]
	var model := PersonModel.make(look, &"", game.view.world_material() if game.view != null else null)
	model.pose_hz = PersonModel.CROWD_HZ
	model.sun = game.sky.sun if game.sky != null else null
	model.name = "cast_%s" % c.id
	row.made = model


func _watch(row: Dictionary, from: Vector2) -> void:
	var model: PersonModel = row.model
	if model == null:
		return
	var to := from - (row.pos as Vector2)
	if to.length() <= WATCH and to.length() > 0.01:
		row.facing = to.angle()
	model.position = game.world.to_3d(row.pos)
	model.rotation.y = -float(row.facing)


## `at cast:ID` in a tour: a spot beside that person, close enough that the `use`
## key reaches them whichever way the player is turned (StoryProps.CLOSE), and
## nearer them than any other named person. The key answers the nearest of the
## cast (49_story `_person_in_front`), and the Holdfast's camp stands several of
## them in one yard: a spot on Vera's far side was nearer Sabine, so `use` opened
## the medic's words and `met:vera` never came.
func tour_place(what: String) -> Vector2:
	if not what.begins_with("cast:"):
		return Vector2.INF
	var id := StringName(what.substr(5))
	for row: Dictionary in people:
		if row.character != id:
			continue
		var pos: Vector2 = row.pos
		var fallback := Vector2.INF
		for r: float in [1.0, 1.2, 0.8, 1.4]:
			for i in 12:
				var p := pos + Vector2.from_angle(TAU * i / 12.0) * r
				if not game.query.standable(floori(p.x), floori(p.y)):
					continue
				if fallback == Vector2.INF:
					fallback = p
				if _nearest_named(p) == id and not _hands_full(p, pos):
					return p
		return fallback if fallback != Vector2.INF else pos
	return Vector2.INF


## Whether something the hand takes from (Survival.use_target: a scrap tree, a
## log) stands nearer `p` than the person at `them`, so `use` there works it
## instead of speaking to them. Sefa at the Tether's foot stands in a stand of
## scrap trees.
func _hands_full(p: Vector2, them: Vector2) -> bool:
	var d := p.distance_to(them)
	for q: WorldProp in game.query.props_near(p, Survival.REACH + 2.0):
		if Takes.workable(q.kind) and not game.world.depleted.has(q.id) and q.pos.distance_to(p) - q.solid <= d:
			return true
	return false


func _nearest_named(p: Vector2) -> StringName:
	var best := &""
	var best_d := INF
	for row: Dictionary in people:
		var d := (row.pos as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best = row.character
	return best


## `cast:ID`: that person is there and drawn. `met:ID`: he has spoken to them.
func tour_seen(what: StringName) -> bool:
	var s := String(what)
	if s.begins_with("met:"):
		return Story.met(StringName(s.substr(4)))
	if s.begins_with("cast:"):
		var id := StringName(s.substr(5))
		for row: Dictionary in people:
			if row.character == id and row.model != null:
				return true
	return false
