extends TestCase
## `Attention.CAUSES` is the closed list of what moves a holding's attention
## (CLAUDE.md, the Raids row), and a closed list is only worth having if
## everything in it is live. Two rows were not: `raided` duplicated the RAID rung
## of `RaidStage.SPENDS` and `keeper_fell` sat beside code that set attention to
## zero by hand. Both read as load-bearing — they are documented, they carry
## numbers, `tests/raid/test_attention.gd` exercises the others beside them — and
## neither was ever applied, so either could have drifted from the behaviour it
## claimed to describe without one test going red.
##
## This reads the shipped source and fails on a row nothing applies.

const CAUSE_HOME := "res://src/core/raid/attention.gd"


static func _gd_under(dir: String, out: PackedStringArray) -> PackedStringArray:
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for name: String in d.get_directories():
		@warning_ignore("return_value_discarded")
		_gd_under(dir.path_join(name), out)
	for name: String in d.get_files():
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	return out


func test_every_cause_the_table_declares_is_applied_by_something() -> void:
	var files := _gd_under("res://src", PackedStringArray())
	gt(float(files.size()), 50.0, "the source was found")
	var text := ""
	for path: String in files:
		if path == CAUSE_HOME:
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			text += f.get_as_text()
	for cause: StringName in Attention.CAUSES:
		check(text.contains('&"%s"' % cause),
			"Attention.CAUSES declares %s at %+.3f and nothing outside %s ever applies it: either wire it or take the row out"
			% [cause, Attention.of(cause), CAUSE_HOME.get_file()])


## And the other half of the same promise: what a step spends lives in one place,
## so nobody adds a second number for it.
func test_what_a_step_spends_is_stated_once() -> void:
	eq(RaidStage.SPENDS.size(), RaidStage.ORDER.size(), "one spend per stage")
	check(not Attention.CAUSES.has(&"raided"),
		"a step's spend is RaidStage.SPENDS, per stage; a single CAUSES row cannot say it")
	for i: int in RaidStage.ORDER.size():
		check(RaidStage.spends(RaidStage.ORDER[i]) >= 0.0, "a spend is taken off, never added")
