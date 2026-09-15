extends GameSystem
## People in the villages. Villagers are costume, not yet characters (M2 gives
## them work and talk): they work at the nearest tree or rock, walk the square,
## stand at their doors, and turn their heads to watch you pass. At dusk they
## put down their work and walk home; each goes in at their door (or as soon as
## nobody can see them) and comes out again at dawn.
##
## Building a person costs ~3 ms, so figures are built from a queue, one on every
## even frame (37_fauna takes the odd ones): walking up to a village never stalls.
## Only setup builds straight away, so the first frame and shots are complete.
##
## Shot options (BootOptions, characters):
##   --hand=ID      put ID in the player's hand (added to the inventory)
##   --look=TOKENS  the player's look: build/hat/coat/hair/beard/salvage names, or seed:N
##   --pose=NAME[:T] the player plays NAME on a loop, or frozen T seconds in
##   --face=DEG     the player's facing in degrees (0 east, 90 south)
##   --folk=N       N villagers in a ring around the player, for crowd shots

const NEAR := 34.0
const FAR := 46.0
const PER_VILLAGE := 6
## Hours: villagers head home from DUSK and are out again from DAWN.
const DUSK := 21.0
const DAWN := 5.5
const PACE := 1.5
const TREES: Array[int] = [PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.SNOW_PINE]
const ROCKS: Array[int] = [PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE]
const GREEN: Array[int] = [PropKind.REEDS, PropKind.BUSH, PropKind.GORSE]

## One villager: {model, pos, home, door, role, target, facing, t, wait, work, tool,
## job_pos, job_facing, village, state}. state: &"out" | &"home" (walking in) | &"in".
var folk: Array[Dictionary] = []
## Villagers waiting to be built: {look, home, door, role, village, h}.
var queue: Array[Dictionary] = []
var _spawned: Dictionary = {} # village index -> true
var _act := &""
var _act_at := -1.0
var _check := 0.0


func setup(g: Game) -> void:
	super.setup(g)
	name = "folk"
	_player_flags()
	var ring := game.options.folk if game.options != null else 0
	if ring > 0:
		_ring(ring)
	_stream(true)


func _player_model() -> PersonModel:
	if game.player == null:
		return null
	return game.player.get("model") as PersonModel


func _player_flags() -> void:
	var m := _player_model()
	var o := game.options
	if m == null:
		return
	# Only the starting hand: keeping the model in step with later changes is the
	# fight and survival systems' job (they own what is held and when).
	if game.inventory != null:
		m.set_held(game.inventory.held)
	if o == null:
		return
	if o.hand != "" and game.inventory != null:
		game.inventory.add(StringName(o.hand))
		game.inventory.set_held(StringName(o.hand))
	if o.hand != "":
		m.set_held(StringName(o.hand))
	if o.look != "":
		m.set_look(parse_look(o.look, o.seed_value))
	if o.face != "" and game.player != null:
		game.player.facing = deg_to_rad(o.face.to_float())
		m.rotation.y = -game.player.facing
	if o.pose != "":
		var parts := o.pose.split(":")
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


## Night for villagers: from DUSK to DAWN.
static func is_night(hour: float) -> bool:
	return hour >= DUSK or hour < DAWN


func _hour() -> float:
	return game.clock.hour() if game.clock != null else 12.0


func _process(delta: float) -> void:
	if game == null or game.world == null or game.player == null:
		return
	var m := _player_model()
	if m != null and _act != &"" and _act_at < 0.0 and not m.busy():
		m.play_action(_act, 0.0)
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_stream(false)
	if not queue.is_empty() and Engine.get_process_frames() % 2 == 0:
		pump()
	var night := is_night(_hour())
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
			if now:
				while not queue.is_empty():
					pump()
		elif d > FAR and _spawned.has(i):
			_spawned.erase(i)
			queue = queue.filter(func(q: Dictionary) -> bool: return q.village != i)
			for f: Dictionary in folk.duplicate():
				if f.get("village", -1) == i:
					(f.model as Node).queue_free()
					folk.erase(f)


## Build the next queued villager. Returns false when there was none.
func pump() -> bool:
	if queue.is_empty():
		return false
	var q: Dictionary = queue.pop_front()
	_add(q.look, q.home, q.role, q.village, q.h, q.door)
	return true


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
		var door := home
		if not houses.is_empty():
			var house := houses[n % houses.size()]
			var out := Vector2(sin(house.rot), cos(house.rot))
			door = house.pos + out * (house.solid + 0.3)
			home = house.pos + out * (2.0 + h)
			home += Vector2(cos(h * TAU), sin(h * TAU)) * 0.7
		if not _standable(home):
			continue
		if not _standable(door):
			door = home
		var role := &"idle"
		if looks[n].build == &"boy":
			role = &"play"
		elif h < 0.45:
			role = &"work"
		elif h < 0.7:
			role = &"walk"
		queue.append({"look": looks[n], "home": home, "door": door, "role": role, "village": index, "h": h})


func _ring(n: int) -> void:
	var at: Vector2 = game.player.pos
	var looks := PersonLook.crowd(game.world.seed_value * 7 + 3, n)
	for i in looks.size():
		var a := TAU * i / looks.size()
		var p := at + Vector2(cos(a), sin(a)) * (1.6 + 0.25 * (i % 2))
		_add(looks[i], p, &"idle", -2, float(i) / n, p)


func _add(look: Dictionary, home: Vector2, role: StringName, village: int, h: float, door: Vector2) -> void:
	var f := {
		"pos": home, "home": home, "door": door, "role": role, "village": village, "t": h * 5.0,
		"facing": h * TAU, "target": home, "wait": h * 3.0, "tool": &"", "work": &"",
		"job_pos": home, "job_facing": h * TAU, "state": &"out",
	}
	if role == &"work":
		var job := _job(home)
		if job.is_empty():
			f.role = &"idle"
		else:
			f.tool = job.tool
			f.work = job.work
			f.pos = job.pos
			f.job_pos = job.pos
			f.facing = job.facing
			f.job_facing = job.facing
	var model := PersonModel.make(look, f.tool, game.view.world_material() if game.view != null else null)
	model.name = "villager_%d" % folk.size()
	add_child(model)
	f.model = model
	if village >= 0 and is_night(_hour()):
		# Built after dark: already indoors.
		f.state = &"in"
		f.pos = door
		model.visible = false
	elif f.role == &"work":
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


## Whether the camera can see a spot. False with no camera (tests, headless):
## then nobody is watching and villagers may vanish at once.
func _seen(p: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.is_position_in_frustum(game.world.to_3d(p) + Vector3(0, 0.6, 0))


# ---------------------------------------------------------------- behaviour

func _step(f: Dictionary, delta: float, night: bool) -> void:
	var model: PersonModel = f.model
	if f.village < 0:
		night = false
	if night and f.state == &"out":
		f.state = &"home"
		f.wait = 0.0
		if model.busy():
			model.play_action(&"", 0.0)
	elif not night and f.state != &"out":
		# Dawn: out of the door and back to the day's work.
		f.state = &"out"
		f.pos = f.door
		f.target = f.door
		f.wait = Rng.hash01(int(f.home.x * 7.0), int(f.home.y * 7.0)) * 2.0
		model.visible = true
	if f.state == &"in":
		return
	f.t = float(f.t) + delta
	var speed := 0.0
	var player_pos: Vector2 = game.player.pos
	var to_player := player_pos - (f.pos as Vector2)
	if f.state == &"home":
		speed = _walk_to(f, f.door, PACE, delta)
		if speed == 0.0 or not _seen(f.pos):
			f.state = &"in"
			model.visible = false
			return
	else:
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
					speed = _walk_to(f, target, PACE if f.role == &"walk" else 4.8, delta)
			&"work":
				if (f.pos as Vector2).distance_to(f.job_pos) > 0.05:
					if f.wait > 0.0:
						f.wait = float(f.wait) - delta
					else:
						speed = _walk_to(f, f.job_pos, PACE, delta)
				else:
					f.facing = lerp_angle(float(f.facing), float(f.job_facing), 1.0 - exp(-8.0 * delta))
					if not model.busy():
						model.play_action(f.work, 0.0)
			_:
				if (f.pos as Vector2).distance_to(f.home) > 0.05 and f.wait <= 0.0:
					speed = _walk_to(f, f.home, PACE, delta)
				elif f.wait > 0.0:
					f.wait = float(f.wait) - delta
	# Heads turn to watch the player go by.
	if to_player.length() < 5.0 and not model.busy():
		var rel := wrapf(to_player.angle() - float(f.facing), -PI, PI)
		model.gaze = clampf(-rel, -1.3, 1.3)
		if absf(rel) > 1.9 and speed == 0.0:
			f.facing = lerp_angle(float(f.facing), to_player.angle(), 1.0 - exp(-2.0 * delta))
	else:
		model.gaze = NAN
	_place(f)
	model.animate(speed, delta)


## One step toward `target` at `pace` tiles/s, turning to face the way. Returns
## the speed moved (0 once there).
func _walk_to(f: Dictionary, target: Vector2, pace: float, delta: float) -> float:
	var d := target - (f.pos as Vector2)
	if d.length() < 0.05:
		f.pos = target
		return 0.0
	var step := d.normalized() * minf(d.length(), pace * delta)
	f.pos = (f.pos as Vector2) + step
	f.facing = lerp_angle(float(f.facing), step.angle(), 1.0 - exp(-10.0 * delta))
	return step.length() / maxf(delta, 1e-5)


func _place(f: Dictionary) -> void:
	var model: PersonModel = f.model
	var p: Vector2 = f.pos
	model.position = game.world.to_3d(p)
	model.rotation.y = -float(f.facing)
