extends GameSystem
## Roles, indifference, interference and stealth, wired into the running game
## (docs/VISION.md §2 and the pillar "live in the gaps").
##
## It does four things, and nothing else may:
##   1. tells the simulation what the player is doing about being noticed:
##      crouched (the crouch key), what they are standing in (Cover), how loud
##      they are (StealthNoise), whether their signature reads as one of the
##      machines' own (Body.spoof_until). The Moment carries it; StealthQuery
##      is the only thing that reads it.
##   2. keeps the interference of every plan network: theft, sabotage, a dead
##      worker, a filing and a broken curfew raise it; time, distance, hiding
##      and a spoofed signature let it fall. Saved.
##   3. writes each live body's disposition from its role and the interference
##      where it stands, and puts it on the model, whose status lamps blink it.
##      As a region heats, workers that walked past you stop working and come.
##   4. lets the world say so without a word of UI: a machine's optics turn to
##      the last noise, its working part flickers with its suspicion, watchers
##      turn toward you when the network files something, a horn goes off at a
##      works, and at the top of the scale the network sends hunters.

## The crouch key is held, not toggled (project.godot: Left Ctrl, Q).
const CROUCH_ACTION := &"crouch"
## Cover is read again when the player has moved this far, or this often (s).
const COVER_STEP := 0.35
const COVER_EVERY := 0.3
## Dispositions are written this often (s): a region heating is felt in a
## breath, not on the frame.
const APPLY_EVERY := 0.25
## A job on a prop makes its noise this often (s): a player hammering a mast is
## heard, and keeps being heard.
const WORK_NOISE_EVERY := 0.7
## How far a rise in interference is felt: watchers within this turn toward the
## player, and the horn is heard from a works this far off.
const FELT_RADIUS := 44.0
## World minutes between hunters the network sends while it is hunted.
const DISPATCH_EVERY := 90.0
## Where a dispatched hunter comes out (tiles from the player).
const DISPATCH_RING := 19.0
## Machines this near a theft take it personally.
const THEFT_RADIUS := 22.0
## The horn a works sounds when its network files something (SoundNames).
const HORN := &"works_horn"

var interference := Interference.new()
var sim: FightSim
var _cover := 0.0
var _cover_at := Vector2(INF, INF)
var _cover_left := 0.0
var _apply_left := 0.0
var _work_left := 0.0
var _last_minutes := 0.0
var _stealing: int = -1
var _dispatch_at := -INF
var _felt_level := 0
## What the tour has been shown (tour_seen).
var _seen: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	sim = g.player.sim
	_last_minutes = g.clock.minutes
	Events.killed.connect(_on_killed)
	Events.took.connect(_on_took)
	Events.made.connect(_on_made)
	Events.hit.connect(_on_hit)
	SaveGame.register(&"disposition", _save, _load)
	SlateFeeds.provide(&"reads", _reads)
	_read_player()
	_apply_dispositions()


func _save() -> Variant:
	return interference.save()


func _load(v: Variant) -> void:
	if v is Dictionary:
		interference.load(v)
	_apply_dispositions()


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	_read_player()
	_cool(delta)
	_work_noise(delta)
	_apply_left -= delta
	if _apply_left <= 0.0:
		_apply_left = APPLY_EVERY
		_apply_dispositions()
		_felt(sim.now)
		_dispatch()


# --- 1. what the player is doing about being noticed --------------------------

## The crouch key, the cover the player is standing in, how loud they are, and
## whether the machines are reading them as one of their own. Written onto the
## Moment every frame, because every one of them can change every frame.
func _read_player() -> void:
	var body := game.body
	var m := sim.moment
	var hero := sim.hero
	body.crouched = Input.is_action_pressed(CROUCH_ACTION) and not game.input_blocked()
	game.player.model.crouched = body.crouched
	m.crouched = body.crouched
	m.spoofed = game.clock.minutes < body.spoof_until
	var p := hero.pos
	var ground := game.world.ground_at(floori(p.x), floori(p.y))
	m.loudness = StealthNoise.loudness(hero.speed, ground, body.crouched, m.laden_tier)
	m.cover = _cover_now(p, m)
	m.interference = interference.value(Interference.network(game.world, p))


func _cover_now(p: Vector2, m: Moment) -> float:
	_cover_left -= get_physics_process_delta_time()
	if _cover_left > 0.0 and p.distance_to(_cover_at) < COVER_STEP:
		return _cover
	_cover_left = COVER_EVERY
	_cover_at = p
	_cover = Cover.at(game.world, game.query, p, m.crouched, m.nightfall() * Senses.DARKEST, m.lamp_lit)
	return _cover


# --- 2. the interference of a plan network -----------------------------------

## What the player just did, filed against the network they did it in.
func raise(cause: StringName, at: Vector2) -> float:
	var net := Interference.network(game.world, at)
	var rose := interference.raise(net, cause, at, game.clock.minutes)
	if rose > 0.0:
		_seen[&"interference"] = true
	return rose


## Time, distance, hiding and a misread signature. A player crouched in cover
## that nothing is looking for is forgotten about faster than one in the open.
func _cool(delta: float) -> void:
	var minutes := game.clock.minutes
	var passed := minutes - _last_minutes
	_last_minutes = minutes
	if passed <= 0.0:
		return
	var m := sim.moment
	var hidden := m.crouched and m.cover > 0.4 and not _anything_aware()
	interference.decay(passed / 60.0, hidden, m.spoofed, Interference.network(game.world, sim.hero.pos), sim.hero.pos)


func _anything_aware() -> bool:
	for mob in sim.mobs:
		if mob.alive and not mob.removed and (mob.roused() or mob.suspicion > 0.5):
			return true
	return false


func _on_killed(kind: StringName, at: Vector3) -> void:
	if not Roster.row(kind).get("machine", false):
		return
	var p := Vector2(at.x, at.z)
	var cause := &"killed_worker" if Roles.of(kind) == Roles.WORKER else &"killed_machine"
	raise(cause, p)
	sim.make_noise(p, StealthNoise.radius(&"kill", game.world.ground_at(floori(p.x), floori(p.y)), false, 0))


## Taking is heard. Taking from the machines' own works is theft, and every
## worker near enough turns on whoever is stripping their plan (VISION §2).
func _on_took(_item: StringName, _count: int) -> void:
	_noise(&"work")


func _on_made(_item: StringName, _count: int) -> void:
	_noise(&"make")


func _on_hit(_attacker: Object, target: Object, _damage: int, _plate: bool, at: Vector3) -> void:
	_noise(&"hit")
	if target is MobState and (target as MobState).machine:
		raise(&"sabotage", Vector2(at.x, at.z))


func _noise(act: StringName) -> void:
	var p := sim.hero.pos
	var ground := game.world.ground_at(floori(p.x), floori(p.y))
	sim.make_noise(p, StealthNoise.radius(act, ground, game.body.crouched, sim.moment.laden_tier))


## A job under way is a noise that keeps going, and a job on the plan's own
## works is a theft the network files once.
func _work_noise(delta: float) -> void:
	var job := SurvivalState.of(game).job
	if job.is_empty():
		_stealing = -1
		return
	var prop: WorldProp = job.get("prop")
	_work_left -= delta
	if _work_left <= 0.0:
		_work_left = WORK_NOISE_EVERY
		var verb: StringName = (job.get("option", {}) as Dictionary).get("verb", &"work")
		_noise(verb if StealthNoise.ACTS.has(verb) else &"work")
	if prop == null or prop.id == _stealing or not Takes.is_plan_work(prop.kind):
		return
	_stealing = prop.id
	_theft(prop)


## Hands on the plan's own parts: the network files it, and every machine near
## enough that its role takes it amiss stops working and turns.
func _theft(prop: WorldProp) -> void:
	raise(&"theft", prop.pos)
	var turned := 0
	for m in sim.mobs:
		if not m.alive or m.removed or not m.machine:
			continue
		if Senses.chebyshev(m.pos, prop.pos) > THEFT_RADIUS:
			continue
		if not Senses.line_clear(game.world, game.query, m.pos, sim.hero.pos):
			continue
		sim.disturb(m, &"theft")
		if m.disturbed:
			turned += 1
	if turned > 0:
		_seen[&"theft"] = true
		Events.sfx.emit(&"alert", game.world.to_3d(prop.pos))


# --- 3. what each body makes of the player ------------------------------------

## A body's disposition is its role, plus the interference where it stands,
## plus what the player has done to it. The model's status lamps blink it.
func _apply_dispositions() -> void:
	for m in sim.mobs:
		if not m.alive or m.removed or not m.machine:
			continue
		var lvl := interference.level(Interference.network(game.world, m.pos))
		var want := Disposition.of(m.role, lvl, m.disturbed)
		if want != m.disposition:
			m.disposition = want
		if m.node is Mob:
			var model := (m.node as Mob).model as MachineModel
			if model != null and model.disposition != want:
				model.disposition = want


# --- 4. the world says so, in the world ---------------------------------------

## A network that has just been filed is felt without a word: the watchers
## still about turn their optics onto the player, and a horn goes off at a
## works over the land.
func _felt(now: float) -> void:
	var net := Interference.network(game.world, sim.hero.pos)
	var lvl := interference.level(net)
	if lvl == _felt_level:
		return
	var rising := lvl > _felt_level
	_felt_level = lvl
	if not rising:
		return
	_seen[&"felt"] = true
	for m in sim.mobs:
		if not m.alive or m.removed or Roles.of_row(m.row) != Roles.WATCHER:
			continue
		if Senses.chebyshev(m.pos, sim.hero.pos) > FELT_RADIUS:
			continue
		m.heard_at = sim.hero.pos
		m.look_until = now + FightSim.LOOK_MS
		m.suspicion = maxf(m.suspicion, 0.5)
	# Off over the land, where the works are: a long way off, and about you.
	var away := Vector2.from_angle(GenWorks.bearing(game.world.seed_value)) * FELT_RADIUS
	Events.sfx.emit(HORN, game.world.to_3d(sim.hero.pos + away))


## At the top of the scale the network stops waiting for the player to walk
## into something and sends a hunter after them.
func _dispatch() -> void:
	if interference.level(Interference.network(game.world, sim.hero.pos)) < 3:
		return
	if game.clock.minutes - _dispatch_at < DISPATCH_EVERY:
		return
	var kind := _hunter_for_here()
	if kind == &"":
		return
	var spot := _spot_for(kind)
	if spot == Vector2.INF:
		return
	_dispatch_at = game.clock.minutes
	var m := sim.add_mob(kind, spot)
	m.last_seen = sim.hero.pos
	m.suspicion = 1.0
	_seen[&"hunter"] = true


func _hunter_for_here() -> StringName:
	var best: StringName = &""
	for kind: StringName in Roster.kinds():
		var row := Roster.row(kind)
		if not row.get("machine", false) or Roles.of_row(row) != Roles.HUNTER:
			continue
		if row.get("approach", &"") == &"dart":
			continue
		if not Spawner.moment_fits(row, sim.moment):
			continue
		best = kind
		break
	return best


func _spot_for(kind: StringName) -> Vector2:
	var row := Roster.row(kind)
	var rng := Rng.make(game.world.seed_value, int(game.clock.minutes))
	for i in 24:
		var a := rng.randf() * TAU
		var p := sim.hero.pos + Vector2.from_angle(a) * DISPATCH_RING
		var tx := floori(p.x)
		var ty := floori(p.y)
		if not game.query.standable(tx, ty):
			continue
		if not Spawner.place_fits(row, game.world, game.query, tx, ty):
			continue
		return p
	return Vector2.INF


# --- the slate's machine reads -------------------------------------------------

## The reads app: what the network makes of the player, and what every machine
## in range makes of them (SlateFeeds).
func _reads(_g: Game) -> Dictionary:
	var net := Interference.network(game.world, sim.hero.pos)
	var scans: Array = []
	for m in sim.mobs:
		if not m.alive or m.removed or not m.machine:
			continue
		if Senses.chebyshev(m.pos, sim.hero.pos) > SlateFeeds.READ_RADIUS:
			continue
		scans.append({"id": StringName("m%d" % m.id), "kind": m.kind, "name": String(m.kind),
			"pos": m.pos, "disposition": m.disposition, "note": _note(m)})
	return {"interference": interference.value(net),
		"network": "%s network" % Country.NAMES[clampi(net, 0, Country.NAMES.size() - 1)],
		"scans": scans}


func _note(m: MobState) -> String:
	if m.disturbed:
		return "it has taken something amiss"
	if m.roused():
		return "it has you"
	if m.suspicion >= 0.5:
		return "it is not sure"
	return String(m.role)


## Tour awaits: interference (a network rose), theft (workers turned on a
## thief), felt (a rise was felt in the world), hunter (one was sent),
## crouched, hidden (crouched in cover, unseen).
func tour_seen(what: StringName) -> bool:
	match what:
		&"crouched":
			return game.body.crouched
		&"hidden":
			return sim.moment.crouched and sim.moment.cover > 0.4
		&"suspicious":
			for m in sim.mobs:
				if m.alive and not m.removed and m.suspicion > 0.0 and not m.roused():
					return true
			return false
		&"turned":
			for m in sim.mobs:
				if m.alive and not m.removed and m.disturbed:
					return true
			return false
	return bool(_seen.get(what, false))
