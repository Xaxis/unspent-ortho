class_name Coast
extends RefCounted
## The world layer around the player (design-extract §7.4): spawner rolls on
## the simulation's own clock, culling past 24 tiles, and a clerk that got
## away with its reading filing it as it goes. Pure; the mobs system ticks it
## every physics frame and soak tests tick it for minutes at a time.

## Never more than this many rolls in one tick, however long the frame was.
const MAX_ROLLS_PER_TICK := 4

var sim: FightSim
var spawner: Spawner
## Set false to keep the coast to what was placed by hand (shots, tests).
var spawning := true
var _rolls_done := -1


func _init(s: FightSim, sp: Spawner) -> void:
	sim = s
	spawner = sp
	_rolls_done = floori(s.now / Spawner.ROLL_MS)


func tick() -> void:
	var rolls := floori(sim.now / Spawner.ROLL_MS)
	_rolls_done = maxi(_rolls_done, rolls - MAX_ROLLS_PER_TICK)
	while _rolls_done < rolls:
		_rolls_done += 1
		if not spawning:
			continue
		var s := spawner.roll(_rolls_done, sim.world, sim.query, sim.moment, sim.hero.pos, sim.living())
		if not s.is_empty():
			sim.add_mob(s.kind, s.pos)
	for m in sim.mobs:
		if Spawner.should_cull(m.pos, sim.hero.pos):
			if m.snatched and not m.reported and m.row.get("hits", {}).get("files", false):
				m.reported = true
				sim.emit(&"filed", {"mob": m})
			sim.remove_mob(m)
