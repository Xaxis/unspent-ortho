extends GameSystem
## The yard answering back (owner, 2026-09-17, docs/VISION.md §9.5). Reachable as
## the system named "47_defences".
##
## Every armed turret of a holding in the realm under the player's feet looks for
## what is coming for the place (`TurretRules.pick`), turns its head onto it, and
## after `AIM_MS` shoots — through `FightSim.strike`, so the blow is the fight's
## own and a kill is the fight's own kill, counted by everything that counts
## kills (a raider down, a machine the plan will file). Only bodies the fight
## holds can be shot, and the fight only holds bodies near the player: a raid the
## player walked out of is settled on paper by the raids package, where the
## turret is `defence` like any wall.
##
## Nothing here is saved. What a turret is doing this second is not a thing a
## player would expect to come back to; that it is armed is (`Structure.off`).
##
## Staging, for shots and tours:
##   tools/tour.sh tours/turret.tour --seed=1 --hour=10 --weather=clear:0 \
##     --holding=hut,wind_spinner,battery_stack,battery_stack,turret

const Works := preload("res://src/models/props/works.gd")

## Tiles from the player a holding's turrets are run within: further than the
## fight holds bodies, so no turret the player could see is ever asleep.
const LIVE := 48.0

## "sid:pid" -> {target: mob id, aim_at: sim ms, next_at: sim ms}
var _state: Dictionary = {}
var _holdings: Node
var _fired := false
var _hit := false
var _killed := false


func holdings() -> Node:
	if _holdings == null or not is_instance_valid(_holdings):
		_holdings = null
		for s in game.systems:
			if s.name == "46_settlements":
				_holdings = s
	return _holdings


func _physics_process(_delta: float) -> void:
	if game == null or game.world == null or game.player == null:
		return
	var sim: FightSim = game.player.sim
	var h := holdings()
	if sim == null or h == null:
		return
	var seen: Dictionary = {}
	for s: Settlement in h.call("all", game.world.realm) as Array[Settlement]:
		if s.centre.distance_to(game.player.pos) > LIVE:
			continue
		for p in s.pieces:
			if p.kind != StructureKind.TURRET:
				continue
			var key := "%d:%d" % [s.id, p.id]
			seen[key] = true
			_work(sim, h, s, p, key)
	for key: String in _state.keys():
		if not seen.has(key):
			_state.erase(key)


func _work(sim: FightSim, h: Node, s: Settlement, p: Structure, key: String) -> void:
	var st: Dictionary = _state.get(key, {"target": -1, "aim_at": INF, "next_at": 0.0})
	_state[key] = st
	var model := h.call("model_of", s, p) as StructureModel
	if not TurretRules.armed(p):
		st["target"] = -1
		return
	var clear := func(q: MobState) -> bool: return Senses.line_clear(game.world, game.query, p.pos, q.pos)
	var m := _mob(sim, int(st["target"]))
	if m == null or not TurretRules.keeps(m, p.pos) or not bool(clear.call(m)):
		m = TurretRules.pick(sim.mobs, p.pos, clear)
		st["target"] = m.id if m != null else -1
		if m == null:
			return
		# A new body: the head comes round and the lens catches before anything is
		# fired, which is the tell.
		st["aim_at"] = sim.now + TurretRules.AIM_MS
		Events.sfx.emit(&"turret_aim", game.world.to_3d(p.pos))
		if model != null:
			MobFx.glint(game, model.muzzle(), Palette.LENS[3], p.id, 0.6)
	if model != null:
		model.aim((m.pos - p.pos).angle())
	if sim.now < float(st["aim_at"]) or sim.now < float(st["next_at"]):
		return
	st["next_at"] = sim.now + TurretRules.EVERY_MS
	var result := sim.strike(m, TurretRules.blow(), p.pos)
	_fired = true
	if result == &"hit":
		_hit = true
	if not m.alive:
		_killed = true
	_shot(p, m, model)


## The shot, seen and heard: a bolt from the muzzle to the body, a flash at the
## muzzle, the crack, and the noise every machine within earshot turns to — a
## turret is the loudest thing in a yard for the instant it fires.
func _shot(p: Structure, m: MobState, model: StructureModel) -> void:
	var at := game.world.to_3d(p.pos)
	var muzzle := model.muzzle() if model != null else at + Vector3(0, 1.0, 0)
	var hit := (m.node as Mob).part_position() if m.node is Mob else game.world.to_3d(m.pos) + Vector3(0, 0.5, 0)
	MobFx.line(game, muzzle, hit, Works.STRIP, 0.09)
	MobFx.glint(game, muzzle, Palette.LENS[3], p.id + 7, 0.5)
	Events.sfx.emit(&"turret_fire", at)
	var ground := game.world.ground_at(floori(p.pos.x), floori(p.pos.y))
	game.player.sim.make_noise(p.pos, StealthNoise.radius(&"hit", ground))
	if model != null:
		model.recoil()


func _mob(sim: FightSim, id: int) -> MobState:
	if id < 0:
		return null
	for m in sim.mobs:
		if m.id == id:
			return m
	return null


## What a tour may await or claim a frame holds.
##   turret_armed   an armed turret with power in it stands in the holding here
##   turret_target  one has a body in its sights
##   turret_fired   one has fired; turret_hit a shot landed; turret_kill one killed
func tour_seen(what: StringName) -> bool:
	match what:
		&"turret_armed":
			return _armed_here()
		&"turret_target":
			for key: String in _state:
				if int((_state[key] as Dictionary).get("target", -1)) >= 0:
					return true
			return false
		&"turret_fired":
			return _fired
		&"turret_hit":
			return _hit
		&"turret_kill":
			return _killed
	return false


func _armed_here() -> bool:
	var h := holdings()
	if h == null:
		return false
	var s := h.call("here") as Settlement
	if s == null:
		return false
	for p in s.pieces:
		if TurretRules.armed(p):
			return true
	return false
