extends RefCounted
## Whether two worlds are the same world, field for field: every script variable
## of WorldData (read off its property list, so a field added later is compared
## without a line here), every object in one by its own script variables, and
## the world's metadata. Stricter than `==`, which calls &"a" and "a" equal, an
## Array[int] and an Array equal, and NaN unequal to itself:
##   - a value's type, and a container's element types, must match;
##   - floats, vectors and packed arrays compare by their bytes;
##   - dictionaries compare in key order (iteration order is behaviour).
##
##   const WorldSame := preload("res://tests/boot/world_same.gd")
##   WorldSame.differences(a, b)  -> PackedStringArray, empty when the same


static func differences(a: WorldData, b: WorldData, most: int = 20) -> PackedStringArray:
	var out := PackedStringArray()
	for p: Dictionary in a.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			_diff(a.get(p.name), b.get(p.name), String(p.name), out, most)
	var am := a.get_meta_list()
	var bm := b.get_meta_list()
	if am != bm:
		out.append("meta: %s against %s" % [str(am), str(bm)])
	else:
		for m: StringName in am:
			_diff(a.get_meta(m), b.get_meta(m), "meta %s" % m, out, most)
	return out


## Any two values, by the same rules.
static func values(a: Variant, b: Variant, at: String = "value", most: int = 20) -> PackedStringArray:
	var out := PackedStringArray()
	_diff(a, b, at, out, most)
	return out


## The script variables of a WorldData, by name.
static func fields(w: WorldData) -> PackedStringArray:
	var out := PackedStringArray()
	for p: Dictionary in w.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(String(p.name))
	return out


static func _diff(a: Variant, b: Variant, at: String, out: PackedStringArray, most: int) -> void:
	if out.size() >= most:
		return
	if typeof(a) != typeof(b):
		out.append("%s: a %s against a %s" % [at, type_string(typeof(a)), type_string(typeof(b))])
		return
	match typeof(a):
		TYPE_OBJECT:
			var oa := a as Object
			var ob := b as Object
			if oa == null or ob == null:
				if (oa == null) != (ob == null):
					out.append("%s: one is null" % at)
				return
			if oa.get_script() != ob.get_script() or oa.get_class() != ob.get_class():
				out.append("%s: %s against %s" % [at, _name_of(oa), _name_of(ob)])
				return
			for p: Dictionary in oa.get_property_list():
				if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
					_diff(oa.get(p.name), ob.get(p.name), "%s.%s" % [at, p.name], out, most)
		TYPE_ARRAY:
			var xa := a as Array
			var xb := b as Array
			if xa.get_typed_builtin() != xb.get_typed_builtin() or xa.get_typed_class_name() != xb.get_typed_class_name() \
					or xa.get_typed_script() != xb.get_typed_script():
				out.append("%s: typed %s/%s against %s/%s" % [at, type_string(xa.get_typed_builtin()), xa.get_typed_class_name(),
					type_string(xb.get_typed_builtin()), xb.get_typed_class_name()])
				return
			if xa.size() != xb.size():
				out.append("%s: %d entries against %d" % [at, xa.size(), xb.size()])
				return
			for i in xa.size():
				_diff(xa[i], xb[i], "%s[%d]" % [at, i], out, most)
		TYPE_DICTIONARY:
			var da := a as Dictionary
			var db := b as Dictionary
			if da.get_typed_key_builtin() != db.get_typed_key_builtin() or da.get_typed_value_builtin() != db.get_typed_value_builtin() \
					or da.get_typed_key_script() != db.get_typed_key_script() or da.get_typed_value_script() != db.get_typed_value_script():
				out.append("%s: a dictionary typed another way" % at)
				return
			var ka := da.keys()
			var kb := db.keys()
			if ka.size() != kb.size():
				out.append("%s: %d keys against %d" % [at, ka.size(), kb.size()])
				return
			for i in ka.size():
				if typeof(ka[i]) != typeof(kb[i]) or var_to_bytes(ka[i]) != var_to_bytes(kb[i]):
					out.append("%s: key %d is %s against %s" % [at, i, str(ka[i]), str(kb[i])])
					return
				_diff(da[ka[i]], db[kb[i]], "%s[%s]" % [at, str(ka[i])], out, most)
		_:
			# Every other value -- floats, vectors, rects, strings, packed arrays --
			# by its bytes: exact, NaN included.
			if var_to_bytes(a) != var_to_bytes(b):
				out.append("%s: %s against %s" % [at, _short(a), _short(b)])


static func _name_of(o: Object) -> String:
	var s := o.get_script() as Script
	return s.resource_path if s != null else o.get_class()


static func _short(v: Variant) -> String:
	var s := str(v)
	return s if s.length() < 80 else s.substr(0, 77) + "..."
