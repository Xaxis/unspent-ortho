extends GameSystem
## The marks the player leaves on the ground behind them (owner, 2026-09-17:
## "depending on terrain foot and track prints should be left behind player").
##
## Three things kept apart, as the harvest mark is: the RULE (TrackGround: what a
## ground keeps, how long, what fills it), the PLACEMENT (TrackPath: a foot every
## step of the path actually walked), and the DRAWING (TrackMarks, interim). This
## system only feeds the placement what the body is doing, asks the rule of the
## ground under each foot, lays what the ground keeps, and wears it away in world
## time under the weather actually falling.
##
## On foot a person's boots; riding the walker rig, its machine feet; on the hover
## sled, a band brushed across the ground; on a raft, nothing. A mark is only laid
## on the terrace the body is standing on, so none hangs off a contour's edge.
## Nothing is saved: a mark is a moment's evidence, and a realm crossing leaves
## the old world's behind.
##
## A tour answers with `tracks` (a mark is standing), `tracks:GROUND` (one on that
## ground, a space written as _), `tracks:SHAPE` (foot scuff flatten rig sweep),
## and `no_tracks` (nothing standing at all).

## Seconds between wearing the marks down (world minutes pass far faster than this
## reads them).
const WEAR_EVERY := 0.25
## How far apart a person's feet land, across the line walked.
const GAUGE := 0.2
## The walker rig: a long stride and its feet set wide.
const RIG_STEP := 1.35
const RIG_GAUGE := 0.6
## The hover sled brushes a band this often.
const SWEEP_STEP := 0.4

var marks: TrackMarks
var path := TrackPath.new()
## [{at: Vector2, ground: int, row, shape, key, slot, wear, depth}]
var live: Array[Dictionary] = []
var _minutes := 0.0
var _wear_in := 0.0
var _speed := 0.0
var _last := Vector2.INF
var _leg := 0.8


func setup(g: Game) -> void:
	super.setup(g)
	marks = TrackMarks.new()
	marks.name = "track_marks"
	add_child(marks)
	# Before anybody walks: see TrackMarks.warm for why a lazily built mark is a
	# hitch at every border rather than a cost paid once at the start.
	TrackMarks.warm()
	# And the GROUP for the ground under the player, which the texture warm-up
	# above does not reach: without it the first footfall of a run compiles the
	# mark shader, measured at 15.2 ms in the frame the player takes their first
	# step. Warming the ground they are standing on makes that step free as well
	# as cheap.
	var here := TrackGround.of(g.world.ground_at(floori(g.player.pos.x), floori(g.player.pos.y)))
	if not here.is_empty():
		marks.warm_group(foot_shape(here), bool(here.white), float(here.rough))
	_minutes = g.clock.minutes


## What a FOOT leaves on this ground: its own print, or the scuff or flattening
## the ground turns one into. `_lay` and the warm-up both ask here, because a
## warm-up that guessed a different shape would build a group nobody uses and
## leave the one that is used to be built under a walking player -- which is the
## bug it exists to prevent, wearing a green light.
static func foot_shape(row: Dictionary) -> StringName:
	if row.is_empty() or row.mark == TrackGround.PRINT:
		return TrackPath.SHAPE_FOOT
	return StringName(row.mark)


func realm_changed(_from: StringName, _to: StringName) -> void:
	marks.clear()
	live.clear()
	path.reset()
	_last = Vector2.INF


func _process(delta: float) -> void:
	if game == null or game.player == null or game.world == null:
		return
	step(delta)


## One frame of it, for a test to drive without the tree.
func step(delta: float) -> void:
	var p := game.player
	var pos := p.pos
	if _last != Vector2.INF and delta > 0.0:
		_speed = lerpf(_speed, pos.distance_to(_last) / delta, 1.0 - exp(-10.0 * delta))
	_last = pos
	for m: Dictionary in path.feed(pos, _state()):
		_lay(m)
	_wear_in -= delta
	if _wear_in <= 0.0:
		_wear_in = WEAR_EVERY
		wear()


func _state() -> Dictionary:
	var p := game.player
	var hero: Hero = p.hero
	# A dodge is timed on the fight's own clock, not the wall's.
	var sim: FightSim = p.sim
	var s := {
		"swimming": hero != null and hero.swimming,
		"airborne": hero != null and hero.airborne,
		"dodging": hero != null and sim != null and hero.dodging(sim.now),
		"dodge_dir": hero.dodge_dir if hero != null else Vector2.ZERO,
		"gauge": GAUGE,
	}
	var ride: CraftRide = p.ride
	if ride == null:
		if p.model != null:
			var d := PersonBody.dims(p.model.look.build, int(p.model.look.gaunt))
			_leg = float(d.thigh) + float(d.shin) + float(d.boot)
		s["kind"] = TrackPath.SHAPE_FOOT
		# A person's step for their leg, a little longer the faster they go. Not the
		# walk animation's cycle: that covers the ground the game's pace asks of it,
		# over a tile a step, and a trail laid at that spacing read as a line of
		# single prints with nobody walking between them.
		s["step"] = _leg * (0.75 + 0.06 * clampf(_speed, 0.0, Tuning.RUN_SPEED))
	else:
		match ride.kind:
			&"walker_rig":
				s["kind"] = TrackPath.SHAPE_RIG
				s["step"] = RIG_STEP
				s["gauge"] = RIG_GAUGE
			&"hover_sled":
				s["kind"] = TrackPath.SHAPE_SWEEP
				s["step"] = SWEEP_STEP
			_:
				s["kind"] = &""
	return s


func _lay(m: Dictionary) -> void:
	var at: Vector2 = m.at
	var w := game.world
	var tx := floori(at.x)
	var ty := floori(at.y)
	if not w.in_bounds(tx, ty):
		return
	# Only on the terrace underfoot: a mark past a contour's edge would hang in air.
	var body := game.player.pos
	if w.level_at(tx, ty) != w.level_at(floori(body.x), floori(body.y)):
		return
	var ground := w.ground_at(tx, ty)
	var row := TrackGround.of(ground)
	if row.is_empty():
		return
	# Nothing is pressed into a board, a stone or a heap lying on the ground.
	for q: WorldProp in game.query.props_near(at, 1.0):
		if not w.depleted.has(q.id) and at.distance_to(q.pos) < maxf(q.solid, 0.3) + 0.12:
			return
	var shape := StringName(m.shape)
	# A boot on loose stones scuffs, on growth it only bends it down.
	if shape == TrackPath.SHAPE_FOOT:
		shape = foot_shape(row)
	var depth := float(row.depth)
	var placed := marks.lay(shape, bool(row.white), float(row.rough), w.to_3d(at), float(m.angle), depth)
	# The slot a new mark took is no longer the old mark's.
	for i in range(live.size() - 1, -1, -1):
		if live[i].key == placed[0] and live[i].slot == placed[1]:
			live.remove_at(i)
	live.append({"at": at, "ground": ground, "row": row, "shape": shape, "key": placed[0], "slot": placed[1], "wear": 0.0, "depth": depth})


## Wear every mark by the world time since the last wearing, under the weather
## falling where the player is. A night slept is a night's wear.
func wear() -> void:
	var now := game.clock.minutes
	var minutes := maxf(0.0, now - _minutes)
	_minutes = now
	if minutes <= 0.0 or live.is_empty():
		return
	var land := BiomeRegistry.at(game.world, game.player.pos)
	var weather := Weather.at_type(game.world.seed_value, now, land.id)
	for i in range(live.size() - 1, -1, -1):
		var mk: Dictionary = live[i]
		mk.wear = float(mk.wear) + TrackGround.wear(mk.row, minutes, weather)
		if float(mk.wear) >= 1.0:
			marks.fade(mk.key, mk.slot, 0.0)
			live.remove_at(i)
			continue
		marks.fade(mk.key, mk.slot, float(mk.depth) * (1.0 - float(mk.wear)))


func tour_seen(what: StringName) -> bool:
	var s := String(what)
	if s == "no_tracks":
		return live.is_empty()
	if s == "tracks":
		return not live.is_empty()
	if s.begins_with("tracks:"):
		# `tracks:mud|tracks:peat` asks for either.
		for one: String in s.split("|", false):
			var want := one.trim_prefix("tracks:")
			for mk: Dictionary in live:
				if String(mk.shape) == want or Ground.NAMES[int(mk.ground)].replace(" ", "_") == want:
					return true
	return false
