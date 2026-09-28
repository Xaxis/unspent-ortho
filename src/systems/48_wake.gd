extends GameSystem
## THE WAKE, the first morning (ROADMAP slice 1, step 1a; docs/STORY.md "Waking
## in the surf"): a new game starts him under the water in the shallows off the
## spawn beach (WakeSpot), the black site in the sea behind him and Maren at the
## water's edge ahead. He rises through the water line on the real clock, held
## still only while he rises, and the record says its first lines on the moments
## the staging makes (StoryContent.WAKE): `surface` as he breaks the water,
## `shallows` as he stands. Then he has his legs, and nothing waits for him to
## reach the sand.
##
## ONLY A PLAYER'S NEW GAME WAKES: the title's New game and dev mode's play set
## `BootOptions.wake` (`--wake` on a command line). A game booted straight into
## a world is a test, a shot or a tour standing where it means to. A LOADED GAME
## HAS WOKEN (Story.began, saved), and a start named by `--at`, `--place` or
## `--village` is staging something else: none is put in the surf. Such a first morning still hears the lines, all at
## once on the first frame, as the old opening was.
##
## Numbered before 49_story, which reads the story after the first morning is
## marked, and 49_cast, whose Maren it stands at the water once she is cast.

## How far under the ground he starts, and how long the rise takes.
const DEPTH := 1.7
const RISE := 1.6
## Maren goes back to her own place once he is this far from where she waited, or
## once he has spoken to her.
const MAREN_LEAVE := 16.0

var _first := false
var _staged: Dictionary = {}
var _t := -1.0
var _said_shallows := false
var _maren_home := Vector2.INF


func started() -> void:
	_first = not Story.began
	Story.began = true
	if not _first or game.player == null or game.world == null:
		return
	# Only a player's new game (the title's, `--wake`): a run booted straight
	# into a world is a test, a shot or a tour standing somewhere on purpose.
	var o := game.options
	if o == null or not o.wake or o.village >= 0 or o.at.x >= 0 or o.place != "":
		return
	_staged = WakeSpot.find(game.world)
	if _staged.is_empty():
		return
	var p: Vector2 = _staged.at
	game.player.place(p, float(_staged.face))
	game.player.sunk = DEPTH
	game.view.ensure_near(p)
	game.camera.snap_to(game.player.position)


func _process(delta: float) -> void:
	if not _first:
		return
	if _staged.is_empty():
		# Not in the surf: the lines, once, on the first frame (the slate's message
		# line is built by 90_ui, after this system starts).
		_first = false
		for beat: StringName in [&"surface", &"shallows"]:
			_say(beat)
		return
	if _t < 0.0:
		# THE RISE WAITS FOR THE PAGE: a new game's first frames are drawn under
		# the loading page, and a rise behind it is a rise nobody sees, its lines
		# said to a message line that drops what arrives while a page is up.
		if not get_tree().get_nodes_in_group(&"boot_page").is_empty():
			game.scripted_move = Vector2.ZERO
			game.scripted_seconds = RISE
			return
		_t = 0.0
		_stand_maren()
		_say(&"surface")
		# Held still while he rises: the input the body is driven by this long is none.
		game.scripted_move = Vector2.ZERO
		game.scripted_seconds = RISE
	_t += delta
	var k := clampf(_t / RISE, 0.0, 1.0)
	game.player.sunk = DEPTH * (1.0 - k) * (1.0 - k)
	if k >= 1.0 and not _said_shallows:
		_said_shallows = true
		game.player.sunk = 0.0
		_say(&"shallows")
	if _said_shallows and _maren_home != Vector2.INF:
		if Story.met(&"maren") or game.player.pos.distance_to(_staged.maren) > MAREN_LEAVE:
			var cast := _cast()
			if cast != null:
				cast.call(&"stand", &"maren", _maren_home, 0.0)
			_maren_home = Vector2.INF
	if _said_shallows and _maren_home == Vector2.INF:
		_first = false


## THE WAKE HOLDS THE GLASS from the moment he is put in the surf until it is
## over (he has met Maren, or walked off): no goal line, no key hint and no line
## but the record's over his first breath (58_guide asks, and 90_ui and the Hud
## ask the guide). The first thing to
## want is Maren's to give (ROADMAP step 2).
func holds_glass() -> bool:
	return _first and not _staged.is_empty()


## What may still be said while it holds the glass: the record's own lines, and
## nothing else (Hud keeps the rest, survival's "soaked through" among them, and
## says them once the wake is over).
func own_lines() -> Array:
	return StoryContent.WAKE[&"surface"] + StoryContent.WAKE[&"shallows"]


func _say(beat: StringName) -> void:
	for line: String in StoryContent.WAKE[beat]:
		Events.message.emit(line)


## Maren waits at the water's edge nearest him, facing him, until he has come
## to her or gone.
func _stand_maren() -> void:
	var cast := _cast()
	if cast == null:
		return
	var at: Vector2 = _staged.maren
	_maren_home = cast.call(&"stand", &"maren", at, (game.player.pos - at).angle())


func _cast() -> Node:
	for s: Node in game.systems:
		if s.name == "49_cast":
			return s
	return null


## `wake`: he is in the surf and has not yet risen. `woken`: the rise is over.
## `wake:staged`: this game put him in the surf at all.
func tour_seen(what: StringName) -> bool:
	match what:
		&"wake":
			return not _staged.is_empty() and not _said_shallows
		&"woken":
			return _said_shallows
		&"wake:staged":
			return not _staged.is_empty()
	return false
