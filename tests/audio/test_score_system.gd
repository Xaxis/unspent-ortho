extends TestCase
## The score in a running game (75_music): it listens to the world (landscape,
## machines closing in, a blow, an installation, a sentinel), plays the stems the
## conductor asks for once they are baked, keeps them on the bar lines, and a
## browser without threads builds them a slice a frame without a long frame.

const MusicSystem := preload("res://src/systems/75_music.gd")
const Fixture := preload("res://tests/audio/audio_fixture.gd")

static var _world: WorldData


class FakeMob:
	extends Node
	var kind: StringName = &"watcher"
	var pos: Vector2
	var alive := true
	var hostile := true
	var aware := true


## A mob that says nothing of noticing, only through its state's mood.
class QuietMob:
	extends Node
	var kind: StringName = &"runner"
	var pos: Vector2
	var alive := true
	var hostile := true
	var state := MobState.new()


class FakeSentinel:
	extends Node
	var pos: Vector2
	var reach := 20.0
	var alive := true
	var land: StringName = &"coast"


## A one-second stand-in for any stem, so a system can play what it wants at once.
static func _stand_in(key: StringName) -> SoundBank.Baked:
	var b := SoundBank._header(key)
	var frames := b.rate
	b.samples.resize(frames * (2 if b.stereo else 1))
	for i in b.samples.size():
		b.samples[i] = 0.2 * sin(TAU * 440.0 * float(i) / b.rate)
	b.gain_db = -12.0
	return b


func _make() -> Array:
	if _world == null:
		_world = WorldGen.generate(11, 96)
	# The running game's buses (70_audio makes them before the score starts).
	SoundBuses.ensure()
	var g := Game.new()
	g.world = _world
	g.query = WorldQuery.new(_world)
	g.clock = WorldClock.new(12.0)
	g.player = Player.new()
	g.player.pos = _world.spawn
	var sys: MusicSystem = MusicSystem.new()
	tree.root.add_child(sys)
	var t0 := Time.get_ticks_usec()
	sys.setup(g)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	sys.set_process(false)
	sys.bank = SoundBank.new()
	sys.bank.threaded = false
	# Everything the score asks for is ready at once: this test is about playing, not baking.
	sys.bank.enabled = false
	return [sys, g, ms]


func _done(parts: Array) -> void:
	var sys: Node = parts[0]
	var g: Game = parts[1]
	sys.free()
	g.player.free()
	g.free()


## Advance, handing the bank a stand-in for anything the conductor wants.
func _advance(sys: MusicSystem, secs: float, step: float = 0.25) -> void:
	for i in roundi(secs / step):
		for key in sys.conductor.wanted():
			if not sys.bank.is_ready(key):
				sys.bank.adopt(_stand_in(key))
		sys.advance(step)


func test_setup_does_no_sound_work() -> void:
	var parts := _make()
	lt(float(parts[2]), 50.0, "the score's setup costs the start nothing (%.1f ms)" % parts[2])
	var sys: MusicSystem = parts[0]
	eq(sys.process_mode, Node.PROCESS_MODE_ALWAYS, "the score does not stop on the pause page")
	check(SaveGame.keys().has(&"score"), "the score saves itself")
	_done(parts)


func test_the_score_plays_the_landscape_underfoot_on_the_bar_lines() -> void:
	var parts := _make()
	var sys: MusicSystem = parts[0]
	var g: Game = parts[1]
	check(not sys.tour_seen("score"), "silent before anything is baked")
	_advance(sys, 30.0)
	var here := sys._land_id(int(SoundMix.dominant_country(g.world, g.player.pos)["country"]))
	var drone := ScoreStems.key_for(here, &"drone", 0)
	check(sys.players.has(drone), "the drone of %s is playing" % here)
	check(sys.tour_seen("score"), "a tour can hear it")
	var p: AudioStreamPlayer = sys.players[drone]
	eq(p.bus, &"Music", "on the Music bus")
	near(p.volume_db, sys.bank.get_baked(drone).gain_db + linear_to_db(float(sys.conductor.levels[drone])), 0.01, "at the conductor's level")
	near(sys._loop_position(4.8), fposmod(sys.conductor.time + sys._sync, 4.8), 1e-6, "a new loop starts at the music clock's place in it")
	_done(parts)


## The nearest spot where ONE landscape really has the ear. Asked of
## `SoundMix.land_share` itself and not of `WorldData.blend`: the share is an
## average over rings around the listener (`EAR_RADII`), so a tile whose own
## blend is zero can still be inside earshot of two borders and split the ear
## between them. Using blend as the proxy made this WORSE -- 0.26 against the
## 0.40 it started from -- which is the whole lesson of asking the thing that
## decides rather than something that correlates with it.
func _ear_core(g: Game, from: Vector2) -> Vector2:
	var w := g.world
	for r in range(0, 90, 3):
		for a in 24:
			var p: Vector2 = from + Vector2.from_angle(TAU * float(a) / 24.0) * float(r)
			var x := floori(p.x)
			var y := floori(p.y)
			if not w.in_bounds(x, y) or w.level[y * w.size + x] <= 0 or not g.query.standable(x, y):
				continue
			var share := SoundMix.land_share(w, p)
			var top := 0.0
			for c: Variant in share:
				top = maxf(top, float(share[c]))
			if top >= 0.8:
				return Vector2(x + 0.5, y + 0.5)
	return Vector2.INF


func test_machines_closing_in_quicken_the_score_and_a_blow_holds_it() -> void:
	var parts := _make()
	var sys: MusicSystem = parts[0]
	var g: Game = parts[1]
	_advance(sys, 20.0)
	var mob := FakeMob.new()
	mob.pos = g.player.pos + Vector2(60, 0)
	tree.root.add_child(mob)
	mob.add_to_group(&"mobs")
	_advance(sys, 1.0)
	eq(float(sys.inputs["danger"]), 0.0, "a machine far off is no danger")
	mob.pos = g.player.pos + Vector2(30, 0)
	_advance(sys, 1.0)
	eq(float(sys.inputs["near"]), 1.0, "but within earshot its tense stems are baked")
	mob.pos = g.player.pos + Vector2(5, 0)
	_advance(sys, 5.0)
	eq(float(sys.inputs["danger"]), 1.0, "close, it is danger")
	# **ASKED IN A LANDSCAPE'S CORE, NOT ON ITS BORDER.** The quick pulse's level
	# is `share * share` (ScoreConductor._targets_for), and a player standing in
	# an ECOTONE has their ear split between two landscapes -- measured here at
	# share 0.63, so the stem settled at 0.398 and could never reach a 0.5 bar
	# however long the machine stood over them or however loud the danger. The
	# claim is about what DANGER does to the score, so it is asked where one
	# landscape has the ear: the blend field is zero in a core and rises toward a
	# border (WorldData.blend, 0.5 on the line itself).
	var core := _ear_core(g, g.player.pos)
	check(core.is_finite(), "somewhere in this world one landscape has the whole ear")
	if core.is_finite():
		g.player.pos = core
		mob.pos = core + Vector2(5, 0)
		_advance(sys, 6.0)
	var here := sys._land_id(int(SoundMix.dominant_country(g.world, g.player.pos)["country"]))
	gt(float(sys.conductor.levels.get(ScoreStems.key_for(here, &"pulse", 1), 0.0)), 0.5, "the pulse has quickened")
	check(sys.tour_seen("score_tense"), "and a tour hears it")
	mob.hostile = false
	_advance(sys, 1.0)
	eq(float(sys.inputs["danger"]), 0.0, "an indifferent machine is no danger")
	Events.hit.emit(mob, g.player, 2, false, Vector3.ZERO)
	_advance(sys, 1.0)
	eq(float(sys.inputs["danger"]), 1.0, "a blow on the player is")
	mob.free()
	_done(parts)


static func _resolves(sys: MusicSystem) -> int:
	return sys.conductor.played.filter(func(p: Array) -> bool: return String(p[1]).contains("_resolve")).size()


## A machine that has not noticed you is presence, not danger: the score bakes
## ahead and says nothing, so it never cries wolf or gives an unseen machine away.
func test_only_a_machine_that_has_noticed_you_is_danger() -> void:
	var parts := _make()
	var sys: MusicSystem = parts[0]
	var g: Game = parts[1]
	_advance(sys, 60.0)
	var here := sys._land_id(int(SoundMix.dominant_country(g.world, g.player.pos)["country"]))
	var tense := ScoreStems.key_for(here, &"pulse", 1)
	var uneasy := ScoreStems.key_for(here, &"dissonance", 0)
	var mob := FakeMob.new()
	mob.aware = false
	mob.pos = g.player.pos + Vector2(6, 0)
	tree.root.add_child(mob)
	mob.add_to_group(&"mobs")
	var resolves := _resolves(sys)
	_advance(sys, 20.0)
	eq(float(sys.inputs["danger"]), 0.0, "an idle machine six tiles off is no danger")
	eq(float(sys.inputs["near"]), 1.0, "but it is near: its tense stems are baked")
	check(sys.conductor.wanted().has(tense), "the quick pulse is baked ahead")
	lt(float(sys.conductor.levels.get(tense, 0.0)), 0.01, "and not heard")
	lt(float(sys.conductor.levels.get(uneasy, 0.0)), 0.01, "no dissonance")
	mob.pos = g.player.pos + Vector2(60, 0)
	_advance(sys, 40.0)
	eq(_resolves(sys), resolves, "nothing to resolve when you walk off")
	mob.free()
	# Without `aware`, a mob's mood says it.
	var quiet := QuietMob.new()
	quiet.pos = g.player.pos + Vector2(6, 0)
	tree.root.add_child(quiet)
	quiet.add_to_group(&"mobs")
	quiet.state.mood = MobState.WORKING
	_advance(sys, 1.0)
	eq(float(sys.inputs["danger"]), 0.0, "a working machine is no danger")
	quiet.state.mood = MobState.CHASING
	_advance(sys, 1.0)
	gt(float(sys.inputs["danger"]), 0.9, "a chasing one is")
	quiet.free()
	_advance(sys, 40.0)
	# A hostile animal that has seen you: a little quicker, never uneasy.
	resolves = _resolves(sys)
	var dog := FakeMob.new()
	dog.kind = &"dog"
	dog.pos = g.player.pos + Vector2(4, 0)
	tree.root.add_child(dog)
	dog.add_to_group(&"mobs")
	_advance(sys, 20.0)
	near(float(sys.inputs["danger"]), MusicSystem.BEAST_SHARE, 0.01, "a dog is a share of the danger")
	lt(float(sys.conductor.levels.get(tense, 0.0)), 0.4, "the pulse only a little quicker")
	lt(float(sys.conductor.levels.get(uneasy, 0.0)), 0.02, "no dissonance for a dog")
	Events.hit.emit(dog, g.player, 1, false, Vector3.ZERO)
	_advance(sys, 1.0)
	near(float(sys.inputs["danger"]), MusicSystem.BEAST_SHARE, 0.01, "nor for its bite")
	dog.free()
	_advance(sys, 40.0)
	eq(_resolves(sys), resolves, "and nothing to resolve after a dog")
	_done(parts)


func test_an_installation_and_a_sentinel_are_heard() -> void:
	var parts := _make()
	var sys: MusicSystem = parts[0]
	var g: Game = parts[1]
	var pylon := WorldProp.new(900001, PropKind.PYLON, g.player.pos + Vector2(2, 0), 0.0, 1.0)
	g.world.add_prop(pylon)
	g.query.add_prop(pylon)
	var s := FakeSentinel.new()
	s.pos = g.player.pos + Vector2(4, 0)
	tree.root.add_child(s)
	s.add_to_group(&"sentinels")
	_advance(sys, 20.0)
	gt(float(sys.inputs["grid"]), 0.9, "a pylon beside you is the whole grid")
	check(sys.tour_seen("score_grid"), "its pulse is heard")
	gt(float((sys.inputs["sentinel"] as Dictionary)["strength"]), 0.9, "inside a sentinel's reach")
	check(sys.cues_played.any(func(k: StringName) -> bool: return String(k).ends_with("_motif")), "its motif played")
	s.free()
	g.query.remove_prop(pylon)
	_done(parts)


## A stem baked ahead for a machine that never came leaves memory once it has
## been neither wanted nor heard for FORGET_AFTER; what is playing stays.
func test_stems_neither_heard_nor_wanted_are_let_go() -> void:
	var parts := _make()
	var sys: MusicSystem = parts[0]
	var g: Game = parts[1]
	var mob := FakeMob.new()
	mob.aware = false
	mob.pos = g.player.pos + Vector2(30, 0)
	tree.root.add_child(mob)
	mob.add_to_group(&"mobs")
	_advance(sys, 10.0)
	var here := sys._land_id(int(SoundMix.dominant_country(g.world, g.player.pos)["country"]))
	var tense := ScoreStems.key_for(here, &"pulse", 1)
	var drone := ScoreStems.key_for(here, &"drone", 0)
	check(sys.bank.is_ready(tense), "the quick pulse is baked ahead for the machine near")
	mob.free()
	_advance(sys, MusicSystem.FORGET_AFTER - 20.0, 1.0)
	check(sys.bank.is_ready(tense), "kept a while after it stops being wanted")
	_advance(sys, 40.0, 1.0)
	check(not sys.bank.is_ready(tense), "then let go")
	check(sys.bank.is_ready(drone), "the drone that plays is kept")
	_done(parts)


func test_night_closes_the_scores_low_pass() -> void:
	SoundBuses.ensure()
	var parts := _make()
	var sys: MusicSystem = parts[0]
	var g: Game = parts[1]
	_advance(sys, 2.0)
	var day := SoundBuses.music_lowpass().cutoff_hz
	g.clock.minutes = 23.5 * 60.0
	_advance(sys, 2.0)
	lt(SoundBuses.music_lowpass().cutoff_hz, day * 0.5, "deeper at night")
	g.clock.minutes = 12.0 * 60.0
	_advance(sys, 1.0)
	_done(parts)


## A small stem under a real score key, so the no-thread bank can be watched
## building one across frames.
static func _small_job(key: StringName, _bars: int = 0) -> ScoreRender:
	var j := ScoreRender.new(key, 16000, true, true, roundi(0.6 * 16000))
	j.highpass = 110.0
	j.hold(ScoreVoices.Analog, {"freqs": [220.0, 330.0], "unison": 2, "detune": 6.0, "cut": 900.0})
	j.note(0.1, ScoreVoices.Fm, {"freq": 660.0, "ratio": 3.5, "index": 2.0, "hold": 0.2, "r": 0.2})
	j.fx(ScoreFx.Hall, {"t60": 0.5, "wet": 0.3})
	return j


func test_without_threads_the_score_is_built_a_slice_a_frame() -> void:
	var bank := SoundBank.new()
	bank.threaded = false
	bank.keep_samples = true
	bank.score_job = _small_job
	var key := &"score_coast_grid"
	check(bank.bakes_here(key), "a score stem may bake on the main thread")
	bank.request(key)
	eq(bank.pending(), 1, "queued")
	var frames := 0
	while not bank.is_ready(key) and frames < 5000:
		bank._pumped_frame = -1
		bank.pump()
		frames += 1
	check(bank.is_ready(key), "it is built")
	gt(float(frames), 3.0, "over many frames (%d)" % frames)
	var whole := _small_job(key)
	whole.run()
	check(bank.get_baked(key).samples == whole.samples, "the same samples as built in one go")
	check(bank.get_baked(key).stream.stereo, "a stereo stream")
	eq(bank.pending(), 0, "nothing left")


## A real stem cut to under a second: its own voices and effects, so its
## blocks cost what the real one's do, over a loop short enough to try again.
static func _cut(key: StringName, _bars: int = 0) -> ScoreRender:
	var j := ScoreStems.job(key, 1)
	j.frames = roundi(0.8 * j.rate)
	return j


## The thickest pad and a drone (its long high-pass priming), cut short, built by
## a no-thread bank that keeps a disk cache: no frame, the finishing ones
## included, does more than a few units of work or runs past the budget.
func test_without_threads_no_frame_waits_on_a_real_stem() -> void:
	var root := "user://score_budget_test_%d" % Time.get_ticks_usec()
	for key: StringName in [ScoreStems.key_for(&"burning", &"pad", 1), ScoreStems.key_for(&"coast", &"drone", 0)]:
		# A lambda copies what it captures, so what it reports comes back in an array.
		var built := [false]
		var build := func() -> Array:
			var bank := SoundBank.new()
			bank.threaded = false
			bank.score_job = _cut
			bank.use_disk_cache(root)
			bank.request(key)
			var times := PackedInt32Array()
			var units := PackedInt32Array()
			while not bank.is_ready(key) and times.size() < 20000:
				bank._pumped_frame = -1
				bank.pump()
				times.append(bank.last_pump_usec)
				units.append(bank.last_pump_units)
			built[0] = bank.is_ready(key)
			# The next run must build it again, not read what this one wrote.
			DirAccess.remove_absolute(bank._cache_path(key, bank.score_bars(key)))
			return [times, units]
		Fixture.judge_frames(self, build, String(key))
		check(built[0], "%s is built" % key)
	var dir := DirAccess.open(root)
	if dir != null:
		for d in dir.get_directories():
			DirAccess.remove_absolute(root.path_join(d))
		DirAccess.remove_absolute(root)
