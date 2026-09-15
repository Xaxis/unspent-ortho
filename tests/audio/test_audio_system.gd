extends TestCase
## The running mix, driven with explicit time: footfalls from how far the player
## moved, one-shots routed by distance, unknown names ignored, beds rising for
## the country underfoot, and only the loudest machine heard.

const Fixture := preload("res://tests/audio/audio_fixture.gd")
const AudioSystem := preload("res://src/systems/70_audio.gd")

static var _world: WorldData


class FakeMob:
	extends Node
	var kind: StringName
	var pos: Vector2
	var alive := true


func _make() -> Array:
	if _world == null:
		_world = WorldGen.generate(11, 96)
	var g := Game.new()
	g.world = _world
	g.query = WorldQuery.new(_world)
	g.clock = WorldClock.new(12.0)
	g.player = Player.new()
	g.player.world = _world
	g.player.query = g.query
	g.player.pos = _world.spawn
	var sys: AudioSystem = AudioSystem.new()
	tree.root.add_child(sys)
	var t0 := Time.get_ticks_usec()
	sys.setup(g)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	sys.set_process(false)
	sys.set_physics_process(false)
	return [sys, g, ms]


func _done(parts: Array) -> void:
	var sys: Node = parts[0]
	var g: Game = parts[1]
	sys.free()
	g.player.free()
	g.free()


func _adopt(sys: AudioSystem, name: StringName) -> void:
	for v in maxi(1, SoundBank.variants(name)):
		var key := SoundBank.key_for(name, v)
		if not sys.bank.is_ready(key):
			var b := Fixture.baked(key)
			var copy := SoundBank.Baked.new()
			copy.key = b.key
			copy.rate = b.rate
			copy.loop = b.loop
			copy.bus = b.bus
			copy.gain_db = b.gain_db
			copy.samples = b.samples
			sys.bank.adopt(copy)


func test_setup_is_cheap() -> void:
	var parts := _make()
	lt(float(parts[2]), 300.0, "audio setup must stay under 300 ms")
	_done(parts)


func test_unknown_names_are_ignored_silently() -> void:
	var parts := _make()
	var sys: AudioSystem = parts[0]
	var before := sys.history.size()
	sys.play(&"no_such_sound", Vector3.ZERO)
	Events.sfx.emit(&"also_not_a_sound", Vector3(1, 0, 1))
	eq(sys.history.size(), before, "nothing played")
	_done(parts)


func test_one_shots_route_by_distance_and_kind() -> void:
	var parts := _make()
	var sys: AudioSystem = parts[0]
	var g: Game = parts[1]
	_adopt(sys, &"hit_plate")
	_adopt(sys, &"ui_accept")
	var p := g.player.pos
	Events.sfx.emit(&"hit_plate", Vector3(p.x + 1.0, 0.0, p.y))
	eq(sys.history.back()["bus"], &"SFX", "a blow beside you is dry")
	var near_db: float = sys.history.back()["db"]
	sys.play(&"hit_plate", Vector3(p.x + 20.0, 0.0, p.y))
	eq(sys.history.back()["bus"], &"SfxFar", "a blow 20 tiles off is dull and wet")
	lt(float(sys.history.back()["db"]), near_db, "and quieter")
	sys.play(&"ui_accept", Vector3.ZERO)
	eq(sys.history.back()["bus"], &"UI", "interface on its own bus")
	var count := sys.history.size()
	sys.play(&"hit_plate", Vector3(p.x + 60.0, 0.0, p.y))
	eq(sys.history.size(), count, "out of earshot is not played")
	_done(parts)


func test_footfalls_come_from_distance_moved() -> void:
	var parts := _make()
	var sys: AudioSystem = parts[0]
	var g: Game = parts[1]
	var family := SoundEffects.step_name(g.world.ground_at(floori(g.player.pos.x), floori(g.player.pos.y)))
	_adopt(sys, family)
	var dt := 1.0 / 60.0
	for i in 60:
		sys.footfalls(dt)
	eq(sys.steps, 0, "standing still makes no footfalls")
	g.player.speed = Tuning.WALK_SPEED
	var start := g.player.pos
	for i in 60:
		g.player.pos = start + Vector2(Tuning.WALK_SPEED * dt * (i + 1), 0.0)
		sys.footfalls(dt)
	# 3.4 tiles walked with a 0.95 stride, the first one early off a standstill.
	check(sys.steps >= 3 and sys.steps <= 4, "3-4 footfalls over 3.4 tiles, got %d" % sys.steps)
	var last: Dictionary = sys.history.back()
	check(String(last["key"]).begins_with("step_"), "a footfall played: %s" % last["key"])
	g.player.pos = start + Vector2(30, 0)
	var before := sys.steps
	sys.footfalls(dt)
	eq(sys.steps, before, "a teleport is not a step")
	_done(parts)


func test_beds_rise_for_the_country_underfoot() -> void:
	var parts := _make()
	var sys: AudioSystem = parts[0]
	var g: Game = parts[1]
	var weights := SoundMix.country_weights(g.world, g.player.pos)
	var main_bed: StringName = weights.keys()[0]
	for k: StringName in weights:
		if float(weights[k]) > float(weights[main_bed]):
			main_bed = k
	for i in 40:
		sys.advance(0.1)
	gt(float(sys.levels.get(main_bed, 0.0)), 0.3, "%s rose" % main_bed)
	lt(float(sys.levels.get(&"weather_storm", 0.0)), 0.001, "no storm on a fair day")
	_done(parts)


func test_only_the_loudest_machine_nearby_is_heard() -> void:
	var parts := _make()
	var sys: AudioSystem = parts[0]
	var g: Game = parts[1]
	var p := g.player.pos
	var mobs: Array[FakeMob] = []
	for s: Array in [[&"machine.watcher", Vector2(6, 0)], [&"rows.harvester", Vector2(0, 4)], [&"line.lineman", Vector2(30, 0)]]:
		var m := FakeMob.new()
		m.kind = s[0]
		m.pos = p + (s[1] as Vector2)
		tree.root.add_child(m)
		m.add_to_group(&"mobs")
		mobs.append(m)
	sys.advance(0.2)
	eq(sys.machine_kind, &"harvester", "the harvester is loudest")
	near(sys.machine_target, SoundMix.machine_level(4.0, 22.0), 1e-4, "level from distance")
	mobs[1].alive = false
	sys.advance(0.2)
	eq(sys.machine_kind, &"watcher", "then the watcher")
	for m in mobs:
		m.queue_free()
	await tree.process_frame
	sys.advance(0.2)
	eq(sys.machine_kind, &"", "nothing near, nothing heard")
	_done(parts)


func test_thunder_is_the_roll_far_off_and_the_crack_close() -> void:
	var parts := _make()
	var sys: AudioSystem = parts[0]
	var g: Game = parts[1]
	_adopt(sys, &"thunder_far")
	_adopt(sys, &"thunder")
	var p := g.player.pos
	# The sky delays thunder behind its flash; the audio system plays it on arrival.
	sys.play(&"thunder", Vector3(p.x + 340.0, 0.0, p.y))
	var far: Dictionary = sys.history.back()
	check(String(far["key"]).begins_with("thunder_far"), "far strikes are only the roll: %s" % far["key"])
	sys.play(&"thunder", Vector3(p.x + 12.0, 0.0, p.y))
	var close: Dictionary = sys.history.back()
	check(String(close["key"]).begins_with("thunder:"), "a close strike cracks: %s" % close["key"])
	eq(close["bus"], &"SFX", "thunder is never sent through the far bus")
	# Heard level = the sheet's level plus the distance gain the call applied.
	var heard_far := float(SoundBank.SHEET[&"thunder_far"][1]) + float(far["db"]) - sys.bank.get_baked(far["key"]).gain_db
	var heard_close := float(SoundBank.SHEET[&"thunder"][1]) + float(close["db"]) - sys.bank.get_baked(close["key"]).gain_db
	gt(heard_close - heard_far, 3.0, "the close one is louder (%.1f vs %.1f dB)" % [heard_close, heard_far])
	gt(heard_far, -8.0, "and the far one still carries over rain")
	_done(parts)


func test_emitted_names_find_their_sounds() -> void:
	var parts := _make()
	var sys: AudioSystem = parts[0]
	var g: Game = parts[1]
	_adopt(sys, &"ui_accept")
	_adopt(sys, &"beast_down")
	_adopt(sys, &"machine_down")
	Events.sfx.emit(&"menu_select", Vector3.ZERO)
	eq(sys.history.back()["key"], &"ui_accept", "the ui package's menu_select")
	eq(sys.history.back()["bus"], &"UI", "on the interface bus")
	var at := Vector3(g.player.pos.x + 2.0, 0.0, g.player.pos.y)
	Events.killed.emit(&"dog.yard", at)
	Events.sfx.emit(&"killed", at)
	eq(sys.history.back()["key"], &"beast_down", "a dog goes down like something alive")
	Events.killed.emit(&"harvester", at)
	Events.sfx.emit(&"killed", at)
	eq(sys.history.back()["key"], &"machine_down", "a harvester's light goes out")
	var before := sys.history.size()
	Events.sfx.emit(&"regrow", at)
	eq(sys.history.size(), before, "regrowth is silent on purpose")
	_done(parts)


func test_a_page_muffles_the_world_and_pause_muffles_more() -> void:
	var parts := _make()
	var sys: AudioSystem = parts[0]
	eq(sys.process_mode, Node.PROCESS_MODE_ALWAYS, "heard while the tree is paused")
	Events.screen_changed.emit(&"inventory", true)
	near(sys.muffle_target, SoundMix.MUFFLE_SCREEN, 1e-6, "a notebook page")
	Events.screen_changed.emit(&"pause", true)
	near(sys.muffle_target, SoundMix.MUFFLE_PAUSE, 1e-6, "pause over it")
	for i in 20:
		sys.advance(0.05)
	var world := AudioServer.get_bus_index(&"World")
	near(AudioServer.get_bus_volume_db(world), SoundMix.muffle_db(SoundMix.MUFFLE_PAUSE), 0.2, "world bus down")
	check(AudioServer.is_bus_effect_enabled(world, SoundBuses.WORLD_LOWPASS), "and dulled")
	Events.screen_changed.emit(&"pause", false)
	Events.screen_changed.emit(&"inventory", false)
	for i in 30:
		sys.advance(0.05)
	near(AudioServer.get_bus_volume_db(world), 0.0, 0.05, "open air again")
	check(not AudioServer.is_bus_effect_enabled(world, SoundBuses.WORLD_LOWPASS), "filter off when not needed")
	_done(parts)


func test_a_machine_sounds_the_same_every_time_and_a_blow_does_not() -> void:
	var parts := _make()
	var sys: AudioSystem = parts[0]
	var g: Game = parts[1]
	_adopt(sys, &"alert_harvester")
	_adopt(sys, &"hit_flesh")
	var at := Vector3(g.player.pos.x + 1.0, 0.0, g.player.pos.y)
	var pitches := {}
	for i in 6:
		sys.play(&"alert_harvester", at)
		for v in sys._voices:
			if v.playing and v.stream == sys.bank.get_baked(&"alert_harvester").stream:
				pitches[v.pitch_scale] = true
	eq(pitches.size(), 1, "an alert is identical every time")
	check(pitches.has(1.0), "at its own pitch")
	var flesh := {}
	for i in 6:
		sys.play(&"hit_flesh", at)
	for v in sys._voices:
		if v.playing and sys._voice_name[sys._voices.find(v)] == &"hit_flesh":
			flesh[v.pitch_scale] = true
	gt(float(flesh.size()), 1.0, "blows land a little differently")
	_done(parts)
