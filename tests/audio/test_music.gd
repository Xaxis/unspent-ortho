extends TestCase
## The figure: the same four notes everywhere, harmony and instrument by
## country, played rarely (on arriving, at some dawns and dusks, never over
## itself, never soon after the last time).

const Fixture := preload("res://tests/audio/audio_fixture.gd")
const MusicSystem := preload("res://src/systems/75_music.gd")


func test_the_figure_is_four_notes_and_every_country_reharmonises_it() -> void:
	var notes: Array[int] = []
	for n: Array in SoundMusic.FIGURE:
		notes.append(int(n[2]))
	eq(notes, [62, 69, 67, 71] as Array[int], "D A G B")
	for c: StringName in SoundMusic.COUNTRIES:
		var spec: Dictionary = SoundMusic.COUNTRIES[c]
		eq((spec["chords"] as Array).size(), 3, "%s has three chords" % c)
		check(spec.has("lead") and spec.has("pad") and spec.has("answer"), "%s spec" % c)
	var leads := {}
	for c: StringName in SoundMusic.COUNTRIES:
		leads[SoundMusic.COUNTRIES[c]["lead"]] = true
	eq(leads.size(), SoundMusic.COUNTRIES.size(), "each country plays it on its own instrument")
	eq(SoundMusic.name_for(Country.SEA), &"music_coast", "at sea it is the coast's")


func test_the_figure_can_be_heard_in_a_phrase() -> void:
	var b := Fixture.baked(&"music_burning:0")
	var bar := Synth.samples(b.rate, 4.0 * 60.0 / SoundMusic.BPM)
	var off := Synth.tone_level(b.samples, b.rate, 349.23, 0, bar)
	for f: float in [293.66, 440.0, 392.0, 493.88]:
		var on := Synth.tone_level(b.samples, b.rate, f, 0, bar)
		gt(on, off * 3.0, "figure note %.0f Hz (on %.4f, off-note %.4f)" % [f, on, off])


## The burning drone is a line under the figure, not a wall at 120-500 Hz.
func test_the_burning_phrase_leaves_room_under_the_figure() -> void:
	var b := Fixture.baked(&"music_burning:0")
	# Energy below 250 Hz over the whole phrase (an eighth-order split; a
	# second-order band leaks the figure's own D4 into the measure). It was 0.24
	# with the full organ and the brass doubled an octave down; the coast's is 0.03.
	var low := Synth.low_energy_ratio(b.samples, b.rate, 250.0, 8.0)
	lt(low, 0.08, "the phrase's weight is not under 250 Hz (%.3f of its energy)" % low)


func test_dawn_and_dusk_are_crossed_once_including_past_midnight() -> void:
	check(MusicSystem._crossed(5.9, 6.05, 6.0), "dawn crossed")
	check(not MusicSystem._crossed(6.05, 6.2, 6.0), "not crossed again")
	check(not MusicSystem._crossed(-1.0, 6.2, 6.0), "not on the first frame")
	check(MusicSystem._crossed(23.9, 0.1, 0.0), "midnight wrap")
	check(not MusicSystem._crossed(23.0, 0.5, 6.0), "wrap without passing dawn")
	check(MusicSystem._approaching(5.6, 6.0, 0.6), "dawn is near")
	check(not MusicSystem._approaching(6.1, 6.0, 0.6), "dawn has passed")


func test_music_is_rare() -> void:
	var w := WorldGen.generate(11, 96)
	var g := Game.new()
	g.world = w
	g.clock = WorldClock.new(12.0)
	g.player = Player.new()
	g.player.pos = w.spawn
	var sys: MusicSystem = MusicSystem.new()
	tree.root.add_child(sys)
	sys.setup(g)
	sys.set_process(false)
	sys.bank = SoundBank.new()
	sys.bank.threaded = false
	var key := SoundMusic.name_for(int(SoundMix.dominant_country(w, w.spawn)["country"]))
	var phrase := Fixture.baked(&"music_burning:0")
	# Any phrase will do for timing; hand it over under the name the system wants.
	var stand_in := SoundBank.Baked.new()
	stand_in.key = SoundBank.key_for(key, 0)
	stand_in.rate = phrase.rate
	stand_in.samples = phrase.samples
	sys.bank.adopt(stand_in)
	for i in 5:
		sys.advance(1.0)
	eq(sys.played.size(), 0, "not in the first seconds")
	for i in 10:
		sys.advance(1.0)
	eq(sys.played.size(), 1, "once on waking")
	sys.player.stop()
	for i in 600:
		sys.advance(1.0)
	lt(float(sys.played.size()), 2.5, "at most once more in ten minutes at noon in one country")
	sys.free()
	g.player.free()
	g.free()


class FakeMob:
	extends Node
	var kind: StringName = &"dog.yard"
	var pos: Vector2
	var alive := true


func _music(w: WorldData) -> Array:
	var g := Game.new()
	g.world = w
	g.clock = WorldClock.new(12.0)
	g.player = Player.new()
	g.player.pos = w.spawn
	var sys: MusicSystem = MusicSystem.new()
	tree.root.add_child(sys)
	sys.setup(g)
	sys.set_process(false)
	sys.bank = SoundBank.new()
	sys.bank.threaded = false
	var phrase := Fixture.baked(&"music_burning:0")
	for c: int in Country.LAND:
		for mood in 3:
			var stand_in := SoundBank.Baked.new()
			stand_in.key = SoundBank.key_for(SoundMusic.name_for(c), mood)
			stand_in.rate = phrase.rate
			stand_in.samples = phrase.samples
			sys.bank.adopt(stand_in)
	return [sys, g]


func _free(parts: Array) -> void:
	var sys: Node = parts[0]
	var g: Game = parts[1]
	sys.free()
	g.player.free()
	g.free()


func test_the_figure_waits_out_a_fight() -> void:
	var parts := _music(WorldGen.generate(11, 96))
	var sys: MusicSystem = parts[0]
	var g: Game = parts[1]
	eq(sys.process_mode, Node.PROCESS_MODE_ALWAYS, "the phrase does not freeze on the pause page")
	var dog := FakeMob.new()
	dog.pos = g.player.pos + Vector2(6, 0)
	tree.root.add_child(dog)
	dog.add_to_group(&"mobs")
	for i in 15:
		sys.advance(1.0)
	eq(sys.played.size(), 0, "not with a dog six tiles off")
	dog.alive = false
	for i in 15:
		sys.advance(1.0)
	eq(sys.played.size(), 1, "once it is down, the arrival can be heard")
	dog.free()
	_free(parts)


func test_getting_up_from_sleep_is_a_moment() -> void:
	var parts := _music(WorldGen.generate(11, 96))
	var sys: MusicSystem = parts[0]
	var g: Game = parts[1]
	sys.last_played = -INF
	g.clock.skip(18.0 * 60.0)
	Events.time_skipped.emit(18.0 * 60.0, &"sleep")
	eq(sys.played.size(), 1, "woke to the figure")
	check(String(sys.played[0]).ends_with(":1"), "in the morning it is the dawn phrase: %s" % sys.played[0])
	sys.player.stop()
	Events.time_skipped.emit(30.0, &"work")
	eq(sys.played.size(), 1, "work is not a moment, and it is too soon anyway")
	_free(parts)
