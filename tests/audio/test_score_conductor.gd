extends TestCase
## The score's form, run over simulated minutes with no sound: layers enter and
## leave over minutes, night is deeper and sparser, weather colours the air,
## danger quickens the pulse and resolves when it passes, an installation brings
## its grid, an ecotone modulates between two keys, a sentinel's motif is rare,
## and the same inputs always give the same score.

const STEP := 0.25


static func _input(land: StringName = &"coast", hour: float = 12.0, extra: Dictionary = {}) -> Dictionary:
	var d := {"weights": {land: 1.0}, "hour": hour, "weather": {"kind": &"clear", "strength": 0.0}, "danger": 0.0, "grid": 0.0}
	d.merge(extra, true)
	return d


static func _level(c: ScoreConductor, land: StringName, layer: StringName, v: int = 0) -> float:
	return float(c.levels.get(ScoreStems.key_for(land, layer, v), 0.0))


## Runs `secs` of the same input; returns per-tick samples of what `probe` reads.
static func _run(c: ScoreConductor, secs: float, input: Dictionary, probe: Callable = Callable()) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in roundi(secs / STEP):
		c.tick(STEP, input)
		if probe.is_valid():
			out.append(float(probe.call(c)))
	return out


static func _mean(xs: PackedFloat32Array) -> float:
	var s := 0.0
	for x in xs:
		s += x
	return s / maxf(1.0, xs.size())


func test_layers_enter_over_minutes_and_leave_again() -> void:
	var c := ScoreConductor.new(7)
	var pad := func(k: ScoreConductor) -> float: return _level(k, &"coast", &"pad", 0) + _level(k, &"coast", &"pad", 1)
	var pulse := func(k: ScoreConductor) -> float: return _level(k, &"coast", &"pulse", 0)
	var drone := func(k: ScoreConductor) -> float: return _level(k, &"coast", &"drone", 0)
	var pads := PackedFloat32Array()
	var pulses := PackedFloat32Array()
	var drones := PackedFloat32Array()
	for i in roundi(40.0 * 60.0 / STEP):
		c.tick(STEP, _input())
		pads.append(pad.call(c))
		pulses.append(pulse.call(c))
		drones.append(drone.call(c))
	var at := func(secs: float) -> int: return roundi(secs / STEP) - 1
	gt(drones[at.call(10.0)], 0.4, "the drone is the first thing heard")
	lt(pads[at.call(6.0)], 0.05, "and it is alone with the air at first")
	lt(pulses[at.call(12.0)], 0.05, "the pulse is not the score's opening move")
	var pad_in := -1.0
	var pulse_in := -1.0
	for i in pads.size():
		if pad_in < 0.0 and pads[i] > 0.5:
			pad_in = (i + 1) * STEP
		if pulse_in < 0.0 and pulses[i] > 0.4:
			pulse_in = (i + 1) * STEP
	check(pad_in > 8.0 and pad_in < 40.0, "the pad comes in the first half minute (at %.0f s)" % pad_in)
	check(pulse_in > 12.0 and pulse_in < 45.0, "and the pulse after it (at %.0f s)" % pulse_in)
	var gone := false
	for i in range(roundi(pulse_in / STEP), pulses.size()):
		if pulses[i] < 0.1:
			gone = true
			break
	check(gone, "and the pulse leaves again: the form rests")
	var phrases := c.played.filter(func(p: Array) -> bool: return ScoreStems.parse(p[1]).get("layer") == &"melody")
	check(phrases.size() >= 12 and phrases.size() <= 90, "phrases now and then over forty minutes (%d)" % phrases.size())
	for i in range(1, phrases.size()):
		gt(float(phrases[i][0]) - float(phrases[i - 1][0]), 12.0, "never one phrase on another")
	for p: Array in c.played:
		near(fmod(float(p[0]) + 0.001, ScoreLandscapes.BAR), 0.0, STEP + 0.01, "a cue waits for its bar line")


## Hours of play never hear the same few recordings in the same order: each
## landscape draws its own shapes from twelve, never one of its last two, and
## what is baked ahead is the phrase that plays.
func test_phrases_vary_by_landscape_and_never_repeat_a_recent_shape() -> void:
	gt(float(ScoreStems.LAYERS[&"melody"]["variants"]), 9.0, "enough shapes to go round")
	var orders := {}
	for land: StringName in [&"coast", &"moss", &"burning"]:
		var c := ScoreConductor.new(7)
		var shapes: Array[int] = []
		var predicted := -1
		for i in roundi(45.0 * 60.0 / STEP):
			var count := c._phrase_count
			var before := c.next_phrase_variant(land)
			c.tick(STEP, _input(land))
			if c._phrase_count > count:
				# Queued for its bar line, or already fired when it fell on one.
				var key: StringName = c._pending[-1][1] if not c._pending.is_empty() else c.played[-1][1]
				eq(int(ScoreStems.parse(key)["variant"]), before, "%s: the phrase baked ahead is the one played" % land)
				shapes.append(before)
				predicted = before
		gt(float(shapes.size()), 15.0, "%s: phrases over three quarters of an hour (%d)" % [land, shapes.size()])
		for i in range(1, shapes.size()):
			check(shapes[i] != shapes[i - 1] and (i < 2 or shapes[i] != shapes[i - 2]), "%s: phrase %d (shape %d) is not one of the last two" % [land, i, shapes[i]])
		var distinct := {}
		for v in shapes:
			distinct[v] = true
		gt(float(distinct.size()), 7.0, "%s: most of the shapes are heard (%d)" % [land, distinct.size()])
		orders[land] = shapes.slice(0, 6)
		check(predicted >= 0, "%s played phrases" % land)
	var lands := orders.keys()
	for i in lands.size():
		for j in range(i + 1, lands.size()):
			check(str(orders[lands[i]]) != str(orders[lands[j]]), "%s and %s do not open with the same phrases" % [lands[i], lands[j]])


func test_night_is_deeper_and_sparser() -> void:
	var day := ScoreConductor.new(3)
	var night := ScoreConductor.new(3)
	var pulse := func(k: ScoreConductor) -> float: return _level(k, &"coast", &"pulse", 0)
	var day_pulse := _mean(_run(day, 1800.0, _input(&"coast", 12.0), pulse))
	var night_pulse := _mean(_run(night, 1800.0, _input(&"coast", 23.0), pulse))
	lt(night_pulse, day_pulse * 0.5, "the pulse is rarer at night (%.3f vs %.3f by day)" % [night_pulse, day_pulse])
	gt(_level(night, &"coast", &"drone", 1), 0.7, "the night drone")
	lt(_level(night, &"coast", &"drone", 0), 0.05, "not the day's")
	lt(float(night.played.size()), float(day.played.size()), "fewer phrases at night")
	lt(ScoreConductor.bus_cutoff(1.0, {}), ScoreConductor.bus_cutoff(0.0, {}) * 0.5, "the score's top closes down at night")


func test_weather_colours_the_air() -> void:
	for pair: Array in [[&"rain", ScoreStems.RAIN], [&"fog", ScoreStems.FOG], [&"snow", ScoreStems.SNOW], [&"ash", ScoreStems.ASH], [&"storm", ScoreStems.RAIN], [&"dust", ScoreStems.ASH]]:
		var c := ScoreConductor.new(5)
		_run(c, 120.0, _input(&"moss", 12.0, {"weather": {"kind": pair[0], "strength": 0.9}}))
		gt(_level(c, &"moss", &"texture", int(pair[1])), 0.6, "%s colours the texture" % pair[0])
		lt(_level(c, &"moss", &"texture", ScoreStems.AIR), 0.45, "%s pushes the plain air back" % pair[0])
	var fog := ScoreConductor.bus_cutoff(0.0, {"kind": &"fog", "strength": 1.0})
	lt(fog, ScoreConductor.bus_cutoff(0.0, {}) * 0.6, "fog muffles the score")


func test_danger_quickens_the_pulse_and_resolves_when_it_passes() -> void:
	var c := ScoreConductor.new(11)
	_run(c, 240.0, _input())
	var before := c.played.size()
	var tense := _run(c, 20.0, _input(&"coast", 12.0, {"danger": 1.0}), func(k: ScoreConductor) -> float: return _level(k, &"coast", &"pulse", 1))
	gt(tense[roundi(4.0 / STEP)], 0.5, "within four seconds the pulse has quickened (%.2f)" % tense[roundi(4.0 / STEP)])
	lt(_level(c, &"coast", &"pulse", 0), 0.2, "the calm pulse has stepped aside")
	gt(_level(c, &"coast", &"dissonance", 0), 0.6, "dissonance has risen")
	var phrases_in_danger := c.played.slice(before).filter(func(p: Array) -> bool: return ScoreStems.parse(p[1]).get("layer") == &"melody")
	eq(phrases_in_danger.size(), 0, "no phrase over a fight")
	_run(c, 40.0, _input())
	lt(_level(c, &"coast", &"dissonance", 0), 0.2, "the dissonance falls away")
	lt(_level(c, &"coast", &"pulse", 1), 0.1, "the quick pulse too")
	var resolves := c.played.slice(before).filter(func(p: Array) -> bool: return ScoreStems.parse(p[1]).get("layer") == &"resolve")
	eq(resolves.size(), 1, "and it resolves, once")
	# A brush with danger that never really came is not resolved.
	var d := ScoreConductor.new(11)
	_run(d, 60.0, _input())
	_run(d, 0.5, _input(&"coast", 12.0, {"danger": 0.3}))
	_run(d, 30.0, _input())
	eq(d.played.filter(func(p: Array) -> bool: return ScoreStems.parse(p[1]).get("layer") == &"resolve").size(), 0, "a glimpse is not a fight")


func test_an_installation_brings_its_grid() -> void:
	var c := ScoreConductor.new(2)
	_run(c, 30.0, _input())
	lt(_level(c, &"coast", &"grid"), 0.01, "no grid in open country")
	_run(c, 15.0, _input(&"coast", 12.0, {"grid": 1.0}))
	gt(_level(c, &"coast", &"grid"), 0.6, "an installation's pulse and hum")
	_run(c, 40.0, _input())
	lt(_level(c, &"coast", &"grid"), 0.1, "gone when it is behind you")


func test_an_ecotone_modulates_from_one_key_into_the_next() -> void:
	var c := ScoreConductor.new(4)
	var busy := func(k: ScoreConductor, weights: Dictionary) -> void:
		k.density = 3.0
		k.section_density = 3
		k.tick(STEP, {"weights": weights, "hour": 12.0, "weather": {}, "danger": 0.0})
	for i in roundi(120.0 / STEP):
		busy.call(c, {&"coast": 1.0})
	var coast_pulse_pure := _level(c, &"coast", &"pulse", 0)
	gt(coast_pulse_pure, 0.6, "deep in the coast its pulse is up")
	var prev_coast := _level(c, &"coast", &"drone", 0)
	var prev_moss := 0.0
	var worst := 0.0
	for i in roundi(120.0 / STEP):
		var u := float(i + 1) / roundi(120.0 / STEP)
		busy.call(c, {&"coast": 1.0 - u, &"moss": u})
		var cd := _level(c, &"coast", &"drone", 0)
		var md := _level(c, &"moss", &"drone", 0)
		worst = maxf(worst, maxf(cd - prev_coast, prev_moss - md))
		prev_coast = cd
		prev_moss = md
		if absf(u - 0.5) < 0.002:
			for i2 in roundi(20.0 / STEP):
				busy.call(c, {&"coast": 0.5, &"moss": 0.5})
			gt(_level(c, &"coast", &"drone", 0), 0.5, "halfway, the coast's drone still sounds")
			gt(_level(c, &"moss", &"drone", 0), 0.5, "and the moss's has come in under it")
			lt(_level(c, &"coast", &"pulse", 0), coast_pulse_pure * 0.45, "the rhythms step back while the keys overlap")
			prev_coast = _level(c, &"coast", &"drone", 0)
			prev_moss = _level(c, &"moss", &"drone", 0)
	lt(worst, 0.02, "the drones cross over steadily, never jumping")
	for i in roundi(60.0 / STEP):
		busy.call(c, {&"moss": 1.0})
	lt(_level(c, &"coast", &"drone", 0), 0.05, "the coast has gone")
	gt(_level(c, &"moss", &"pulse", 0), 0.6, "and the moss has its own pulse")


func test_a_sentinels_reach_plays_its_motif_rarely() -> void:
	var c := ScoreConductor.new(9)
	_run(c, 30.0, _input())
	_run(c, 300.0, _input(&"coast", 12.0, {"sentinel": {"land": &"coast", "strength": 1.0}}))
	var motifs := func() -> int: return c.played.filter(func(p: Array) -> bool: return ScoreStems.parse(p[1]).get("layer") == &"motif").size()
	eq(motifs.call(), 1, "once on entering its reach, not again while inside")
	gt(_level(c, &"coast", &"dissonance", 0), 0.2, "and its reach is uneasy")
	_run(c, 10.0, _input())
	_run(c, 10.0, _input(&"coast", 12.0, {"sentinel": {"land": &"coast", "strength": 1.0}}))
	eq(motifs.call(), 2, "leaving and coming back after a long while plays it again")
	_run(c, 10.0, _input())
	_run(c, 10.0, _input(&"coast", 12.0, {"sentinel": {"land": &"coast", "strength": 1.0}}))
	eq(motifs.call(), 2, "but not straight away")


func test_arriving_somewhere_is_a_phrase() -> void:
	var c := ScoreConductor.new(6)
	_run(c, 20.0, _input(&"pinewood"))
	var first := c.played.filter(func(p: Array) -> bool: return String(p[1]).begins_with("score_pinewood_melody"))
	eq(first.size(), 1, "waking in the pines, a phrase of theirs")
	gt(float(first[0][0]), ScoreConductor.ARRIVE_HOLD, "once properly there")


func test_the_same_inputs_give_the_same_score() -> void:
	var a := ScoreConductor.new(21)
	var b := ScoreConductor.new(21)
	var script := func(t: float) -> Dictionary:
		return _input(&"bonelands", 11.0 + t / 60.0, {"danger": 1.0 if t > 300.0 and t < 320.0 else 0.0, "weather": {"kind": &"dust", "strength": clampf((t - 200.0) / 100.0, 0.0, 1.0)}})
	for i in roundi(600.0 / STEP):
		var t := i * STEP
		a.tick(STEP, script.call(t))
		b.tick(STEP, script.call(t))
	check(str(a.levels) == str(b.levels), "same levels")
	check(str(a.played) == str(b.played), "same cues at the same moments")
	var c := ScoreConductor.new(22)
	for i in roundi(600.0 / STEP):
		c.tick(STEP, script.call(i * STEP))
	check(str(c.played) != str(a.played), "another world's seed shapes it differently")


func test_what_is_wanted_is_baked_before_it_is_heard() -> void:
	var c := ScoreConductor.new(1)
	c.tick(STEP, _input(&"coast", 12.0, {"near": 1.0}))
	var wanted := c.wanted()
	eq(wanted[0], ScoreStems.key_for(&"coast", &"drone", 0), "the loudest first")
	for key: StringName in [ScoreStems.key_for(&"coast", &"pulse", 1), ScoreStems.key_for(&"coast", &"dissonance", 0), ScoreStems.key_for(&"coast", &"resolve", 0), ScoreStems.key_for(&"coast", &"pad", 0)]:
		check(wanted.has(key), "%s is baked ahead" % key)
	c.tick(STEP, _input(&"coast", 20.6))
	check(c.wanted().has(ScoreStems.key_for(&"coast", &"drone", 1)), "the night drone is baked as dusk comes")
