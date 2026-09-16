extends TestCase
## The one door every sense in the game goes through: how far a machine sees
## and hears the player, given what the player is doing about it.

const Fx := preload("res://tests/fight/fixture.gd")


func _noon(kind: StringName = &"runner") -> Array:
	var m := Moment.new()
	m.seed_value = 7
	m.minutes = 12.0 * 60.0
	m.weather = &"clear"
	return [Roster.row(kind), m]


func test_sight_starts_at_what_senses_says_and_the_player_takes_it_down() -> void:
	var r: Array = _noon()
	var row: Dictionary = r[0]
	var m: Moment = r[1]
	var open := StealthQuery.sight_range(row, m)
	near(open, Senses.sight_range(row, m), 1e-5, "in the open, nothing is changed")
	m.crouched = true
	near(StealthQuery.sight_range(row, m), open * StealthQuery.CROUCH_SIGHT, 1e-4, "crouched")
	m.crouched = false
	m.cover = 1.0
	near(StealthQuery.sight_range(row, m), open * (1.0 - StealthQuery.COVER_SIGHT), 1e-4, "buried in cover")
	m.cover = 0.5
	near(StealthQuery.sight_range(row, m), open * (1.0 - StealthQuery.COVER_SIGHT * 0.5), 1e-4, "half hidden")
	m.cover = 0.0
	m.spoofed = true
	lt(StealthQuery.sight_range(row, m), open * 0.25, "read as one of their own, it barely looks")


func test_crouching_in_cover_is_worth_more_than_either_alone() -> void:
	var r: Array = _noon()
	var row: Dictionary = r[0]
	var m: Moment = r[1]
	var open := StealthQuery.sight_range(row, m)
	m.crouched = true
	var down := StealthQuery.sight_range(row, m)
	m.crouched = false
	m.cover = 0.6
	var hid := StealthQuery.sight_range(row, m)
	m.crouched = true
	var both := StealthQuery.sight_range(row, m)
	lt(both, minf(down, hid), "down in the heather is the two together")
	lt(both / open, 0.35, "and it is most of a machine's sight")


func test_hearing_is_how_loud_you_are_and_nothing_else() -> void:
	var r: Array = _noon()
	var row: Dictionary = r[0]
	var m: Moment = r[1]
	near(StealthQuery.hearing_range(row, m), Senses.hearing_range(row, m), 1e-5, "walking: as the source says")
	m.cover = 1.0
	near(StealthQuery.hearing_range(row, m), Senses.hearing_range(row, m), 1e-5, "cover is nothing to ears")
	m.loudness = StealthNoise.loudness(Tuning.WALK_SPEED, Ground.MOSS, true, 0)
	lt(StealthQuery.hearing_range(row, m), Senses.hearing_range(row, m) * 0.3, "creeping on moss")
	m.loudness = StealthNoise.loudness(Tuning.RUN_SPEED, Ground.SHINGLE, false, 0)
	gt(StealthQuery.hearing_range(row, m), Senses.hearing_range(row, m) * 2.0, "running on shingle")


func test_a_watcher_reads_a_narrow_strip_and_a_hunter_almost_everything() -> void:
	lt(StealthQuery.cone_half(Roster.row(&"watcher")), 0.8, "a watcher's cone is narrow")
	gt(StealthQuery.cone_half(Roster.row(&"runner")), 1.5, "a hunter has hardly a blind side")
	gt(StealthQuery.cone_half(Roster.row(&"harvester")), StealthQuery.cone_half(Roster.row(&"watcher")),
		"a worker looks where it works, wider than a watcher reads")


func test_behind_its_cone_a_machine_only_catches_you_close() -> void:
	var r: Array = _noon(&"watcher")
	var row: Dictionary = r[0]
	var m: Moment = r[1]
	var w := Fx.flat_world()
	var q := WorldQuery.new(w)
	var at := Vector2(20.5, 20.5)
	var ahead := at + Vector2(9.0, 0.0)
	var behind := at + Vector2(-9.0, 0.0)
	check(StealthQuery.sees(row, at, ahead, m, w, q, 0.0), "nine tiles down its line of sight")
	check(not StealthQuery.sees(row, at, behind, m, w, q, 0.0), "the same nine tiles at its back")
	check(StealthQuery.sees(row, at + Vector2(-1.5, 0), behind + Vector2(6.5, 0), m, w, q, 0.0),
		"but right behind it, it still catches you")
	check(StealthQuery.sees(row, at, behind, m, w, q), "asked without a facing, the cone does not apply")


func test_a_watchers_sweep_is_exact_and_repeats() -> void:
	check(StealthQuery.sweeps(Roster.row(&"watcher")), "a watcher sweeps")
	check(not StealthQuery.sweeps(Roster.row(&"runner")), "a hunter holds its line")
	near(StealthQuery.sweep(0.0, 0.0), 0.0, 1e-5, "it starts on its bearing")
	near(StealthQuery.sweep(0.0, StealthQuery.SWEEP_PERIOD), 0.0, 1e-5, "and comes back to it")
	near(StealthQuery.sweep(0.0, StealthQuery.SWEEP_PERIOD * 0.25), StealthQuery.SWEEP_SPAN, 1e-5, "a quarter in, right over")
	var spread := 0.0
	for i in 60:
		spread = maxf(spread, absf(StealthQuery.sweep(0.0, i * 0.15)))
	near(spread, StealthQuery.SWEEP_SPAN, 0.02, "and never further than its span")


func test_a_noise_is_heard_by_ears_that_are_good_enough_and_never_by_an_eye() -> void:
	var r: Array = _noon(&"dredger")
	var m: Moment = r[1]
	var at := Vector2(20.5, 20.5)
	var far := at + Vector2(12.0, 0.0)
	check(StealthQuery.hears_noise(Roster.row(&"dredger"), far, at, 14.0, m), "a dredger hears a long way")
	check(not StealthQuery.hears_noise(Roster.row(&"dredger"), far, at, 4.0, m), "not a quiet one")
	check(not StealthQuery.hears_noise(Roster.row(&"watcher"), far, at, 30.0, m),
		"a watcher reads by eye alone and hears nothing")
	check(not StealthQuery.hears_noise(Roster.row(&"runner"), far, at, 0.0, m), "silence is not a noise")


func test_the_senses_door_still_answers_and_now_answers_the_same_way() -> void:
	var r: Array = _noon()
	var row: Dictionary = r[0]
	var m: Moment = r[1]
	var w := Fx.flat_world()
	var q := WorldQuery.new(w)
	var a := Vector2(20.5, 20.5)
	var b := a + Vector2(8.0, 0.0)
	check(Senses.notices(row, a, b, m, w, q), "seen at eight tiles by day")
	m.crouched = true
	m.cover = 0.7
	m.loudness = 0.1
	check(not Senses.notices(row, a, b, m, w, q), "not by a player down in cover and creeping")
