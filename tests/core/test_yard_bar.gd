extends TestCase
## What a yardstick bar (TestCase.yard_lt) may and may not decline to judge. A
## cost read over its bar is a failure on any machine, however busy: skipping it
## "because the box was loud" is how a real regression ships on a busy gate. Only
## the doubled reading may abstain, and only when it did not read as a doubling.


func _judge(us: float, doubled_us: float, slack: float) -> PackedStringArray:
	var t := TestCase.new()
	t.current = "probe"
	# Judged here, in every shard: this is the bar's own rule under test.
	t.defer_costs = false
	var kept_slack := TestCase._slack
	var kept_at := TestCase._slack_at
	TestCase._slack = slack
	TestCase._slack_at = Time.get_ticks_msec()
	t.yard_lt(us, doubled_us, 10.0, 5.0, "probe")
	TestCase._slack = kept_slack
	TestCase._slack_at = kept_at
	return t.failures


func test_over_its_bar_fails_on_a_busy_machine_too() -> void:
	eq(_judge(60.0, 120.0, 8.0).size(), 1, "6 yardsticks against a bar of 5, the machine at 8x")
	eq(_judge(60.0, 120.0, 1.0).size(), 1, "and on a quiet one")


func test_under_its_bar_passes_and_a_doubling_it_misses_fails() -> void:
	eq(_judge(30.0, 62.0, 1.0).size(), 0, "3 shipped, 6.2 doubled, bar 5")
	eq(_judge(20.0, 42.0, 1.0).size(), 1, "2 shipped, 4.2 doubled: the bar misses a real doubling")


## In a gate shard (UNSPENT_COSTS_LATER set) a real test's cost is deferred to
## the alone pass, and one judged as its own subject is not: CI's gate went red
## on all three tests here when the probe was deferred too.
func test_a_shard_defers_a_cost_and_not_a_bars_own_probe() -> void:
	var path := RunnerHome.path().path_join("costs-later-probe")
	var kept := OS.get_environment("UNSPENT_COSTS_LATER")
	OS.set_environment("UNSPENT_COSTS_LATER", path)
	var deferred := TestCase.new()
	deferred.current = "test_x:test_y"
	deferred.yard_lt(60.0, 120.0, 10.0, 5.0, "a cost in a shard")
	eq(_judge(60.0, 120.0, 1.0).size(), 1, "the bar's own probe is still judged in a shard")
	OS.set_environment("UNSPENT_COSTS_LATER", kept)
	eq(deferred.failures.size(), 0, "a real test's cost is not judged in the shard")
	var f := FileAccess.open(path, FileAccess.READ)
	check(f != null, "it is listed for the alone pass")
	if f != null:
		eq(f.get_as_text().strip_edges(), "test_x:test_y", "by its runner id, and nothing else is")
		f.close()
	DirAccess.remove_absolute(path)


func test_only_a_doubling_that_was_not_seen_abstains() -> void:
	eq(_judge(30.0, 42.0, 1.0).size(), 0, "3 shipped, 4.2 doubled (1.4x): a disturbed run, said and not judged")
	eq(_judge(60.0, 84.0, 8.0).size(), 1, "and the shipped reading is still judged in that run")


## An absolute bar (cost_lt) is deferred from a shard the same way: judged there
## beside two sibling shards, a villager's build read 24.24 ms against 24.0 on
## CI with nothing about villagers changed.
func test_a_shard_defers_an_absolute_cost_too() -> void:
	var path := RunnerHome.path().path_join("costs-later-absolute")
	DirAccess.remove_absolute(path)
	var kept := OS.get_environment("UNSPENT_COSTS_LATER")
	OS.set_environment("UNSPENT_COSTS_LATER", path)
	var deferred := TestCase.new()
	deferred.current = "test_x:test_z"
	deferred.cost_lt(30.0, 24.0, "a build over its bar in a shard")
	OS.set_environment("UNSPENT_COSTS_LATER", kept)
	eq(deferred.failures.size(), 0, "not judged in the shard")
	var f := FileAccess.open(path, FileAccess.READ)
	check(f != null, "it is listed for the alone pass")
	if f != null:
		eq(f.get_as_text().strip_edges(), "test_x:test_z", "by its runner id")
		f.close()
	DirAccess.remove_absolute(path)
	# Judged alone on a QUIET machine, which is what the alone pass is for: this
	# half is the bar's own rule, not a measurement, and on a busy CI runner
	# (slack over 2) cost_lt reads an over-bar number as unmeasured and fails
	# nothing, which is what went red on CI.
	var kept_slack := TestCase._slack
	var kept_at := TestCase._slack_at
	TestCase._slack = 1.0
	TestCase._slack_at = Time.get_ticks_msec()
	var alone := TestCase.new()
	alone.current = "test_x:test_z"
	alone.defer_costs = false
	alone.cost_lt(30.0 * (TestCase.CI_SPEED + 1.0), 24.0, "the same build judged alone")
	TestCase._slack = kept_slack
	TestCase._slack_at = kept_at
	eq(alone.failures.size(), 1, "and alone it is judged")
