extends Logger
## Counts the engine's errors while installed, so a test can say a run was
## clean (a green test that prints ERROR lines is not green). The engine may log
## from any thread, hence the mutex.

var lines: PackedStringArray = []
var _lock := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_lock.lock()
	lines.append("%s (%s:%d %s) %s" % [code, file, line, function, rationale])
	_lock.unlock()


func errors() -> PackedStringArray:
	_lock.lock()
	var out := lines.duplicate()
	_lock.unlock()
	return out
