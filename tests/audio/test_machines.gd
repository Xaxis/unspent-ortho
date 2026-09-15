extends TestCase
## Machines never wander: every bed is an exact 8.0 s loop at 44.1 kHz with
## event counts that divide it, integer partials, and a seam you cannot find.
## Only the loudest machine nearby is heard.

const Fixture := preload("res://tests/audio/audio_fixture.gd")


class FakeMob:
	extends Node
	var kind: StringName
	var pos: Vector2
	var alive := true


func _key(kind: StringName) -> StringName:
	return StringName("machine_" + String(kind))


func test_there_are_twelve_machine_beds_in_the_sheet() -> void:
	eq(SoundMachines.KINDS.size(), 12, "kinds")
	for kind in SoundMachines.KINDS:
		check(SoundBank.has_sound(_key(kind)), "no sheet row for %s" % kind)
		check(SoundMachines.RACKET.has(kind), "no racket for %s" % kind)
	eq(SoundMachines.COUNTS[&"warden"]["ticks"], 96, "the warden keeps the research's 96 as its even count")


func test_every_machine_loop_is_exactly_eight_seconds_at_44k() -> void:
	eq(SoundMachines.LOOP, 8 * SoundMachines.RATE, "LOOP is 8.0 s")
	for kind in SoundMachines.KINDS:
		var b := Fixture.baked(_key(kind))
		eq(b.samples.size(), SoundMachines.LOOP, "%s length" % kind)
		eq(b.rate, 44100, "%s rate" % kind)
		check(b.loop, "%s loops" % kind)
		var s := Synth.to_wav(b.samples, b.rate, b.loop)
		eq(s.loop_end, SoundMachines.LOOP, "%s loop end" % kind)


func test_every_machine_loop_is_seamless() -> void:
	for kind in SoundMachines.KINDS:
		var b := Fixture.baked(_key(kind))
		lt(Synth.seam_ratio(b.samples), 1.5, "%s seam" % kind)


func test_event_counts_divide_the_loop_and_partials_make_whole_cycles() -> void:
	for kind: StringName in SoundMachines.COUNTS:
		var counts: Dictionary = SoundMachines.COUNTS[kind]
		for what: String in counts:
			var c: int = counts[what]
			eq(SoundMachines.LOOP % c, 0, "%s %s = %d does not divide the loop" % [kind, what, c])
	for key: StringName in SoundMachines.PARTIALS:
		for f: float in SoundMachines.PARTIALS[key]:
			var cycles := f * SoundMachines.LOOP / SoundMachines.RATE
			near(cycles, roundf(cycles), 1e-6, "%s %.3f Hz is not a whole number of cycles" % [key, f])


func test_the_watcher_holds_its_note_and_its_bearing() -> void:
	var b := Fixture.baked(&"machine_watcher")
	var rate := b.rate
	for f: float in [137.5, 275.0, 412.5, 1063.0]:
		var on := Synth.tone_level(b.samples, rate, f, 0, 65536)
		var off := Synth.tone_level(b.samples, rate, f + 23.0, 0, 65536)
		gt(on, off * 20.0, "watcher partial %.1f Hz (on %.4f off %.4f)" % [f, on, off])


func test_nothing_below_120_hz_carries_a_machine() -> void:
	for kind in SoundMachines.KINDS:
		lt(float(Fixture.facts(_key(kind))["lf120"]), 0.05, "%s below 120 Hz" % kind)
	var flock := Fixture.baked(&"machine_flock")
	lt(Synth.low_energy_ratio(flock.samples, flock.rate, 900.0), 0.05, "the flock must have nothing below 900 Hz so wind masks it")
	var lineman := Fixture.baked(&"machine_lineman")
	lt(Synth.low_energy_ratio(lineman.samples, lineman.rate, 200.0), 0.03, "the lineman has no body below 200 Hz")


func test_roster_ids_map_to_their_beds() -> void:
	eq(SoundMachines.kind_of(&"machine.longlegs"), &"longlegs")
	eq(SoundMachines.kind_of(&"rows.harvester"), &"harvester")
	eq(SoundMachines.kind_of(&"long_legs"), &"longlegs")
	eq(SoundMachines.kind_of(&"cold.clerk"), &"clerk")
	eq(SoundMachines.kind_of(&"dog.yard"), &"", "a dog is not a machine")


func test_level_follows_the_research_inside_and_fades_in_at_the_edge() -> void:
	near(SoundMix.machine_level(0.0, 20.0), 1.0)
	near(SoundMix.machine_level(10.0, 20.0), 0.725)
	near(SoundMix.machine_level(17.0, 20.0), 0.45 + 0.55 * 0.15, 1e-4, "the formula holds to the edge band")
	eq(SoundMix.machine_level(20.0, 20.0), 0.0, "silent at the racket")
	eq(SoundMix.machine_level(3.0, 0.0), 0.0, "a racket of 0 is never heard")
	# Coming into range it arrives, never switches on: no step between 1% moves.
	var prev := 0.0
	for i in range(100, -1, -1):
		var lvl := SoundMix.machine_level(20.0 * i / 100.0, 20.0)
		# The old edge jumped 0.45 at once; the fade spreads that over 15% of the racket.
		lt(absf(lvl - prev), 0.06, "a jump of %.3f at %d%% of the racket" % [lvl - prev, i])
		check(lvl >= prev - 1e-6, "louder as it comes closer (%d%%)" % i)
		prev = lvl
	lt(SoundMix.machine_level(19.8, 20.0), 0.01, "a whisper at the very edge")
	gt(SoundMix.machine_cutoff(0.0, 20.0), SoundMix.machine_cutoff(10.0, 20.0), "further is duller")
	gt(SoundMix.machine_cutoff(10.0, 20.0), SoundMix.machine_cutoff(20.0, 20.0), "further is duller")


class RosterMob:
	extends Node
	var kind: StringName
	var pos: Vector2
	var alive := true
	var row: Dictionary = {}


func test_the_racket_is_the_mobs_own_when_it_has_one() -> void:
	var watcher := RosterMob.new()
	watcher.kind = &"watcher"
	watcher.pos = Vector2(25, 0)
	watcher.row = {"racket": 30}
	near(SoundMix.racket_of(watcher, &"watcher"), 30.0, 1e-6, "the roster's number")
	var heard := SoundMix.loudest_machine([watcher], Vector2.ZERO)
	eq(heard.get("kind"), &"watcher", "heard at 25 tiles when its roster says 30")
	near(float(heard.get("racket", 0.0)), 30.0, 1e-6)
	var clerk := RosterMob.new()
	clerk.kind = &"clerk"
	clerk.pos = Vector2(1, 0)
	clerk.row = {"racket": 0}
	check(SoundMix.loudest_machine([clerk], Vector2.ZERO).is_empty(), "a clerk with racket 0 beside you is not heard")
	var bare := FakeMob.new()
	bare.kind = &"clerk"
	bare.pos = Vector2(1, 0)
	eq(SoundMix.racket_of(bare, &"clerk"), 0.0, "and the table agrees with the roster")
	check(SoundMix.loudest_machine([bare], Vector2.ZERO).is_empty(), "the fallback clerk is silent too")
	for m: Node in [watcher, clerk, bare]:
		m.free()


func test_only_the_loudest_living_machine_is_chosen() -> void:
	var mobs: Array = []
	var specs := [[&"machine.watcher", Vector2(5, 0), true], [&"rows.harvester", Vector2(0, 3), true], [&"cut.cutter", Vector2(0.5, 0), false], [&"dog.yard", Vector2(0, 0), true]]
	for s: Array in specs:
		var m := FakeMob.new()
		m.kind = s[0]
		m.pos = s[1]
		m.alive = s[2]
		mobs.append(m)
	var best := SoundMix.loudest_machine(mobs, Vector2.ZERO)
	eq(best.get("kind"), &"harvester", "the harvester at 3 tiles is louder than the watcher at 5")
	near(float(best.get("level", 0.0)), SoundMix.machine_level(3.0, 22.0), 1e-6)
	var none := SoundMix.loudest_machine([mobs[3]], Vector2.ZERO)
	check(none.is_empty(), "a dog makes no machine bed")
	for m: Node in mobs:
		m.free()


func test_a_machine_coming_on_gets_brighter_before_it_gets_louder() -> void:
	var b := Fixture.baked(&"machine_harvester")
	var scene := {"secs": 4.0, "at": Vector2(20.5, 20.5), "layers": [&"machine"], "weather": {"kind": &"clear", "strength": 0.0, "wind": 0.0},
		"machine": {"kind": &"harvester", "from": 22.0, "to": 0.0}}
	# The approach starts at the edge of the racket, where it is only arriving.
	var w := WorldData.new(9, 48)
	var out := SoundScene.render(scene, w, {&"machine_harvester": b})
	var mix: PackedFloat32Array = out["samples"]
	var early := mix.slice(Synth.samples(SoundScene.RATE, 0.2), Synth.samples(SoundScene.RATE, 1.0))
	var late := mix.slice(Synth.samples(SoundScene.RATE, 3.2), Synth.samples(SoundScene.RATE, 4.0))
	gt(Synth.rms(late), Synth.rms(early) * 1.6, "louder on top of you")
	var bright_early := Synth.tone_level(early, SoundScene.RATE, 5000.0) + Synth.rms(_high(early))
	var bright_late := Synth.tone_level(late, SoundScene.RATE, 5000.0) + Synth.rms(_high(late))
	gt(bright_late / maxf(1e-9, Synth.rms(late)), 1.5 * bright_early / maxf(1e-9, Synth.rms(early)), "and the top comes in first: distance is timbre")
	near(SoundScene.heard_db(mix, 3.4, 4.0), b.heard, 2.0, "on top of it, heard at its sheet level")


func _high(buf: PackedFloat32Array) -> PackedFloat32Array:
	var h := buf.duplicate()
	Synth.highpass4(h, SoundScene.RATE, 3000.0)
	return h
