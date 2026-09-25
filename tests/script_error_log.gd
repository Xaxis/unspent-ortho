extends Logger
## The runner's ear for SCRIPT ERRORs (tests/run.gd): a parse error, a call on
## null, a bad index. GDScript prints one and goes on — the function it happened
## in simply stops — so a test whose code died half way through still returns,
## has no failed assertion, and was printed "ok". That is a false green, and the
## worst kind: the code under test did not run and the gate said it did.
##
## Only script errors are kept. Engine errors (a leaked RID at exit, a shader
## warning) are other checks' business, and counting them here would turn every
## run red at quit for reasons no test caused. The engine may log from any
## thread, hence the mutex.

var _lines: PackedStringArray = []
var _lock := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_lock.lock()
	_lines.append("SCRIPT ERROR %s (%s:%d %s) %s" % [code, file, line, function, rationale])
	_lock.unlock()


## Every script error since the last take, and forget them.
func take() -> PackedStringArray:
	_lock.lock()
	var out := _lines.duplicate()
	_lines.clear()
	_lock.unlock()
	return out
