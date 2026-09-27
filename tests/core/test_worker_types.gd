extends TestCase
## NO WORKER RUNS AN OPERATOR ON AN UNTYPED VALUE (tests/core/worker_scan.gd has
## the rule and the reach). The failure this guards is not a red test but the
## process gone mid-play: two workers meeting one cold operator at once. Every
## finding is fixed by typing the operand (a cast, a typed container, a table
## read into typed arrays on the main thread), or it is named in
## worker_untyped_ok.txt with the reason it is safe.

const Scan := preload("res://tests/core/worker_scan.gd")
const OK_PATH := "res://tests/core/worker_untyped_ok.txt"


func _allowed() -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string(OK_PATH).split("\n"):
		var l := line.strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		out[l.get_slice(" -- ", 0)] = true
	return out


func test_the_scan_reaches_the_known_worker_code() -> void:
	var reached := Scan.reached(Scan.sources())
	for k: String in ["res://src/ui/ui_sketch.gd::_raster", "res://src/ui/ui_sketch.gd::to_phosphor",
			"res://src/audio/synth.gd::buffer", "res://src/core/worldgen/gen_fields.gd::batch"]:
		check(reached.has(k) or not FileAccess.file_exists(k.get_slice("::", 0)), "%s is reached from a worker" % k)
	gt(float(reached.size()), 200.0, "the reach goes through the calls (%d functions)" % reached.size())


func test_no_worker_runs_an_operator_on_an_untyped_value() -> void:
	var ok := _allowed()
	var found := Scan.findings(Scan.sources())
	for f in found:
		check(ok.has(f), "%s: a worker runs an operator on an untyped value; type the operand or name it in worker_untyped_ok.txt" % f)
	var live := {}
	for f in found:
		live[f] = true
	for k: String in ok:
		check(live.has(k), "%s is allowed in worker_untyped_ok.txt and no longer found: delete its line" % k)
