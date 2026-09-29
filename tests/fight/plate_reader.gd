extends "res://tests/fight/shoulder_reader.gd"
## The shoulder reader as the proof tour's player stands (tours/reaper_force.tour):
## between bites it does not keep its distance, it walks round the body to the
## plate side (opposite the working part) and stands against it, facing it,
## waiting for the tell. Everything else -- the tell answered react_ms late, the
## dodge out of the box, the strike only from where it reaches the part -- is the
## reader's. It moves by `hero.move` at the walk and is never put anywhere.
## Where the plate side is ground a blow does not pass to (a bank two levels up,
## the sea), it waits as the reader does. `keep_off` / `keep_on` hold its walk
## to firm ground or out on the flats; `home` is where it walks back to.

## Tiles off the skin it stands, as `walkto plate` stops (98_tour).
const PLATE_GAP := 0.45
## Grounds it never walks onto (a player keeping off the flats), grounds it
## never walks off (one holding out on them), and where it walks back to when
## nothing is out (come to after a down at the edge of its ground).
var keep_off: Array = []
var keep_on: Array = []
var home := Vector2.INF
## A lure: once it has the keeper after it, it walks out to here (onto the
## `keep_on` ground) and holds there, dodging, as a player drawing it out does.
var lure := Vector2.INF


func _wait(m: MobState) -> void:
	var hero := sim.hero
	var off := 0.0
	match m.part:
		&"back": off = PI
		&"left": off = -PI * 0.5
		&"right": off = PI * 0.5
	var spot := m.pos + Vector2.from_angle(m.facing + off + PI) * (m.radius + hero.radius + PLATE_GAP)
	if not sim.meets(spot, m.pos) or not sim.query.standable(floori(spot.x), floori(spot.y)):
		# Its plate is up a bank or in the sea: no blow passes there, and a player
		# sees that. They keep their distance and let it come, as the reader does.
		super(m)
		return
	var to_mob := m.pos - hero.pos
	hero.facing = to_mob.angle()
	if hero.pos.distance_to(spot) <= 0.25:
		hero.move = Vector2.ZERO
		return
	hero.move = _round_to(m, spot)


## A player sees a bank two levels up for what it is: no blow passes between it
## and the machine below. Every step is kept to ground that meets the body's
## level, turned aside if the straight step would climb off it; carried up
## there anyway, they come straight back down.
func act() -> void:
	super()
	var hero := sim.hero
	var m := _nearest()
	if m == null:
		hero.move = (home - hero.pos).normalized() if home.is_finite() and hero.pos.distance_to(home) > 1.0 else Vector2.ZERO
		return
	if not sim.meets_hero(m.pos):
		# Up on the bank beside it (a dodge can carry them there): down again,
		# the nearest way onto its level.
		hero.move = Vector2.ZERO
		for k in 16:
			var dir := Vector2.from_angle((m.pos - hero.pos).angle() + float((k + 1) / 2) * (TAU / 16.0) * (1.0 if k % 2 == 0 else -1.0))
			var at := hero.pos + dir * 0.8
			if sim.meets(at, m.pos) and sim.query.standable(floori(at.x), floori(at.y)):
				hero.move = dir
				return
		return
	var here_g := sim.world.ground_at(floori(hero.pos.x), floori(hero.pos.y))
	if lure.is_finite() and m.roused() and not keep_on.has(here_g) and sim.now >= _escape_until:
		hero.move = (lure - hero.pos).normalized() if hero.pos.distance_to(lure) > 0.3 else Vector2.ZERO
		return
	if hero.move.length() < 0.05:
		return
	for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var step := hero.move.rotated(turn)
		var at := hero.pos + step.normalized() * 0.6
		var g := sim.world.ground_at(floori(at.x), floori(at.y))
		if keep_off.has(g) or (not keep_on.is_empty() and not keep_on.has(g)):
			continue
		if sim.meets(at, m.pos):
			hero.move = step
			return
	hero.move = Vector2.ZERO
