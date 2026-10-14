extends GameSystem
## EARNED BRACKETS, counted (Brackets; owner, 2026-10-14). Every machine he
## brings down and every keeper he fells goes on the body's count, and so does
## every tile he runs; when a count passes the next mark the bracket is his,
## full, said on the message line in plain words with how the next is earned,
## and lit on the glass (Hud.earned). The fight reads the brackets through
## Hero.read_body, so the new maximum is in the fight the same frame.

var _health := -1
var _wind := -1
var _was_winded := false
var _said_winded := false
## Said the first time he runs out of breath, so the bar that just emptied is
## understood (FightRules.WIND_BACK).
const WINDED_LINE := "Out of breath. You walk until a stamina bracket is back. Running earns more brackets."


func setup(g: Game) -> void:
	super.setup(g)
	Events.killed.connect(_on_killed)
	Events.sentinel_fell.connect(_on_keeper_fell)


func _exit_tree() -> void:
	if Events.killed.is_connected(_on_killed):
		Events.killed.disconnect(_on_killed)
	if Events.sentinel_fell.is_connected(_on_keeper_fell):
		Events.sentinel_fell.disconnect(_on_keeper_fell)


func _on_killed(kind: StringName, _at: Vector3) -> void:
	if bool(Roster.row(kind).get("machine", false)):
		game.body.machines_down += 1
		_check()


func _on_keeper_fell(_region: int, _land: StringName, _how: StringName) -> void:
	game.body.keepers_down += 1
	_check()


func _physics_process(delta: float) -> void:
	if game == null or game.player == null or game.body == null:
		return
	var p := game.player
	var winded := p.hero != null and p.hero.winded
	if winded and not _was_winded and not _said_winded:
		_said_winded = true
		Events.message.emit(WINDED_LINE)
	_was_winded = winded
	# A run on his own feet: not swimming, not carried, not aboard anything.
	if p.ride == null and not p.swimming and p.speed > (Tuning.WALK_SPEED + Tuning.RUN_SPEED) * 0.5:
		game.body.run_tiles += p.speed * delta
		if Brackets.wind_earned(game.body.run_tiles) != _wind:
			_check()


## A bracket earned since last asked: given full, said, and lit.
func _check() -> void:
	var b := game.body
	var health := Brackets.health_earned(b.machines_down, b.keepers_down)
	var wind := Brackets.wind_earned(b.run_tiles)
	if _health < 0:
		_health = health
		_wind = wind
		return
	if health > _health:
		b.health += (health - _health) * Brackets.HEALTH_BRACKET
		var total := FightRules.HEALTH / Brackets.HEALTH_BRACKET + health
		Events.message.emit(health_line(total, Brackets.machines_to_next(b.machines_down) >= 0))
		_lit(&"health")
	if wind > _wind:
		var total := roundi(FightRules.WIND / Brackets.WIND_BRACKET) + wind
		Events.message.emit(wind_line(total, Brackets.run_to_next(b.run_tiles) >= 0.0))
		_lit(&"wind")
	_health = health
	_wind = wind


func started() -> void:
	_check()


static func health_line(total: int, more: bool) -> String:
	return "Health bracket earned: %d now.%s" % [total, " Bring down more machines to earn the next." if more else ""]


static func wind_line(total: int, more: bool) -> String:
	return "Stamina bracket earned: %d now.%s" % [total, " Keep running to earn the next." if more else ""]


func _lit(which: StringName) -> void:
	Events.sfx.emit(&"ui_slate_switch", Vector3.ZERO)
	if game.hud != null:
		game.hud.earned(which)
