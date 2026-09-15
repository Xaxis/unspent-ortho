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
		var b := Fixture.baked(_key(kind))
		lt(Synth.low_energy_ratio(b.samples, b.rate, 120.0), 0.05, "%s below 120 Hz" % kind)
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


func test_level_is_045_at_the_edge_of_the_racket_and_1_on_top() -> void:
	near(SoundMix.machine_level(0.0, 20.0), 1.0)
	near(SoundMix.machine_level(10.0, 20.0), 0.725)
	near(SoundMix.machine_level(19.999, 20.0), 0.45, 1e-3)
	eq(SoundMix.machine_level(20.0, 20.0), 0.0, "silent at the racket")
	gt(SoundMix.machine_cutoff(0.0, 20.0), SoundMix.machine_cutoff(10.0, 20.0), "further is duller")
	gt(SoundMix.machine_cutoff(10.0, 20.0), SoundMix.machine_cutoff(20.0, 20.0), "further is duller")


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
