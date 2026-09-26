extends TestCase
## What a yardstick bar (TestCase.yard_lt) may and may not decline to judge. A
## cost read over its bar is a failure on any machine, however busy: skipping it
## "because the box was loud" is how a real regression ships on a busy gate. Only
## the doubled reading may abstain, and only when it did not read as a doubling.


func _judge(us: float, doubled_us: float, slack: float) -> PackedStringArray:
	var t := TestCase.new()
	t.current = "probe"
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


func test_only_a_doubling_that_was_not_seen_abstains() -> void:
	eq(_judge(30.0, 42.0, 1.0).size(), 0, "3 shipped, 4.2 doubled (1.4x): a disturbed run, said and not judged")
	eq(_judge(60.0, 84.0, 8.0).size(), 1, "and the shipped reading is still judged in that run")
