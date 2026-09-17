class_name ConfigChoices
## The settings as the slate shows and steps them, and the checks that need the
## game's content: where a game may start (the landscapes), the weather kinds,
## what can be carried and what can be worn. ConfigSchema stays light; this does not.
##
##   ConfigChoices.options(id)           a choice's values, in stepping order
##   ConfigChoices.step(id, value, dir)  the next value left (-1) or right (+1)
##   ConfigChoices.show(id, value)       the value in a few words
##   ConfigChoices.check(id, value)      "" or why not, content included
##   ConfigChoices.problems(settings)    every why-not in a table of settings


static func options(id: String) -> Array:
	var r := ConfigSchema.row(id)
	match str(r.get("from", "")):
		"places":
			var out: Array = ["spawn"]
			for b in BiomeRegistry.land():
				out.append(String(b.id))
			out.append_array(["river", "cliff"])
			return out
		"weather":
			var out: Array = ["rules"]
			for k in Weather.KINDS:
				out.append(String(k))
			return out
	return (r.get("options", []) as Array).duplicate()


## Things a kit may hold: every item, in the order Items declares them.
static func kit_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Items.DEFS:
		out.append(id)
	return out


## Things that can be worn: gear pieces and modules.
static func fit_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Items.DEFS:
		if Gear.slot_of(id) != &"" or Gear.is_module(id):
			out.append(id)
	return out


static func check(id: String, v: Variant) -> String:
	var why := ConfigSchema.check(id, v)
	if why != "":
		return why
	var r := ConfigSchema.row(id)
	if r.has("from") and not options(id).has(v):
		return "%s: %s is not one of the game's" % [id, str(v)]
	match str(r.kind):
		"kit":
			for k: Variant in v:
				if not Items.DEFS.has(StringName(str(k))):
					return "%s: there is no item %s" % [id, str(k)]
		"fit":
			var wearable := fit_items()
			for x: Variant in v:
				if not wearable.has(StringName(str(x))):
					return "%s: %s is not worn" % [id, str(x)]
	return ""


static func problems(settings: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for id: Variant in settings:
		var why := check(str(id), settings[id])
		if why != "":
			out.append(why)
	return out


## The value one step left or right of `v`. Text, kits and gear lists do not
## step: they are edited on pages of their own.
static func step(id: String, v: Variant, dir: int) -> Variant:
	var r := ConfigSchema.row(id)
	match str(r.get("kind", "")):
		"bool":
			return not bool(v)
		"int":
			var n := int(v) + signi(dir)
			if n < int(r.min):
				n = int(r.max)
			elif n > int(r.max):
				n = int(r.min)
			return n
		"choice":
			var opts := options(id)
			if opts.is_empty():
				return v
			var i := -1
			for k in opts.size():
				if ConfigSchema.same(opts[k], v) and (opts[k] is String) == (v is String):
					i = k
			return opts[posmod(i + signi(dir), opts.size())] if i >= 0 else opts[0]
	return v


static func show(id: String, v: Variant) -> String:
	var r := ConfigSchema.row(id)
	match str(r.get("kind", "")):
		"bool":
			return "yes" if bool(v) else "no"
		"text":
			return "-" if str(v) == "" else str(v)
		"kit":
			var n := 0
			for k: Variant in v:
				n += int(v[k])
			return "nothing" if n == 0 else ("%d thing%s" % [n, "" if n == 1 else "s"])
		"fit":
			var n := (v as Array).size()
			return "nothing" if n == 0 else ("%d piece%s" % [n, "" if n == 1 else "s"])
		"targets":
			return " ".join(PackedStringArray((v as Array).map(func(t: Variant) -> String: return target_name(str(t)))))
	match id:
		"world.hour":
			var h := float(v)
			return "%02d:%02d" % [floori(h), roundi(fmod(h, 1.0) * 60.0)]
		"world.start":
			if str(v) == "spawn":
				return "the strand"
			var b := BiomeRegistry.get_def(StringName(str(v)))
			return b.display_name.to_lower() if b != null and b.display_name != "" else str(v)
		"world.weather":
			return "each land's own" if str(v) == "rules" else str(v).replace("_", " ")
		"world.weather_strength":
			return "%d%%" % roundi(float(v) * 100.0)
		"rules.clock":
			var m := float(v)
			if m <= 0.0:
				return "stopped"
			return "x%s  a day in %s" % [_num(m), _span(1440.0 / m)]
		"rules.hazards":
			var h := float(v)
			return "none" if h <= 0.0 else "x%s" % _num(h)
		"rules.autosave":
			match str(v):
				"off":
					return "never"
				"rare":
					return "every 6 hours"
				"normal":
					return "every 3 hours"
				"often":
					return "every 90 minutes"
			return str(v)
		"rules.harm", "rules.hunger":
			var h := float(v)
			return "none" if h <= 0.0 else "x%s" % _num(h)
		"rules.bodies":
			return "x%s" % _num(float(v))
	return str(v)


static func target_name(t: String) -> String:
	match t:
		"web-nothreads":
			return "web no threads"
	return t


static func _num(f: float) -> String:
	return str(int(f)) if is_equal_approx(f, roundf(f)) else str(f)


## Real seconds said plainly: "24 min", "48 s".
static func _span(real_seconds: float) -> String:
	if real_seconds >= 3600.0:
		return "%s h" % _num(snappedf(real_seconds / 3600.0, 0.1))
	if real_seconds >= 60.0:
		return "%d min" % roundi(real_seconds / 60.0)
	return "%d s" % roundi(real_seconds)
