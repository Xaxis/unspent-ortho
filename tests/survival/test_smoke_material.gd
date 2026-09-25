extends TestCase
## Building the fire's smoke and spark materials makes the engine say nothing.
## The web gate fails on any console line, and a property a material does not
## have (a Light's, a 3.x SpatialMaterial's) is a warning, not a parse error.


class Warnings extends Logger:
	var lines: PackedStringArray = []
	var _lock := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		lines.append("%s %s (%s:%d)" % [code, rationale, file, line])
		_lock.unlock()


func test_smoke_and_spark_materials_build_without_a_warning() -> void:
	var log := Warnings.new()
	OS.add_logger(log)
	# Another test in this process may have built them already; build afresh.
	FireModel._puff = null
	FireModel._spark = null
	var smoke := FireModel.smoke_material()
	var spark := FireModel.spark_material()
	OS.remove_logger(log)
	check(smoke != null and spark != null, "both built")
	eq(log.lines, PackedStringArray(), "the engine printed nothing while building them")
