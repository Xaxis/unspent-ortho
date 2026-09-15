extends GameSystem
## The sky over the running game: reads the weather of every landscape around
## the camera, mixes it (WeatherLook), eases the regional light cast, drifts
## clouds and fog, lays the dawn mist, throws lightning (storms and the dry
## lightning of the bonelands) with its afterglow and the machines' stutter, and
## hands it all to SkyLight (the one writer of the sky shader globals, composed
## once a frame) and WeatherView (what falls through the air).

## Seconds for the light cast and the weather mix to settle after a border.
const REGION_EASE := 2.5
const WEATHER_EASE := 1.2
## Tiles around the focus that are sampled for country and weather.
const SAMPLE_REACH := 7.0

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
## The country whose weather falls at the focus (fall_country), last frame.
var here := Country.COAST

## The afterglow rolling through the clouds after a strike, in real seconds:
## [until, level]. Stepped, a lit patch catching and letting go, never a fade.
const AFTERGLOW: Array[Vector2] = [
	Vector2(0.10, 0.0), Vector2(0.28, 0.85), Vector2(0.40, 0.3), Vector2(0.62, 0.65),
	Vector2(0.80, 0.18), Vector2(1.05, 0.45), Vector2(1.30, 0.12), Vector2(1.60, 0.24),
]
## Tiles the lit patch of cloud has rolled out from the strike after 1 s.
const AFTERGLOW_ROLL := 16.0
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
		_forced_bolt = false
		return true
	var parts := spec.split(":")
	var kind := StringName(parts[0])
	if not Weather.KINDS.has(kind):
		push_warning("unknown weather %s" % parts[0])
		return false
	Weather.force(kind, parts[1].to_float() if parts.size() > 1 else 1.0)
	_forced_any = true
	_forced_bolt = parts.size() > 2 and parts[2] == "bolt"
	return true


func _process(delta: float) -> void:
	_update(delta, false)


func _focus() -> Vector3:
	if game.camera != null:
		return game.camera.target
	return game.player.position


## Countries around the focus with their share, blending across ecotones.
func sample_countries(focus: Vector2) -> Dictionary:
	var w := game.world
	var shares := {}
	var offsets: Array[Vector2] = [Vector2.ZERO, Vector2(SAMPLE_REACH, 0), Vector2(-SAMPLE_REACH, 0), Vector2(0, SAMPLE_REACH), Vector2(0, -SAMPLE_REACH)]
	for o in offsets:
		var x := clampi(floori(focus.x + o.x), 0, w.size - 1)
		var y := clampi(floori(focus.y + o.y), 0, w.size - 1)
		var i := y * w.size + x
		var weight := 2.0 if o == Vector2.ZERO else 1.0
		var c := int(w.country[i])
		var b := clampf(w.blend[i], 0.0, 1.0) if w.blend.size() > i else 0.0
		var c2 := int(w.country2[i]) if w.country2.size() > i else c
		shares[c] = float(shares.get(c, 0.0)) + weight * (1.0 - b)
		if b > 0.0:
			shares[c2] = float(shares.get(c2, 0.0)) + weight * b
	var total := 0.0
	for c: int in shares:
		total += float(shares[c])
	for c: int in shares:
		shares[c] = float(shares[c]) / total
	return shares


## What the sky draws from the focus country alone (WeatherLook.compose keys).
const FALL_KEYS: Array[String] = ["rain", "drizzle", "hail", "snow", "ash", "dust", "fog", "heat", "whiteout", "glare", "haze", "bolt", "storm"]


## The country whose weather falls at a point: the tile's own, or the one it
## has turned toward once past the middle of an ecotone.
static func fall_country(w: WorldData, at: Vector2) -> int:
	var x := clampi(floori(at.x), 0, w.size - 1)
	var y := clampi(floori(at.y), 0, w.size - 1)
	var i := y * w.size + x
	if w.blend.size() > i and w.blend[i] > 0.5 and w.country2.size() > i:
		return int(w.country2[i])
	return int(w.country[i])


func _update(delta: float, snap: bool) -> void:
	var f3 := _focus()
	var focus := Vector2(f3.x, f3.z)
	var minutes := game.clock.minutes
	var seed_value := game.world.seed_value
	var shares := sample_countries(focus)

	var entries: Array = []
	var target_region := Vector3.ZERO
	var target_wind := 0.0
	var target_mist := 0.0
	for c: int in shares:
		var wx := Weather.at_place(seed_value, minutes, c)
		entries.append({"kind": wx.kind, "strength": wx.strength, "weight": shares[c]})
		target_region += SkyLight.country_tint(c) * SkyLight.country_light(c) * SkyLight.mood_light(Weather.type_of(c), game.clock.hour()) * float(shares[c])
		target_wind += float(wx.wind) * float(shares[c])
		target_mist += float(wx.mist) * float(shares[c])
	var target := WeatherLook.compose(entries)
	# The light and the clouds blend across a border, but what falls through the
	# air is one country's: the one under the focus. A frame at a triple border
	# must not snow, rain ash and lie in fog all at once.
	here = fall_country(game.world, focus)
	var wh := Weather.at_place(seed_value, minutes, here)
	var falls := WeatherLook.compose([{"kind": wh.kind, "strength": wh.strength, "weight": 1.0}])
	for k: String in FALL_KEYS:
		target[k] = falls[k]
	target.mist = target_mist
	target.wisp = wisp_amount(1.0 if here == Country.MOSS else 0.0, Weather.night_fall(game.clock.hour()), float(target.rain) + float(target.drizzle), target_wind)
	# What lies on the ground changes over hours: recompute once a world minute.
	# Each thing is the most any country in view has left; the sky_ground mask
	# lays it only on the countries that make it.
	if snap or absf(minutes - _settle_minute) >= 1.0:
		_settle_minute = minutes
		for k: String in _settle_target:
			_settle_target[k] = 0.0
		for c: int in shares:
			var st := Weather.settled(seed_value, minutes, c)
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
	# A held bolt (shots) holds the afterglow and the machines' dip where they read.
	var t := 0.5 if _forced_bolt else since_strike
	sky.bolt = Vector4(_strike_at.x, _strike_at.y, afterglow(t) * _glow_gain, lerpf(1.0, machine_power(t), _glow_gain))
	sky.glow_reach = AFTERGLOW_ROLL * (0.35 + minf(t, 2.0))
	# Sway advances faster in a strong wind, so reeds never snap to a new speed.
	_sway_phase = fposmod(_sway_phase + delta * (0.8 + 3.2 * absf(wind)), TAU * 1000.0)
	var gust := clampf(float(look.storm) + float(look.dust) * 0.6 + float(look.whiteout) * 0.6 + absf(wind) * 0.3, 0.0, 1.0)
	var along := _cloud_bearing * wind
	sky.wind = Vector4(along.x, along.y, gust, _sway_phase)
	# Tufts and crowns never hang dead still, and a storm bends them hard.
	sky.sway = clampf(0.15 + absf(wind) * 0.6 + gust * 0.5, 0.0, 1.2)
	sky.cast_allowed = float(look.overcast) < 0.6
	sky.set_hour(game.clock.hour())
	view.update(look, wind, f3, delta)
	_update_ground_marks(focus, minutes, seed_value, delta, snap)
	_tick_thunder(delta)


## Drips from eaves, arms and crowns, and dust devils on hot dusty ground: marks
## that belong to things on the land, so they are placed from the props and the
## terrain here and drawn by the view.
func _update_ground_marks(focus: Vector2, minutes: float, seed_value: int, delta: float, snap: bool) -> void:
	var drip := Drips.amount(float(look.rain) + float(look.drizzle) * 0.5, float(settled.wet))
	# Under the pinewood's crowns the rain comes down as drips.
	if here == Country.PINEWOOD:
		drip = clampf(drip * 1.5, 0.0, 1.0)
	_drip_scan -= delta
	if drip > 0.01 and (snap or _drip_scan <= 0.0):
		_drip_scan = 0.5
		var props := game.query.props_near(focus, Drips.REACH)
		view.set_drip_points(Drips.points(props, focus, seed_value, game.world.to_3d, game.world.depleted))
	view.set_drips(drip, float(look.snow) > 0.2)
	var dusty := clampf(float(look.dust) * 1.2 + float(look.glare) * 0.5, 0.0, 1.0)
	var devils := DustDevils.at(seed_value, minutes, focus, dusty, _cloud_bearing * signf(wind if absf(wind) > 0.01 else 1.0))
	var placed: Array[Dictionary] = []
	for d: Dictionary in devils:
		placed.append({"at": game.world.to_3d(d.pos), "life": d.life, "seed": d.seed})
	view.set_devils(placed)


## Wisps: cold lights over the moss after dark, never in rain or a wind.
static func wisp_amount(moss_share: float, night: float, rain: float, wind_now: float) -> float:
	return clampf(moss_share * night * (1.0 - clampf(rain, 0.0, 1.0)) * (1.0 - absf(wind_now) * 1.5), 0.0, 1.0)


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
	var at := Vector2(f3.x, f3.z) + Vector2(r.randf_range(-9.0, 9.0), r.randf_range(-6.0, 6.0))
	# Strikes find the tallest thing near where they land.
	var best := -1.0
	for p: WorldProp in game.query.props_near(at, 5.0):
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
