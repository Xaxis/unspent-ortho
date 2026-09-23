extends GameSystem
## What the place is doing to the body, every half second: the landscape type's
## hazards through the hour, the weather, the height, a roof and a fire
## (src/core/hazards/hazards.gd), less what the gear keeps off (Body.resist,
## written by 54_gear), onto Body.pressure, which the slate's gauges read.
##
## The rule this system exists to keep: **a pressure is felt long before it
## hurts**. At Hazards.FELT a gauge lights, breath shows in the cold, heat lifts
## off the ground, a cough answers the fumes. At BITE walking slows and a line is
## said, once. Only at HARM does health go, slowly, with hours to answer it, and
## it stops at Hazards.HARM_FLOOR: the weather never kills outright.
##
## Look at it:
##   tools/shot.sh shots/hazards/cold.png --place=snowfield --hour=19 --frames=90
##   tools/tour.sh tours/hazards.tour --seed=1

## Real seconds between readings: often enough to answer a squall, cheap enough
## to run beside everything else.
const SWEEP := 0.5
## A fire warms a body within this many tiles (Survival keeps the same reach).
const FIRE_REACH := 4.0
## A roof within this many tiles is shelter; a crown overhead is a little.
const ROOF_REACH := 2.2
const CANOPY_REACH := 1.6
const ROOFS: Array[int] = [PropKind.HOUSE, PropKind.SHACK, PropKind.RUIN, PropKind.PUMP_HOUSE,
	PropKind.ARCHIVE, PropKind.CHECKPOINT, PropKind.FIRE_TOWER,
	# A glass blister is shade on a landscape with none (docs/LANDSCAPES.md §3):
	# a body steps in through the burst side. Its solid is 0, so ROOF_REACH is
	# the whole of how far its shade is felt.
	PropKind.GLASS_BLISTER]
const CANOPY: Array[int] = [PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF]
## A line is not said again until the pressure has let go this far.
const SAID_CLEAR := Hazards.FELT * 0.8
## How long a breath hangs in the air: long enough that a player walking sees it.
const BREATH_SECONDS := 1.6

## Hazard id -> the real second its next cue is due.
var _cue_at: Dictionary = {}
## The cue mark last drawn on the body and the real second it stops counting as
## JUST drawn, so a tour can `await breath` (or shimmer, cough, tick, drip,
## ring) instead of guessing at the beat and shooting into the gap between two
## of them. The window is short on purpose: an await that latched onto a mark
## already half over would hand the tour a frame with nothing in it.
const MARK_FRESH := 0.35
var _mark_shown: StringName = &""
var _mark_until := 0.0
## Hazard id -> a line has been said for it and not yet cleared.
var _said: Dictionary = {}
var _since := 0.0
## Health owed to the drain, kept as a fraction until it is a whole point.
var _carried := 0.0
## What the last sweep found, for the tour and for tests.
var _raw: Dictionary = {}
var _felt_ever: Dictionary = {}
## Something has bitten at some point in this game (for a tour's `answered`).
var _bit_ever := false
## Which pressures have bitten this game, for a tour's `answered:ID`. A place
## that presses three ways at once can never be wholly answered — the salt
## flats' thirst is worn on the same slot as its glare — so proving that gear
## answered one of them has to be askable one id at a time.
var _bit_ids: Dictionary = {}
## This game came out of a file, so its first reading came with it.
var _loaded := false


func setup(g: Game) -> void:
	super.setup(g)
	SaveGame.register(&"hazards", _save, _load)


## The first reading waits for every setup to have run, because 54_gear writes
## Body.resist after this system is loaded. Taken in setup it would read a naked
## body and say the cold bites through gear that is actually answering it.
##
## A loaded game already carries a reading taken with its own gear on, so it
## keeps it: the next ordinary sweep is half a second away, and overwriting the
## file's copy before the first frame only makes a load differ from the save it
## came from.
func started() -> void:
	if _loaded:
		return
	_sweep(0.0)


func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	_since += delta
	if _since < SWEEP:
		return
	var span := _since
	_since = 0.0
	_sweep(span)


## What the world is doing where the body stands.
func place() -> Hazards.Place:
	var p := Hazards.Place.new()
	var pos := game.player.pos
	var def := BiomeRegistry.at(game.world, pos)
	p.hazards = def.hazards
	p.hour = game.clock.hour()
	var w := Weather.at_type(game.world.seed_value, game.clock.minutes, def.id)
	p.weather = StringName(w.get("kind", &"clear"))
	p.weather_strength = float(w.get("strength", 0.0))
	p.wind = float(w.get("wind", 0.0))
	p.level = game.world.level_at(floori(pos.x), floori(pos.y))
	p.lamp = game.body.lamp_lit
	p.in_water = Ground.is_water(game.world.ground_at(floori(pos.x), floori(pos.y)))
	p.fire = _fire()
	p.shelter = _shelter()
	p.pos = pos
	p.near_props = _near_props(pos)
	# The realm decides whether there is a sky, and it is the SAME question
	# 20_realms asks to set `SkyLight.closed`. Asked here rather than derived
	# from the landscape, because no landscape file may say the hour has stopped
	# mattering (src/core/realm/realm.gd).
	p.roofed = Realm.roofed(game.world.realm)
	return p


func _fire() -> float:
	var f := Survival.fire_near(game, FIRE_REACH)
	if f == null:
		return 0.0
	return clampf(1.0 - f.pos.distance_to(game.player.pos) / FIRE_REACH, 0.0, 1.0)


## The standing things near enough to press the body by their own kind's rows
## (`PropHazards.TABLE`), for `Hazards._prop_shift`. Read off the tile index the
## same way `_shelter` and 16_vents read it, never off `world.props`: with the
## table's furthest reach at 4 tiles that is a 9x9 block of cell lookups, about
## 81 dictionary reads and a handful of appends, once every SWEEP — measured
## under `tests/hazards/test_prop_hazards.gd` at well under a tenth of a
## millisecond, against a `world.props` walk that would be tens of thousands
## of reads on a real island. Only kinds with a row are handed over, so `felt`
## never has to look a boulder up, and a thing already taken presses nothing.
func _near_props(pos: Vector2) -> Array:
	var out: Array = []
	for p: WorldProp in game.query.props_near(pos, PropHazards.reach_most()):
		if PropHazards.near(p.kind).is_empty() or game.world.depleted.has(p.id):
			continue
		out.append(p)
	return out


## A roof over you, a village around you, or a crown above you.
func _shelter() -> float:
	var best := 0.7 if Survival.in_village(game) else 0.0
	var pos := game.player.pos
	for p: WorldProp in game.query.props_near(pos, ROOF_REACH):
		if game.world.depleted.has(p.id):
			continue
		if ROOFS.has(p.kind):
			best = maxf(best, clampf(1.0 - pos.distance_to(p.pos) / (ROOF_REACH + p.solid), 0.3, 1.0))
		elif CANOPY.has(p.kind) and pos.distance_to(p.pos) <= CANOPY_REACH:
			best = maxf(best, 0.35)
	return best


## What a configuration scales every pressure by (rules.hazards); 1.0 is the land as it is.
var pressure_scale := 1.0


func _sweep(span: float) -> void:
	var p := place()
	_raw = Hazards.felt(p)
	var pressure := Hazards.after_resist(_raw, game.body.resist)
	if not is_equal_approx(pressure_scale, 1.0):
		# A configuration may say how hard this land presses (rules.hazards, 94_dev).
		for id: Variant in pressure:
			pressure[id] = clampf(float(pressure[id]) * pressure_scale, 0.0, 1.0)
	game.body.pressure = pressure
	for id: Variant in pressure:
		if float(pressure[id]) >= Hazards.FELT:
			_felt_ever[StringName(id)] = true
	_bit_ever = _bit_ever or Hazards.worst(pressure) >= Hazards.BITE
	for id: Variant in pressure:
		if float(pressure[id]) >= Hazards.BITE:
			_bit_ids[StringName(id)] = true
	_tell(pressure)
	_drain(pressure, span)
	_cues(pressure)


## The first time a pressure begins to bite, the body says so, once, and the
## slate's gauge turns to the warning colour beside it. Nothing repeats until it
## has let go.
func _tell(pressure: Dictionary) -> void:
	var ids: Array = pressure.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id: Variant in ids:
		var key := StringName(id)
		var v := float(pressure[id])
		if v >= Hazards.BITE and not _said.has(key):
			_said[key] = true
			Events.message.emit(Hazards.line_for(key))
			Events.sfx.emit(&"hazard_warn", game.player.position)
	for key: StringName in _said.keys():
		if float(pressure.get(key, 0.0)) < SAID_CLEAR:
			_said.erase(key)


## Above HARM the body loses health slowly, and never its last point: what the
## weather does is take you down to where everything else is dangerous.
func _drain(pressure: Dictionary, span: float) -> void:
	var minutes := span * Tuning.MINUTES_PER_SECOND
	_carried += Hazards.drain(pressure, minutes)
	if _carried < 1.0:
		return
	var before := game.body.health
	var after := Hazards.drained_health(before, _carried)
	_carried -= floorf(_carried)
	if after >= before:
		return
	game.body.health = after
	# Not a hit: the weather is not an attacker. `Events.hit` would have survival
	# break off whatever was being made and the score tense as though something
	# had struck the player. The cold takes its point quietly, and the body,
	# the gauge and the sound are what say so.
	game.player.flash(0.12)
	game.player.shudder(0.3)
	Events.sfx.emit(&"hazard_drain", game.player.position)


## The body answers a pressure in the notebook's hand: breath in the cold,
## shimmer off hot ground, a cough at the fumes, a counter's ticks. Only the
## hardest one is answered, so a bad place never fills the screen with marks.
func _cues(pressure: Dictionary) -> void:
	var id := Hazards.worst_id(pressure)
	if id == &"":
		return
	var v := float(pressure[id])
	var beat := HazardCues.beat(v)
	if beat == INF:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_cue_at.get(id, 0.0)):
		return
	_cue_at[id] = now + beat
	var cue := HazardCues.cue(id)
	_draw_cue(id, cue, v)
	var sound := StringName(cue.get("sound", &""))
	if sound != &"":
		Events.sfx.emit(sound, game.player.position)


func _draw_cue(id: StringName, cue: Dictionary, v: float) -> void:
	var col := HazardCues.colour(id)
	var at := game.player.position
	var head := at + Vector3(0, 1.25, 0)
	var seed_value := int(Time.get_ticks_msec()) + int(v * 1000.0)
	var ahead := Vector2(cos(game.player.facing), sin(game.player.facing))
	var drift := ahead * 0.4
	var mark := StringName(cue.get("mark", &""))
	if mark != &"":
		_mark_shown = mark
		_mark_until = Time.get_ticks_msec() / 1000.0 + MARK_FRESH
	match mark:
		&"breath":
			# Two puffs off the MOUTH, the second a little further out: a plume,
			# not a dot, and it hangs long enough to be seen at walking pace.
			# Both are put out in front of the face, never at the head's own
			# point: drawn there and then risen, breath ends up above and behind
			# the head and stops reading as breath (wave A2, art finding 9).
			var mouth := head + Vector3(ahead.x, -0.06, ahead.y) * 0.26
			MobFx.breath(_fx_parent(), mouth, col, 0.30 + 0.14 * v, BREATH_SECONDS, drift, seed_value)
			MobFx.breath(_fx_parent(), mouth + Vector3(ahead.x, 0.10, ahead.y) * 0.30, col,
				0.20 + 0.10 * v, BREATH_SECONDS * 0.8, drift, seed_value + 5)
			if bool(cue.get("shiver", false)) and v >= Hazards.BITE:
				game.player.shudder(0.22)
		&"shimmer":
			for k in 3:
				var away := Vector3(cos(k * 2.1) * 0.5, 0.05, sin(k * 2.1) * 0.5)
				MobFx.breath(_fx_parent(), at + away, col, 0.22, 1.4, Vector2.ZERO, seed_value + k * 7)
		&"cough":
			MobFx.puff(_fx_parent(), head, Vector2.from_angle(game.player.facing), col, 0.36, seed_value)
			game.player.shudder(0.26)
		&"tick":
			for k in 3:
				var off := Vector3(cos(k * 2.4) * 0.45, 0.6 + 0.3 * k, sin(k * 2.4) * 0.45)
				MobFx.glint(_fx_parent(), at + off, col, seed_value + k * 13, 0.3)
		&"drip":
			MobFx.puff(_fx_parent(), at + Vector3(0, 0.35, 0), Vector2.ZERO, col, 0.28, seed_value)
		&"ring":
			MobFx.ring(_fx_parent(), at, col, 0.7 + 0.5 * v, 0.45)
			game.player.shudder(0.2)


func _fx_parent() -> Node:
	return game


## Tours ask what the player could see: a pressure felt at all (`pressure`), any
## of them biting (`pressure_bites`), a named one felt (`ID`) or biting
## (`bites:ID`), one that bit and no longer does (`answered`, `answered:ID`), and
## shelter (`sheltered`). A bare id is FELT and `bites:ID` is BITE, because that
## is the line between a gauge and something the glass says out loud.
func tour_seen(what: StringName) -> bool:
	match what:
		&"pressure":
			return Hazards.worst(game.body.pressure) >= Hazards.FELT
		&"pressure_bites":
			return Hazards.worst(game.body.pressure) >= Hazards.BITE
		&"sheltered":
			return Hazards.worst(game.body.pressure) < Hazards.FELT and not _felt_ever.is_empty()
		&"answered":
			# Something bit earlier and nothing bites now: the gear was felt.
			return _bit_ever and Hazards.worst(game.body.pressure) < Hazards.BITE
	var s := String(what)
	if s.begins_with("bites:"):
		# THAT ONE pressure is biting now. `pressure_bites` is any of them, which a
		# tour walking out of one landscape into another cannot use: the cold it
		# just left goes on biting while the heat it came for has not started, so
		# the await is satisfied by the wrong land and the frame after it is taken
		# before anything the frame is about has happened (tours/slate-hud.tour,
		# which is what found it). A bare hazard id answers at FELT, and a line and
		# a badge are only said at BITE, so neither of those could say this either.
		return float(game.body.pressure.get(StringName(s.substr(6)), 0.0)) >= Hazards.BITE
	if s.begins_with("answered:"):
		var id := StringName(s.substr(9))
		return _bit_ids.has(id) and float(game.body.pressure.get(id, 0.0)) < Hazards.BITE
	if what == _mark_shown:
		# The cue's own mark has just been drawn on the body: a tour shoots the
		# breath itself rather than the gap between two of them.
		return Time.get_ticks_msec() / 1000.0 < _mark_until
	if Hazards.IDS.has(what):
		return float(game.body.pressure.get(what, 0.0)) >= Hazards.FELT
	return false


## What the last sweep read before the gear took its share (tests, tools).
func raw() -> Dictionary:
	return _raw


func _save() -> Variant:
	var said := PackedStringArray()
	for k: StringName in _said:
		said.append(String(k))
	return {"said": said, "carried": _carried}


func _load(v: Variant) -> void:
	_loaded = true
	if not (v is Dictionary):
		return
	_said.clear()
	for s: Variant in ((v as Dictionary).get("said", []) as Array):
		_said[StringName(s)] = true
	_carried = float((v as Dictionary).get("carried", 0.0))
