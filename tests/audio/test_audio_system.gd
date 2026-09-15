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


func test_thunder_waits_for_its_distance() -> void:
	var parts := _make()
	var sys: AudioSystem = parts[0]
	var g: Game = parts[1]
	_adopt(sys, &"thunder_far")
	var p := g.player.pos
	var before := sys.history.size()
	sys.play(&"thunder", Vector3(p.x + 340.0, 0.0, p.y))
	eq(sys.history.size(), before, "light first")
	sys.advance(0.5)
	eq(sys.history.size(), before, "still waiting at 0.5 s")
	sys.advance(0.6)
	eq(sys.history.size(), before + 1, "sound after ~1 s")
	eq(sys.history.back()["key"].begins_with("thunder_far"), true, "far strikes are only the roll")
	_done(parts)
