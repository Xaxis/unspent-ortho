class_name Coast
extends RefCounted
## The world layer around the player (design-extract §7.4): spawner rolls on
## the simulation's own clock, culling past 24 tiles, and a clerk that got
## away with its reading filing it as it goes. Pure; the mobs system ticks it
## every physics frame and soak tests tick it for minutes at a time.

## Never more than this many rolls in one tick, however long the frame was.
const MAX_ROLLS_PER_TICK := 4
## World minutes after a dart of a kind comes out before another of that kind may.
const DART_KIND_GAP := 240.0
## World minutes after any dart has reached the player before any dart comes
## out again. Darts are seen, and met rarely: without this a clerk country
## read and filed the player several times an hour.
const MEETING_GAP := 600.0

var sim: FightSim
var spawner: Spawner
## Set false to keep the coast to what was placed by hand (shots, tests).
var spawning := true
var _rolls_done := -1
## Dart kind -> world minutes before which no other of it comes out.
var _kind_ready: Dictionary = {}


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
		var s := spawner.roll(_rolls_done, sim.world, sim.query, sim.moment, sim.hero.pos, sim.living(), shut())
		if not s.is_empty():
			sim.add_mob(s.kind, s.pos)
			if Roster.row(s.kind).get("approach", &"") == &"dart":
				_kind_ready[s.kind] = sim.moment.minutes + DART_KIND_GAP
	for m in sim.mobs:
		if Spawner.should_cull(m.pos, sim.hero.pos):
			if m.snatched and not m.reported and m.row.get("hits", {}).get("files", false):
				m.reported = true
				sim.emit(&"filed", {"mob": m})
			sim.remove_mob(m)


## The kinds that may not come out right now.
func shut() -> Dictionary:
	var out := {}
	var minutes := sim.moment.minutes
	var met := minutes - sim.last_meeting_minutes < MEETING_GAP
	for k: StringName in Roster.DEFS:
		if Roster.row(k).get("approach", &"") != &"dart":
			continue
		if met or minutes < float(_kind_ready.get(k, -INF)):
			out[k] = true
	return out
