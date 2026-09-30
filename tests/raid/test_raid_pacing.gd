extends TestCase
## A LIT, STAFFED HOLDING ON A WILD COAST IS FOUND. Played on real frames: the
## coast spawns and walks its machines, they read the place, what they carry
## home is filed, and the plan acts on it. Nothing here is skipped or staged past
## the holding itself, because the pacing IS the passing machines.
##
## The bar (owner, via teammate1, 2026-09-29): the first survey is warned within
## about one in-game day, and the first warning past a survey within about two.
## Measured before this test existed (seed 1, lean-to and hearth, three days):
## three notices filed, each worth ~0.007, attention back to 0 within the hour,
## no plan ever made.

const Sx := preload("res://tests/save/save_fixture.gd")
## In-game minutes the bars allow: a day and a bit, two days and a bit.
const SURVEY_BY := 30.0 * 60.0
const WARNED_BY := 54.0 * 60.0
## The owner's floor: a working day before anything past a look (48_raids
## FIRST_WARNING_AFTER).
const WARNED_NOT_BEFORE := 12.0 * 60.0


func test_a_lit_staffed_holding_on_a_wild_coast_is_surveyed_then_warned() -> void:
	if not stepped_now():
		return
	var first: Dictionary = await _play("lean-to,hearth", true)
	check(first.has("survey") and float(first["survey"]) <= SURVEY_BY,
		"surveyed within a day and a bit (%s)" % _when(first, "survey"))
	check(first.has("past") and float(first["past"]) <= WARNED_BY,
		"warned of more than a look within two days and a bit (%s)" % _when(first, "past"))
	# And not before a working day: the time to hear why and put the shutters up.
	check(first.has("past") and float(first["past"]) >= WARNED_NOT_BEFORE,
		"but no sooner than a working day (%s)" % _when(first, "past"))


## The defence, seen from the plan's side: a holding with its hearth out and its
## beds boarded gives a passing machine nothing over the floor, and what little
## the plan ever had of it cools away. Two days on the same wild coast, unsurveyed.
func test_a_dark_shuttered_holding_on_the_same_coast_is_left_alone() -> void:
	if not stepped_now():
		return
	var first: Dictionary = await _play("lean-to,shutters", false)
	check(not first.has("survey"), "never surveyed in two days (%s)" % _when(first, "survey"))
	check(not first.has("past"), "and never warned")


## Stand the holding, play the coast for up to WARNED_BY, and say when the first
## survey and the first warning past one came (in-game minutes from the start).
## `until_warned`: stop at the first warning past a survey.
func _play(holding: String, until_warned: bool) -> Dictionary:
	Sx.use_root("raid_pacing")
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0", "--holding=" + holding])
	await frames(3)
	var raids := Sx.system(g, "48_raids")
	var s: Settlement = Sx.system(g, "46_settlements").call("here")
	check(s != null, "the holding stands")
	var start := g.clock.minutes
	var first := {}
	var on_warned := func(_id: int, stage: StringName) -> void:
		var key := "survey" if stage == RaidStage.SURVEY else "past"
		if not first.has(key):
			first[key] = g.clock.minutes - start
	Events.raid_warned.connect(on_warned)
	var next_log := start
	var wall := Time.get_ticks_msec()
	while g.clock.minutes - start < WARNED_BY and not (until_warned and first.has("past")):
		await frames(60)
		# The player stands at the holding the whole time, well fed.
		g.body.fed_until = g.clock.minutes + 360.0
		if g.clock.minutes >= next_log:
			next_log += 60.0
			print("pacing %5.1f h: attention %.3f sig %.3f notices %s near %s nearest reader %s (%d s wall)" % [
				(g.clock.minutes - start) / 60.0, s.attention, s.signature().total(),
				_count_notices(raids), _near_bodies(g), _nearest_reader(g, s), (Time.get_ticks_msec() - wall) / 1000])
	Events.raid_warned.disconnect(on_warned)
	Sx.end(g)
	Sx.finish()
	return first


func _when(first: Dictionary, key: String) -> String:
	return "at %.1f h" % (float(first[key]) / 60.0) if first.has(key) else "never"


func _count_notices(raids: Node) -> Dictionary:
	var by := {}
	for n: Notice in raids.get("notices"):
		by[n.state] = int(by.get(n.state, 0)) + 1
	return by


func _near_bodies(g: Game) -> Dictionary:
	var near := {}
	for m in g.player.sim.mobs:
		if m.alive and not m.removed and m.pos.distance_to(g.player.pos) < 40.0:
			var k := "%s%s" % [m.kind, "*" if Notices.reports(m.row) else ""]
			near[k] = int(near.get(k, 0)) + 1
	return near


## The reporting body nearest the holding this hour: its distance, and the best a
## channel reads there before the role and the floor (for the log).
func _nearest_reader(g: Game, s: Settlement) -> String:
	var best: MobState = null
	for m in g.player.sim.mobs:
		if m.alive and not m.removed and Notices.reports(m.row):
			if best == null or m.pos.distance_to(s.centre) < best.pos.distance_to(s.centre):
				best = m
	if best == null:
		return "none"
	var d := best.pos.distance_to(s.centre)
	var sig := s.signature()
	var raw := 0.0
	for c: StringName in Signature.CHANNELS:
		var r := Notices.reach(c)
		if r > 0.0 and d < r:
			raw = maxf(raw, sig.get_channel(c) * (1.0 - d / r))
	return "%s %.1f tiles raw %.2f" % [best.kind, d, raw]

