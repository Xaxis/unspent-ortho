extends GameSystem
## The sky over the running game: reads the weather of every country around the
## camera, mixes it (WeatherLook), eases the regional light cast, drifts clouds
## and fog, throws lightning, and hands it all to SkyLight (the one writer of
## the sky shader globals) and WeatherView (what falls through the air).

## Seconds for the light cast and the weather mix to settle after a border.
const REGION_EASE := 2.5
const WEATHER_EASE := 1.2
## Tiles around the focus that are sampled for country and weather.
const SAMPLE_REACH := 7.0

var view: WeatherView
## The last composed look (WeatherLook.compose), eased. Other systems may read it.
var look: Dictionary = {}
var wind := 0.0
var region := Vector3.ONE
var _cloud_drift := Vector2.ZERO
var _fog_drift := Vector2.ZERO
var _cloud_bearing := Vector2.RIGHT
var _last_minutes := 0.0
var _flash := 0.0
var _pending_strikes: Array = [] # [world minute, strength, minute index]
var _pending_thunder: Array = [] # [real seconds left, Vector3]
var _forced_bolt := false


func setup(g: Game) -> void:
	super.setup(g)
	_apply_forced(g.options.weather)
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
	if game != null and game.options.weather != "":
		Weather.unforce()


## "kind:strength[:bolt]"
func _apply_forced(spec: String) -> void:
	if spec == "":
		return
	var parts := spec.split(":")
	var kind := StringName(parts[0])
	if not Weather.KINDS.has(kind):
		push_warning("unknown weather %s" % parts[0])
		return
	Weather.force(kind, parts[1].to_float() if parts.size() > 1 else 1.0)
	_forced_bolt = parts.size() > 2 and parts[2] == "bolt"


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


func _update(delta: float, snap: bool) -> void:
	var f3 := _focus()
	var focus := Vector2(f3.x, f3.z)
	var minutes := game.clock.minutes
	var seed_value := game.world.seed_value
	var shares := sample_countries(focus)

	var entries: Array = []
	var target_region := Vector3.ZERO
	var target_wind := 0.0
	for c: int in shares:
		var wx := Weather.at_place(seed_value, minutes, c)
		entries.append({"kind": wx.kind, "strength": wx.strength, "weight": shares[c]})
		target_region += SkyLight.country_tint(c) * float(shares[c])
		target_wind += float(wx.wind) * float(shares[c])
	var target := WeatherLook.compose(entries)

	var kr := 1.0 if snap else 1.0 - exp(-delta / REGION_EASE)
	var kw := 1.0 if snap else 1.0 - exp(-delta / WEATHER_EASE)
	region = region.lerp(target_region, kr)
	wind = lerpf(wind, target_wind, kw)
	if look.is_empty() or snap:
		look = target
	else:
		for k: String in target:
			if target[k] is Vector3:
				look[k] = (look[k] as Vector3).lerp(target[k], kw)
			else:
				look[k] = lerpf(float(look[k]), float(target[k]), kw)

	# Drift by world minutes, so a skipped hour moves the sky an hour on.
	var dm := clampf(minutes - _last_minutes, 0.0, 600.0)
	_scan_lightning(_last_minutes, minutes, seed_value)
	_last_minutes = minutes
	_cloud_drift += _cloud_bearing * dm * (0.35 + 1.1 * absf(wind))
	_fog_drift += _cloud_bearing.orthogonal() * dm * (0.08 + 0.3 * absf(wind))

	_flash = maxf(0.0, _flash - delta * 5.0)
	var sky := game.sky
	sky.region_tint = region
	sky.weather_tint = look.tint
	sky.season_turn = Weather.season_turn(minutes)
	sky.clouds = Vector4(_cloud_drift.x, _cloud_drift.y, float(look.cover), float(look.cloud))
	sky.fog = Vector4(_fog_drift.x, _fog_drift.y, float(look.fog), float(look.heat) * (1.0 - Weather.night_fall(game.clock.hour())))
	sky.flash = _flash
	sky.cast_allowed = float(look.overcast) < 0.6
	sky.set_hour(game.clock.hour())
	view.update(look, wind, f3, delta)
	_tick_thunder(delta)


func _scan_lightning(from_minutes: float, to_minutes: float, seed_value: int) -> void:
	var storm := float(look.get("storm", 0.0))
	if storm <= 0.0 or Weather.forced_kind != &"" and _forced_bolt:
		return
	var m0 := maxi(floori(from_minutes), floori(to_minutes) - 3)
	for m in range(m0, floori(to_minutes) + 1):
		var f := Weather.lightning(seed_value, m, Weather.STORM, storm)
		if f < 0.0:
			continue
		var at := m + f
		if at > from_minutes and at <= to_minutes:
			_strike(storm, m, false)


func _strike(strength: float, minute: int, hold: bool) -> void:
	var seed_value := game.world.seed_value
	var dist := Weather.strike_distance(seed_value, minute, strength)
	_flash = maxf(_flash, clampf(300.0 / dist, 0.3, 1.0))
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
	# Thunder comes tiles/34 beats (0.1 s) after the light. (source)
	_pending_thunder.append([dist / 34.0 * 0.1, ground])
	if hold:
		_flash = 0.55


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
