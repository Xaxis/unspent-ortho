class_name SoundMix
## The mix as rules: bus layout and levels, the heard-level measure, how beds
## are weighted by where the player stands and what the weather does, and which
## machine is heard. Pure (no nodes), so the running game, the tests and
## tools/audio.sh all use the same numbers.
##
## Reference: 0 dB heard is the weather bed (rain) at full strength.
##   thunder +6..+10 | world events -4..+5 | interface <= -6
## heard = rms(loudest 0.5 s) x bus x call gain. Nothing carries its weight
## below 120 Hz (judge on a laptop). Hearing takes no penalty from weather or
## dark: you hear a machine before you see it.

const WEATHER_PATH := "res://src/core/weather.gd"

## [name, send, volume dB], in creation order (a bus sends only to one made
## before it). Made in code by SoundBuses; Master gets a limiter. World holds
## what a notebook page muffles (the ground's sounds and your own); machines
## and the interface stay out of it, because you hear a machine before you see
## it, page open or not.
const BUSES := [
	[&"Music", &"Master", -8.0],
	[&"World", &"Master", 0.0],
	[&"SFX", &"World", -2.5],
	[&"SfxFar", &"SFX", -1.0],
	[&"Ambience", &"World", -11.9],
	[&"Machines", &"Master", -11.9],
	[&"UI", &"Master", -6.0],
]

## How far a page muffles the world: 0 none, 1 fully (World low-pass at
## MUFFLE_HZ and MUFFLE_DB down). A notebook page is a partial muffle; pause
## is most of the way.
const MUFFLE_SCREEN := 0.45
const MUFFLE_PAUSE := 0.85
const MUFFLE_HZ := 1400.0
const MUFFLE_DB := -7.0

## Beds ease toward their targets with this time constant (s); the place is
## re-read (sea, river, remoteness) this often. SoundScene renders with the same.
## Space already crossfades (country_weights hears around you), so the fade only
## smooths the jumps: a scan, a weather read, a skip in time.
const BED_FADE := 0.6
const SCAN_EVERY := 0.5

## Footfalls: tiles travelled per step sound when walking and running, and the
## shortest gap between two (so a stutter at a wall does not machine-gun).
const STRIDE_WALK := 0.95
const STRIDE_RUN := 1.3
const STEP_MIN_GAP := 0.2

## One-shots further than this are not heard; past SFX_FAR they are dull and wet.
const SFX_RANGE := 40.0
const SFX_FAR := 9.0

## The bed a landscape lies under, named after what makes its sound.
static func country_bed(c: int) -> StringName:
	var bed := BiomeRegistry.by_index(c).sound_bed
	return bed if bed != &"" else &"bed_wind"


## Weather kind (Weather.KINDS) -> its bed. Kinds with no bed (clear, grey,
## fog, heat) only damp the others or scatter something of their own.
const WEATHER_BED := {
	&"rain": &"weather_rain",
	&"storm": &"weather_storm",
	&"hail": &"weather_hail",
	&"snow": &"weather_snow",
	&"blizzard": &"weather_blizzard",
	&"ash": &"weather_ash",
	&"dust": &"weather_sand",
	&"sand": &"weather_sand",
}

## How much a weather kind at full strength softens the country beds. Fog and
## snow deaden; a storm or blizzard drowns.
const WEATHER_DAMP := {
	&"grey": 0.95, &"fog": 0.75, &"snow": 0.65, &"storm": 0.5, &"blizzard": 0.4, &"rain": 0.8,
	&"hail": 0.75, &"sand": 0.6, &"dust": 0.6, &"ash": 0.7, &"heat": 0.85,
}

## Kinds whose wind is loud enough to gust on its own at strength.
const GUSTING := {&"storm": 0.6, &"blizzard": 0.8, &"dust": 0.4, &"sand": 0.4}

## One-shots a weather kind scatters while it lasts: [name, min gap, max gap] s.
const WEATHER_SCATTER := {
	&"heat": [&"heat_tick", 4.0, 16.0],
	&"storm": [&"thunder_roll", 25.0, 70.0],
}

## What is left of the far works by day, remote and still: a trace, not a bed.
const FAR_WORKS_DAY := 0.08

## Thunder is heard a long way: past THUNDER_NEAR tiles only the roll carries.
const THUNDER_NEAR := 90.0

## Absolute heard level (dBFS, loudest 0.5 s RMS after its bus) of the weather
## bed at full strength: 0 dB of the mix sheet. Loud enough for laptop speakers
## (calm places sit near -24 dBFS, a storm with thunder near -12). Spiky sounds
## keep under the Master limiter by having their own crest limited when they
## are baked (SoundBank.CEILING_DBFS), never by turning the whole game down.
const REF_DBFS := -20.0

static var _weather_script: GDScript
static var _weather_checked := false
static var _weather_has_place := false
static var _weather_has_tide := false


static func bus_db(bus: StringName) -> float:
	var total := 0.0
	var at := bus
	for guard in 4:
		var found := false
		for row: Array in BUSES:
			if row[0] == at:
				total += float(row[2])
				at = row[1]
				found = true
				break
		if not found:
			break
	return total


## How loud a baked sound is heard, measured from its samples, its bus and its
## call gain, in dB relative to the weather bed at full strength.
static func heard_db(b: SoundBank.Baked, extra_db: float = 0.0) -> float:
	# Interleaved stereo is measured as if at twice the rate: a half-second window
	# then holds both sides of every frame in it.
	var r := Synth.loudest_rms(b.samples, b.rate * (2 if b.stereo else 1), 0.5)
	return 20.0 * log(maxf(1e-9, r)) / log(10.0) + bus_db(b.bus) + b.gain_db + extra_db - REF_DBFS


# ------------------------------------------------------------------ beds

## Country bed weights for a listener: the tile underfoot turning toward its
## neighbour by WorldData.blend, and the land around it heard too, so the next
## country is audible before it is underfoot (and a border with no blend
## painted is still a crossfade, not a switch). Samples: the tile itself, then
## rings of EAR_RING points at EAR_RADII, weighted by EAR_WEIGHTS. Sums to 1.
const EAR_RADII: Array[float] = [0.0, 3.0, 7.0, 12.0]
const EAR_WEIGHTS: Array[float] = [0.18, 0.35, 0.3, 0.2]
const EAR_RING := 8


static func country_weights(world: WorldData, p: Vector2) -> Dictionary:
	var out := {}
	var total := 0.0
	for ring in EAR_RADII.size():
		var r := EAR_RADII[ring]
		var count := 1 if r == 0.0 else EAR_RING
		var w := EAR_WEIGHTS[ring] / count
		for k in count:
			# Rings turned off each other, so no two samples cross a straight border together.
			var a := TAU * (k + 0.5) / count + ring * 0.13
			var q := p + Vector2(cos(a), sin(a)) * r
			total += w
			_weigh_tile(world, q, w, out)
	for bed: StringName in out:
		out[bed] = float(out[bed]) / total
	return out


## The same rings as country_weights, by LANDSCAPE TYPE index rather than bed
## (`WorldData.country` carries the registry's index, and `country2`/`blend`
## carry the pair at a border), so the score reads what the ear is actually in.
## Sums to 1.
static func land_share(world: WorldData, p: Vector2) -> Dictionary:
	var out := {}
	var total := 0.0
	for ring in EAR_RADII.size():
		var r := EAR_RADII[ring]
		var count := 1 if r == 0.0 else EAR_RING
		var w := EAR_WEIGHTS[ring] / count
		for k in count:
			var a := TAU * (k + 0.5) / count + ring * 0.13
			var q := p + Vector2(cos(a), sin(a)) * r
			var x := clampi(floori(q.x), 0, world.size - 1)
			var y := clampi(floori(q.y), 0, world.size - 1)
			var i := y * world.size + x
			var c: int = world.country[i]
			var c2: int = world.country2[i] if world.country2.size() > i else c
			var bl: float = clampf(world.blend[i], 0.0, 1.0) if world.blend.size() > i else 0.0
			out[c] = float(out.get(c, 0.0)) + w * (1.0 - bl)
			if bl > 0.0:
				out[c2] = float(out.get(c2, 0.0)) + w * bl
			total += w
	for c: int in out:
		out[c] = float(out[c]) / total
	return out


## Rings the score looks along for what it will need next, as shares of `reach`.
const SOON_RINGS: Array[float] = [0.55, 1.0]
const SOON_RING := 8
## How much more the way the player is walking counts than the way behind them.
const SOON_LEAN := 0.75


## Landscapes the listener will be in soon: a ring at `reach` tiles and one
## halfway out, each sample leaning toward `heading` (a zero heading looks all
## ways equally), plus the point straight ahead. Never heard — it is what the
## score bakes before a border, so arriving somewhere is never silence. Sums to 1.
static func land_soon(world: WorldData, p: Vector2, heading: Vector2, reach: float) -> Dictionary:
	var dir := heading.normalized() if heading.length_squared() > 1e-6 else Vector2.ZERO
	var out := {}
	var total := 0.0
	var sample := func(q: Vector2, w: float) -> void:
		var x := clampi(floori(q.x), 0, world.size - 1)
		var y := clampi(floori(q.y), 0, world.size - 1)
		var i := y * world.size + x
		var c: int = world.country[i]
		out[c] = float(out.get(c, 0.0)) + w
		total += w
	for ring in SOON_RINGS.size():
		var r := reach * SOON_RINGS[ring]
		for k in SOON_RING:
			var a := TAU * (k + 0.5) / SOON_RING + ring * 0.19
			var v := Vector2(cos(a), sin(a))
			sample.call(p + v * r, 1.0 + SOON_LEAN * v.dot(dir))
	if dir != Vector2.ZERO:
		sample.call(p + dir * reach * 1.45, SOON_RING * 0.5)
	for c: int in out:
		out[c] = float(out[c]) / maxf(1e-6, total)
	return out


# ------------------------------------------------------------------ works

## Prop kinds, by name, that are the machines' installations: what hums, what a
## relay clicks in, what the score's grid pulse belongs to. By name, so a kind a
## landscape adds later ("relay", "substation", "mast") is heard the day it
## exists. Neon means something (VISION §8): an installation is heard where it
## stands, never over a whole village, so a word is a whole word of the name
## and each has a reach (INSTALLATION_REACH, else INSTALLATION_REACH_DEFAULT).
const INSTALLATION_WORDS: Array[String] = ["pylon", "relay", "transformer", "substation", "mast", "antenna", "array", "server", "beacon", "terminal", "junction",
	"intake", "pump", "checkpoint", "stack", "drill", "conveyor"]
## Tiles at which an installation's grid and hum begin; both are full within
## INSTALLATION_NEAR of that. A lone pylon is only heard standing under it; a
## substation fills its yard.
const INSTALLATION_REACH := {"pylon": 6.0, "mast": 8.0, "antenna": 8.0, "beacon": 9.0,
	# The land's works stand in lines and fields: each alone is heard close, the
	# field together further (shares add), and never over most of the island.
	"relay": 4.0, "drill": 4.0, "conveyor": 4.0, "pump": 6.0, "checkpoint": 7.0, "intake": 8.0, "stack": 9.0}
const INSTALLATION_REACH_DEFAULT := 14.0
const INSTALLATION_NEAR := 0.3
## Wires strung between poles: a faint sing in the wind, nothing more (a
## village's power line is not the machines' grid).
const WIRE_WORDS: Array[String] = ["pole", "wire", "cable"]
## Wreckage the wind finds a voice in: sheet, wire, girders, hulks.
const WRECK_WORDS: Array[String] = ["wreck", "ruin", "tip", "hulk", "girder", "fence", "barricade", "sign", "car", "rubble", "scrap", "shell", "cage", "wire", "tank", "crane", "container", "hut", "debris", "vehicle", "hull", "slag"]
## Roofs, walls and pipes that gather rain into gutters and drips.
const SHELTER_WORDS: Array[String] = ["house", "ruin", "wreck", "hut", "shelter", "shed", "tank", "container", "tower", "works", "kiln", "shell", "shack", "archive", "checkpoint", "vehicle", "hull"]
## Canopy that rain falls on as leaves and needles.
const LEAF_WORDS: Array[String] = ["pine", "broadleaf", "bush", "gorse", "reeds"]
## How far works_near looks (tiles).
const WORKS_RADIUS := 22.0
## How far strung wire is heard singing (tiles), and how loud at most (0..1 of its sheet level).
const WIRE_REACH := 8.0
const WIRE_FAINT := 0.4

const INSTALLATION := 1
const WRECK := 2
const SHELTER := 4
const CANOPY := 8
const WIRE := 16

static var _prop_classes: Dictionary = {}
static var _prop_reach: Dictionary = {}


## The whole words of a prop kind's name, lower case: "dead tree" is dead and
## tree; a "scarecrow" is never a car. A plural keeps its word ("wrecks").
static func name_words(name: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var word := ""
	for ch in name.to_lower() + " ":
		if (ch >= "a" and ch <= "z"):
			word += ch
		elif word != "":
			out.append(word)
			word = ""
	return out


static func _has_word(words: PackedStringArray, list: Array[String]) -> String:
	for w in words:
		for word in list:
			if w == word or w == word + "s" or w == word + "es":
				return word
	return ""


## Which of the word lists a prop kind's name falls in: INSTALLATION, WRECK,
## SHELTER, CANOPY and WIRE bits. Cached per kind.
static func prop_class(kind: int) -> int:
	if _prop_classes.has(kind):
		return _prop_classes[kind]
	var words := name_words(PropKind.NAMES[kind] if kind >= 0 and kind < PropKind.NAMES.size() else "")
	var bits := 0
	var installation := _has_word(words, INSTALLATION_WORDS)
	if installation != "":
		bits |= INSTALLATION
		_prop_reach[kind] = float(INSTALLATION_REACH.get(installation, INSTALLATION_REACH_DEFAULT))
	for pair: Array in [[WRECK_WORDS, WRECK], [SHELTER_WORDS, SHELTER], [LEAF_WORDS, CANOPY], [WIRE_WORDS, WIRE]]:
		if _has_word(words, pair[0]) != "":
			bits |= int(pair[1])
	_prop_classes[kind] = bits
	return bits


## Tiles at which an installation kind's grid and hum begin (0 for a kind that is not one).
static func installation_reach(kind: int) -> float:
	return float(_prop_reach.get(kind, 0.0)) if prop_class(kind) & INSTALLATION else 0.0


## How much of an installation's presence reaches `d` tiles from it: 1 within
## INSTALLATION_NEAR of its reach, 0 past it.
static func installation_share(d: float, reach: float) -> float:
	return smoothstep(reach, reach * INSTALLATION_NEAR, d)


## What the made and the found around a listener sound like, from the props
## within WORKS_RADIUS: {installation: distance to the nearest (INF when none),
## grid: 0..1 the installations' pulse (their shares summed, so several
## together carry further than one), hum: 0..1 their transformer hum, shelter:
## distance to the nearest roof or wall, wreck: 0..1 how much wreckage the wind
## can find, leaves: 0..1 how much canopy the rain can fall on, wires: 0..1
## strung wire close enough to sing}.
static func works_near(query: WorldQuery, p: Vector2, radius: float = WORKS_RADIUS) -> Dictionary:
	var out := {"installation": INF, "grid": 0.0, "hum": 0.0, "shelter": INF, "wreck": 0.0, "leaves": 0.0, "wires": 0.0}
	if query == null:
		return out
	var wreck := 0.0
	var leaves := 0.0
	var grid := 0.0
	var hum := 0.0
	var wires := 0.0
	for q: WorldProp in query.props_near(p, radius):
		if query.world.depleted.has(q.id):
			continue
		var bits := prop_class(q.kind)
		if bits == 0:
			continue
		var d := q.pos.distance_to(p)
		if d > radius:
			continue
		if bits & INSTALLATION:
			out["installation"] = minf(float(out["installation"]), d)
			var share := installation_share(d, installation_reach(q.kind))
			grid += share
			hum += pow(share, 1.5)
		if bits & SHELTER:
			out["shelter"] = minf(float(out["shelter"]), d)
		var near := 1.0 - d / radius
		if bits & WRECK:
			wreck += near * near * maxf(1.0, q.scale)
		if bits & CANOPY:
			leaves += near
		if bits & WIRE:
			wires = maxf(wires, smoothstep(WIRE_REACH, 1.5, d))
	out["grid"] = clampf(grid, 0.0, 1.0)
	out["hum"] = clampf(hum, 0.0, 1.0)
	out["wreck"] = clampf(wreck / 3.0, 0.0, 1.0)
	out["leaves"] = clampf(leaves / 25.0, 0.0, 1.0)
	out["wires"] = wires
	return out


## The country beds within `radius` tiles (a ring of samples): what is about
## to be heard, so it can be baked before the ear reaches it.
static func beds_ahead(world: WorldData, p: Vector2, radius: float = 30.0) -> Array[StringName]:
	var out: Array[StringName] = []
	for k in 12:
		var a := TAU * k / 12.0
		var q := p + Vector2(cos(a), sin(a)) * radius
		var c := world.country_at(clampi(floori(q.x), 0, world.size - 1), clampi(floori(q.y), 0, world.size - 1))
		var bed := country_bed(c)
		if not out.has(bed):
			out.append(bed)
	return out


static func _weigh_tile(world: WorldData, p: Vector2, weight: float, out: Dictionary) -> void:
	var x := clampi(floori(p.x), 0, world.size - 1)
	var y := clampi(floori(p.y), 0, world.size - 1)
	var i := y * world.size + x
	var c: int = world.country[i]
	var c2: int = world.country2[i] if world.country2.size() > i else c
	var bl: float = clampf(world.blend[i], 0.0, 1.0) if world.blend.size() > i else 0.0
	var a := country_bed(c)
	out[a] = float(out.get(a, 0.0)) + weight * (1.0 - bl)
	if bl > 0.0:
		var b := country_bed(c2)
		out[b] = float(out.get(b, 0.0)) + weight * bl


## The country the player is most in (for music), from the same weights.
static func dominant_country(world: WorldData, p: Vector2) -> Dictionary:
	var x := clampi(floori(p.x), 0, world.size - 1)
	var y := clampi(floori(p.y), 0, world.size - 1)
	var i := y * world.size + x
	var c: int = world.country[i]
	var bl: float = world.blend[i] if world.blend.size() > i else 0.0
	if c == Country.SEA:
		c = Country.COAST
	return {"country": c, "purity": 1.0 - clampf(bl, 0.0, 1.0)}


static func is_sea(world: WorldData, x: int, y: int) -> bool:
	if not world.in_bounds(x, y):
		return true
	var g := world.ground[y * world.size + x]
	return world.level[y * world.size + x] <= 0 and (g == Ground.WATER or g == Ground.DEEP_WATER)


## Nearest tile matching `match_fn(world, x, y)` within radius, coarse then fine,
## and the direction the matches lie in, weighted by closeness.
## Returns {distance: float (INF if none), direction: Vector2}.
static func nearest(world: WorldData, p: Vector2, radius: int, match_fn: Callable) -> Dictionary:
	var px := floori(p.x)
	var py := floori(p.y)
	var best := INF
	var best_at := Vector2i(px, py)
	var dir := Vector2.ZERO
	for dy in range(-radius, radius + 1, 2):
		for dx in range(-radius, radius + 1, 2):
			if match_fn.call(world, px + dx, py + dy):
				var d := Vector2(dx, dy).length()
				if d < best:
					best = d
					best_at = Vector2i(px + dx, py + dy)
				if d > 0.0:
					dir += Vector2(dx, dy) / (d * maxf(1.0, d * d))
	if best < INF:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var tx := best_at.x + dx
				var ty := best_at.y + dy
				if match_fn.call(world, tx, ty):
					best = minf(best, Vector2(tx + 0.5 - p.x, ty + 0.5 - p.y).length())
	return {"distance": best, "direction": dir.normalized() if dir.length() > 1e-6 else Vector2.ZERO}


static func sea_near(world: WorldData, p: Vector2, radius: int = 24) -> Dictionary:
	return nearest(world, p, radius, is_sea)


static func river_near(world: WorldData, p: Vector2, radius: int = 12) -> Dictionary:
	return nearest(world, p, radius, func(w: WorldData, x: int, y: int) -> bool:
		return w.in_bounds(x, y) and w.ground[y * w.size + x] == Ground.RIVER)


static func shore_weight(sea_distance: float) -> float:
	return pow(clampf(1.0 - (sea_distance - 1.5) / 20.0, 0.0, 1.0), 1.6)


static func river_weight(river_distance: float) -> float:
	return pow(clampf(1.0 - (river_distance - 1.0) / 10.0, 0.0, 1.0), 1.5)


## Gusts: two slow sines multiplied (0.041 and 0.017 Hz, from the source), so
## wind never repeats on a period anyone would notice. 0.1..1.
static func gust(seconds: float) -> float:
	return 0.55 + 0.45 * sin(TAU * 0.041 * seconds) * sin(TAU * 0.017 * seconds + 1.1)


## How far the listener is from people, 0 in a village to 1 well out of reach
## of one: the machines' country, where the far works carry.
static func remoteness(world: WorldData, p: Vector2) -> float:
	var best := INF
	for v: Dictionary in world.villages:
		var at: Variant = v.get("pos")
		if at is Vector2:
			best = minf(best, (at as Vector2).distance_to(p))
		elif at is Vector2i:
			best = minf(best, Vector2(at as Vector2i).distance_to(p))
	return smoothstep(18.0, 60.0, best) if best < INF else 1.0


## Night 0..1 by the hour: in over 20:00-21:00, out over 04:30-06:00 (the
## source's night fall, so the ears and the sky agree).
static func night(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h >= 21.0 or h < 4.5:
		return 1.0
	if h >= 20.0:
		return h - 20.0
	if h < 6.0:
		return 1.0 - (h - 4.5) / 1.5
	return 0.0


## Every bed's target level 0..1 for a listener. `near_sea` and `near_river`
## come from sea_near/river_near (scanned a few times a second, not per frame).
## `extra` (all optional): hour (for the far works), remote (remoteness()),
## tide 0..1 (high water brings the shore closer), wet (wetness()), and what
## works_near found (wreck, hum, installation, shelter, leaves).
static func bed_levels(world: WorldData, p: Vector2, weather: Dictionary, near_sea: Dictionary, near_river: Dictionary, seconds: float, extra: Dictionary = {}) -> Dictionary:
	# A kind the beds were not written for sounds like the M1 kind it acts like
	# (drizzle as rain, a whiteout as a blizzard, dry lightning as dust...).
	var kind: StringName = Weather.family(StringName(weather.get("kind", &"fair")))
	var s := clampf(float(weather.get("strength", 0.0)), 0.0, 1.0)
	var wind := clampf(absf(float(weather.get("wind", 0.0))), 0.0, 1.0)
	var g := gust(seconds)
	var out := {}
	var shore := shore_weight(float(near_sea.get("distance", INF)))
	var river := river_weight(float(near_river.get("distance", INF)))
	var damp := lerpf(1.0, float(WEATHER_DAMP.get(kind, 1.0)), s)
	var dark_share := night(float(extra.get("hour", 12.0)))
	var weights := country_weights(world, p)
	for bed: StringName in weights:
		var w: float = weights[bed]
		var lvl := w * damp * (1.0 - 0.35 * shore)
		match bed:
			&"bed_wind":
				# Nights fall calmer; the sea and the far works come up through it.
				lvl *= (0.55 + 0.45 * wind) * lerpf(0.75, 1.1, g) * lerpf(1.0, 0.75, dark_share)
			&"bed_pines":
				lvl *= (0.6 + 0.4 * wind) * lerpf(0.8, 1.1, g)
			&"bed_bones":
				lvl *= (0.7 + 0.3 * wind) * lerpf(0.85, 1.05, g)
		out[bed] = float(out.get(bed, 0.0)) + lvl
	var tide := clampf(float(extra.get("tide", 0.5)), 0.0, 1.0)
	out[&"bed_shore"] = shore * lerpf(0.82, 1.08, tide) * lerpf(1.0, 0.8, s * float(kind == &"storm" or kind == &"blizzard"))
	out[&"bed_river"] = river * damp
	for bed: StringName in WEATHER_BED.values():
		out[bed] = 0.0
	if WEATHER_BED.has(kind):
		out[WEATHER_BED[kind]] = s
	out[&"weather_gust"] = clampf(smoothstep(0.3, 1.0, wind) * g * g + float(GUSTING.get(kind, 0.0)) * s, 0.0, 1.0)
	# The far works: only on still air, loudest at night and far from people,
	# gone under any weather and under the sea.
	var calm := 1.0 - smoothstep(0.25, 0.7, wind)
	# By day it is only a trace under the country (FAR_WORKS_DAY); it is a
	# night sound.
	var dark := lerpf(FAR_WORKS_DAY, 1.0, dark_share)
	var remote := clampf(float(extra.get("remote", 0.0)), 0.0, 1.0)
	var clear := 1.0 - s * (0.4 if kind == &"heat" or kind == &"grey" else 0.9)
	out[&"bed_far_works"] = remote * calm * dark * clear * (1.0 - 0.6 * shore)
	_dystopia_levels(out, weights, kind, s, wind, g, shore, river, dark_share, remote, extra)
	# The hush (23_hush): in a ring the world falls silent, every bed with it.
	var hush := clampf(float(extra.get("hush", 0.0)), 0.0, 1.0)
	if hush > 0.0:
		for bed: StringName in out:
			out[bed] = float(out[bed]) * (1.0 - hush)
	return out


## How near the listener stands to wreckage the wind can find (0..1, from
## works_near), an installation's hum (works_near's hum), gutters by rain lately
## and a roof or wall nearby, and rain split over the surfaces it falls on.
const GUTTER_NEAR := 3.0
const GUTTER_FAR := 16.0
const RAIN_SURFACES: Array[StringName] = [&"weather_rain", &"weather_rain_metal", &"weather_rain_leaves", &"weather_rain_water"]


## {turf, metal, leaves, water} shares of the rain here, summing to 1.
static func rain_surfaces(weights: Dictionary, shore: float, river: float, extra: Dictionary) -> Dictionary:
	var wreck := clampf(float(extra.get("wreck", 0.0)), 0.0, 1.0)
	var water := maxf(maxf(shore * 0.8, river), float(weights.get(&"bed_moss", 0.0)) * 0.7)
	var canopy := maxf(clampf(float(extra.get("leaves", 0.0)), 0.0, 1.0), float(weights.get(&"bed_pines", 0.0)) * 0.8)
	var metal := clampf(wreck * 0.8 + (1.0 - smoothstep(4.0, 14.0, float(extra.get("shelter", INF)))) * 0.6 + (1.0 - smoothstep(3.0, 12.0, float(extra.get("installation", INF)))) * 0.4, 0.0, 1.0)
	var scale := 1.0 / maxf(1.0, water + canopy + metal)
	water *= scale
	canopy *= scale
	metal *= scale
	return {"turf": maxf(0.0, 1.0 - water - canopy - metal), "metal": metal, "leaves": canopy, "water": water}


static func _dystopia_levels(out: Dictionary, weights: Dictionary, kind: StringName, s: float, wind: float, g: float, shore: float, river: float, dark_share: float, remote: float, extra: Dictionary) -> void:
	var wreck := clampf(float(extra.get("wreck", 0.0)), 0.0, 1.0)
	out[&"bed_wreck"] = wreck * (0.3 + 0.7 * wind) * lerpf(0.75, 1.1, g)
	out[&"bed_hum"] = clampf(float(extra.get("hum", 0.0)), 0.0, 1.0) * lerpf(1.0, 0.8, s)
	# The plan's machines far off: by day too, stronger away from people and on
	# still air, gone under loud weather and against the surf.
	var still := 1.0 - smoothstep(0.35, 0.8, wind)
	out[&"bed_far_drone"] = lerpf(0.25, 0.7, remote) * lerpf(0.55, 1.0, dark_share) * still * (1.0 - 0.7 * s) * (1.0 - 0.6 * shore)
	# The colossi: as loud as the nearest one is near (19_colossi `hum`), and
	# only thinned by weather, never by people or the sea -- nothing covers it.
	out[&"bed_colossus"] = clampf(float(extra.get("colossi", 0.0)), 0.0, 1.0) * lerpf(1.0, 0.6, s)
	var wet := clampf(float(extra.get("wet", 0.0)), 0.0, 1.0)
	out[&"bed_gutter"] = wet * smoothstep(GUTTER_FAR, GUTTER_NEAR, float(extra.get("shelter", INF)))
	# Rain keeps its loudness and changes its surface: each surface at the square
	# root of its share (equal power), turf taking what the others leave.
	var falling := s if kind == &"rain" else (s * 0.6 if kind == &"storm" or kind == &"hail" else 0.0)
	var shares := rain_surfaces(weights, shore, river, extra)
	if kind == &"rain":
		out[&"weather_rain"] = s * sqrt(float(shares["turf"]))
	out[&"weather_rain_metal"] = falling * sqrt(float(shares["metal"]))
	out[&"weather_rain_leaves"] = falling * sqrt(float(shares["leaves"]))
	out[&"weather_rain_water"] = falling * sqrt(float(shares["water"]))


## How wet the ground and the roofs are: rain now, or rain in the last half hour
## of world time fading, so gutters run on after the rain stops.
static func wetness(seed_value: int, minutes: float, country: int = -1) -> float:
	var best := 0.0
	for k in 4:
		var w := weather_at(seed_value, minutes - k * 10.0, country)
		if w["kind"] in [&"rain", &"storm", &"hail"]:
			best = maxf(best, float(w["strength"]) * (1.0 - k * 0.22))
	return best


## Whether a scatter entry ([name, gap, gap, {hours, fair, wet, wind}]) may
## sound now (SoundBeds.SCATTER has the vocabulary).
static func scatter_allowed(entry: Array, hour: float, weather: Dictionary) -> bool:
	if entry.size() < 4:
		return true
	var when: Dictionary = entry[3]
	var kind: StringName = weather.get("kind", &"clear")
	var s := float(weather.get("strength", 0.0))
	var wind := absf(float(weather.get("wind", 0.0)))
	if when.has("hours"):
		var span: Array = when["hours"]
		var from := float(span[0])
		var to := float(span[1])
		var inside := (hour >= from and hour < to) if from <= to else (hour >= from or hour < to)
		if not inside:
			return false
	if when.get("fair", false):
		if s > 0.35 and kind != &"fog" and kind != &"grey":
			return false
		if wind > 0.8:
			return false
	if when.has("wet"):
		if not (kind in (when["wet"] as Array)) or s < 0.2:
			return false
	if when.has("wind") and wind < float(when["wind"]):
		return false
	return true


# --------------------------------------------------------------- weather

## The weather where the listener stands: Weather.at_place(seed, minutes,
## country) when the sky's core has it (so a front that rains on the coast
## snows on the snowfield), else Weather.at, else a fair day whose wind still
## breathes.
static func weather_at(seed_value: int, minutes: float, country: int = -1) -> Dictionary:
	if not _weather_checked:
		_weather_checked = true
		if ResourceLoader.exists(WEATHER_PATH):
			use_weather_script(load(WEATHER_PATH))
	if _weather_script == null:
		return {"kind": &"fair", "strength": 0.0, "wind": 0.35 + 0.2 * sin(minutes / 97.0)}
	var raw: Variant
	if _weather_has_place and country >= 0:
		raw = _weather_script.call("at_place", seed_value, minutes, country)
	else:
		raw = _weather_script.call("at", seed_value, minutes)
	return normalize_weather(raw, _weather_script)


## Tide 0..1 from the sky's core, or slack water.
static func tide_at(minutes: float) -> float:
	if _weather_script != null and _weather_has_tide:
		return clampf(float(_weather_script.call("tide", minutes)), 0.0, 1.0)
	return 0.5


## Point the mix at a weather rules script (the sky's, or a test's stand-in).
static func use_weather_script(script: GDScript) -> void:
	_weather_checked = true
	_weather_script = script
	_weather_has_place = false
	_weather_has_tide = false
	if script == null:
		return
	for m: Dictionary in script.get_script_method_list():
		if m.name == "at_place":
			_weather_has_place = true
		elif m.name == "tide":
			_weather_has_tide = true


## Whatever shape Weather.at returns (kind as String, StringName or enum int),
## a {kind: StringName lower-case, strength: 0..1, wind: -1..1}.
static func normalize_weather(raw: Variant, script: GDScript = null) -> Dictionary:
	var out := {"kind": &"fair", "strength": 0.0, "wind": 0.0}
	if not raw is Dictionary:
		return out
	var d: Dictionary = raw
	var k: Variant = d.get("kind", &"fair")
	var name := ""
	if k is int and script != null:
		var consts := script.get_script_constant_map()
		for key: String in ["NAMES", "KINDS", "KIND_NAMES"]:
			if consts.has(key) and int(k) >= 0 and int(k) < consts[key].size():
				name = String(consts[key][int(k)])
				break
	elif k is String or k is StringName:
		name = String(k)
	out["kind"] = StringName(name.to_lower()) if name != "" else &"fair"
	out["strength"] = clampf(float(d.get("strength", 0.0)), 0.0, 1.0)
	out["wind"] = clampf(float(d.get("wind", 0.0)), -1.0, 1.0)
	return out


# -------------------------------------------------------------- machines

## Level of a machine bed at distance d: the research's 0.45 + 0.55 (1 - d/racket)
## inside its racket, eased in from silence over the outer RACKET_EDGE share so
## a machine coming into range is heard arriving, never switched on.
## A racket of 0 is a machine that gives no warning: never heard.
const RACKET_EDGE := 0.15


static func machine_level(d: float, racket: float) -> float:
	if racket <= 0.0 or d >= racket:
		return 0.0
	var inner := racket * (1.0 - RACKET_EDGE)
	var edge := 1.0
	if d > inner:
		var u := (racket - d) / (racket - inner)
		edge = u * u * (3.0 - 2.0 * u)
	return (0.45 + 0.55 * (1.0 - maxf(0.0, d) / racket)) * edge


## Distance is a timbre change before it is a level change: the low-pass
## corner falls from 16 kHz on top of it to 1.4 kHz at the edge.
static func machine_cutoff(d: float, racket: float) -> float:
	var t := clampf(d / maxf(0.001, racket), 0.0, 1.0)
	return 16000.0 * pow(1400.0 / 16000.0, pow(t, 0.8))


static func machine_wet(d: float, racket: float) -> float:
	return 0.03 + 0.22 * clampf(d / maxf(0.001, racket), 0.0, 1.0)


## How far a mob's work carries (tiles): the mob's own number when it exposes
## one (a `racket` property, or `row.racket` / `state.row.racket` as the fight
## roster keeps it), so the fight and the ears can never disagree; the
## SoundMachines table only for mobs that say nothing.
static func racket_of(m: Object, kind: StringName) -> float:
	var own: Variant = m.get("racket")
	if own is float or own is int:
		return float(own)
	var row: Variant = m.get("row")
	if not row is Dictionary:
		var state: Variant = m.get("state")
		if state is Object and is_instance_valid(state):
			row = (state as Object).get("row")
	if row is Dictionary and (row as Dictionary).has("racket"):
		return float((row as Dictionary)["racket"])
	return float(SoundMachines.RACKET.get(kind, 0.0))


## The one machine that plays: the loudest living mob within its racket.
## mobs: nodes exposing kind, pos (tile space) and alive. Returns
## {kind, level, distance, racket, node} or an empty Dictionary.
static func loudest_machine(mobs: Array, listener: Vector2) -> Dictionary:
	var best := {}
	var best_level := 0.0
	for m: Object in mobs:
		if m == null or not is_instance_valid(m):
			continue
		var alive: Variant = m.get("alive")
		if alive is bool and not alive:
			continue
		var raw_kind: Variant = m.get("kind")
		if raw_kind == null:
			continue
		var kind := SoundMachines.kind_of(StringName(str(raw_kind)))
		if kind == &"":
			continue
		var pos: Variant = m.get("pos")
		if not pos is Vector2:
			continue
		var d := (pos as Vector2).distance_to(listener)
		var racket := racket_of(m, kind)
		var lvl := machine_level(d, racket)
		if lvl > best_level:
			best_level = lvl
			best = {"kind": kind, "level": lvl, "distance": d, "racket": racket, "node": m}
	return best


# ----------------------------------------------------------- one-shots

## Level of a one-shot at distance d tiles (1 within 3 tiles).
static func sfx_gain(d: float) -> float:
	if d >= SFX_RANGE:
		return 0.0
	return 1.0 / (1.0 + maxf(0.0, d - 3.0) / 7.0)


## A colossus's landing, `d` metres off: full within a few kilometres, a fifth
## of itself on the skyline, and it never quite goes -- the one sound in the
## game that carries past the edge of the world.
static func colossus_gain(d: float) -> float:
	return clampf(1.0 - 0.8 * log(maxf(d, 3000.0) / 3000.0) / log(80.0), 0.2, 1.0)


## Thunder carries across the whole coast: which recording, and its level.
## Emitters delay it behind the flash (the sky does, tiles / 34 beats of 0.1 s).
static func thunder_sound(d: float) -> StringName:
	return &"thunder_far" if d > THUNDER_NEAR else &"thunder"


static func thunder_gain(d: float) -> float:
	return clampf(1.0 / (1.0 + maxf(0.0, d - 20.0) / 220.0), 0.2, 1.0)


## World bus cutoff and level for a muffle amount 0..1.
static func muffle_cutoff(amount: float) -> float:
	return 20000.0 * pow(MUFFLE_HZ / 20000.0, clampf(amount, 0.0, 1.0))


static func muffle_db(amount: float) -> float:
	return MUFFLE_DB * clampf(amount, 0.0, 1.0)
