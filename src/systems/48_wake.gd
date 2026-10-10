extends GameSystem
## THE WAKE, the first morning (ROADMAP slice 1, step 1a; docs/STORY.md "Waking
## in the surf"): a new game opens on him washed up at the tideline of the spawn
## beach (WakeSpot), face down on the sand with the sea running up to his boots,
## the black site out in the water behind him and Maren a few paces off, who
## pulled him out. He lies there, out cold, until he comes to (or the player
## presses something), then gets up off the sand on the real clock (the person's
## `rise`), held still only while he is down. The record says its first lines on
## the moments the staging makes (StoryContent.WAKE): `comes_to` as he stirs,
## `stands` as he is up. Then he has his legs, and nothing waits for him.
##
## ONLY A PLAYER'S NEW GAME WAKES: the title's New game and dev mode's play set
## `BootOptions.wake` (`--wake` on a command line). A game booted straight into
## a world is a test, a shot or a tour standing where it means to. A LOADED GAME
## HAS WOKEN (Story.began, saved), and a start named by `--at`, `--place` or
## `--village` is staging something else: none is put on the tideline. Such a
## first morning still hears the lines, all at once on the first frame.
##
## Numbered before 49_story, which reads the story after the first morning is
## marked, and 49_cast, whose Maren it stands by him once she is cast.

## How long he lies out cold before he comes to by himself, and how soon a press
## may bring him round: the opening frame is seen before anything cuts it short.
const OUT := 2.4
const OUT_LEAST := 0.8
## The wake is over once he has spoken to her and the talk is closed, or is this
## far from where she waited.
const MAREN_LEAVE := 16.0
## She goes back to her own place once he is this far from where she waited:
## past what a frame from above holds, so nobody watches her jump.
const MAREN_BACK := 18.0
## THE FIRST SIGHT OF THE TETHER: this long after he stands, the view turns to
## the far horizon (42_stage) and holds there, up the line to the Foundry
## (19_orbit's Tether), while the record says what is there. How far up the
## look tips, as a share of the Foundry's elevation, and how wide it opens: the
## line from its foot to its top in one frame.
const SIGHT_AFTER := 2.2
const SIGHT_HOLD := 3.2
const SIGHT_TIP := 0.5
## Degrees of view the look widens to, so the horizon and the Foundry (up to
## Tether.TOP_MOST, 60) are both in the one frame.
const SIGHT_FOV := 72.0

## THE OPENING HOLDS THE COAST (Coast.opening; owner, playtest 2026-10-09: no
## machine walks into the scene while he is still learning to play). From the sand
## until Maren has given him somewhere to go, or he has walked this far from where
## he woke without asking her, or OPENING_MOST seconds after he stood up.
const OPENING_LEAVE := 40.0
const OPENING_MOST := 300.0

var _first := false
var _staged: Dictionary = {}
var _coast: Coast = null
var _opening_t := -1.0
var _t := -1.0
var _rise_at := -1.0
var _stood := false
var _maren_home := Vector2.INF
var _sight_at := INF
var _sighted := false


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
	var mobs := game.get_node_or_null(^"30_mobs")
	_coast = mobs.get(&"coast") if mobs != null else null
	if _coast != null:
		_coast.opening = true
	var p: Vector2 = _staged.at
	game.player.place(p, float(_staged.face))
	game.view.ensure_near(p)
	game.camera.snap_to(game.player.position)
	_lie()
	# Out of the sea: soaked through, however dry the sand he lies on.
	SurvivalState.of(game).wet_until = game.clock.minutes + Condition.WET_MINUTES


func _process(delta: float) -> void:
	_send_maren_home()
	_hold_opening(delta)
	if not _first:
		return
	if _staged.is_empty():
		# Not on the tideline: the lines, once, on the first frame (the slate's
		# message line is built by 90_ui, after this system starts).
		_first = false
		for beat: StringName in [&"comes_to", &"stands"]:
			_say(beat)
		return
	if _t < 0.0:
		# THE WAKE WAITS FOR THE PAGE: a new game's first frames are drawn under
		# the loading page, and a waking behind it is one nobody sees, its lines
		# said to a message line that drops what arrives while a page is up.
		_hold(OUT + PersonAnim.RISE_SECONDS)
		if not get_tree().get_nodes_in_group(&"boot_page").is_empty():
			return
		_t = 0.0
		_stand_maren()
	_t += delta
	if _rise_at < 0.0:
		if _t >= OUT or (_t >= OUT_LEAST and Input.is_anything_pressed()):
			_rise_at = _t
			_say(&"comes_to")
			game.player.model.play_action(&"rise", 0.0)
			_hold(PersonAnim.RISE_SECONDS)
		else:
			_hold(OUT + PersonAnim.RISE_SECONDS)
	if _rise_at >= 0.0 and not _stood and _t - _rise_at >= PersonAnim.RISE_SECONDS:
		_stood = true
		_say(&"stands")
		_sight_at = _t + SIGHT_AFTER
	if _stood and not _sighted and _t >= _sight_at:
		_sighted = true
		_first_sight()
	var met := Story.met(&"maren") and not game.talking
	var gone := game.player.pos.distance_to(_staged.maren) > MAREN_LEAVE
	if _stood and _sighted and not _stage_looking() and (met or gone):
		_first = false


## Out cold on the sand: the body lying as a fall leaves it, breathing.
func _lie() -> void:
	var model := game.player.model
	if model == null:
		return
	model.pose_at(&"downed", 1.0)
	model.unfreeze()


## Held still while he is down: the input the body is driven by this long is none.
func _hold(seconds: float) -> void:
	game.scripted_move = Vector2.ZERO
	game.scripted_seconds = seconds


## Let the coast go once he has a reason to (see OPENING_LEAVE). Timed from the
## rise, never from the load: the page can stand over the first minute.
func _hold_opening(delta: float) -> void:
	if _coast == null or not _coast.opening:
		return
	if _t >= 0.0:
		_opening_t = maxf(_opening_t, 0.0) + delta
	var given := Story.landed(&"marens_lead")
	var walked := not _first and game.player.pos.distance_to(_staged.at) > OPENING_LEAVE
	if given or walked or _opening_t > OPENING_MOST:
		_coast.open()


## SHE GOES BACK TO HER FIRE out of his sight: once he is MAREN_BACK from where
## she waited, never while he stands talking to her (a talk marks them met as it
## opens, and she stepped off mid-sentence).
func _send_maren_home() -> void:
	if _maren_home == Vector2.INF or _staged.is_empty():
		return
	if game.player.pos.distance_to(_staged.maren) <= MAREN_BACK:
		return
	var cast := _cast()
	if cast != null:
		cast.call(&"stand", &"maren", _maren_home, 0.0)
	_maren_home = Vector2.INF


## While he is down on the sand the view looks down on him, even in a game that
## opens over the shoulder (41_shoulder asks): the shoulder's eye sat in the sand.
func keeps_view_down() -> bool:
	return _first and not _staged.is_empty() and not _stood


## THE WAKE HOLDS THE GLASS from the moment he is put on the tideline until it is
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
	var out: Array = []
	for beat: StringName in StoryContent.WAKE:
		out.append_array(StoryContent.WAKE[beat])
	return out


## The Tether, seen for the first time: the view turned to it and held, and the
## record's line. Without a stage or a far sky (`--orbit=off`) there is nothing
## to turn to, and the wake goes on without it.
func _first_sight() -> void:
	var stage := get_tree().get_first_node_in_group(&"stage")
	var orbit: Node = null
	for s: Node in game.systems:
		if s.name == "19_orbit" and bool(s.call(&"drawn")):
			orbit = s
	if stage == null or orbit == null:
		return
	var top := float(orbit.call(&"tether_top"))
	if bool(stage.call(&"look_bearing", float(orbit.call(&"tether_bearing")), top * SIGHT_TIP, SIGHT_HOLD, &"tether", SIGHT_FOV)) \
			and StoryContent.WAKE.has(&"tether"):
		_say(&"tether")


func _stage_looking() -> bool:
	var stage := get_tree().get_first_node_in_group(&"stage")
	return stage != null and bool(stage.call(&"looking"))


func _say(beat: StringName) -> void:
	for line: String in StoryContent.WAKE[beat]:
		Events.message.emit(line)


## Maren waits a few paces off along the water's edge, facing him, until he has
## come to her or gone.
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


## `waking`: he is down on the tideline and not yet up (not `wake`, which is the
## ring's shards, 19_orbit). `woken`: he is on his feet. `wake:staged`: this game
## put him on the tideline at all.
func tour_seen(what: StringName) -> bool:
	match what:
		&"waking":
			return not _staged.is_empty() and not _stood
		&"woken":
			return _stood
		&"wake:staged":
			return not _staged.is_empty()
	return false
