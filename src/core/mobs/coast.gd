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
## put out in view within the first minutes, with nothing else hostile about
## until that meeting is over. It is fair: it waits for a player who is well and
## has not just fought, and it is seen on its round before it notices them.
## After a bad end no hunter comes out for a while.

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
## Times a patrol still in sight at the end of its line carries on over the land.
const PATROL_LEGS := 2
## The first meeting comes this long into a game (sim ms), tried again every
## FIRST_RETRY_MS until there is ground for it.
const FIRST_MEETING_MS := 75000.0
const FIRST_RETRY_MS := 2000.0
## The kind the first meeting is, and nothing hostile nearer than this when it comes.
const FIRST_KIND := &"runner"
const FIRST_CLEAR := 24.0
## A first meeting is one machine: no worker on its round nearer the player
## than this when it comes (a hunter no nearer than FIRST_CLEAR), no patrol put
## out while it is on, nor in the FIRST_HUSH_MS before it is due.
const FIRST_ALONE := 8.0
const FIRST_HUSH_MS := 20000.0
## The first meeting waits for a player at this health or more, and this long
## (sim ms) after any fight ended.
const FIRST_MIN_HEALTH := 9
const FIRST_QUIET_MS := 120000.0
## On its round it is not hunting: it notices only this close (Chebyshev tiles,
## sight and hearing), stands this many beats when it does before it comes, and
## walks at this share of its pace. It is put out further off than that and in
## view, so the player sees it before it sees them. Roused, it is a runner again.
const FIRST_SEES := 5.0
const FIRST_HEARS := 3.0
const FIRST_READY := 8
const FIRST_ROUND_PACE := 0.45
## After the player is downed or carried off, no hunter comes out for this long (sim ms).
const AFTER_DOWNED_MS := 180000.0

var sim: FightSim
var spawner: Spawner
## Set false to keep the coast to what was placed by hand (shots, tests).
var spawning := true
## Set false to keep patrols and the first meeting off (soaks of the plain rolls).
var rounds := true
## Another package may shut kinds out of the rolls for a reason of its own, given
## the dictionary `shut` has built and where the player is standing: the plan's
## depots (src/core/works) close a whole region's machines once the yard that
## sends them is dark, which is what "the region quiets" means past the yard gate.
var also_shut := Callable()
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
		# A patrol is a crossing: once it has walked its round to the end (or been
		# out long), it comes off the land as soon as the camera cannot see it,
		# rather than pacing back and forth past the player.
		if m.patrol and m.alive and not m.roused() and not m.line_to_b and m.legs < PATROL_LEGS \
				and m.pos.distance_to(m.line_b) < 1.0 and spawner.in_view(sim.hero.pos, m.pos, 2.0):
			# At the end of its line (not turned back by something in its way) and still
			# in sight: it carries on the same way, off over the land, rather than
			# turning back past the player.
			var on := (m.line_b - m.line_a).normalized()
			m.line_a = m.line_b
			m.line_b = m.line_b + on * Spawner.PATROL_LENGTH * 0.5
			m.line_to_b = true
			m.legs += 1
		var crossed := not m.line_to_b or m.legs > 0 or sim.now - m.put_out_at > PATROL_LIFE_MS
		if not gone and m.patrol and not m.roused() and m.alive and crossed:
			gone = not spawner.in_view(sim.hero.pos, m.pos, 2.0)
		if gone:
			if m.snatched and not m.reported and m.row.get("hits", {}).get("files", false):
				m.reported = true
				sim.emit(&"filed", {"mob": m})
			sim.remove_mob(m)
	if first_meeting == 0 and (_first_mob == null or _first_mob.removed or not _first_mob.alive):
		first_meeting = 1
		_first_mob = null
	elif first_meeting == 0 and _first_mob.roused() and _first_mob.row.get("on_round", false):
		# Roused: off its round, and a runner's eyes and ears again.
		_first_mob.row = Roster.row(_first_mob.kind)


## The kinds that may not come out right now: darts on their gaps, and every
## hunter until the first meeting has come.
func shut() -> Dictionary:
	var out := {}
	var minutes := sim.moment.minutes
	var met := minutes - sim.last_meeting_minutes < MEETING_GAP
	var sore := sim.now - sim.last_downed_at < AFTER_DOWNED_MS
	for k: StringName in Roster.DEFS:
		var row := Roster.row(k)
		if Spawner.is_hunter(row) and (sore or (rounds and first_meeting < 0)):
			out[k] = true
			continue
		if row.get("approach", &"") != &"dart":
			continue
		if met or minutes < float(_kind_ready.get(k, -INF)):
			out[k] = true
	if also_shut.is_valid():
		also_shut.call(out, sim.hero.pos)
	return out


## Keep one worker on its round within sight of the land about the player.
func _patrols() -> void:
	if sim.now < _patrol_at or first_meeting == 0 or sim.fight_on or _first_due():
		return
	_patrol_at = sim.now + PATROL_EVERY_MS
	for m in sim.mobs:
		if m.patrol and m.alive and not m.removed:
			return
	if sim.living() >= Spawner.MAX_LIVING:
		return
	_patrol_rolls += 1
	var p := spawner.patrol(_patrol_rolls, sim.world, sim.query, sim.moment, sim.hero.pos)
	# A round is a roll like any other, so whatever is shut out of the rolls is
	# shut out of the rounds: a region whose depot is dark sends nobody across it.
	if p.is_empty() or shut().has(p.kind):
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


## A lone runner on its round in view, once the game is a minute or so old,
## the player is out of the village, well, and not just out of a fight. Its
## round crosses in front of the player, near enough that it notices them if
## they stay; they see it first either way.
func _first_meeting() -> void:
	if first_meeting >= 0 or sim.now < _first_try_at or sim.fight_on:
		return
	if sim.moment.day() > 1:
		# A first meeting belongs to a new game's first hours.
		first_meeting = 1
		return
	_first_try_at = sim.now + FIRST_RETRY_MS
	if not ready_for_first_meeting():
		return
	for m in sim.mobs:
		if not m.alive or m.removed or not m.row.get("hostile", true):
			continue
		var d := Senses.chebyshev(m.pos, sim.hero.pos)
		if d <= FIRST_ALONE or (not m.indifferent() and d <= FIRST_CLEAR):
			return
	if Spawner.green_distance(sim.world, sim.hero.pos) < Spawner.FIRST_GREEN - 2.0:
		return
	var spot := spawner.first_meeting_spot(sim.moment.seed_value * 31 + floori(sim.now / FIRST_RETRY_MS), sim.world, sim.query, FIRST_KIND, sim.hero.pos, maxf(FIRST_SEES, FIRST_HEARS))
	if spot.is_empty():
		return
	var at: Vector2 = spot.from
	var m := sim.add_mob(FIRST_KIND, at)
	m.first_meeting = true
	var row := m.row.duplicate()
	row["sees"] = FIRST_SEES
	row["hears"] = FIRST_HEARS
	row["ready"] = FIRST_READY
	row["on_round"] = true
	m.row = row
	m.pace *= FIRST_ROUND_PACE
	m.line_a = at
	m.line_b = spot.to
	m.line_to_b = true
	m.facing = (m.line_b - at).angle()
	m.aim = m.facing
	_first_mob = m
	first_meeting = 0
	sim.emit(&"first_meeting", {"mob": m})


## The first meeting is due and the player is where it could come: a new
## patrol would only stand in its way.
func _first_due() -> bool:
	return first_meeting < 0 and sim.now >= _first_try_at - FIRST_HUSH_MS and sim.moment.day() <= 1 \
			and Spawner.green_distance(sim.world, sim.hero.pos) >= Spawner.FIRST_GREEN - 2.0


## The player is fit for a first meeting: health enough to take a bite or two,
## and a while since any fight ended.
func ready_for_first_meeting() -> bool:
	return sim.hero.health >= FIRST_MIN_HEALTH and sim.now - sim.last_fight_end_at >= FIRST_QUIET_MS
