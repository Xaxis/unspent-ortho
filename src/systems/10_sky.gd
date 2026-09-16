extends GameSystem
## The sky over the running game: reads the weather of every landscape type
## around the camera (BiomeRegistry, Weather.at_type), mixes it (WeatherLook),
## eases each type's light and mood, drifts
## clouds and fog, lays the dawn mist, throws lightning (storms and the dry
## lightning of the bonelands) with its afterglow and the machines' stutter, and
## hands it all to SkyLight (the one writer of the sky shader globals, composed
## once a frame) and WeatherView (what falls through the air).

## Seconds for the light cast and the weather mix to settle after a border.
const REGION_EASE := 2.5
const WEATHER_EASE := 1.2
## Tiles around the focus that are sampled for landscape type and weather.
const SAMPLE_REACH := 7.0
## Where the types around the focus are read, and how much each counts: the
## focus twice, a near ring and a far ring, so light and mood turn gradually
## as a border is walked rather than in one step.
const SAMPLES: Array[Vector3] = [
	Vector3(0, 0, 2), Vector3(0.5, 0, 1), Vector3(-0.5, 0, 1), Vector3(0, 0.5, 1), Vector3(0, -0.5, 1),
	Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(0, 1, 1), Vector3(0, -1, 1),
]

var view: WeatherView
## The last composed look (WeatherLook.compose), eased, plus `mist`. Other
## systems may read it.
var look: Dictionary = {}
var wind := 0.0
var region := Vector3.ONE
var _cloud_drift := Vector2.ZERO
var _fog_drift := Vector2.ZERO
var _cloud_bearing := Vector2.RIGHT
var _last_minutes := 0.0
var _flash := 0.0
## What the page does on the frames after a strike: a pale step, half of it,
## nothing, a flicker, gone. Two or three frames, never a white veil.
const FLASH_FRAMES: Array[float] = [0.36, 0.18, 0.0, 0.12]
var _flash_frame := FLASH_FRAMES.size()
var _flash_gain := 0.0
var _pending_thunder: Array = [] # [real seconds left, Vector3]
var _forced_bolt := false
## Anything forced the weather (a boot option or a tour line): lifted on exit.
var _forced_any := false
## Lying snow, ash and wet around the focus (Weather.settled), eased.
var settled := {"snow": 0.0, "ash": 0.0, "wet": 0.0}
var _settle_target := {"snow": 0.0, "ash": 0.0, "wet": 0.0}
var _settle_minute := -INF
var _sway_phase := 0.0
## Milliseconds the sky_ground texture took to build (start-up budget).
var ground_ms := 0
## Real seconds since the last strike (INF before the first): the afterglow and
## the stutter run on it, and a tour awaits it.
var since_strike := INF
var strikes := 0
var _strike_at := Vector2.ZERO
var _glow_gain := 0.0
var _drip_scan := 0.0
## Real seconds the sky has run, for sheet lightning's beat.
var _sheet_clock := 0.0
## Home dust devils kept in sight in real dust (DustDevils.keep_one).
var _home_devils: Array = []
## The landscape type whose weather falls at the focus (fall_type), last frame.
var here: StringName = &"coast"

## The afterglow rolling through the clouds after a strike, in real seconds:
## [until, level]. Stepped, a lit patch catching and letting go, never a fade.
const AFTERGLOW: Array[Vector2] = [
	Vector2(0.10, 0.0), Vector2(0.28, 0.85), Vector2(0.40, 0.3), Vector2(0.62, 0.65),
	Vector2(0.80, 0.18), Vector2(1.05, 0.45), Vector2(1.30, 0.12), Vector2(1.60, 0.24),
]
## Tiles the lit patch of cloud has rolled out from the strike after 1 s.
const AFTERGLOW_ROLL := 16.0
## Sheet lightning between strikes: every SHEET_SECONDS a window in which a
## patch of cloud may flicker, no bolt, no stutter, no thunder, so a storm
## that throws lightning reads as one before the first strike. The flicker's
## steps in real seconds: [until, level]. Faint beside a strike's afterglow.
const SHEET_SECONDS := 3.2
const SHEET: Array[Vector2] = [
	Vector2(0.07, 0.5), Vector2(0.13, 0.0), Vector2(0.22, 0.35), Vector2(0.3, 0.1), Vector2(0.38, 0.25),
]
## How bright a sheet flicker lights the cloud, as a share of a strike's glow.
const SHEET_GAIN := 0.45
## Real seconds after a strike that a held bolt (a shot) stands at: the cloud
## at its brightest, with the machines' power back between two dips.
const HELD_STRIKE := 0.2
## The machines' power after a strike, in real seconds: [until, level]. Their
## strips and beacons drop out, catch, drop again and come back.
const STUTTER: Array[Vector2] = [
	Vector2(0.06, 1.0), Vector2(0.16, 0.0), Vector2(0.24, 1.0), Vector2(0.36, 0.1),
	Vector2(0.44, 0.0), Vector2(0.58, 0.7), Vector2(0.70, 0.2), Vector2(0.92, 0.55),
]


func setup(g: Game) -> void:
	super.setup(g)
	g.sky.driven = true
	apply_weather(g.options.weather)
	var t0 := Time.get_ticks_msec()
	g.sky.set_ground(SkyGround.texture(g.world), g.world.size)
	ground_ms = Time.get_ticks_msec() - t0
	var a := Rng.hash01(g.world.seed_value, 0xC10D) * TAU
	_cloud_bearing = Vector2.from_angle(a)
	_last_minutes = g.clock.minutes
	# Start the drift where the clock is, so a shot at 12:00 is not a shot at 00:00.
	_cloud_drift = _cloud_bearing * g.clock.minutes * 0.6
	_fog_drift = _cloud_bearing.orthogonal() * g.clock.minutes * 0.12
	view = WeatherView.new()
	view.name = "weather"
	add_child(view)
	view.setup(g.camera)
	_update(0.0, true)
	if _forced_bolt:
		_strike(1.0, 0, true)


func _exit_tree() -> void:
	if _forced_any:
		Weather.unforce()


## "kind:strength[:bolt]" forces the sky; "" or "rules" hands it back to the
## rules. Boot options and a tour's `weather` line both come through here.
func apply_weather(spec: String) -> bool:
	if spec == "":
		return true
	if spec == "rules":
		Weather.unforce()
		_hold_bolt(false)
		return true
	var parts := spec.split(":")
	var kind := StringName(parts[0])
	if not Weather.KINDS.has(kind):
		push_warning("unknown weather %s" % parts[0])
		return false
	Weather.force(kind, parts[1].to_float() if parts.size() > 1 else 1.0)
	_forced_any = true
	_hold_bolt(parts.size() > 2 and parts[2] == "bolt")
	return true


## Hold one strike for a still, or let the held one go. A held bolt asked for
## while the game runs has to be STRUCK, not only flagged: setup strikes one so
## a shot has lightning in it, and a tour asking for one mid-play must get the
## same picture instead of an empty sky held at the bright moment (a drawn bolt
## lives four frames, so waiting to catch a real one with a shot is chance).
## Letting go has to take the drawn bolt with it, or the lightning hangs in
## every frame after — a noon glare, another landscape, for ever.
func _hold_bolt(hold: bool) -> void:
	var was := _forced_bolt
	_forced_bolt = hold
	if view == null or was == hold:
		return
	if hold:
		_strike(1.0, 0, true)
	else:
		view.release_bolt()


func _process(delta: float) -> void:
	_update(delta, false)


func _focus() -> Vector3:
	if game.camera != null:
		return game.camera.target
	return game.player.position


## Landscape type ids around the focus with their share (BiomeRegistry.at at
## SAMPLES), summing to 1.
func sample_types(focus: Vector2) -> Dictionary:
	var w := game.world
	var shares := {}
	var total := 0.0
	for o in SAMPLES:
		var at := _clamped(w, focus + Vector2(o.x, o.y) * SAMPLE_REACH)
		var id := BiomeRegistry.at(w, at).id
		shares[id] = float(shares.get(id, 0.0)) + o.z
		total += o.z
	for id: StringName in shares:
		shares[id] = float(shares[id]) / total
	return shares


## What the sky draws from the focus type alone (WeatherLook.compose keys).
const FALL_KEYS: Array[String] = ["rain", "drizzle", "hail", "snow", "ash", "dust", "fog", "heat", "whiteout", "glare", "haze", "bolt", "storm"]


## The landscape type whose weather falls at a point: the one under it.
static func fall_type(w: WorldData, at: Vector2) -> StringName:
	return BiomeRegistry.at(w, _clamped(w, at)).id


## A tile position pulled onto the map, so the edge reads its own land and not
## the sea beyond it.
static func _clamped(w: WorldData, at: Vector2) -> Vector2:
	return Vector2(clampf(at.x, 0.0, w.size - 1.0), clampf(at.y, 0.0, w.size - 1.0))


func _update(delta: float, snap: bool) -> void:
	var f3 := _focus()
	var focus := Vector2(f3.x, f3.z)
	var minutes := game.clock.minutes
	var seed_value := game.world.seed_value
	var shares := sample_types(focus)
	var hour := game.clock.hour()

	var entries: Array = []
	var target_region := Vector3.ZERO
	var target_wind := 0.0
	var target_mist := 0.0
	for id: StringName in shares:
		var wx := Weather.at_type(seed_value, minutes, id)
		entries.append({"kind": wx.kind, "strength": wx.strength, "weight": shares[id]})
		target_region += SkyLight.type_light(BiomeRegistry.get_def(id), hour) * float(shares[id])
		target_wind += float(wx.wind) * float(shares[id])
		target_mist += float(wx.mist) * float(shares[id])
	var target := WeatherLook.compose(entries)
	# The light and the clouds blend across a border, but what falls through the
	# air is one landscape's: the one under the focus. A frame at a triple border
	# must not snow, rain ash and lie in fog all at once.
	here = fall_type(game.world, focus)
	var wh := Weather.at_type(seed_value, minutes, here)
	var falls := WeatherLook.compose([{"kind": wh.kind, "strength": wh.strength, "weight": 1.0}])
	for k: String in FALL_KEYS:
		target[k] = falls[k]
	target.mist = target_mist
	target.wisp = wisp_amount(float(WISPS.get(here, 0.0)), Weather.night_fall(hour), float(target.rain) + float(target.drizzle), target_wind)
	# What lies on the ground changes over hours: recompute once a world minute.
	# Each thing is the most any landscape in view has left; the sky_ground mask
	# lays it only on the land that makes it.
	if snap or absf(minutes - _settle_minute) >= 1.0:
		_settle_minute = minutes
		for k: String in _settle_target:
			_settle_target[k] = 0.0
		for id: StringName in shares:
			var st := Weather.settled_type(seed_value, minutes, id)
			for k: String in _settle_target:
				_settle_target[k] = maxf(float(_settle_target[k]), float(st[k]))

	var kr := 1.0 if snap else 1.0 - exp(-delta / REGION_EASE)
	var kw := 1.0 if snap else 1.0 - exp(-delta / WEATHER_EASE)
	region = region.lerp(target_region, kr)
	wind = lerpf(wind, target_wind, kw)
	if look.is_empty() or snap:
		look = target
	else:
		for k: String in target:
			if target[k] is Vector3:
				look[k] = (look.get(k, target[k]) as Vector3).lerp(target[k], kw)
			else:
				look[k] = lerpf(float(look.get(k, target[k])), float(target[k]), kw)

	# Drift by world minutes, so a skipped hour moves the sky an hour on.
	var dm := clampf(minutes - _last_minutes, 0.0, 600.0)
	_scan_lightning(_last_minutes, minutes, seed_value, wh.kind, float(wh.strength))
	_last_minutes = minutes
	_cloud_drift += _cloud_bearing * dm * (0.35 + 1.1 * absf(wind))
	_fog_drift += _cloud_bearing.orthogonal() * dm * (0.08 + 0.3 * absf(wind))

	# A forced bolt (shots) holds its strike drawn with no flash on the page;
	# real strikes flash for a few frames.
	_flash = 0.0
	if not _forced_bolt and _flash_frame < FLASH_FRAMES.size():
		_flash = FLASH_FRAMES[_flash_frame] * _flash_gain
		_flash_frame += 1
	since_strike += delta
	var sky := game.sky
	sky.neon_shares = shares
	sky.region_tint = region
	sky.weather_tint = look.tint
	sky.season_turn = Weather.season_turn(minutes)
	sky.clouds = Vector4(_cloud_drift.x, _cloud_drift.y, float(look.cover), float(look.cloud))
	sky.fog = Vector4(_fog_drift.x, _fog_drift.y, clampf(float(look.fog) + float(look.mist), 0.0, 1.0), 0.0)
	sky.flash = _flash
	for k: String in settled:
		settled[k] = lerpf(float(settled[k]), float(_settle_target[k]), kr)
	sky.settle = Vector4(float(settled.snow), float(settled.ash), float(settled.wet), 0.0)
	sky.air = Vector4(clampf(float(look.rain) + float(look.drizzle) * 0.6 + float(look.hail) * 0.5, 0.0, 1.0), float(look.glare), WeatherLook.haze_share(look), float(look.whiteout))
	# A held bolt (shots) holds the moment the cloud catches: the afterglow at its
	# brightest, and the machines' power back up after their first dip, so a still
	# of a strike shows both the light in the air and the works that run on it.
	var t := HELD_STRIKE if _forced_bolt else since_strike
	sky.bolt = Vector4(_strike_at.x, _strike_at.y, afterglow(t) * _glow_gain, lerpf(1.0, machine_power(t), _glow_gain))
	sky.glow_reach = AFTERGLOW_ROLL * (0.35 + minf(t, 2.0))
	_sheet_clock += delta
	if sky.bolt.z <= 0.0 and Weather.strikes(wh.kind) and not _forced_bolt:
		var sheet_now := sheet(seed_value, _sheet_clock, float(wh.strength))
		if float(sheet_now.level) > 0.0:
			var at: Vector2 = focus + (sheet_now.at as Vector2)
			sky.bolt = Vector4(at.x, at.y, float(sheet_now.level) * SHEET_GAIN, 1.0)
			sky.glow_reach = AFTERGLOW_ROLL * 0.6
	# Sway advances faster in a strong wind, so reeds never snap to a new speed.
	_sway_phase = fposmod(_sway_phase + delta * (0.8 + 3.2 * absf(wind)), TAU * 1000.0)
	var gust := clampf(float(look.storm) + float(look.dust) * 0.6 + float(look.whiteout) * 0.6 + absf(wind) * 0.3, 0.0, 1.0)
	var along := _cloud_bearing * wind
	sky.wind = Vector4(along.x, along.y, gust, _sway_phase)
	# Tufts and crowns never hang dead still, and a storm bends them hard.
	sky.sway = clampf(0.15 + absf(wind) * 0.6 + gust * 0.5, 0.0, 1.2)
	sky.cast_allowed = float(look.overcast) < 0.6
	sky.focus = f3
	sky.set_hour(hour)
	view.update(look, wind, f3, delta)
	_update_ground_marks(focus, minutes, seed_value, delta, snap)
	_tick_thunder(delta)


## Drips from eaves, arms and crowns, and dust devils on hot dusty ground: marks
## that belong to things on the land, so they are placed from the props and the
## terrain here and drawn by the view.
func _update_ground_marks(focus: Vector2, minutes: float, seed_value: int, delta: float, snap: bool) -> void:
	var drip := Drips.amount(float(look.rain) + float(look.drizzle) * 0.5, float(settled.wet))
	# Under a canopy the rain comes down as drips.
	drip = clampf(drip * float(CANOPY_DRIP.get(here, 1.0)), 0.0, 1.0)
	_drip_scan -= delta
	if drip > 0.01 and (snap or _drip_scan <= 0.0):
		_drip_scan = 0.5
		var props := game.query.props_near(focus, Drips.REACH)
		view.set_drip_points(Drips.points(props, focus, seed_value, game.world.to_3d, game.world.depleted))
	view.set_drips(drip, float(look.snow) > 0.2)
	var dusty := clampf(float(look.dust) * 1.2 + float(look.glare) * 0.5, 0.0, 1.0)
	var bearing := _cloud_bearing * signf(wind if absf(wind) > 0.01 else 1.0)
	var kept := DustDevils.keep_one(DustDevils.at(seed_value, minutes, focus, dusty, bearing), _home_devils, seed_value, minutes, focus, dusty, bearing, snap)
	_home_devils = kept.homes
	var devils: Array[Dictionary] = kept.list
	var placed: Array[Dictionary] = []
	for d: Dictionary in devils:
		placed.append({"at": game.world.to_3d(d.pos), "life": d.life, "seed": d.seed})
	view.set_devils(placed)


## Landscape types whose canopy turns rain into drips: how much more they drip.
const CANOPY_DRIP := {&"pinewood": 1.5}
## Landscape types where cold lights drift low after dark, and how many.
const WISPS := {&"moss": 1.0}


## Wisps: cold lights over the moss after dark, never in rain or a wind.
static func wisp_amount(moss_share: float, night: float, rain: float, wind_now: float) -> float:
	return clampf(moss_share * night * (1.0 - clampf(rain, 0.0, 1.0)) * (1.0 - absf(wind_now) * 1.5), 0.0, 1.0)


## Sheet lightning at `seconds` of real time in a storm of `strength`:
## {level: 0..1 stepped, at: Vector2 tiles from the focus the lit cloud centres
## on}. Most windows flicker in a full storm, few in a weak one.
static func sheet(seed_value: int, seconds: float, strength: float) -> Dictionary:
	var e := floori(seconds / SHEET_SECONDS)
	var into := seconds - e * SHEET_SECONDS - Rng.hash01(seed_value, e, 0x5EE1) * (SHEET_SECONDS - 0.5)
	var out := {"level": 0.0, "at": Vector2.ZERO}
	if into < 0.0 or Rng.hash01(seed_value, e, 0x5EE2) >= 0.25 + 0.6 * clampf(strength, 0.0, 1.0):
		return out
	for step: Vector2 in SHEET:
		if into < step.x:
			out.level = step.y * clampf(strength, 0.0, 1.0)
			break
	out.at = Vector2.from_angle(Rng.hash01(seed_value, e, 0x5EE3) * TAU) * lerpf(4.0, 12.0, Rng.hash01(seed_value, e, 0x5EE4))
	return out


## The afterglow level `t` real seconds after a strike (AFTERGLOW), 0 after it.
static func afterglow(t: float) -> float:
	for step: Vector2 in AFTERGLOW:
		if t < step.x:
			return step.y
	return 0.0


## The machines' power `t` real seconds after a strike (STUTTER): 1 steady.
static func machine_power(t: float) -> float:
	if t < 0.0:
		return 1.0
	for step: Vector2 in STUTTER:
		if t < step.x:
			return step.y
	return 1.0


func _scan_lightning(from_minutes: float, to_minutes: float, seed_value: int, kind: StringName, strength: float) -> void:
	if strength <= 0.0 or not Weather.strikes(kind) or _forced_bolt:
		return
	var m0 := maxi(floori(from_minutes), floori(to_minutes) - 3)
	for m in range(m0, floori(to_minutes) + 1):
		var f := Weather.lightning(seed_value, m, kind, strength)
		if f < 0.0:
			continue
		var at := m + f
		if at > from_minutes and at <= to_minutes:
			_strike(strength, m, false)


func _strike(strength: float, minute: int, hold: bool) -> void:
	var seed_value := game.world.seed_value
	var dist := Weather.strike_distance(seed_value, minute, strength)
	_flash_gain = clampf(300.0 / dist, 0.3, 1.0)
	_flash_frame = 0
	var f3 := _focus()
	var r := Rng.make(seed_value, minute)
	var here := Vector2(f3.x, f3.z)
	var at := here + Vector2(r.randf_range(-STRIKE_REACH.x, STRIKE_REACH.x), r.randf_range(-STRIKE_REACH.y, STRIKE_REACH.y))
	# Strikes find the tallest thing near where they land, but never wander off
	# the page to do it: a bolt drawn where nobody can see it is only thunder.
	var best := -1.0
	for p: WorldProp in game.query.props_near(at, 5.0):
		if absf(p.pos.x - here.x) > STRIKE_REACH.x or absf(p.pos.y - here.y) > STRIKE_REACH.y:
			continue
		var tall: float = STRIKE_HEIGHT.get(p.kind, 0.0) * p.scale
		if tall > best:
			best = tall
			at = p.pos
	var ground := game.world.to_3d(at) + Vector3(0, maxf(best, 0.0), 0)
	if hold or dist < 450.0:
		view.strike(ground, seed_value ^ minute, hold)
	# The glow rolls from where the strike was, and a far one barely lights the
	# cloud; every one in sight stutters the machines' lights for a beat.
	since_strike = 0.0
	strikes += 1
	_strike_at = at
	_glow_gain = clampf(420.0 / dist, 0.35, 1.0)
	# Thunder comes tiles/34 beats (0.1 s) after the light. (source)
	_pending_thunder.append([dist / 34.0 * 0.1, ground])


## Tiles either side of the focus a drawn strike may land in: the page is about
## 26 tiles across and 18 deep, and a bolt has to be on it to be lightning.
const STRIKE_REACH := Vector2(9.0, 6.0)


const STRIKE_HEIGHT := {
	PropKind.PYLON: 3.6, PropKind.POLE: 2.2, PropKind.PINE: 2.3, PropKind.SNOW_PINE: 2.3,
	PropKind.BROADLEAF: 1.8, PropKind.DEAD_TREE: 1.5, PropKind.HOUSE: 2.5, PropKind.STANDING_STONE: 1.6,
}


func _tick_thunder(delta: float) -> void:
	var i := 0
	while i < _pending_thunder.size():
		var t: Array = _pending_thunder[i]
		t[0] = float(t[0]) - delta
		if float(t[0]) <= 0.0:
			Events.sfx.emit(&"thunder", t[1])
			_pending_thunder.remove_at(i)
		else:
			i += 1
