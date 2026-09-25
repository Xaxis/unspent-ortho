extends RefCounted
## A careless player: walks straight at the nearest body and swings whenever it
## is in reach, whatever side it is on and whatever the body is doing. Never
## dodges. The first meetings must beat this player, or reading them is not
## the skill.

var sim: FightSim
var _last_pull := -1000.0
## Holds every swing for the heavy blow: a heavy blow thrown without reading
## the machine must lose as surely as a light one.
var heavy := false


func _init(s: FightSim) -> void:
	sim = s


func act() -> void:
	var hero := sim.hero
	hero.run = false
	if hero.held():
		if sim.now - _last_pull >= 160.0:
			_last_pull = sim.now
			sim.press_swing()
		return
	var best: MobState = null
	for m in sim.mobs:
		if m.alive and not m.removed and (best == null or m.pos.distance_to(hero.pos) < best.pos.distance_to(hero.pos)):
			best = m
	if best == null:
		hero.move = Vector2.ZERO
		return
	var to := best.pos - hero.pos
	var inv := hero.inventory
	var b := Blow.for_item(inv.held, inv.edge(inv.held)) if inv != null and inv.held != &"" else Blow.fists()
	if FightRules.box_hits(hero.pos, to.angle(), hero.radius, b, best.pos, best.radius):
		hero.move = Vector2.ZERO
		hero.facing = to.angle()
		if hero.swing_refusal(sim.now) == &"":
			if heavy:
				sim.press_heavy()
			else:
				sim.press_swing()
		return
	hero.move = to.normalized()
