class_name SaveGame
## Contract: every system persists its own state by registering a key, so
## nothing central needs to know every system.
##
##   SaveGame.register(&"survival", func() -> Variant: return {...}, func(v: Variant) -> void: ...)
##
## save callables return JSON-safe Variants (Dictionary, Array, String, float,
## int, bool; SaveCodec converts INF, vectors, bytes). load callables receive
## what save returned after a trip through JSON: numbers come back as floats and
## keys as Strings, so a load converts (SaveCodec.to_int, to_vec2, to_counts).
##
## Register in a GameSystem's setup(). A loaded game is applied once, after every
## system's setup and before the first frame (GameSystem.started, 05_save), in
## registration order: core state first (05_save registers it), then each system.
## A key a save holds that nobody registered in this build is kept and written
## back on the next save, so a package that is not loaded never loses its state.
## The registry belongs to one running game: 05_save clears it when that game ends.

static var _entries: Dictionary = {} # StringName -> {save: Callable, load: Callable}
## Keys from the last applied save that nothing registered: carried forward.
static var _unclaimed: Dictionary = {}


static func register(key: StringName, save: Callable, load: Callable) -> void:
	_entries[key] = {"save": save, "load": load}


static func registered(key: StringName) -> bool:
	return _entries.has(key)


static func keys() -> Array:
	return _entries.keys()


static func collect() -> Dictionary:
	var out := _unclaimed.duplicate(true)
	for k: StringName in _entries:
		out[String(k)] = (_entries[k].save as Callable).call()
	return out


## Apply a save's data, key by key in registration order. Returns the keys that
## were applied. One key's load failing to find its fields never stops another's.
static func apply(data: Dictionary) -> PackedStringArray:
	var done := PackedStringArray()
	_unclaimed.clear()
	for k: String in data:
		if not _entries.has(StringName(k)):
			_unclaimed[k] = data[k]
	for k: StringName in _entries:
		if data.has(String(k)):
			(_entries[k].load as Callable).call(data[String(k)])
			done.append(String(k))
	return done


## Drop entries whose owner has been freed (a game that ended without clearing).
static func forget_invalid() -> void:
	for k: StringName in _entries.keys():
		var e: Dictionary = _entries[k]
		if not (e.save as Callable).is_valid() or not (e.load as Callable).is_valid():
			_entries.erase(k)


static func clear() -> void:
	_entries.clear()
	_unclaimed.clear()
