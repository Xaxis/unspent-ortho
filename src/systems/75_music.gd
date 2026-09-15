extends GameSystem
## The figure, rarely. It plays when you arrive somewhere (a country you have
## not heard it in lately, once you are properly inside it, and once on waking),
## and at dawn or dusk on some days. Never over itself and never sooner than
## MIN_GAP real seconds after the last time. Its phrase is baked ahead when a
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
	bank = SoundBank.shared()
	player = AudioStreamPlayer.new()
	player.bus = &"Music"
	add_child(player)
	_last_hour = game.clock.hour()


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
		if seconds - last >= COUNTRY_REST:
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
	_pending = key
	_pending_until = seconds + PENDING_FOR
	bank.request(key, true)
	_try(key)


func _try(key: StringName) -> void:
	if player.playing or seconds - last_played < MIN_GAP:
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
