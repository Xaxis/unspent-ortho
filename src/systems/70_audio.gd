extends GameSystem
## Everything heard in the world: the buses (made in code), country and weather
## beds crossfaded by where the player stands, scattered one-shots over them,
## the one machine that is loudest nearby, one-shots from Events.sfx (whatever
## name an emitter uses, through SoundNames), and the player's own footfalls
## observed from game.player.
##
## Sounds are generated the first time they are wanted (SoundBank, on worker
## threads); until a sound is ready it is silent, never a hitch. In --shot runs
## nothing is generated, so screenshots cost no audio work.
##
## Distance is timbre before level: far one-shots go through SfxFar (dull, wet),
## and the machine bus low-passes by distance before its level falls. A
## notebook page muffles the world bus; the interface and machines stay clear.
## The system runs while the tree is paused, so the pause page still clicks and
## the world is heard, muffled, behind it.

const WEATHER_EVERY := 1.0
const MACHINE_EVERY := 0.15
const MACHINE_FADE := 0.35
const MUFFLE_FADE := 0.12
const VOICES := 14
const UI_VOICES := 3
## Per sound name, how many may sound at once before the oldest is cut.
const POLYPHONY := 3
## Screen offset (pixels from centre) where the sea is heard at full lean.
const LEAN_PX := 260.0
## Common one-shots baked in the background right after start, most wanted first.
const WARM: Array[StringName] = [
	&"ui_move", &"ui_accept", &"book_open", &"book_close", &"swing", &"hit_flesh", &"hit_plate",
	&"whiff", &"dodge", &"pickup", &"gather", &"refuse", &"ui_refuse", &"ui_back", &"cut", &"break",
	&"dig", &"fell", &"grip", &"pull", &"loose", &"machine_down", &"eat",
]

var bank: SoundBank
var seconds := 0.0
var steps := 0
var weather := {"kind": &"fair", "strength": 0.0, "wind": 0.0}
var sea := {"distance": INF, "direction": Vector2.ZERO}
var river := {"distance": INF, "direction": Vector2.ZERO}
var remote := 0.0
## Bed name -> smoothed level 0..1 (what the players are set to).
var levels: Dictionary = {}
var targets: Dictionary = {}
## The machine heard: kind, level (smoothed), and the players crossfading.
var machine_kind: StringName = &""
var machine_target := 0.0
## World muffle 0..1, smoothed toward what the open pages ask for.
var muffle := 0.0
var muffle_target := 0.0
## The last one-shots started, newest last: {key, bus, db}. For tests and debugging.
var history: Array[Dictionary] = []

var _beds: Dictionary = {}
var _voices: Array[AudioStreamPlayer2D] = []
var _voice_name: Array[StringName] = []
var _voice_started: Array[float] = []
var _ui_voices: Array[AudioStreamPlayer] = []
var _machine: Array[AudioStreamPlayer2D] = []
var _machine_levels: Array[float] = [0.0, 0.0]
var _machine_kinds: Array[StringName] = [&"", &""]
var _machine_active := 0
var _machine_distance := 0.0
var _machine_racket := 1.0
var _machine_at := Vector2.ZERO
var _scan_t := 0.0
var _weather_t := 0.0
var _machine_t := 0.0
var _stride := 0.0
var _last_pos := Vector2.ZERO
var _last_step := -10.0
var _foot_clock := 0.0
var _scatter_next: Dictionary = {}
var _last_variant: Dictionary = {}
var _last_killed: StringName = &""
var _open_pages: Dictionary = {}
var _played := 0


func setup(g: Game) -> void:
	super.setup(g)
	var t0 := Time.get_ticks_usec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	bank = SoundBank.shared()
	bank.enabled = game.options == null or game.options.shot == ""
	SoundBuses.ensure()
	for i in VOICES:
		_voices.append(_player(&"SFX"))
		_voice_name.append(&"")
		_voice_started.append(-1.0)
	for i in UI_VOICES:
		var u := AudioStreamPlayer.new()
		u.bus = &"UI"
		add_child(u)
		_ui_voices.append(u)
	for i in 2:
		_machine.append(_player(&"Machines"))
	_last_pos = game.player.pos
	Events.sfx.connect(play)
	Events.killed.connect(_on_killed)
	Events.screen_changed.connect(_on_screen)
	Events.time_skipped.connect(_on_skip)
	_scan()
	_read_weather()
	targets = SoundMix.bed_levels(game.world, game.player.pos, weather, sea, river, seconds, _extra())
	# What the first seconds need, first: this ground's footfalls, the beds here.
	var family := SoundEffects.step_name(_ground())
	for v in SoundBank.variants(family):
		bank.request(SoundBank.key_for(family, v), true)
	# Loudest bed here first: it is most of what the first seconds sound like.
	var here: Array = targets.keys().filter(func(b: StringName) -> bool: return float(targets[b]) > 0.01)
	here.sort_custom(func(a: StringName, b: StringName) -> bool: return float(targets[a]) > float(targets[b]))
	for bed: StringName in here:
		bank.request(bed)
	for n: StringName in WARM:
		bank.request(SoundBank.key_for(n, 0))
	for n: StringName in WARM:
		for v in range(1, SoundBank.variants(n)):
			bank.request(SoundBank.key_for(n, v))
	print("audio setup %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))


func _exit_tree() -> void:
	for pair: Array in [[Events.sfx, play], [Events.killed, _on_killed], [Events.screen_changed, _on_screen], [Events.time_skipped, _on_skip]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	SoundBuses.set_muffle(0.0)
	if bank != null:
		bank.cancel()


func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	bank.pump()
	advance(delta)


func _physics_process(delta: float) -> void:
	if game == null or game.player == null or get_tree().paused:
		return
	footfalls(delta)


## The whole per-frame mix, with explicit time so tests can drive it.
func advance(delta: float) -> void:
	seconds += delta
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SoundMix.SCAN_EVERY
		_scan()
	_weather_t -= delta
	if _weather_t <= 0.0:
		_weather_t = WEATHER_EVERY
		_read_weather()
	targets = SoundMix.bed_levels(game.world, game.player.pos, weather, sea, river, seconds, _extra())
	_mix_beds(delta)
	_scatter()
	_machine_t -= delta
	if _machine_t <= 0.0:
		_machine_t = MACHINE_EVERY
		_pick_machine()
	_mix_machine(delta)
	muffle += (muffle_target - muffle) * (1.0 - exp(-delta / MUFFLE_FADE))
	SoundBuses.set_muffle(muffle)


# ------------------------------------------------------------------ one-shots

## Plays a named sound at a place (Events.sfx). The name goes through
## SoundNames, so menu_select, work_tap or alert_dog all find their sound;
## names that resolve to nothing are ignored silently.
func play(emitted: StringName, at: Vector3 = Vector3.ZERO, extra_db: float = 0.0) -> void:
	if game == null or game.player == null:
		return
	var name := SoundNames.resolve(emitted)
	if emitted == &"killed" and _last_killed != &"":
		name = SoundNames.killed_sound(_last_killed)
	if name == &"" or not SoundBank.has_sound(name):
		return
	var cat := SoundBank.category_of(name)
	var ui := cat == &"ui"
	var here := at == Vector3.ZERO or ui
	var d := 0.0 if here else Vector2(at.x, at.z).distance_to(game.player.pos)
	var gain := 1.0
	if cat == &"thunder":
		name = SoundMix.thunder_sound(d)
		gain = SoundMix.thunder_gain(d)
	elif not here:
		gain = SoundMix.sfx_gain(d)
	if gain <= 0.0:
		return
	var baked := _pick_variant(name)
	if baked == null:
		return
	_played += 1
	var db := baked.gain_db + linear_to_db(gain) + extra_db
	if ui:
		var u := _ui_voice()
		u.stream = baked.stream
		u.volume_db = db
		u.play()
		_remember(baked.key, &"UI", db)
		return
	var p := _free_voice(name)
	p.stream = baked.stream
	p.bus = &"SfxFar" if (not here and d > SoundMix.SFX_FAR and baked.bus == &"SFX" and cat != &"thunder") else baked.bus
	p.volume_db = db
	var natural := cat != &"thunder"
	p.pitch_scale = 1.0 + (Rng.hash01(_played, 0x77) - 0.5) * 0.06 if natural else 1.0
	p.position = _screen_centre() if here else _screen_at(Vector2(at.x, at.z))
	p.play()
	_remember(baked.key, p.bus, db)


## A baked take of `name`, never the one played last time when there is a
## choice; if the wanted take is not baked yet, any baked take will do.
func _pick_variant(name: StringName) -> SoundBank.Baked:
	var count := maxi(1, SoundBank.variants(name))
	var last := int(_last_variant.get(name, -1))
	var v := floori(Rng.hash01(_played, int(name.hash()), 0x5f) * count)
	if count > 1 and v == last:
		v = (v + 1) % count
	var baked := bank.get_baked(SoundBank.key_for(name, v), true)
	if baked == null:
		for k in count:
			if bank.is_ready(SoundBank.key_for(name, k)):
				v = k
				baked = bank.get_baked(SoundBank.key_for(name, k))
				break
	if baked != null:
		_last_variant[name] = v
	return baked


func _remember(key: StringName, bus: StringName, db: float) -> void:
	history.append({"key": key, "bus": bus, "db": db})
	if history.size() > 64:
		history.pop_front()


func _free_voice(name: StringName) -> AudioStreamPlayer2D:
	var same := 0
	var oldest_same := -1
	var oldest := 0
	var free := -1
	for i in _voices.size():
		var playing := _voices[i].playing
		if not playing:
			if free < 0:
				free = i
			continue
		if _voice_name[i] == name:
			same += 1
			if oldest_same < 0 or _voice_started[i] < _voice_started[oldest_same]:
				oldest_same = i
		if _voice_started[i] < _voice_started[oldest]:
			oldest = i
	var pick := free
	if same >= POLYPHONY:
		pick = oldest_same
	elif pick < 0:
		pick = oldest
	_voices[pick].stop()
	_voice_name[pick] = name
	_voice_started[pick] = seconds + _played * 1e-6
	return _voices[pick]


func _ui_voice() -> AudioStreamPlayer:
	for u in _ui_voices:
		if not u.playing:
			return u
	# All busy: the interface is quick, so the first one is the oldest near enough.
	_ui_voices[0].stop()
	return _ui_voices[0]


func _on_killed(kind: StringName, _at: Vector3) -> void:
	_last_killed = kind


## A page open muffles the world; the pause page most of all.
func _on_screen(page: StringName, open: bool) -> void:
	if open:
		_open_pages[page] = true
	else:
		_open_pages.erase(page)
	muffle_target = 0.0
	for p: StringName in _open_pages:
		muffle_target = maxf(muffle_target, SoundMix.MUFFLE_PAUSE if p == &"pause" else SoundMix.MUFFLE_SCREEN)


## After a jump in time the weather and the place are read again at once.
func _on_skip(_minutes: float, _reason: StringName) -> void:
	_weather_t = 0.0
	_scan_t = 0.0


# ------------------------------------------------------------------ footfalls

## Footfalls from how far the player actually moved (walls, wading and load
## all show up for free), one per stride, never closer than STEP_MIN_GAP.
func footfalls(delta: float) -> void:
	_foot_clock += delta
	var p := game.player.pos
	var moved := p.distance_to(_last_pos)
	_last_pos = p
	if moved > 2.0:
		_stride = 0.0
		return
	var run := game.player.speed > (Tuning.WALK_SPEED + Tuning.RUN_SPEED) * 0.5
	var stride := SoundMix.STRIDE_RUN if run else SoundMix.STRIDE_WALK
	if moved < 1e-4:
		# Standing: the first step of the next walk lands quickly.
		_stride = maxf(_stride, stride * 0.7)
		return
	_stride += moved
	if _stride >= stride and _foot_clock - _last_step >= SoundMix.STEP_MIN_GAP:
		_stride = fmod(_stride, stride)
		_last_step = _foot_clock
		steps += 1
		play(SoundEffects.step_name(_ground()), Vector3.ZERO, 1.5 if run else 0.0)


func _ground() -> int:
	return game.world.ground_at(floori(game.player.pos.x), floori(game.player.pos.y))


# ----------------------------------------------------------------------- beds

func _scan() -> void:
	sea = SoundMix.sea_near(game.world, game.player.pos)
	river = SoundMix.river_near(game.world, game.player.pos)
	remote = SoundMix.remoteness(game.world, game.player.pos)


func _read_weather() -> void:
	var here := SoundMix.dominant_country(game.world, game.player.pos)
	weather = SoundMix.weather_at(game.world.seed_value, game.clock.minutes, int(here["country"]))


func _extra() -> Dictionary:
	return {"hour": game.clock.hour(), "remote": remote, "tide": SoundMix.tide_at(game.clock.minutes)}


func _mix_beds(delta: float) -> void:
	var k := 1.0 - exp(-delta / SoundMix.BED_FADE)
	for bed: StringName in targets:
		if not levels.has(bed):
			levels[bed] = 0.0
	for bed: StringName in levels.keys():
		var target := float(targets.get(bed, 0.0))
		var lvl: float = levels[bed]
		lvl += (target - lvl) * k
		levels[bed] = lvl
		var p: AudioStreamPlayer2D = _beds.get(bed)
		if lvl < 0.002 and target < 0.002:
			if p != null and p.playing:
				p.stop()
			continue
		var baked := bank.get_baked(bed)
		if baked == null:
			continue
		if p == null:
			p = _player(baked.bus)
			p.stream = baked.stream
			_beds[bed] = p
		if not p.playing:
			# Start somewhere inside the loop so two beds never phase together.
			var len_s := baked.stream.get_length()
			p.play(Rng.hash01(int(bed.hash()), steps, 0x8e) * len_s)
		p.volume_db = baked.gain_db + linear_to_db(maxf(lvl, 1e-5))
		p.position = _sea_lean() if bed == &"bed_shore" else _screen_centre()


func _sea_lean() -> Vector2:
	var dir: Vector2 = sea.get("direction", Vector2.ZERO)
	if dir == Vector2.ZERO:
		return _screen_centre()
	var here := _screen_at(game.player.pos)
	var there := _screen_at(game.player.pos + dir * 8.0)
	var s := there - here
	return _screen_centre() + (s.normalized() * LEAN_PX if s.length() > 0.5 else Vector2.ZERO)


## Scattered one-shots over the beds that are up: never on a pattern, never
## the same variant twice running, placed somewhere left or right.
func _scatter() -> void:
	var hour := game.clock.hour()
	var kind: StringName = weather.get("kind", &"fair")
	var s := float(weather.get("strength", 0.0))
	var tide := SoundMix.tide_at(game.clock.minutes)
	for bed: StringName in SoundBeds.SCATTER:
		var lvl := float(levels.get(bed, 0.0))
		if lvl < 0.12:
			continue
		for entry: Array in SoundBeds.SCATTER[bed]:
			var name: StringName = entry[0]
			if not SoundMix.scatter_allowed(entry, hour, weather):
				continue
			var spacing := 1.0
			if name == &"shore_gull":
				# Gulls crowd the low tide near people.
				spacing = lerpf(0.6, 1.5, tide) * lerpf(0.7, 1.4, remote)
			_scatter_entry(name, entry, lvl, spacing)
	if SoundMix.WEATHER_SCATTER.has(kind) and s > 0.25:
		var entry: Array = SoundMix.WEATHER_SCATTER[kind]
		_scatter_entry(entry[0], entry, s, 1.0)
	if kind == &"fog" and s > 0.4 and float(levels.get(&"bed_shore", 0.0)) > 0.2:
		if not _scatter_next.has(&"fog_horn"):
			_scatter_next[&"fog_horn"] = seconds + 20.0
			bank.request(&"fog_horn")
		elif seconds >= float(_scatter_next[&"fog_horn"]):
			_scatter_next[&"fog_horn"] = seconds + 45.0 + Rng.hash01(steps, floori(seconds)) * 50.0
			_scatter_one(&"fog_horn", s)


func _scatter_entry(name: StringName, entry: Array, level: float, spacing: float) -> void:
	if not _scatter_next.has(name):
		_scatter_next[name] = seconds + _gap(name, entry) * spacing
		bank.request(SoundBank.key_for(name, 0))
		return
	if seconds < float(_scatter_next[name]):
		return
	_scatter_next[name] = seconds + _gap(name, entry) * spacing
	_scatter_one(name, level)


func _gap(name: StringName, entry: Array) -> float:
	return lerpf(float(entry[1]), float(entry[2]), Rng.hash01(int(name.hash()), floori(seconds * 10.0), 0x5c))


func _scatter_one(name: StringName, level: float) -> void:
	var baked := _pick_variant(name)
	if baked == null:
		return
	_played += 1
	var p := _free_voice(name)
	p.stream = baked.stream
	p.bus = baked.bus
	p.volume_db = baked.gain_db + linear_to_db(maxf(level, 1e-4))
	p.pitch_scale = 1.0 + (Rng.hash01(_played, floori(seconds)) - 0.5) * 0.08
	var side := (Rng.hash01(floori(seconds * 7.0), _played, 0x51) - 0.5) * 2.0
	p.position = _screen_centre() + Vector2(side * 300.0, 0.0)
	p.play()
	_remember(baked.key, p.bus, p.volume_db)


# -------------------------------------------------------------------- machines

func _pick_machine() -> void:
	var mobs := get_tree().get_nodes_in_group(&"mobs")
	var best := SoundMix.loudest_machine(mobs, game.player.pos)
	# Bake ahead: anything within half again its racket is about to be heard.
	for m: Node in mobs:
		var kind := SoundMachines.kind_of(StringName(str(m.get("kind"))))
		var pos: Variant = m.get("pos")
		if kind != &"" and pos is Vector2 and (pos as Vector2).distance_to(game.player.pos) < SoundMachines.RACKET[kind] * 1.5:
			bank.request(StringName("machine_" + String(kind)))
			bank.request(StringName("alert_" + String(kind)))
	if best.is_empty():
		machine_kind = &""
		machine_target = 0.0
		return
	machine_kind = best["kind"]
	machine_target = best["level"]
	_machine_distance = best["distance"]
	_machine_racket = SoundMachines.RACKET[machine_kind]
	var node: Object = best["node"]
	_machine_at = node.get("pos")


func _mix_machine(delta: float) -> void:
	var k := 1.0 - exp(-delta / MACHINE_FADE)
	if machine_kind != &"" and _machine_kinds[_machine_active] != machine_kind:
		# Crossfade: the other player takes the new kind from silence.
		_machine_active = 1 - _machine_active
		_machine_kinds[_machine_active] = machine_kind
		_machine_levels[_machine_active] = 0.0
		_machine[_machine_active].stop()
	for i in 2:
		var target := machine_target if (i == _machine_active and _machine_kinds[i] == machine_kind) else 0.0
		_machine_levels[i] += (target - _machine_levels[i]) * k
		var p := _machine[i]
		if _machine_levels[i] < 0.003 and target == 0.0:
			if p.playing:
				p.stop()
			continue
		if _machine_kinds[i] == &"":
			continue
		var baked := bank.get_baked(StringName("machine_" + String(_machine_kinds[i])))
		if baked == null:
			continue
		if p.stream != baked.stream:
			p.stream = baked.stream
		if not p.playing:
			p.play()
		p.volume_db = baked.gain_db + linear_to_db(maxf(_machine_levels[i], 1e-5))
		p.position = _screen_at(_machine_at)
	var lp := SoundBuses.machine_lowpass()
	if lp != null and machine_kind != &"":
		lp.cutoff_hz = lerpf(lp.cutoff_hz, SoundMix.machine_cutoff(_machine_distance, _machine_racket), k)
	var room := SoundBuses.machine_room()
	if room != null and machine_kind != &"":
		room.wet = lerpf(room.wet, SoundMix.machine_wet(_machine_distance, _machine_racket), k)


# ---------------------------------------------------------------------- places

func _player(bus: StringName) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.bus = bus
	# Level is ours (distance and weights are computed); the node only pans.
	p.attenuation = 0.0
	p.max_distance = 1e6
	p.panning_strength = 1.5
	add_child(p)
	p.position = _screen_centre()
	return p


func _screen_centre() -> Vector2:
	if not is_inside_tree():
		return Vector2(320, 180)
	return get_viewport().get_visible_rect().size * 0.5


## Where a tile-space point is on screen, clamped a little past the edges.
func _screen_at(p: Vector2) -> Vector2:
	var cam := game.camera
	if cam == null or not cam.is_inside_tree():
		return _screen_centre()
	var v := cam.unproject_position(game.world.to_3d(p))
	var size := get_viewport().get_visible_rect().size
	return Vector2(clampf(v.x, -size.x * 0.25, size.x * 1.25), clampf(v.y, -size.y * 0.25, size.y * 1.25))
