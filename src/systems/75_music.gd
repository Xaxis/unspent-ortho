extends GameSystem
## The figure, rarely. It plays when you arrive somewhere (a country you have
## not heard it in lately, once you are properly inside it, and once on waking),
## at dawn or dusk on some days, and when you get up from sleeping. Never over
## itself, never sooner than MIN_GAP real seconds after the last time, never
## with something alive or running close by (a fight is not a moment), and
## never into a storm that would drown it. Its phrase is baked ahead when a
## moment is near; a moment that finds it unbaked simply passes.

const MIN_GAP := 240.0
## How far into a country (1 - blend) before it counts as arrived, and how long
## you must stay.
const ARRIVE_PURITY := 0.75
const ARRIVE_HOLD := 8.0
const WAKE_HOLD := 9.0
## A country is not announced again for this long.
const COUNTRY_REST := 900.0
const DAWN_HOUR := 6.0
const DUSK_HOUR := 20.0
## Chance, hashed per day and window, that dawn or dusk gets the figure.
const WINDOW_CHANCE := 0.55
const PENDING_FOR := 25.0
## Nothing that moves may be this close (tiles) when the figure starts.
const QUIET_RADIUS := 18.0
## Weather this strong drowns it.
const DROWNING := {&"storm": 0.45, &"blizzard": 0.45, &"hail": 0.7, &"dust": 0.7, &"sand": 0.7}

var bank: SoundBank
var seconds := 0.0
var last_played := -INF
var played: Array[StringName] = []
var player: AudioStreamPlayer

var _country := -1
var _country_since := 0.0
var _announced: Dictionary = {}
var _woke := false
var _last_hour := -1.0
var _pending: StringName = &""
var _pending_until := 0.0


func setup(g: Game) -> void:
	super.setup(g)
	process_mode = Node.PROCESS_MODE_ALWAYS
	bank = SoundBank.shared()
	player = AudioStreamPlayer.new()
	player.bus = &"Music"
	add_child(player)
	_last_hour = game.clock.hour()
	Events.time_skipped.connect(_on_skip)


func _exit_tree() -> void:
	if Events.time_skipped.is_connected(_on_skip):
		Events.time_skipped.disconnect(_on_skip)


## Getting up from sleep is a moment: the dawn phrase in the morning, else the
## arrival one. The hour marks crossed while asleep do not count.
func _on_skip(_minutes: float, reason: StringName) -> void:
	_last_hour = game.clock.hour()
	if reason != &"sleep":
		return
	var hour := game.clock.hour()
	var key := SoundMusic.name_for(int(SoundMix.dominant_country(game.world, game.player.pos)["country"]))
	want(SoundBank.key_for(key, 1 if hour >= 4.0 and hour < 11.0 else 0))


func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	bank.pump()
	advance(delta)


## Explicit time, so tests can drive it.
func advance(delta: float) -> void:
	seconds += delta
	var dom := SoundMix.dominant_country(game.world, game.player.pos)
	var c: int = dom["country"]
	var key := SoundMusic.name_for(c)
	if c != _country and float(dom["purity"]) >= ARRIVE_PURITY:
		_country = c
		_country_since = seconds
		bank.request(SoundBank.key_for(key, 0))
	var hold := ARRIVE_HOLD if _woke else WAKE_HOLD
	if _country >= 0 and seconds - _country_since >= hold:
		var last := float(_announced.get(_country, -INF))
		# A country is only counted announced once the moment allows it.
		if seconds - last >= COUNTRY_REST and not player.playing and seconds - last_played >= MIN_GAP and is_moment():
			_announced[_country] = seconds
			_woke = true
			want(SoundBank.key_for(key, 0))
	var hour := game.clock.hour()
	for w: Array in [[DAWN_HOUR, 1], [DUSK_HOUR, 2]]:
		var at: float = w[0]
		var mood: int = w[1]
		if _approaching(hour, at, 0.6):
			bank.request(SoundBank.key_for(key, mood))
		if _crossed(_last_hour, hour, at) and Rng.hash01(game.world.seed_value, game.clock.day(), mood, 0x3f) < WINDOW_CHANCE:
			want(SoundBank.key_for(key, mood))
	_last_hour = hour
	if _pending != &"" and seconds < _pending_until:
		_try(_pending)
	elif _pending != &"":
		_pending = &""


## Ask for a phrase now; it plays if nothing forbids it and it is (or soon is) baked.
func want(key: StringName) -> void:
	if player.playing or seconds - last_played < MIN_GAP:
		return
	if not is_moment():
		return
	_pending = key
	_pending_until = seconds + PENDING_FOR
	bank.request(key, true)
	_try(key)


## Nothing close enough to be a fight, and no weather loud enough to drown it.
func is_moment() -> bool:
	if is_inside_tree():
		for m: Node in get_tree().get_nodes_in_group(&"mobs"):
			var alive: Variant = m.get("alive")
			var pos: Variant = m.get("pos")
			if (not alive is bool or alive) and pos is Vector2 and (pos as Vector2).distance_to(game.player.pos) < QUIET_RADIUS:
				return false
	var here := SoundMix.dominant_country(game.world, game.player.pos)
	var w := SoundMix.weather_at(game.world.seed_value, game.clock.minutes, int(here["country"]))
	return float(w.get("strength", 0.0)) < float(DROWNING.get(w.get("kind", &"clear"), 2.0))


func _try(key: StringName) -> void:
	if player.playing or seconds - last_played < MIN_GAP or not is_moment():
		_pending = &""
		return
	var baked := bank.get_baked(key)
	if baked == null:
		return
	player.stream = baked.stream
	player.volume_db = baked.gain_db
	player.play()
	last_played = seconds
	played.append(key)
	_pending = &""


static func _crossed(before: float, now: float, at: float) -> bool:
	if before < 0.0:
		return false
	if now >= before:
		return before < at and now >= at
	# Wrapped past midnight.
	return before < at or now >= at


static func _approaching(hour: float, at: float, window: float) -> bool:
	var d := fposmod(at - hour, 24.0)
	return d > 0.0 and d < window
