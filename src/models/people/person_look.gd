class_name PersonLook
## What a person looks like, as data: build, clothes, colours, salvage kit.
## Pure (no nodes), so crowds can be generated and checked headless.
##
## A spec is a Dictionary; every key is optional and missing keys fall back to
## the player's base look (art-audio-extract §2d, §4):
##   build      StringName  one of BUILDS
##   hat        StringName  one of HATS
##   coat       StringName  one of COATS
##   shirt_cut  StringName  one of SHIRT_CUTS
##   beard      StringName  one of BEARDS
##   hair_style StringName  one of HAIR_STYLES
##   hair       StringName  a HAIR preset, or a colour
##   skin       StringName  a SKIN window;  skin_v int 1..3 (centre of 3 adjacent values)
##   shirt, coat_col, trouser, boot, hat_col   colour: Color, "ramp:v", or [ramp, v]
##   extras     Array       of EXTRAS
##   salvage    Array       of SALVAGE (one or two parts; never the full set)
##   side       int         +1 salvage on the right, -1 on the left
##
## Identity is carried by costume, never by complexion: generators pick skin
## independently of everything else.

const BUILDS: Array[StringName] = [&"man", &"woman", &"boy", &"heavy", &"slight", &"old", &"tall", &"stark", &"squat", &"bent"]
const HATS: Array[StringName] = [&"none", &"band", &"brim", &"cap", &"knit", &"scarf", &"souwester"]
const COATS: Array[StringName] = [&"none", &"jerkin", &"long", &"oilskin"]
const SHIRT_CUTS: Array[StringName] = [&"tucked", &"loose", &"smock"]
const BEARDS: Array[StringName] = [&"none", &"chin", &"full", &"stache"]
const HAIR_STYLES: Array[StringName] = [&"bald", &"bun", &"crop", &"long", &"tail", &"thin", &"unkempt"]
const EXTRAS: Array[StringName] = [&"rolled", &"apron", &"buckle", &"shawl", &"neckerchief", &"satchel"]
const SALVAGE: Array[StringName] = [&"plate", &"brace", &"rig", &"gauntlet", &"tally", &"aerial", &"lens", &"mask"]

## Body proportions as multipliers on the base man. stoop is radians of spine lean.
##   leg torso: lengths   chest hip girth: width, width, depth   head arm limb: sizes
## Pushed well past the source's pixel deltas: under a 57-degree ortho camera a
## 10% difference in chest width is invisible, and every pair must read apart.
##   arms: how far the arms stand off the body at rest   knees: rest knee bend
const BUILD_SHAPE := {
	&"man": {"leg": 1.0, "torso": 1.0, "chest": 1.0, "hip": 1.0, "girth": 1.0, "head": 1.0, "arm": 1.0, "limb": 1.0, "stoop": 0.0, "belly": 0.0, "arms": 0.08, "knees": 0.0},
	# The only build with hips wider than shoulders.
	&"woman": {"leg": 0.94, "torso": 0.95, "chest": 0.78, "hip": 1.2, "girth": 0.9, "head": 0.95, "arm": 0.92, "limb": 0.84, "stoop": 0.0, "belly": 0.0, "arms": 0.12, "knees": 0.0},
	&"boy": {"leg": 0.62, "torso": 0.68, "chest": 0.7, "hip": 0.74, "girth": 0.78, "head": 0.9, "arm": 0.68, "limb": 0.76, "stoop": 0.0, "belly": 0.0, "arms": 0.1, "knees": 0.0},
	&"heavy": {"leg": 0.94, "torso": 1.04, "chest": 1.36, "hip": 1.34, "girth": 1.55, "head": 1.05, "arm": 1.0, "limb": 1.38, "stoop": 0.0, "belly": 0.1, "arms": 0.26, "knees": 0.05},
	# Long torso over short legs.
	&"slight": {"leg": 0.84, "torso": 1.16, "chest": 0.8, "hip": 0.84, "girth": 0.8, "head": 0.94, "arm": 0.95, "limb": 0.78, "stoop": 0.0, "belly": 0.0, "arms": 0.05, "knees": 0.0},
	&"old": {"leg": 0.88, "torso": 0.95, "chest": 0.9, "hip": 0.95, "girth": 0.9, "head": 0.98, "arm": 0.98, "limb": 0.82, "stoop": 0.34, "belly": 0.03, "arms": 0.1, "knees": 0.24},
	# Short torso over long legs.
	&"tall": {"leg": 1.3, "torso": 0.9, "chest": 0.98, "hip": 0.94, "girth": 0.92, "head": 0.98, "arm": 1.16, "limb": 0.92, "stoop": 0.0, "belly": 0.0, "arms": 0.06, "knees": 0.0},
	# Starved: narrow at every row, small head.
	&"stark": {"leg": 1.08, "torso": 1.04, "chest": 0.7, "hip": 0.72, "girth": 0.62, "head": 0.84, "arm": 1.08, "limb": 0.6, "stoop": 0.08, "belly": 0.0, "arms": 0.03, "knees": 0.06},
	&"squat": {"leg": 0.7, "torso": 0.94, "chest": 1.42, "hip": 1.2, "girth": 1.3, "head": 1.02, "arm": 0.9, "limb": 1.4, "stoop": 0.0, "belly": 0.04, "arms": 0.2, "knees": 0.1},
	# A big person folded.
	&"bent": {"leg": 1.02, "torso": 1.1, "chest": 1.2, "hip": 1.08, "girth": 1.2, "head": 1.06, "arm": 1.12, "limb": 1.14, "stoop": 0.72, "belly": 0.0, "arms": 0.14, "knees": 0.18},
}

## Skin windows (art-audio-extract §2d), 5 values each, dark to light.
const SKIN := {
	&"deep": [Color("1a1220"), Color("33231f"), Color("4f3627"), Color("6f4d31"), Color("997044")],
	&"brown": [Color("33191b"), Color("5b2f28"), Color("8c563a"), Color("b87f57"), Color("e0aa7e")],
	&"tan": [Color("5b2f28"), Color("8c563a"), Color("b87f57"), Color("e0aa7e"), Color("d8c193")],
	&"fair": [Color("8c563a"), Color("b87f57"), Color("e0aa7e"), Color("d8c193"), Color("e8dcc0")],
}
const SKIN_WINDOWS: Array[StringName] = [&"deep", &"brown", &"tan", &"fair"]

const HAIR := {
	&"black": [Color("12111d"), Color("1e1c2e")],
	&"dark": [Color("33231f"), Color("4f3627")],
	&"red": [Color("6e3320"), Color("9a4f28")],
	&"fair": [Color("5c4d45"), Color("85705a")],
	&"grey": [Color("5c626e"), Color("868d99")],
	&"white": [Color("c0b394"), Color("e8dcc0")],
}
const HAIR_PRESETS: Array[StringName] = [&"black", &"dark", &"red", &"fair", &"grey", &"white"]

## Wearable ramps: ink and copper are reserved and never recoloured.
const WEAR: Array[StringName] = [&"stone", &"brine", &"slate", &"earth", &"rust", &"moss", &"spruce", &"sand", &"linen"]

const BASE := {
	"build": &"man", "hat": &"none", "coat": &"none", "shirt_cut": &"tucked", "beard": &"none",
	"hair_style": &"crop", "hair": &"fair", "skin": &"brown", "skin_v": 3,
	"shirt": "linen:2", "coat_col": "earth:2", "trouser": "slate:1", "boot": "earth:1", "hat_col": "slate:2",
	"extras": [&"neckerchief", &"satchel"], "salvage": [], "side": 1,
}


static func ramp(n: StringName) -> Array[Color]:
	match n:
		&"stone": return Palette.STONE
		&"brine": return Palette.BRINE
		&"slate": return Palette.SLATE
		&"earth": return Palette.EARTH
		&"rust": return Palette.RUST
		&"moss": return Palette.MOSS
		&"spruce": return Palette.SPRUCE
		&"sand": return Palette.SAND
		&"linen": return Palette.LINEN
		&"ash": return Palette.ASH
		&"ink": return Palette.INK
		&"flesh": return Palette.FLESH
	return Palette.LINEN


## A colour value from a spec: Color, "ramp:v" or [ramp, v].
static func colour(v: Variant) -> Color:
	if v is Color:
		return v
	var r := &"linen"
	var i := 2
	if v is String or v is StringName:
		var parts := String(v).split(":")
		r = StringName(parts[0])
		i = parts[1].to_int() if parts.size() > 1 else 2
	elif v is Array and (v as Array).size() >= 2:
		r = StringName(str(v[0]))
		i = int(v[1])
	var ramp_colours := ramp(r)
	return ramp_colours[clampi(i, 0, ramp_colours.size() - 1)]


## One step lighter/darker on the same ramp, for rims and shade faces. Colours
## given directly (not by ramp) step by the source's measured multiply.
static func step(v: Variant, by: int) -> Color:
	if v is String or v is StringName or v is Array:
		var r := &"linen"
		var i := 2
		if v is Array:
			r = StringName(str(v[0]))
			i = int(v[1])
		else:
			var parts := String(v).split(":")
			r = StringName(parts[0])
			i = parts[1].to_int() if parts.size() > 1 else 2
		var rc := ramp(r)
		return rc[clampi(i + by, 0, rc.size() - 1)]
	var c: Color = colour(v)
	var k := Vector3(0.7, 0.704, 0.749)
	if by < 0:
		return Color(c.r * k.x, c.g * k.y, c.b * k.z)
	return Color(minf(1.0, c.r / k.x), minf(1.0, c.g / k.y), minf(1.0, c.b / k.z))


## Fill every missing key from BASE and validate names. Unknown names fall back.
static func normalize(spec: Dictionary) -> Dictionary:
	var out := BASE.duplicate(true)
	for k: String in spec:
		out[k] = spec[k]
	out.build = _pick(out.build, BUILDS)
	out.hat = _pick(out.hat, HATS)
	out.coat = _pick(out.coat, COATS)
	out.shirt_cut = _pick(out.shirt_cut, SHIRT_CUTS)
	out.beard = _pick(out.beard, BEARDS)
	out.hair_style = _pick(out.hair_style, HAIR_STYLES)
	if not SKIN.has(StringName(str(out.skin))):
		out.skin = &"brown"
	out.skin = StringName(str(out.skin))
	out.skin_v = clampi(int(out.skin_v), 1, 3)
	out.side = 1 if int(out.side) >= 0 else -1
	var ex: Array = []
	for e: Variant in out.extras:
		if EXTRAS.has(StringName(str(e))):
			ex.append(StringName(str(e)))
	out.extras = ex
	var sv: Array = []
	for s: Variant in out.salvage:
		if SALVAGE.has(StringName(str(s))) and not sv.has(StringName(str(s))):
			sv.append(StringName(str(s)))
	out.salvage = sv
	return out


static func _pick(v: Variant, allowed: Array[StringName]) -> StringName:
	var s := StringName(str(v))
	return s if allowed.has(s) else allowed[0]


static func shape(build: StringName) -> Dictionary:
	return BUILD_SHAPE.get(build, BUILD_SHAPE[&"man"])


## Three adjacent skin values: [shade, base, light].
static func skin_values(spec: Dictionary) -> Array[Color]:
	var w: Array = SKIN.get(StringName(str(spec.get("skin", &"brown"))), SKIN[&"brown"])
	var v := clampi(int(spec.get("skin_v", 3)), 1, 3)
	return [w[v - 1], w[v], w[v + 1]]


static func hair_values(spec: Dictionary) -> Array[Color]:
	var h: Variant = spec.get("hair", &"fair")
	if h is Color:
		return [step(h, -1), h]
	var s := StringName(str(h))
	if HAIR.has(s):
		var hv: Array = HAIR[s]
		return [hv[0], hv[1]]
	var c := colour(h)
	return [step(h, -1), c]


## Rec. 601 luminance on 0..255, as the source's contrast bar measured it.
static func luma(c: Color) -> float:
	return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * 255.0


## The outermost layer on the torso: the coat if there is one, else the shirt.
static func outer(spec: Dictionary) -> Color:
	var s := normalize(spec)
	return colour(s.coat_col) if s.coat != &"none" and s.coat != &"jerkin" else colour(s.shirt)


## Contrast bar (§2d): skin to outer >= 25, outer to trousers >= 25, spread >= 60.
static func contrast_ok(spec: Dictionary) -> bool:
	var s := normalize(spec)
	var sk := luma(skin_values(s)[1])
	var o := luma(outer(s))
	var t := luma(colour(s.trouser))
	return absf(sk - o) >= 25.0 and absf(o - t) >= 25.0 and maxf(sk, maxf(o, t)) - minf(sk, minf(o, t)) >= 60.0


## The three silhouette axes a crowd must not repeat.
static func signature(spec: Dictionary) -> String:
	var s := normalize(spec)
	return "%s/%s/%s" % [s.build, s.hat, s.coat]


## How many of {build, hat, coat} set this person apart from the base man.
static func distinct_axes(spec: Dictionary) -> int:
	var s := normalize(spec)
	return int(s.build != &"man") + int(s.hat != &"none") + int(s.coat != &"none")


## One person, deterministic in (seed, index). Obeys the contrast bar and has at
## least two of {build, hat, coat}.
static func random(seed_value: int, index: int = 0) -> Dictionary:
	var r := Rng.make(seed_value, 7717 + index * 131)
	var spec: Dictionary = {}
	for attempt in 24:
		spec = _roll(r)
		if distinct_axes(spec) >= 2 and contrast_ok(spec):
			return normalize(spec)
	# Force the bar: darkest trousers, lightest shirt that still reads as wool.
	spec.trouser = "slate:0"
	spec.shirt = "linen:4"
	spec.coat = &"none"
	if distinct_axes(spec) < 2:
		spec.hat = &"cap"
		spec.build = &"heavy" if spec.build == &"man" else spec.build
	return normalize(spec)


static func _roll(r: RandomNumberGenerator) -> Dictionary:
	var build: StringName = BUILDS[r.randi_range(0, BUILDS.size() - 1)]
	var old := build == &"old" or build == &"bent"
	var hair_style: StringName = HAIR_STYLES[r.randi_range(0, HAIR_STYLES.size() - 1)]
	var hair: StringName = HAIR_PRESETS[r.randi_range(0, 3)]
	if old or r.randf() < 0.12:
		hair = [&"grey", &"white", &"grey"][r.randi_range(0, 2)]
		if r.randf() < 0.4:
			hair_style = [&"bald", &"thin"][r.randi_range(0, 1)]
	var beard := &"none"
	if build != &"woman" and build != &"boy" and r.randf() < 0.45:
		beard = BEARDS[r.randi_range(1, BEARDS.size() - 1)]
	if build == &"woman" and hair_style == &"bald":
		hair_style = &"bun"
	var hat: StringName = HATS[r.randi_range(0, HATS.size() - 1)] if r.randf() < 0.75 else &"none"
	var coat: StringName = COATS[r.randi_range(0, COATS.size() - 1)] if r.randf() < 0.7 else &"none"
	var extras: Array = []
	for e: StringName in EXTRAS:
		if r.randf() < 0.16:
			extras.append(e)
	var salvage: Array = []
	if r.randf() < 0.35:
		salvage.append(SALVAGE[r.randi_range(0, SALVAGE.size() - 1)])
		if r.randf() < 0.3:
			var second: StringName = SALVAGE[r.randi_range(0, SALVAGE.size() - 1)]
			if not salvage.has(second):
				salvage.append(second)
	return {
		"build": build, "hat": hat, "coat": coat,
		"shirt_cut": SHIRT_CUTS[r.randi_range(0, SHIRT_CUTS.size() - 1)],
		"beard": beard, "hair_style": hair_style, "hair": hair,
		"skin": SKIN_WINDOWS[r.randi_range(0, SKIN_WINDOWS.size() - 1)], "skin_v": r.randi_range(1, 3),
		"shirt": _wear(r, SHIRT_WEAR), "coat_col": _wear(r, COAT_WEAR), "trouser": _wear(r, TROUSER_WEAR),
		"boot": _wear(r, BOOT_WEAR), "hat_col": _wear(r, HAT_WEAR),
		"extras": extras, "salvage": salvage, "side": 1 if r.randf() < 0.6 else -1,
	}


## Wool and canvas live on the muted middle of the wearable ramps: [ramp, lo, hi].
## Rust and brine are the rare warm and blue things in a crowd, and never bright.
const SHIRT_WEAR := [["linen", 2, 4], ["linen", 3, 4], ["sand", 3, 4], ["stone", 3, 4], ["slate", 3, 4], ["earth", 3, 4], ["brine", 3, 3], ["moss", 3, 3], ["rust", 2, 3]]
const COAT_WEAR := [["earth", 1, 3], ["earth", 2, 3], ["slate", 1, 3], ["spruce", 1, 2], ["moss", 1, 2], ["sand", 2, 3], ["stone", 1, 2], ["rust", 1, 2], ["brine", 1, 2]]
const TROUSER_WEAR := [["slate", 0, 2], ["earth", 0, 2], ["stone", 0, 1], ["sand", 1, 2], ["spruce", 0, 1], ["linen", 1, 1]]
const BOOT_WEAR := [["earth", 0, 1], ["earth", 1, 2], ["slate", 0, 1], ["stone", 0, 1]]
const HAT_WEAR := [["earth", 1, 3], ["slate", 1, 3], ["spruce", 1, 2], ["moss", 1, 2], ["sand", 2, 3], ["stone", 1, 3], ["rust", 1, 2], ["linen", 2, 3], ["ash", 1, 2]]


static func _wear(r: RandomNumberGenerator, table: Array) -> String:
	var e: Array = table[r.randi_range(0, table.size() - 1)]
	return "%s:%d" % [e[0], r.randi_range(int(e[1]), int(e[2]))]


## n people where nobody repeats another's {build, hat, coat}.
static func crowd(seed_value: int, n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var i := 0
	while out.size() < n and i < n * 40:
		var p := random(seed_value, i)
		i += 1
		var sig := signature(p)
		if seen.has(sig):
			continue
		seen[sig] = true
		out.append(p)
	return out
