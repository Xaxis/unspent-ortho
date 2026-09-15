class_name Coast
extends RefCounted
## The world layer around the player (design-extract §7.4): spawner rolls on
## the simulation's own clock, culling past 24 tiles, and a clerk that got
## away with its reading filing it as it goes. Pure; the mobs system ticks it
## every physics frame and soak tests tick it for minutes at a time.
##
## Seen often, met rarely (M1.5): the land is watched by workers crossing it on
## their rounds at a distance (patrols, indifferent until disturbed), hunters
## are thin on the first days, and the first hunter of a game is a lone runner
## put out a fair distance away within the first minutes, with nothing else
## hostile about until that meeting is over.

## Never more than this many rolls in one tick, however long the frame was.
const MAX_ROLLS_PER_TICK := 4
## World minutes after a dart of a kind comes out before another of that kind may.
const DART_KIND_GAP := 240.0
## World minutes after any dart has reached the player before any dart comes
## out again. Darts are seen, and met rarely: without this a clerk country
## read and filed the player several times an hour.
const MEETING_GAP := 600.0
## Sim ms between tries at putting a worker on its round past the player.
const PATROL_EVERY_MS := 3000.0
## A patrol this long out comes off the land once the camera cannot see it,
## so another can cross somewhere else.
const PATROL_LIFE_MS := 45000.0
## The first meeting comes this long into a game (sim ms), tried again every
## FIRST_RETRY_MS until there is ground for it.
const FIRST_MEETING_MS := 75000.0
const FIRST_RETRY_MS := 2000.0
## The kind the first meeting is, and nothing hostile nearer than this when it comes.
const FIRST_KIND := &"runner"
const FIRST_CLEAR := 24.0

var sim: FightSim
var spawner: Spawner
## Set false to keep the coast to what was placed by hand (shots, tests).
var spawning := true
## Set false to keep patrols and the first meeting off (soaks of the plain rolls).
var rounds := true
var _rolls_done := -1
## Dart kind -> world minutes before which no other of it comes out.
var _kind_ready: Dictionary = {}
var _patrol_at := 0.0
var _patrol_rolls := 0
## -1 not yet; 0 out on the coast; 1 over (met, beaten, lost or culled).
var first_meeting := -1
var _first_try_at := FIRST_MEETING_MS
var _first_mob: MobState = null


func _init(s: FightSim, sp: Spawner) -> void:
	sim = s
	spawner = sp
	_rolls_done = floori(s.now / Spawner.ROLL_MS)
	_first_try_at = s.now + FIRST_MEETING_MS


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
	if spawning and rounds:
		_patrols()
		_first_meeting()
	for m in sim.mobs:
		var gone := Spawner.should_cull(m.pos, sim.hero.pos, m.patrol and not m.roused())
		if not gone and m.patrol and not m.roused() and sim.now - m.put_out_at > PATROL_LIFE_MS and m.alive:
			gone = not spawner.in_view(sim.hero.pos, m.pos, 2.0)
		if gone:
			if m.snatched and not m.reported and m.row.get("hits", {}).get("files", false):
				m.reported = true
				sim.emit(&"filed", {"mob": m})
			sim.remove_mob(m)
	if first_meeting == 0 and (_first_mob == null or _first_mob.removed or not _first_mob.alive):
		first_meeting = 1
		_first_mob = null


## The kinds that may not come out right now: darts on their gaps, and every
## hunter until the first meeting has come.
func shut() -> Dictionary:
	var out := {}
	var minutes := sim.moment.minutes
	var met := minutes - sim.last_meeting_minutes < MEETING_GAP
	for k: StringName in Roster.DEFS:
		var row := Roster.row(k)
		if rounds and first_meeting < 0 and Spawner.is_hunter(row):
			out[k] = true
			continue
		if row.get("approach", &"") != &"dart":
			continue
		if met or minutes < float(_kind_ready.get(k, -INF)):
			out[k] = true
	return out


## Keep one worker on its round within sight of the land about the player.
func _patrols() -> void:
	if sim.now < _patrol_at:
		return
	_patrol_at = sim.now + PATROL_EVERY_MS
	for m in sim.mobs:
		if m.patrol and m.alive and not m.removed:
			return
	if sim.living() >= Spawner.MAX_LIVING:
		return
	_patrol_rolls += 1
	var p := spawner.patrol(_patrol_rolls, sim.world, sim.query, sim.moment, sim.hero.pos)
	if p.is_empty():
		return
	var m := sim.add_mob(p.kind, p.from)
	var dir: Vector2 = (p.to - p.from).normalized()
	m.line_a = p.from
	m.line_b = p.to
	m.line_to_b = true
	m.facing = dir.angle()
	m.aim = m.facing
	m.patrol = true
	m.put_out_at = sim.now
	sim.emit(&"patrol", {"mob": m})


## A lone runner, a fair walk off and out of view, once the game is a minute
## or so old and the player is out of the village. It comes when it notices.
func _first_meeting() -> void:
	if first_meeting >= 0 or sim.now < _first_try_at or sim.fight_on:
		return
	if sim.moment.day() > 1:
		# A first meeting belongs to a new game's first hours.
		first_meeting = 1
		return
	_first_try_at = sim.now + FIRST_RETRY_MS
	for m in sim.mobs:
		if m.alive and not m.removed and not m.indifferent() and m.row.get("hostile", true) \
				and Senses.chebyshev(m.pos, sim.hero.pos) <= FIRST_CLEAR:
			return
	if Spawner.green_distance(sim.world, sim.hero.pos) < Spawner.FIRST_GREEN - 2.0:
		return
	var at := spawner.first_meeting_spot(sim.moment.seed_value * 31 + floori(sim.now / FIRST_RETRY_MS), sim.world, sim.query, FIRST_KIND, sim.hero.pos)
	if not at.is_finite():
		return
	var m := sim.add_mob(FIRST_KIND, at)
	m.first_meeting = true
	# On its round, slanting in toward where the player is: seen before it sees,
	# and it comes within its sight of them unless they walk away.
	var radial := (at - sim.hero.pos).normalized()
	m.line_a = at
	m.line_b = at - radial * 6.0 + radial.orthogonal() * 3.0
	m.line_to_b = true
	m.facing = (m.line_b - at).angle()
	m.aim = m.facing
	_first_mob = m
	first_meeting = 0
	sim.emit(&"first_meeting", {"mob": m})
