extends TestCase
## The score blending with the land: landscapes crossfade with equal power on
## the world's own weights, nothing restarts at a border, keys are chosen so
## neighbours modulate into each other, the whole score is heard within half a
## minute of waking, and a player moving faster than the bake never hears the
## score collapse.

const MusicSystem := preload("res://src/systems/75_music.gd")

const STEP := 0.25
## Where a layer counts as heard, matching 75_music.HEARD.
const HEARD := 0.3

static var _world: WorldData


static func _input(weights: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var d := {"weights": weights, "hour": 12.0, "weather": {"kind": &"clear", "strength": 0.0}, "danger": 0.0, "grid": 0.0}
	d.merge(extra, true)
	return d


static func _power(c: ScoreConductor) -> float:
	var p := 0.0
	for land: StringName in c.blend:
		p += float(c.blend[land]) * float(c.blend[land])
	return p


static func _sum(d: Dictionary) -> float:
	var s := 0.0
	for k: Variant in d:
		s += float(d[k])
	return s


static func _level(c: ScoreConductor, land: StringName, layer: StringName, v: int = 0) -> float:
	return float(c.levels.get(ScoreStems.key_for(land, layer, v), 0.0))


## The score's whole bed power: every landscape's drone and air together. This
## is what a collapse would empty out.
static func _bed(c: ScoreConductor) -> float:
	var p := 0.0
	for key: StringName in c.levels:
		var layer := ScoreConductor.layer_of(key)
		if layer == &"drone" or layer == &"texture":
			p += float(c.levels[key]) * float(c.levels[key])
	return sqrt(p)


static func _run(c: ScoreConductor, secs: float, input: Dictionary) -> void:
	for i in roundi(secs / STEP):
		c.tick(STEP, input)


# ------------------------------------------------------------------ the crossfade

## A border is a crossfade, not a switch: the shares always sum to one, the
## gains' squares always sum to one (so the score neither dips nor swells in the
## middle of an ecotone), and nothing ever moves in a step.
func test_a_border_is_an_equal_power_crossfade_that_never_steps() -> void:
	for pair: Array in [[&"coast", &"pinewood"], [&"coast", &"snowfield"], [&"moss", &"burning"]]:
		var c := ScoreConductor.new(5)
		_run(c, 60.0, _input({pair[0]: 1.0}))
		var was := c.blend.duplicate()
		var worst_step := 0.0
		var worst_power := 0.0
		var steps := roundi(90.0 / STEP)
		for i in steps:
			var u := float(i + 1) / steps
			c.tick(STEP, _input({pair[0]: 1.0 - u, pair[1]: u}))
			near(_sum(c.heard_weights), 1.0, 1e-4, "%s -> %s: the shares of the ear sum to one" % pair)
			worst_power = maxf(worst_power, absf(_power(c) - 1.0))
			for land: StringName in c.blend:
				worst_step = maxf(worst_step, absf(float(c.blend[land]) - float(was.get(land, 0.0))))
			was = c.blend.duplicate()
		lt(worst_power, 1e-4, "%s -> %s: equal power the whole way across (worst %.5f off)" % [pair[0], pair[1], worst_power])
		lt(worst_step, 0.02, "%s -> %s: no gain ever jumps (worst step %.4f)" % [pair[0], pair[1], worst_step])
		_run(c, 60.0, _input({pair[1]: 1.0}))
		near(float(c.blend.get(pair[1], 0.0)), 1.0, 1e-3, "%s -> %s: and the far side is whole again" % pair)


## Keys that share a tonal centre lean into each other across a whole ecotone;
## keys that stand far apart turn over in a shorter, marked stretch. Both are
## continuous: neither is a cut.
func test_far_keys_turn_over_in_a_shorter_stretch_than_near_ones() -> void:
	var near_pair: Array = [&"coast", &"pinewood"]
	var far_pair: Array = [&"coast", &"snowfield"]
	gt(ScoreLandscapes.affinity(near_pair[0], near_pair[1]), 0.7, "the coast and the pines are the same seven notes")
	lt(ScoreLandscapes.affinity(far_pair[0], far_pair[1]), 0.45, "the coast and the snowfield are not")
	var overlap := func(pair: Array) -> float:
		var c := ScoreConductor.new(5)
		_run(c, 40.0, _input({pair[0]: 1.0}))
		var both := 0
		var steps := roundi(120.0 / STEP)
		for i in steps:
			var u := float(i + 1) / steps
			c.tick(STEP, _input({pair[0]: 1.0 - u, pair[1]: u}))
			if float(c.blend.get(pair[0], 0.0)) > 0.35 and float(c.blend.get(pair[1], 0.0)) > 0.35:
				both += 1
		return both * STEP
	var near_s: float = overlap.call(near_pair)
	var far_s: float = overlap.call(far_pair)
	gt(near_s, 40.0, "a shared centre modulates slowly (%.0f s of overlap)" % near_s)
	lt(far_s, near_s * 0.8, "a far key turns over in a shorter stretch (%.0f s against %.0f s)" % [far_s, near_s])
	gt(far_s, 8.0, "but it is still a turn and not a cut (%.0f s)" % far_s)


## Every landscape's key stands near enough to the others to modulate into them,
## and a landscape nobody has written a score for picks its key from the same
## web instead of landing a tritone away from everything.
func test_every_key_stands_in_the_tonal_web() -> void:
	var ids := ScoreLandscapes.ids()
	for a in ids:
		near(ScoreLandscapes.affinity(a, a), 1.0, 1e-6, "%s: a landscape is its own key" % a)
		var best := 0.0
		for b in ids:
			if a == b:
				continue
			near(ScoreLandscapes.affinity(a, b), ScoreLandscapes.affinity(b, a), 1e-6, "%s and %s: affinity reads the same both ways" % [a, b])
			best = maxf(best, ScoreLandscapes.affinity(a, b))
		gt(best, 0.5, "%s has a neighbour it shares a centre with (best %.2f)" % [a, best])
	for id: StringName in [&"salt_flats", &"scrapwood", &"undercroft", &"orbital_yard", &"ruined_metropolis"]:
		var s := ScoreLandscapes.spec(id)
		gt(ScoreLandscapes.nearest_written(s), ScoreLandscapes.KEY_FLOOR * 0.8, "%s is composed into the web, not away from it" % id)
	var keys := {}
	for id: StringName in [&"salt_flats", &"scrapwood", &"undercroft", &"orbital_yard", &"ruined_metropolis", &"tailings", &"drowned_works"]:
		var s := ScoreLandscapes.spec(id)
		keys["%d %s" % [posmod(int(s["tonic"]), 12), s["mode"]]] = true
	gt(float(keys.size()), 3.0, "and composed landscapes still take keys of their own (%d of 7)" % keys.size())


# ------------------------------------------------------------------ never collapsing

## Moving faster than the bake — a teleport, a portal, a route through three
## small landscapes — leaves the score playing what it has. The bed never
## empties out, and the turn finishes as soon as the stems arrive.
func test_the_score_holds_what_it_has_until_the_next_landscape_can_sound() -> void:
	var c := ScoreConductor.new(8)
	_run(c, 90.0, _input({&"coast": 1.0}))
	var before := _bed(c)
	gt(before, 0.7, "the coast is playing")
	# Gone in one tick, and nothing of the moss is baked for twenty seconds.
	var worst := before
	for i in roundi(20.0 / STEP):
		c.tick(STEP, _input({&"moss": 1.0}, {"ready": {&"moss": 0.0}}))
		worst = minf(worst, _bed(c))
	gt(worst, before * 0.85, "the score keeps playing the coast rather than falling silent (%.2f of %.2f)" % [worst, before])
	gt(_level(c, &"coast", &"drone", 0), 0.6, "on the coast's own drone")
	lt(_level(c, &"moss", &"drone", 0), 0.02, "and nothing of the moss is forced through unbaked")
	# The drone arrives, then the air.
	for i in roundi(30.0 / STEP):
		c.tick(STEP, _input({&"moss": 1.0}, {"ready": {&"moss": 0.75}}))
		worst = minf(worst, _bed(c))
	_run(c, 40.0, _input({&"moss": 1.0}))
	gt(_level(c, &"moss", &"drone", 0), 0.7, "the moss takes over once it can")
	lt(_level(c, &"coast", &"drone", 0), 0.1, "and the coast lets go")
	gt(worst, before * 0.7, "with no hole anywhere in the turn (worst %.2f)" % worst)


## Half a landscape ready is half a crossfade: the ear is given back to whatever
## can sound, so an ecotone met too fast leans on the side that is baked.
func test_an_unbaked_neighbour_does_not_take_the_ear() -> void:
	var c := ScoreConductor.new(3)
	_run(c, 60.0, _input({&"coast": 1.0}))
	_run(c, 20.0, _input({&"coast": 0.5, &"moss": 0.5}, {"ready": {&"coast": 1.0, &"moss": 0.0}}))
	near(_power(c), 1.0, 1e-4, "the mix is still whole")
	gt(float(c.blend.get(&"coast", 0.0)), 0.95, "the coast still has the ear")
	check(not c.blend.has(&"moss") or float(c.blend[&"moss"]) < 0.1, "the moss is not mixed in silent")
	_run(c, 30.0, _input({&"coast": 0.5, &"moss": 0.5}))
	near(_power(c), 1.0, 1e-4, "and once it is baked the mix is still whole")
	gt(float(c.blend.get(&"moss", 0.0)), 0.6, "with the moss now half the ear")


## The whole score within half a minute of waking, not a minute and a half
## (playtest 14: the pulse arrived at 86 s).
func test_the_score_reaches_full_voice_in_seconds() -> void:
	for land: StringName in [&"coast", &"moss", &"bonelands"]:
		var c := ScoreConductor.new(2)
		var at := {}
		for i in roundi(60.0 / STEP):
			c.tick(STEP, _input({land: 1.0}))
			for layer: StringName in [&"drone", &"texture", &"pad", &"pulse"]:
				if at.has(layer):
					continue
				var sum := 0.0
				for v in int(ScoreStems.LAYERS[layer]["variants"]):
					sum += _level(c, land, layer, v)
				if sum >= HEARD:
					at[layer] = (i + 1) * STEP
		for layer: StringName in [&"drone", &"texture", &"pad", &"pulse"]:
			check(at.has(layer), "%s: the %s is heard inside a minute" % [land, layer])
		lt(float(at.get(&"drone", 99.0)), 12.0, "%s: the drone at once (%.0f s)" % [land, at.get(&"drone", 99.0)])
		lt(float(at.get(&"pad", 99.0)), 25.0, "%s: the pad soon after (%.0f s)" % [land, at.get(&"pad", 99.0)])
		lt(float(at.get(&"pulse", 99.0)), 40.0, "%s: full voice in %.0f s" % [land, at.get(&"pulse", 99.0)])


## Readiness and the landscapes ahead change nothing about determinism: the same
## world, the same walk, the same score.
func test_the_same_walk_gives_the_same_blend() -> void:
	var script := func(t: float) -> Dictionary:
		var u := clampf((t - 40.0) / 60.0, 0.0, 1.0)
		return _input({&"coast": 1.0 - u, &"pinewood": u}, {
			"ready": {&"coast": 1.0, &"pinewood": clampf((t - 30.0) / 20.0, 0.0, 1.0)},
			"soon": {&"pinewood": 0.4},
		})
	var a := ScoreConductor.new(31)
	var b := ScoreConductor.new(31)
	for i in roundi(180.0 / STEP):
		a.tick(STEP, script.call(i * STEP))
		b.tick(STEP, script.call(i * STEP))
	check(str(a.levels) == str(b.levels), "the same levels")
	check(str(a.blend) == str(b.blend), "the same blend")
	check(str(a.played) == str(b.played), "the same cues at the same moments")


## What the score bakes, in the order it will need it: the core of everywhere
## the ear reaches first, then the core of everywhere the player is walking
## toward, and only then the layers that fill a landscape out.
func test_the_landscapes_ahead_are_baked_before_their_border() -> void:
	var c := ScoreConductor.new(1)
	_run(c, 40.0, _input({&"coast": 1.0}, {"soon": {&"coast": 0.6, &"moss": 0.4}}))
	var wanted := c.wanted()
	var core := ScoreConductor.core_keys(&"coast", 12.0)
	eq(wanted[0], core[0], "the drone of the landscape underfoot comes first")
	check(wanted.slice(0, 2).has(core[1]), "with its air")
	for key in ScoreConductor.core_keys(&"moss", 12.0):
		check(wanted.has(key), "%s is baked before the border" % key)
		lt(float(wanted.find(key)), float(wanted.find(ScoreStems.key_for(&"coast", &"pad", 0))), "%s is asked for before a pad" % key)
	check(not wanted.has(ScoreStems.key_for(&"moss", &"pad", 0)), "but only the core of it: a landscape ahead is not a second score")
	var night := ScoreConductor.core_keys(&"coast", 23.0)
	eq(night[0], ScoreStems.key_for(&"coast", &"drone", 1), "at night the core is the night drone")


# ------------------------------------------------------------------ in the game

func _make() -> Array:
	if _world == null:
		_world = WorldGen.generate(11, 96)
	SoundBuses.ensure()
	var g := Game.new()
	g.world = _world
	g.query = WorldQuery.new(_world)
	g.clock = WorldClock.new(12.0)
	g.player = Player.new()
	g.player.pos = _world.spawn
	var sys: MusicSystem = MusicSystem.new()
	tree.root.add_child(sys)
	sys.setup(g)
	sys.set_process(false)
	sys.bank = SoundBank.new()
	sys.bank.threaded = false
	sys.bank.enabled = false
	return [sys, g]


func _done(parts: Array) -> void:
	var sys: Node = parts[0]
	var g: Game = parts[1]
	sys.free()
	g.player.free()
	g.free()


static func _stand_in(key: StringName) -> SoundBank.Baked:
	var b := SoundBank._header(key)
	b.samples.resize(b.rate * (2 if b.stereo else 1))
	for i in b.samples.size():
		b.samples[i] = 0.2 * sin(TAU * 440.0 * float(i) / b.rate)
	b.gain_db = -12.0
	return b


## Advance, baking only the keys in `bake` (everything, when it is empty).
func _advance(sys: MusicSystem, secs: float, bake: Array = []) -> void:
	for i in roundi(secs / STEP):
		for key in sys.conductor.wanted():
			if sys.bank.is_ready(key):
				continue
			if bake.is_empty() or bake.any(func(p: String) -> bool: return String(key).contains(p)):
				sys.bank.adopt(_stand_in(key))
		sys.advance(STEP)


## Crossing a border moves levels, never players: a loop that is sounding is
## started once and is still the same player, still playing, on the far side.
func test_nothing_restarts_at_a_border() -> void:
	var parts := _make()
	var sys: MusicSystem = parts[0]
	_advance(sys, 40.0)
	var here := sys.heard_lands()
	gt(float(here.size()), 0.0, "a landscape is sounding")
	var key := ScoreStems.key_for(here[0], &"drone", 0)
	var player: AudioStreamPlayer = sys.players.get(key)
	check(player != null, "its drone is playing")
	var id := player.get_instance_id()
	var broke := false
	for i in roundi(60.0 / STEP):
		var u := clampf(float(i) * STEP / 45.0, 0.0, 1.0)
		sys.inputs["weights"] = {here[0]: 1.0 - u * 0.5, &"pinewood": u * 0.5}
		sys.inputs["ready"] = {here[0]: 1.0, &"pinewood": 1.0}
		for k in sys.conductor.wanted():
			if not sys.bank.is_ready(k):
				sys.bank.adopt(_stand_in(k))
		sys.conductor.tick(STEP, sys.inputs)
		sys._mix(STEP)
		var p: AudioStreamPlayer = sys.players.get(key)
		broke = broke or p == null or not p.playing or p.get_instance_id() != id
	check(not broke, "the drone that was playing never stopped or started again")
	gt(float(sys.heard_lands().size()), 1.0, "and both landscapes are sounding at the border")
	check(sys.tour_seen("score_blend"), "which is what a tour sees as a blend")
	_done(parts)


## A stem that arrives late slides in under what is playing instead of appearing
## at its full level.
func test_a_stem_baked_late_slides_in() -> void:
	var parts := _make()
	var sys: MusicSystem = parts[0]
	_advance(sys, 40.0, ["drone", "texture"])
	var land := sys.heard_lands()[0]
	var pad := ScoreStems.key_for(land, &"pad", 0)
	gt(float(sys.conductor.levels.get(pad, 0.0)), 0.2, "the form wants a pad")
	check(not sys.players.has(pad), "but it has not been baked, so nothing plays it")
	sys.bank.adopt(_stand_in(pad))
	sys.advance(STEP)
	var quiet := float((sys.players[pad] as AudioStreamPlayer).volume_db)
	lt(float(sys._fade[pad]), 0.3, "when it arrives it starts from silence, not at its level")
	_advance(sys, 4.0)
	near(float(sys._fade[pad]), 1.0, 1e-6, "and is all the way in within seconds")
	gt(float((sys.players[pad] as AudioStreamPlayer).volume_db), quiet + 8.0, "which is a rise a listener hears as a fade, not a cut")
	_done(parts)


## The score keeps a running account of itself, and a tour can fail on it.
func test_the_score_reports_whether_it_ever_broke() -> void:
	var parts := _make()
	var sys: MusicSystem = parts[0]
	check(not sys.tour_seen("score_unbroken"), "it claims nothing a second into a game")
	_advance(sys, 45.0)
	check(sys.tour_seen("score_unbroken"), "after a clean minute it says so")
	check(sys.tour_seen("score_full"), "with the whole score heard")
	gt(sys.first_voice, 0.0, "it knows when it first sounded")
	lt(sys.worst_gap, MusicSystem.GAP_BUDGET, "and that it never fell silent")
	# Silence it by hand: the account notices.
	for key: StringName in sys.players.keys():
		(sys.players[key] as AudioStreamPlayer).stop()
		sys.players[key].queue_free()
		sys.players.erase(key)
	sys.bank.enabled = false
	sys.bank._done.clear()
	for i in roundi(6.0 / STEP):
		sys.conductor.tick(STEP, sys.inputs)
		sys.seconds += STEP
		sys._mix(STEP)
	gt(sys.worst_gap, MusicSystem.GAP_BUDGET, "a silence of seconds is a collapse (%.1f s)" % sys.worst_gap)
	check(not sys.tour_seen("score_unbroken"), "and it stays reported")
	_done(parts)


## The cores of the landscapes around the player are held in memory whatever
## else is let go, so turning back at a border is never met with silence.
func test_a_landscape_within_reach_never_loses_its_core() -> void:
	var parts := _make()
	var sys: MusicSystem = parts[0]
	_advance(sys, 30.0)
	var land := sys.heard_lands()[0]
	var core := ScoreConductor.core_keys(land, 12.0)
	var stray := ScoreStems.key_for(land, &"motif", 0)
	sys.bank.adopt(_stand_in(stray))
	sys._heard_at[stray] = sys.seconds
	sys.seconds += MusicSystem.FORGET_AFTER + 10.0
	sys._forget_unheard()
	for key in core:
		check(sys.bank.is_ready(key), "%s is still in hand" % key)
	check(not sys.bank.is_ready(stray), "a stem nothing needs is let go")
	_done(parts)


## Without worker threads (a browser with no SharedArrayBuffer) the heavier bake
## the blend asks for — the cores of the landscapes ahead as well as the one
## underfoot — is still built a slice at a time, and no frame runs long.
func test_without_threads_the_blends_bakes_never_hold_a_frame() -> void:
	var root := "user://score_blend_budget_%d" % Time.get_ticks_usec()
	var cut := func(key: StringName) -> ScoreRender:
		var j := ScoreStems.job(key, 1)
		j.frames = roundi(0.6 * j.rate)
		return j
	var bank := SoundBank.new()
	bank.threaded = false
	bank.score_job = cut
	bank.use_disk_cache(root)
	var keys: Array[StringName] = []
	for land: StringName in [&"coast", &"moss", &"pinewood"]:
		keys.append_array(ScoreConductor.core_keys(land, 12.0))
	for key in keys:
		bank.request(key)
	var worst := 0
	var frames := 0
	while bank.pending() > 0 and frames < 60000:
		bank._pumped_frame = -1
		bank.pump()
		worst = maxi(worst, bank.last_pump_usec)
		frames += 1
	for key in keys:
		check(bank.is_ready(key), "%s was built" % key)
	gt(float(frames), 20.0, "across many frames, not in one (%d)" % frames)
	lt(float(worst), float(SoundBank.SCORE_BUDGET_USEC * 4), "no frame held for long (worst %d us)" % worst)
	for key in keys:
		DirAccess.remove_absolute(bank._cache_path(key))
	var dir := DirAccess.open(root)
	if dir != null:
		for d in dir.get_directories():
			DirAccess.remove_absolute(root.path_join(d))
		DirAccess.remove_absolute(root)
