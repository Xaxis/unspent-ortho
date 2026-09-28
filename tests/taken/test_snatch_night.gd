extends TestCase
## WHO THE PLAN COMES FOR (slice 1 step 6; docs/STORY.md: the depots run the
## minds of people who have seen him, to predict him). Pure: when a village that
## has seen him loses somebody to its region's yard, in world minutes.

const DAY := 1440.0


func test_it_comes_in_the_small_hours_at_least_half_a_day_after_he_was_seen() -> void:
	for v in 40:
		var seen := 600.0 + float(v) * 97.0
		var due := SnatchNight.due(seen, 1, v)
		gt(due, seen + SnatchNight.AFTER_HOURS * 60.0 - 0.001, "village %d: not before half a day has gone" % v)
		lt(due, seen + (SnatchNight.AFTER_HOURS + SnatchNight.AFTER_SPREAD) * 60.0 + DAY, "village %d: and within a day of the latest it could be" % v)
		var hour := fposmod(due, DAY) / 60.0
		check(hour >= SnatchNight.NIGHT_FROM and hour < SnatchNight.NIGHT_TO, "village %d: in the small hours (%.2f)" % [v, hour])


func test_villages_are_not_all_come_for_at_once() -> void:
	var dues := {}
	for v in 12:
		dues[SnatchNight.due(600.0, 1, v)] = true
	gt(float(dues.size()), 6.0, "twelve villages seen at the same minute are come for at different times")


func test_not_while_he_is_there() -> void:
	var due := SnatchNight.due(600.0, 1, 3)
	check(not SnatchNight.comes(due - 1.0, due, false), "not before it is due")
	check(SnatchNight.comes(due, due, false), "due, and he is away: it comes")
	check(not SnatchNight.comes(due, due, true), "due, and he is there: it waits")
	var next := SnatchNight.after_him(due + 30.0, 1, 3)
	gt(next, due + 30.0, "and it is due again after he was last there")
	var hour := fposmod(next, DAY) / 60.0
	check(hour >= SnatchNight.NIGHT_FROM and hour < SnatchNight.NIGHT_TO, "in the next small hours (%.2f)" % hour)
