extends GameSystem
## People in the villages, and the player's own figure kept in step with what
## they carry. Villagers are costume, not yet characters (M2 gives them work and
## talk): they stand at their doors, work at the nearest tree or rock, walk the
## square, and turn their heads to watch you pass.
##
## Also the shot flags for people (parsed here so no shared file changes):
##   --held=ID            put ID in the player's hand (added to the inventory)
##   --look=TOKENS        the player's look: comma list of build/hat/coat/hair/beard/
##                        salvage names, or seed:N for a generated person
##   --act=NAME[:T]       player plays NAME on a loop, or frozen T seconds in
##   --face=DEG           player facing in degrees (0 east, 90 south)
##   --folk=N             N villagers in a ring around the player, for crowd shots

const NEAR := 34.0
const FAR := 46.0
const PER_VILLAGE := 6
const TREES: Array[int] = [PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.SNOW_PINE]
const ROCKS: Array[int] = [PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE]
const GREEN: Array[int] = [PropKind.REEDS, PropKind.BUSH, PropKind.GORSE]

## One villager: {model, pos, home, role, target, facing, t, wait, work, tool}.
var folk: Array[Dictionary] = []
var _spawned: Dictionary = {} # village index -> true
var _act := &""
var _act_at := -1.0
var _check := 0.0


func setup(g: Game) -> void:
	super.setup(g)
	name = "folk"
	_player_flags()
	if game.inventory != null:
		game.inventory.changed.connect(_sync_held)
	_sync_held()
	var ring := int(_arg("folk", "0"))
	if ring > 0:
		_ring(ring)
	_stream(true)


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.trim_prefix("--" + key + "=")
	return fallback


func _player_model() -> PersonModel:
	if game.player == null:
		return null
	return game.player.get("model") as PersonModel


func _sync_held() -> void:
	var m := _player_model()
	if m != null and game.inventory != null:
		m.set_held(game.inventory.held)


func _player_flags() -> void:
	var m := _player_model()
	var held := _arg("held", "")
	if held != "" and game.inventory != null:
		game.inventory.add(StringName(held))
		game.inventory.set_held(StringName(held))
	var look := _arg("look", "")
	if look != "" and m != null:
		m.set_look(parse_look(look, game.options.seed_value if game.options != null else 1))
	var face := _arg("face", "")
	if face != "" and game.player != null:
		game.player.facing = deg_to_rad(face.to_float())
		if m != null:
			m.rotation.y = -game.player.facing
	var act := _arg("act", "")
	if act != "" and m != null:
		var parts := act.split(":")
		_act = StringName(parts[0])
		_act_at = parts[1].to_float() if parts.size() > 1 else -1.0
		if _act_at >= 0.0:
			m.pose_at(_act, _act_at)
		else:
			m.play_action(_act, 0.0)


## "heavy,cap,long,plate" or "seed:12" into a look spec.
static func parse_look(text: String, seed_value: int) -> Dictionary:
	if text.begins_with("seed:"):
		return PersonLook.random(seed_value, text.trim_prefix("seed:").to_int())
	var spec := {}
	var salvage: Array = []
	var extras: Array = []
	for tok: String in text.split(",", false):
		var s := StringName(tok)
		if PersonLook.BUILDS.has(s): spec.build = s
		elif PersonLook.HATS.has(s): spec.hat = s
		elif PersonLook.COATS.has(s): spec.coat = s
		elif PersonLook.HAIR_STYLES.has(s): spec.hair_style = s
		elif PersonLook.BEARDS.has(s): spec.beard = s
		elif PersonLook.SHIRT_CUTS.has(s): spec.shirt_cut = s
		elif PersonLook.SALVAGE.has(s): salvage.append(s)
		elif PersonLook.EXTRAS.has(s): extras.append(s)
		elif PersonLook.HAIR.has(s): spec.hair = s
	if not salvage.is_empty():
		spec.salvage = salvage
	if not extras.is_empty():
		spec.extras = extras
	return spec


func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	var m := _player_model()
	if m != null and _act != &"" and _act_at < 0.0 and not m.busy():
		m.play_action(_act, 0.0)
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_stream(false)
	var hour := game.clock.hour() if game.clock != null else 12.0
	var night := hour < 5.5 or hour > 22.0
	for f in folk:
		_step(f, delta, night)


# ---------------------------------------------------------------- streaming

func _stream(now: bool) -> void:
	var at: Vector2 = game.player.pos
	for i in game.world.villages.size():
		var v: Dictionary = game.world.villages[i]
		var vp: Vector2 = v.get("pos", Vector2(-9999, -9999))
		var d := vp.distance_to(at)
		if d < NEAR and not _spawned.has(i):
			_spawned[i] = true
			_populate(i, vp)
		elif d > FAR and _spawned.has(i):
			_spawned.erase(i)
			for f: Dictionary in folk.duplicate():
				if f.get("village", -1) == i:
					(f.model as Node).queue_free()
					folk.erase(f)


func _populate(index: int, centre: Vector2) -> void:
	var w := game.world
	var houses: Array[WorldProp] = []
	for p in game.query.props_near(centre, 12.0):
		if p.kind == PropKind.HOUSE:
			houses.append(p)
	var looks := PersonLook.crowd(w.seed_value * 31 + index * 977, PER_VILLAGE)
	for n in looks.size():
		var h := Rng.hash01(w.seed_value, index, n, 71)
		var home := centre + Vector2(Rng.hash01(w.seed_value, index, n, 72) - 0.5, Rng.hash01(w.seed_value, index, n, 73) - 0.5) * 8.0
		if not houses.is_empty():
			var house := houses[n % houses.size()]
			home = house.pos + Vector2(sin(house.rot), cos(house.rot)) * (2.0 + h)
			home += Vector2(cos(h * TAU), sin(h * TAU)) * 0.7
		if not _standable(home):
			continue
		var role := &"idle"
		if looks[n].build == &"boy":
			role = &"play"
		elif h < 0.45:
			role = &"work"
		elif h < 0.7:
			role = &"walk"
		_add(looks[n], home, role, index, h)


func _ring(n: int) -> void:
	var at: Vector2 = game.player.pos
	var looks := PersonLook.crowd(game.world.seed_value * 7 + 3, n)
	for i in looks.size():
		var a := TAU * i / looks.size()
		var p := at + Vector2(cos(a), sin(a)) * (1.6 + 0.25 * (i % 2))
		_add(looks[i], p, &"idle", -2, float(i) / n)


func _add(look: Dictionary, home: Vector2, role: StringName, village: int, h: float) -> void:
	var f := {
		"pos": home, "home": home, "role": role, "village": village, "t": h * 5.0,
		"facing": h * TAU, "target": home, "wait": h * 3.0, "tool": &"", "work": &"",
	}
	if role == &"work":
		var job := _job(home)
		if job.is_empty():
			f.role = &"idle"
		else:
			f.tool = job.tool
			f.work = job.work
			f.pos = job.pos
			f.facing = job.facing
	var model := PersonModel.make(look, f.tool, game.view.world_material())
	model.name = "villager_%d" % folk.size()
	add_child(model)
	f.model = model
	if f.role == &"work":
		model.play_action(f.work, 0.0)
	_place(f)
	folk.append(f)


## The nearest thing to work near a spot, and the tool and verb for it.
func _job(at: Vector2) -> Dictionary:
	var best: WorldProp = null
	var bd := 49.0
	for p in game.query.props_near(at, 7.0):
		if game.world.depleted.has(p.id):
			continue
		if TREES.has(p.kind) or ROCKS.has(p.kind) or GREEN.has(p.kind):
			var d := p.pos.distance_squared_to(at)
			if d < bd:
				bd = d
				best = p
	var tool := &"mattock"
	var work := &"work_dig"
	var face_to := at + Vector2(1, 0)
	var stand := at
	if best != null:
		face_to = best.pos
		var away := (at - best.pos).normalized() if at.distance_to(best.pos) > 0.01 else Vector2(1, 0)
		stand = best.pos + away * (best.solid + 0.55)
		if TREES.has(best.kind):
			tool = &"axe_felling" if Rng.hash01(best.id, 3) < 0.5 else &"axe_hand"
			work = &"work_fell"
		elif ROCKS.has(best.kind):
			tool = &"pick"
			work = &"work_break"
		else:
			tool = &"billhook"
			work = &"work_cut"
	if not _standable(stand):
		return {}
	return {"tool": tool, "work": work, "pos": stand, "facing": (face_to - stand).angle()}


func _standable(p: Vector2) -> bool:
	var w := game.world
	var g := w.ground_at(floori(p.x), floori(p.y))
	return w.in_bounds(floori(p.x), floori(p.y)) and not Ground.is_water(g) and w.level_at(floori(p.x), floori(p.y)) > 0


# ---------------------------------------------------------------- behaviour

func _step(f: Dictionary, delta: float, night: bool) -> void:
	var model: PersonModel = f.model
	model.visible = not night
	if night:
		return
	f.t = float(f.t) + delta
	var speed := 0.0
	var player_pos: Vector2 = game.player.pos
	var to_player := player_pos - (f.pos as Vector2)
	match f.role:
		&"walk", &"play":
			var target: Vector2 = f.target
			var d := target - (f.pos as Vector2)
			if f.wait > 0.0:
				f.wait = float(f.wait) - delta
			elif d.length() < 0.15:
				var h := Rng.hash01(int(f.t * 10.0), int(f.home.x), int(f.home.y))
				var r := 3.5 if f.role == &"walk" else 2.5
				var next: Vector2 = (f.home as Vector2) + Vector2(cos(h * TAU), sin(h * TAU)) * r * (0.4 + h * 0.6)
				if _standable(next):
					f.target = next
				f.wait = (1.5 + h * 3.0) if f.role == &"walk" else h * 0.6
			else:
				var pace := 1.5 if f.role == &"walk" else 4.8
				var step := d.normalized() * minf(d.length(), pace * delta)
				f.pos = (f.pos as Vector2) + step
				f.facing = lerp_angle(float(f.facing), step.angle(), 1.0 - exp(-10.0 * delta))
				speed = pace
	# Heads turn to watch the player go by.
	if to_player.length() < 5.0 and f.role != &"work":
		var rel := wrapf(to_player.angle() - float(f.facing), -PI, PI)
		model.gaze = clampf(-rel, -1.3, 1.3)
		if absf(rel) > 1.9 and speed == 0.0:
			f.facing = lerp_angle(float(f.facing), to_player.angle(), 1.0 - exp(-2.0 * delta))
	else:
		model.gaze = NAN
	_place(f)
	model.animate(speed, delta)


func _place(f: Dictionary) -> void:
	var model: PersonModel = f.model
	var p: Vector2 = f.pos
	model.position = game.world.to_3d(p)
	model.rotation.y = -float(f.facing)
