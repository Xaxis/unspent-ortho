extends GameSystem
## The score: haunting, synthesizer-heavy ambient that never stops evolving
## (owner, 2026-09-15). ScoreConductor decides; this system listens to the world
## for it and plays what it decides.
##
## What it hears, four times a second: the landscapes around the player (their
## weights, so an ecotone is two scores at once), the hour, the weather, hostile
## machines that have noticed the player closing in (danger), any within earshot
## (near: their tense stems are baked before they are needed, and nothing is
## heard, so the score never tells a sneaking player where an unseen machine
## stands), a blow landing on the player, a machine installation's proximity
## (the grid) and a sentinel's reach.
##
## Loops play on their own players, started at the music clock's place in them
## so every stem keeps to the shared bar lines; a stem is heard only once it is
## baked (on a worker, or a slice a frame without threads), and fades in from
## silence by the conductor's own easing. Phrases, the resolution and the motif
## wait for their bar line. The Music bus's low-pass closes at night and in fog.
## A landscape's stems unheard for FORGET_AFTER seconds leave memory (the disk
## cache keeps them).
##
## Nothing here runs in --shot runs (the bank bakes nothing), and setup does no
## sound work, so the game still starts in its budget.

const INPUT_EVERY := 0.25
const WORKS_EVERY := 1.0
const BAKE_EVERY := 0.5
## Tiles: a hostile machine this close is full danger; danger begins at FAR.
const DANGER_NEAR := 8.0
const DANGER_FAR := 26.0
## Tiles within which a hostile machine is "near": its tense stems are baked.
const EAR_REACH := 44.0
## A hostile animal is this much of a machine's danger: a dog on your heels
## quickens the pulse a little, never the dissonance or its resolution.
const BEAST_SHARE := 0.3
## A mob's moods (MobState) that mean it has noticed the player.
const AWARE_MOODS: Array[StringName] = [&"alerted", &"chasing", &"attacking"]
## Seconds a blow on the player holds danger at full.
const HIT_HOLD := 6.0
## A sentinel's reach when it does not say (tiles).
const SENTINEL_REACH := 30.0
const FORGET_AFTER := 180.0
const CUE_VOICES := 3
## A layer is heard (by a tour, and in its log) from this share of its sheet
## level: about 10 dB under it, plainly there, not a trace.
const HEARD := 0.3
## Seconds into a game before the score asks for anything to be baked: the
## first seconds' CPU belongs to the land streaming in, and the score fades in
## over tens of seconds anyway. A game that ends sooner (a test, the title
## flicking by) leaves no score half-rendered on the workers.
const START_DELAY := 2.0

var bank: SoundBank
var conductor: ScoreConductor
var inputs: Dictionary = {}
var seconds := 0.0
## Stem key -> AudioStreamPlayer for the loops that are sounding.
var players: Dictionary = {}
## Keys of cues started, newest last (tests and tours).
var cues_played: Array[StringName] = []

var _cue_players: Array[AudioStreamPlayer] = []
var _input_t := 0.0
var _works_t := 0.0
var _bake_t := 0.0
var _grid := 0.0
var _hit_until := -INF
var _hit_share := 1.0
var _heard_at: Dictionary = {}
## Seconds the audio thread runs ahead of the music clock, learnt from a playing loop.
var _sync := 0.0
var _land_ids: Dictionary = {}
## In a tour the score says what it is doing, so the tour's log shows it evolve.
var _tour_log := false
var _logged := ""


func setup(g: Game) -> void:
	super.setup(g)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		_tour_log = _tour_log or a.begins_with("--tour=")
	bank = SoundBank.shared()
	conductor = ScoreConductor.new(game.world.seed_value)
	for i in CUE_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		add_child(p)
		_cue_players.append(p)
	Events.hit.connect(_on_hit)
	Events.time_skipped.connect(_on_skip)
	SaveGame.register(&"score", _save, _load)
	_read_inputs()
	_read_works()
	conductor.tick(0.0, inputs)


func _exit_tree() -> void:
	if Events.hit.is_connected(_on_hit):
		Events.hit.disconnect(_on_hit)
	if Events.time_skipped.is_connected(_on_skip):
		Events.time_skipped.disconnect(_on_skip)


func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	bank.pump()
	advance(delta)


## Explicit time, so tests can drive it.
func advance(delta: float) -> void:
	seconds += delta
	_input_t -= delta
	if _input_t <= 0.0:
		_input_t = INPUT_EVERY
		_read_inputs()
	_works_t -= delta
	if _works_t <= 0.0:
		_works_t = WORKS_EVERY
		_read_works()
	conductor.tick(delta, inputs)
	_mix()
	for c: Array in conductor.cues:
		_play_cue(c[0], float(c[1]))
	if _tour_log:
		_log_layers()
	_bake_t -= delta
	if _bake_t <= 0.0 and seconds >= START_DELAY:
		_bake_t = BAKE_EVERY
		_request_wanted()
		_forget_unheard()
	var lp := SoundBuses.music_lowpass()
	if lp != null:
		lp.cutoff_hz = ScoreConductor.bus_cutoff(conductor.night, inputs.get("weather", {}))


# ------------------------------------------------------------------ listening

func _on_hit(attacker: Object, target: Object, damage: int, _plate: bool, _at: Vector3) -> void:
	if target == game.player and damage > 0:
		_hit_until = seconds + HIT_HOLD
		_hit_share = share_of(attacker)


## How much of a machine's danger a body is: a machine all of it, anything else BEAST_SHARE.
static func share_of(body: Object) -> float:
	if body == null or not is_instance_valid(body):
		return 1.0
	return 1.0 if SoundMachines.kind_of(StringName(str(body.get("kind")))) != &"" else BEAST_SHARE


## Whether a mob has noticed the player: its own `aware` when it exposes one
## (asked of the mob contract), else its state's mood; a mob that says neither
## is presence only.
static func aware_of(m: Object) -> bool:
	var own: Variant = m.get("aware")
	if own is bool:
		return own
	var state: Variant = m.get("state")
	if state is Object and is_instance_valid(state):
		var mood: Variant = (state as Object).get("mood")
		if mood is StringName or mood is String:
			return StringName(mood) in AWARE_MOODS
	return false


func _on_skip(_minutes: float, _reason: StringName) -> void:
	_input_t = 0.0
	_works_t = 0.0


## The score's landscape id for a country id: its type's name, or the motif the
## type names for its music (BiomeDef.music_motif) when it names one.
func _land_id(country: int) -> StringName:
	if not _land_ids.has(country):
		var id := StringName(Country.NAMES[clampi(country, 0, Country.NAMES.size() - 1)])
		if id == &"sea":
			id = &"coast"
		var def := BiomeRegistry.get_def(id)
		if def != null and def.music_motif != &"":
			id = def.music_motif
		_land_ids[country] = id
	return _land_ids[country]


func _read_inputs() -> void:
	var p := game.player.pos
	var weights := {}
	for c: int in _country_weights(p):
		var id := _land_id(c)
		weights[id] = float(weights.get(id, 0.0)) + float(_country_weights(p)[c])
	var here := SoundMix.dominant_country(game.world, p)
	var danger := 0.0
	var near := 0.0
	if is_inside_tree():
		for m: Node in get_tree().get_nodes_in_group(&"mobs"):
			var alive: Variant = m.get("alive")
			var hostile: Variant = m.get("hostile")
			var pos: Variant = m.get("pos")
			if (alive is bool and not alive) or (hostile is bool and not hostile) or not pos is Vector2:
				continue
			var d := (pos as Vector2).distance_to(p)
			if d < EAR_REACH:
				near = 1.0
			if aware_of(m):
				danger = maxf(danger, smoothstep(DANGER_FAR, DANGER_NEAR, d) * share_of(m))
	if seconds < _hit_until:
		danger = maxf(danger, _hit_share)
	inputs = {
		"weights": weights,
		"hour": game.clock.hour(),
		"weather": SoundMix.weather_at(game.world.seed_value, game.clock.minutes, int(here["country"])),
		"danger": danger,
		"near": maxf(near, danger),
		"grid": _grid,
		"sentinel": _sentinel(p),
	}


var _weights_cache_p := Vector2(-1, -1)
var _weights_cache := {}


## Country id -> share of the ear, from the same rings the beds hear with.
func _country_weights(p: Vector2) -> Dictionary:
	if p != _weights_cache_p:
		_weights_cache_p = p
		_weights_cache = SoundMix.country_share(game.world, p)
	return _weights_cache


func _read_works() -> void:
	if game.query == null:
		_grid = 0.0
		return
	# Each installation's reach is its own (a pylon only underneath it, a
	# substation over its yard): SoundMix.works_near sums them.
	_grid = float(SoundMix.works_near(game.query, game.player.pos)["grid"])


func _sentinel(p: Vector2) -> Dictionary:
	if not is_inside_tree():
		return {}
	var best := {}
	var best_s := 0.0
	for s: Node in get_tree().get_nodes_in_group(&"sentinels"):
		var alive: Variant = s.get("alive")
		var pos: Variant = s.get("pos")
		if (alive is bool and not alive) or not pos is Vector2:
			continue
		var reach_v: Variant = s.get("reach")
		var reach := float(reach_v) if (reach_v is float or reach_v is int) else SENTINEL_REACH
		var strength := smoothstep(reach, reach * 0.5, (pos as Vector2).distance_to(p))
		if strength > best_s:
			best_s = strength
			var land: Variant = s.get("land")
			best = {"strength": strength, "land": StringName(str(land)) if land != null else &""}
	return best


# ------------------------------------------------------------------ playing

func _mix() -> void:
	for key: StringName in conductor.levels:
		var level := float(conductor.levels[key])
		var baked := bank.get_baked(key) if seconds >= START_DELAY else null
		if baked == null:
			continue
		var p: AudioStreamPlayer = players.get(key)
		if p == null:
			p = AudioStreamPlayer.new()
			p.bus = &"Music"
			p.stream = baked.stream
			add_child(p)
			players[key] = p
		if not p.playing:
			p.play(_loop_position(baked.stream.get_length()))
		p.volume_db = baked.gain_db + linear_to_db(maxf(level, 1e-5))
		_heard_at[key] = seconds
	for key: StringName in players.keys():
		if not conductor.levels.has(key):
			var p: AudioStreamPlayer = players[key]
			p.stop()
			p.queue_free()
			players.erase(key)
	_learn_sync()


## Where in a loop of `length` seconds the music clock is now.
func _loop_position(length: float) -> float:
	return fposmod(conductor.time + _sync, maxf(0.01, length))


## The audio thread and the frame clock drift apart; a playing loop says by how
## much, and later loops start where it is, not where the frame clock thinks.
func _learn_sync() -> void:
	for key: StringName in players:
		var p: AudioStreamPlayer = players[key]
		if not p.playing or p.stream == null:
			continue
		var length := p.stream.get_length()
		var actual := p.get_playback_position() + AudioServer.get_time_since_last_mix()
		var err := fposmod(actual - _loop_position(length) + length * 0.5, length) - length * 0.5
		if absf(err) < 0.5:
			_sync += err * 0.2
		return


func _play_cue(key: StringName, gain: float) -> void:
	if seconds < START_DELAY:
		return
	var baked := bank.get_baked(key, true)
	if baked == null:
		return
	var voice := _cue_players[0]
	for p in _cue_players:
		if not p.playing:
			voice = p
			break
	voice.stop()
	voice.stream = baked.stream
	voice.volume_db = baked.gain_db + linear_to_db(maxf(gain, 1e-5))
	voice.play()
	cues_played.append(key)
	_heard_at[key] = seconds
	if _tour_log:
		print("tour score %.0fs: cue %s" % [seconds, String(key).trim_prefix("score_")])


func _request_wanted() -> void:
	var wanted := conductor.wanted()
	for i in wanted.size():
		# The loudest few jump the queue: they are what the next seconds sound like.
		bank.request(wanted[i], i < 2)


func _forget_unheard() -> void:
	for key: StringName in _heard_at.keys():
		if seconds - float(_heard_at[key]) > FORGET_AFTER and not players.has(key):
			bank.forget(key)
			_heard_at.erase(key)


# ------------------------------------------------------------------ proofs and saves

## For tours: whether the player could hear WHAT now, a layer playing at HEARD
## or more: score (any layer), score_pad, score_pulse (calm), score_tense (the
## quickened pulse), score_grid, score_dissonance, score_texture; score_phrase,
## score_resolve, score_motif (that cue has been played).
func tour_seen(what: String) -> bool:
	if not what.begins_with("score"):
		return false
	for cue: String in ["phrase", "resolve", "motif"]:
		if what == "score_" + cue:
			var suffix := "_melody" if cue == "phrase" else "_" + cue
			return cues_played.any(func(k: StringName) -> bool: return String(k).get_slice(":", 0).ends_with(suffix))
	var layer := StringName(what.trim_prefix("score_")) if what != "score" else &""
	for key: StringName in players:
		var p: AudioStreamPlayer = players[key]
		if p.playing and float(conductor.levels.get(key, 0.0)) >= HEARD and (layer == &"" or ScoreConductor.layer_of(key) == layer):
			return true
	return false


## One line whenever the set of layers heard (at HEARD) changes.
func _log_layers() -> void:
	var heard: PackedStringArray = []
	for key: StringName in players:
		if (players[key] as AudioStreamPlayer).playing and float(conductor.levels.get(key, 0.0)) >= HEARD:
			heard.append(String(key).trim_prefix("score_"))
	heard.sort()
	var line := ", ".join(heard)
	if line != _logged:
		_logged = line
		print("tour score %.0fs (form %.1f, danger %.2f): %s" % [seconds, conductor.effective, conductor.danger, line if line != "" else "silent"])


func _save() -> Variant:
	return {"clock": conductor.time}


func _load(v: Variant) -> void:
	if v is Dictionary:
		conductor.time = float((v as Dictionary).get("clock", conductor.time))
