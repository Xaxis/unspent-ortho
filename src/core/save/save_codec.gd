class_name SaveCodec
## Turning game values into JSON-safe ones and back. JSON has no INF, no
## vectors, no int keys and no bytes, and it hands every number back as a
## float; these helpers make each of those explicit so a load callable gets
## back exactly the values its save callable started from.
##
##   SaveCodec.num(INF) -> "inf"        SaveCodec.to_num("inf") -> INF
##   SaveCodec.vec2(Vector2(1, 2)) -> [1.0, 2.0]
##   SaveCodec.bytes(PackedByteArray) -> String   (zstd, then base64)
##   SaveCodec.canonical(v) -> String   one spelling per value: sorted keys, JSON numbers

## A float that may be infinite: INF and -INF become strings.
static func num(f: float) -> Variant:
	if is_inf(f):
		return "inf" if f > 0.0 else "-inf"
	return f


static func to_num(v: Variant, fallback: float = 0.0) -> float:
	if v is String:
		match v:
			"inf":
				return INF
			"-inf":
				return -INF
		return fallback
	if v is float or v is int:
		return float(v)
	return fallback


static func to_int(v: Variant, fallback: int = 0) -> int:
	if v is float or v is int:
		return int(v)
	return fallback


static func vec2(p: Vector2) -> Array:
	return [p.x, p.y]


static func to_vec2(v: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(to_num(v[0]), to_num(v[1]))
	return fallback


## StringName -> int (a creel, edges) as String -> int.
static func counts(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		out[String(k)] = int(d[k])
	return out


static func to_counts(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k: Variant in v:
			out[StringName(str(k))] = to_int(v[k])
	return out


## Bytes packed small: zstd, then base64 with the raw length in front ("N:...").
static func bytes(b: PackedByteArray) -> String:
	if b.is_empty():
		return "0:"
	return "%d:%s" % [b.size(), Marshalls.raw_to_base64(b.compress(FileAccess.COMPRESSION_ZSTD))]


static func to_bytes(v: Variant) -> PackedByteArray:
	if not (v is String):
		return PackedByteArray()
	var s: String = v
	var colon := s.find(":")
	if colon <= 0:
		return PackedByteArray()
	var n := s.substr(0, colon).to_int()
	if n <= 0:
		return PackedByteArray()
	var packed := Marshalls.base64_to_raw(s.substr(colon + 1))
	if packed.is_empty():
		return PackedByteArray()
	var out := packed.decompress(n, FileAccess.COMPRESSION_ZSTD)
	return out if out.size() == n else PackedByteArray()


static func floats(a: PackedFloat32Array) -> String:
	return bytes(a.to_byte_array())


static func to_floats(v: Variant) -> PackedFloat32Array:
	return to_bytes(v).to_float32_array()


## One spelling for a JSON-safe value, keys sorted at every depth, so two values
## compare equal as text exactly when a save file would hold the same thing.
## Floats are spelled to 12 significant digits: JSON's reader can land a float
## one representable step from the one written (1920.1166666666666 comes back
## ...663), which is not a difference anything in the game can see.
static func canonical(v: Variant) -> String:
	return JSON.stringify(_sorted(v), "", true, true)


static func _sorted(v: Variant) -> Variant:
	if v is Dictionary:
		var keys: Array = (v as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var out := {}
		for k: Variant in keys:
			out[str(k)] = _sorted(v[k])
		return out
	if v is Array:
		var out: Array = []
		for e: Variant in v:
			out.append(_sorted(e))
		return out
	# JSON reads every number back as a float: spell ints the same way.
	if v is int:
		return float(v)
	if v is float:
		return 0.0 if v == 0.0 else float(String.num(v, maxi(0, 11 - floori(log(absf(v)) / log(10.0)))))
	if v is StringName:
		return String(v)
	return v
