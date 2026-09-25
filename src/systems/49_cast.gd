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

## One row per placed character: {character, pos, facing, state, trade, model}.
## The shape 49_story already reads for a villager, plus `character`.
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
		if here and row.model == null:
			_dress(row, c)
		elif not here and row.model != null:
			(row.model as Node).queue_free()
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
		people.append({
			"character": c.id, "pos": pos, "facing": (at - pos).angle(),
			"state": &"out", "trade": c.trade, "model": null,
		})


func _clear() -> void:
	for row: Dictionary in people:
		if row.model != null and is_instance_valid(row.model):
			(row.model as Node).queue_free()
	people.clear()


## A standable tile a few paces off the slot, at a bearing of their own, so two
## people cast at one place do not stand in each other — and out of reach of
## anything with words on it, or the one `use` key reads the post beside them
## instead of speaking to them (a works yard is full of the plan's terminals).
func _stand_near(at: Vector2, id: StringName) -> Vector2:
	var turn := Rng.hash01(game.world.seed_value, absi(int(id.hash())), 0, 0xCA57) * TAU
	var fallback := Vector2.INF
	for r: float in [2.5, 3.5, 1.5, 4.5, 5.5, 6.5, 8.0]:
		for i in 12:
			var p := at + Vector2.from_angle(turn + TAU * i / 12.0) * r
			if not game.query.standable(floori(p.x), floori(p.y)):
				continue
			var spot := Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)
			if fallback == Vector2.INF and r <= 4.5:
				fallback = spot
			if not _near_words(spot):
				return spot
	return fallback if fallback != Vector2.INF else at


## Whether a thing somebody could read stands within the key's reach of `p`.
func _near_words(p: Vector2) -> bool:
	for q: WorldProp in game.query.props_near(p, StoryProps.REACH + 2.0):
		if StoryProps.readable(q.kind) and q.pos.distance_to(p) - q.solid <= StoryProps.REACH:
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
	add_child(model)
	row.model = model


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
## key reaches them whichever way the player is turned (StoryProps.CLOSE).
func tour_place(what: String) -> Vector2:
	if not what.begins_with("cast:"):
		return Vector2.INF
	var id := StringName(what.substr(5))
	for row: Dictionary in people:
		if row.character != id:
			continue
		var pos: Vector2 = row.pos
		for i in 12:
			var p := pos + Vector2.from_angle(TAU * i / 12.0) * 1.2
			if game.query.standable(floori(p.x), floori(p.y)):
				return p
		return pos
	return Vector2.INF


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
