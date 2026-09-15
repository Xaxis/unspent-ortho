extends GameSystem
## The first hour's guide: at wake, the one-line goal and the keys, then each
## hint as its moment comes, said once as a short Events.message line and
## retired for good when the player has used it (Guide has the rules). The
## goal is said again when it changes. Lines keep a few seconds apart so each
## is read. Off in single-frame shots, so canon frames stay as they were.
##
## Retiring: walk (moved a few tiles), take (Events.took), fire (made fire),
## make (made anything else), carry (the carrying page opened), lamp (lit),
## dodge (a dodge pressed), side (a blow reached a working part), runner and
## worker (said once).

## Real seconds between two guide lines, and before the first.
const SPACING := 4.5
const FIRST_AT := 1.5
## Tiles walked that retire the walking hint.
const WALKED := 3.0
## The plate hint waits for the fight to be over (no text in a fight).
const SIDE_LINE := "Plate rings, and does nothing. Strike the side that is lit, while the machine is spent."

var retired: Dictionary = {}
var said: Array[String] = []
var _t := 0.0
var _next := FIRST_AT
var _goal := ""
var _goal_at := -INF
var _from := Vector2.ZERO
var _rang := false
var _off := false


func setup(g: Game) -> void:
	super.setup(g)
	_off = g.options.shot != ""
	_from = g.player.pos
	Events.took.connect(_on_took)
	Events.made.connect(_on_made)
	Events.hit.connect(_on_hit)
	Events.screen_changed.connect(_on_screen)
	Events.fight_ended.connect(_on_fight_ended)


func _exit_tree() -> void:
	for pair: Array in [[Events.took, _on_took], [Events.made, _on_made], [Events.hit, _on_hit],
			[Events.screen_changed, _on_screen], [Events.fight_ended, _on_fight_ended]]:
		var s: Signal = pair[0]
		if s.is_connected(pair[1]):
			s.disconnect(pair[1])


func _process(delta: float) -> void:
	if game == null or _off:
		return
	_t += delta
	_watch()
	if _t < _next or game.input_blocked():
		return
	var goal := Guide.goal(game)
	if goal != _goal and (_goal == "" or _t - _goal_at >= SPACING):
		_goal = goal
		_goal_at = _t
		_say(goal)
		return
	var h := Guide.hint_for(game, retired)
	if h.is_empty():
		return
	retired[h.id] = true
	_say(String(h.line))


func _say(line: String) -> void:
	said.append(line)
	Events.message.emit(line)
	_next = _t + SPACING


## Uses that retire hints without an event of their own.
func _watch() -> void:
	if not retired.has(&"walk") and game.player.pos.distance_to(_from) >= WALKED:
		retired[&"walk"] = true
	if not retired.has(&"lamp") and game.body.lamp_lit:
		retired[&"lamp"] = true
	var sim := game.player.sim
	if sim != null and not retired.has(&"dodge") and sim.hero.dodge_at > 0.0:
		retired[&"dodge"] = true


func _on_took(_item: StringName, _n: int) -> void:
	retired[&"take"] = true


func _on_made(item: StringName, _n: int) -> void:
	retired[&"fire" if item == &"fire" else &"make"] = true


func _on_screen(n: StringName, open: bool) -> void:
	if open and n == &"inventory":
		retired[&"carry"] = true


func _on_hit(_attacker: Object, target: Object, damage: int, plate: bool, _at: Vector3) -> void:
	if target == null or target == game.player:
		return
	if plate:
		_rang = true
	elif damage > 0 and target is Mob and (target as Mob).state.machine:
		retired[&"side"] = true


func _on_fight_ended(_outcome: StringName) -> void:
	# Rang off plate and never found the part: the lesson, now the fight is over.
	if _rang and not retired.has(&"side") and not _off:
		retired[&"side"] = true
		_say(SIDE_LINE)
	_rang = false
