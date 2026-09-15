class_name SaveGame
## Contract (M2 saves package implements the rest): every system persists its own
## state by registering a key, so nothing central needs to know every system.
##
##   SaveGame.register(&"survival", func() -> Variant: return {...}, func(v: Variant) -> void: ...)
##
## save callables return JSON-safe Variants (Dictionary, Array, String, float,
## int, bool). load callables receive exactly what save returned. Register in a
## GameSystem's setup(); the save package clears the registry when a game ends.

static var _entries: Dictionary = {} # StringName -> {save: Callable, load: Callable}


static func register(key: StringName, save: Callable, load: Callable) -> void:
	_entries[key] = {"save": save, "load": load}


static func keys() -> Array:
	return _entries.keys()


static func collect() -> Dictionary:
	var out := {}
	for k: StringName in _entries:
		out[String(k)] = (_entries[k].save as Callable).call()
	return out


static func apply(data: Dictionary) -> void:
	for k: StringName in _entries:
		if data.has(String(k)):
			(_entries[k].load as Callable).call(data[String(k)])


static func clear() -> void:
	_entries.clear()
