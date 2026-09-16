extends GameSystem
## The first hour's guide: at wake, the one-line goal and the keys, then each
## hint as its moment comes, said once on the teaching channel (Events.hint,
## which is dropped rather than queued, so no lesson arrives out of its moment)
## and retired for good when the player has used it. Nothing is emitted while
## the glass is hushed, or a hint would retire without ever being read. The
## goal is said again when it changes. Lines keep a few seconds apart so each
## is read. Off in single-frame shots, so canon frames stay as they were.
##
## Retiring: walk (moved a few tiles), take (Events.took), fire (made fire),
## make (made anything else), carry (the carrying page opened), lamp (lit),
## dodge (a dodge pressed), side (a blow reached a working part), runner and
## worker (said once).
##
## Nothing is said in a fight (lines there stack under the fight's own). When a
## fight ends the goal is said again; a player who comes round after a bad end
## hears the goal once they are up, and no key hint for AFTER_DOWNED seconds.
##
## A lesson whose moment is "the fight is over" (the plate line) is held here
## until the glass will take it (Hud.can_teach): the commonest ending is a
## machine breaking off while it is still roused and still within the radius
## that hushes the slate, and a teaching line emitted into that is dropped, not
## queued. It is never retired before it has been said.

## Real seconds between two guide lines, and before the first.
const SPACING := 4.5
const FIRST_AT := 1.5
## Tiles walked that retire the walking hint.
const WALKED := 3.0
## Seconds after coming round before the goal is said again, and before any key hint.
const WAKE_DELAY := 2.2
const AFTER_DOWNED := 12.0
## The plate hint waits for the fight to be over (no text in a fight).
const SIDE_LINE := "Plate rings, and does nothing. Strike the side that is lit, while the machine is spent."
## Said on the first kill of a game, so a player who struck it down knows it is over.
const KILL_LINE := "Its light is out. It is finished."
const KILL_LINE_BEAST := "It lies still. It is finished."

var retired: Dictionary = {}
var said: Array[String] = []
var _t := 0.0
var _next := FIRST_AT
var _goal := ""
var _goal_at := -INF
var _from := Vector2.ZERO
var _rang := false
var _off := false
var _killed_one := false
var _hints_after := 0.0
## A lesson waiting for a glass that will take it (see the header).
var _lesson := ""


func setup(g: Game) -> void:
	super.setup(g)
	_off = g.options.shot != ""
	_from = g.player.pos
	Events.took.connect(_on_took)
	Events.made.connect(_on_made)
	Events.hit.connect(_on_hit)
	Events.screen_changed.connect(_on_screen)
	Events.fight_ended.connect(_on_fight_ended)
	Events.killed.connect(_on_killed)


func _exit_tree() -> void:
	for pair: Array in [[Events.took, _on_took], [Events.made, _on_made], [Events.hit, _on_hit],
			[Events.screen_changed, _on_screen], [Events.fight_ended, _on_fight_ended], [Events.killed, _on_killed]]:
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
	var sim := game.player.sim
	if sim != null and sim.fight_on:
		return
	# Nothing is said into a hushed glass. A teaching line there is dropped, not
	# queued, so a hint retired in front of a machine is a lesson lost for good:
	# the guide waits for the glass rather than spending them into it.
	if game.hud != null and not game.hud.can_teach():
		return
	if _lesson != "" and _hold_lesson():
		return
	var goal := Guide.goal(game)
	if goal != _goal and (_goal == "" or _t - _goal_at >= SPACING):
		_goal = goal
		_goal_at = _t
		_say(goal)
		return
	if _t < _hints_after:
		return
	var h := Guide.hint_for(game, retired)
	if h.is_empty():
		return
	retired[h.id] = true
	_say(String(h.line), String(h.key))


## The held lesson: dropped if the player has since learned it for themselves,
## said as soon as the glass will take it, and retired only then. True when it
## was said, so nothing else is said over it this turn.
func _hold_lesson() -> bool:
	if retired.has(&"side"):
		_lesson = ""
		return false
	retired[&"side"] = true
	_say(_lesson, "space")
	_lesson = ""
	return true


func _say(line: String, key: String = "") -> void:
	said.append(line)
	Events.hint.emit(line, key)
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


func _on_killed(kind: StringName, _at: Vector3) -> void:
	if _killed_one or _off or not bool(Roster.row(kind).get("hostile", true)):
		return
	_killed_one = true
	# Said at once, over whatever else: this is the line that says the fight is won.
	Events.message.emit(KILL_LINE if Roster.row(kind).get("machine", false) else KILL_LINE_BEAST)


func _on_fight_ended(outcome: StringName) -> void:
	if _off:
		return
	# What to want is said again once it is over: a fight is not the goal.
	_goal = ""
	# Rang off plate and never found the part: the lesson is owed, whatever way
	# the fight went. It is held until the glass will take it (see the header):
	# a machine that broke off is still near, and still hushing the slate.
	if _rang and not retired.has(&"side"):
		_lesson = SIDE_LINE
	_rang = false
	if outcome == &"downed" or outcome == &"carried":
		# Coming round: the goal when up, and no keys while the hours sink in.
		_next = _t + WAKE_DELAY
		_hints_after = _t + AFTER_DOWNED
		return
	# The fight's own last line (a kill, an escape) is read before the goal comes back.
	_next = maxf(_next, _t + WAKE_DELAY)
