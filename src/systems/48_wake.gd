extends GameSystem
## THE WAKE, the first morning (ROADMAP slice 1, step 1a; docs/STORY.md "Waking
## in the surf"; owner, 2026-10-13: "start with our main character laying
## partially in the tide, washed up, and effects of him slowly coming to
## consciousness, where that one character and the game immediately start
## narrating and talking to you without the character needing to trigger it").
##
## A new game opens in the black. The record speaks into it at once (`dark`: the
## tide dragging at his legs). His eyes open on him from close by (UiWaking): a
## slit, the world swimming and drained, and shut again. A voice (`voice`): hers.
## Open again, wider; a blink; open for good while he still lies there, face
## down across the waterline of the spawn beach (WakeSpot), head up the sand and
## his legs in the sea, the surf running round them, the black site out in the
## water behind him. He stirs (`comes_to`) and gets up off the sand (the person's
## `rise`) while the view draws back to the player's own. Up (`stands`), and
## Maren, a few paces off along the water, who pulled him out, speaks first: her
## talk opens by itself. Once it is closed the view turns once to the Tether. He
## is held still only while he is down; the world's sound is muffled until his
## eyes are open; a press brings him round sooner.
##
## ONLY A PLAYER'S NEW GAME WAKES: the title's New game and dev mode's play set
## `BootOptions.wake` (`--wake` on a command line). A game booted straight into
## a world is a test, a shot or a tour standing where it means to. A LOADED GAME
## HAS WOKEN (Story.began, saved), and a start named by `--at`, `--place` or
## `--village` is staging something else: none is put in the tide. Such a first
## morning still hears the lines, all at once on the first frame.
##
## Numbered before 49_story, which reads the story after the first morning is
## marked, and 49_cast, whose Maren it stands by him once she is cast.

## THE COMING TO, on the real clock from the first frame he is seen: his eyes as
## [seconds, open, focus, light] (UiWaking), eased between. Shut, a slit that
## falls shut, wider, a blink, and open for good while he still lies there, so
## he is seen in the tide a breath before he stirs.
const EYES := [
	[0.0, 0.0, 0.0, 0.0],
	[1.3, 0.0, 0.0, 0.0],
	[1.9, 0.3, 0.0, 0.15],
	[2.3, 0.32, 0.05, 0.2],
	[2.6, 0.0, 0.05, 0.2],
	[3.0, 0.0, 0.1, 0.25],
	[3.9, 0.62, 0.4, 0.5],
	[4.3, 0.65, 0.5, 0.55],
	[4.5, 0.1, 0.5, 0.55],
	[4.7, 0.6, 0.6, 0.65],
	[5.5, 1.0, 1.0, 1.0],
]
## When the record says what: into the black, as his eyes first open (her voice),
## and as he stirs and starts to get up. `stands` comes when he is up.
const SAY_DARK := 0.3
const SAY_VOICE := 1.9
const STIR := 6.6
## A press brings him round: past HURRY_FROM, the clock jumps to HURRY_TO.
const HURRY_FROM := 1.0
const HURRY_TO := 3.9
## How close the view comes while he is down (world units of view height, under
## the player's own nearest, 09_view.CLOSE), drawn back to the player's own as
## he gets up.
const CLOSE := 6.5
## LAID IN THE TIDE: the beach stands a step above the sea (its sand at the
## tile's level, the water's sheet at Swim.WATER_Y under it) and is drawn along
## a contour the tiles do not follow (TerrainMesher), so where the sand ends is
## found on the drawn land (`WorldView.surface_height`), walking down the beach
## from where he will stand up. He lies with his hips HIPS_OUT out from it in the
## shallows, awash at HIPS_Y, his legs out behind him in the sea and his chest
## up over the lip (PersonAnim `washed`). LYING_Y is how high the pose holds the
## hips over the figure's own feet.
const HIPS_OUT := 0.3
const HIPS_Y := Swim.WATER_Y - 0.03
const LYING_Y := 0.12
const WATERLINE_REACH := 2.0
## The wake is over once he has spoken to her and the talk is closed, or is this
## far from where she waited.
const MAREN_LEAVE := 16.0
## She goes back to her own place once he is this far from where she waited:
## past what a frame from above holds, so nobody watches her jump.
const MAREN_BACK := 18.0
## THE FIRST SIGHT OF THE TETHER: this long after her talk is closed (or he is
## up, if she has nothing to say), the view turns to
## the far horizon (42_stage) and holds there, up the line to the Foundry
## (19_orbit's Tether), while the record says what is there. How far up the
## look tips, as a share of the Foundry's elevation, and how wide it opens: the
## line from its foot to its top in one frame.
const SIGHT_AFTER := 0.8
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
var _spoke := false
var _maren_home := Vector2.INF
var _sight_at := INF
var _sighted := false
var _said: Dictionary = {}
var _eyes: UiWaking = null
var _height := CameraRig.VIEW_HEIGHT
var _zoomed := false
var _press_was := true
var _lie_at := Vector2.ZERO
var _lift := 0.0


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
	_lay_in_the_tide()
	_lie()
	# Out of the sea: soaked through.
	SurvivalState.of(game).wet_until = game.clock.minutes + Condition.WET_MINUTES
	# The first frame anybody sees is his eyes shut, from close by.
	_eyes = UiWaking.new()
	game.add_child(_eyes)
	if game.camera != null:
		_height = game.camera.view_height
		game.camera.view_height = CLOSE
		_zoomed = true
		game.camera.snap_to(game.player.position)


func _process(delta: float) -> void:
	_send_maren_home()
	_hold_opening(delta)
	if not _first:
		return
	if _staged.is_empty():
		# Not in the tide: the lines, once, on the first frame (the slate's
		# message line is built by 90_ui, after this system starts).
		_first = false
		for beat: StringName in [&"dark", &"voice", &"comes_to", &"stands"]:
			_say(beat)
		return
	if _t < 0.0:
		# THE WAKE WAITS FOR THE PAGE: a new game's first frames are drawn under
		# the loading page, and a waking behind it is one nobody sees, its lines
		# said to a message line that drops what arrives while a page is up.
		_hold(STIR + PersonAnim.RISE_SECONDS)
		if not get_tree().get_nodes_in_group(&"boot_page").is_empty():
			return
		_t = 0.0
		_stand_maren()
	_t += delta
	# A fresh press, never the key still down from the title's New game.
	var pressed := Input.is_anything_pressed()
	if pressed and not _press_was and _rise_at < 0.0 and _t >= HURRY_FROM and _t < HURRY_TO:
		_t = HURRY_TO
	_press_was = pressed
	_say_at(&"dark", SAY_DARK)
	_say_at(&"voice", SAY_VOICE)
	_open_eyes()
	if _rise_at < 0.0:
		if _t >= STIR:
			_rise_at = _t
			_say(&"comes_to")
			game.player.model.play_action(&"rise", 0.0)
			_hold(PersonAnim.RISE_SECONDS)
		else:
			_hold(STIR - _t + PersonAnim.RISE_SECONDS)
	_draw_back()
	if _rise_at >= 0.0 and not _stood and _t - _rise_at >= PersonAnim.RISE_SECONDS:
		_stood = true
		_say(&"stands")
		# SHE SPEAKS FIRST: nothing for him to walk to or press.
		_spoke = _story_call(&"talk_with", &"maren")
		if not _spoke:
			_sight_at = _t + SIGHT_AFTER
	if _spoke and _sight_at == INF and not game.talking:
		_sight_at = _t + SIGHT_AFTER
	if _stood and not _sighted and _t >= _sight_at:
		_sighted = true
		_first_sight()
	var met := Story.met(&"maren") and not game.talking
	var gone := game.player.pos.distance_to(_staged.maren) > MAREN_LEAVE
	if _stood and _sighted and not _stage_looking() and (met or gone):
		_first = false


## A beat said once, the first frame the clock is past `at`.
func _say_at(beat: StringName, at: float) -> void:
	if _t >= at and not _said.has(beat):
		_say(beat)


## His eyes along EYES at `_t`, and gone once they are open for good.
func _open_eyes() -> void:
	if _eyes == null:
		return
	var k := _eyes_at(_t)
	_eyes.eyes(k[0], k[1], k[2])
	if _eyes.awake():
		_eyes.queue_free()
		_eyes = null


## [open, focus, light] at `t` along EYES, eased between its keys.
static func _eyes_at(t: float) -> Array:
	var last: Array = EYES[EYES.size() - 1]
	if t >= float(last[0]):
		return [float(last[1]), float(last[2]), float(last[3])]
	for i in range(1, EYES.size()):
		var b: Array = EYES[i]
		if t < float(b[0]):
			var a: Array = EYES[i - 1]
			var u := smoothstep(float(a[0]), float(b[0]), t)
			return [lerpf(float(a[1]), float(b[1]), u), lerpf(float(a[2]), float(b[2]), u), lerpf(float(a[3]), float(b[3]), u)]
	return [0.0, 0.0, 0.0]


## The view comes back to the player's own height as he gets up, and the zoom
## is his again once it is there (09_view asks `owns_zoom`), while he comes up
## out of the water.
func _draw_back() -> void:
	if not _zoomed or game.camera == null:
		return
	if _rise_at < 0.0:
		game.camera.view_height = CLOSE
		return
	var u := smoothstep(0.0, PersonAnim.RISE_SECONDS, _t - _rise_at)
	game.camera.view_height = lerpf(CLOSE, _height, u)
	_come_up(u)
	if u >= 1.0:
		_zoomed = false


## In the tide at the foot of the beach: the point on the drawn land where it
## ends over the sea, walking down from where he will stand, then his hips out
## in the shallows from it, held awash (`lift`). Without a drawn view (a test's
## headless world) the sand ends at the tile's seaward edge.
func _lay_in_the_tide() -> void:
	var inland := Vector2.from_angle(float(_staged.face))
	var up: Vector2 = _staged.at
	var lip := up - inland * 0.5
	if game.view != null:
		var s := 0.0
		while s < WATERLINE_REACH:
			var q := up - inland * s
			if game.view.surface_height(q) < Swim.WATER_Y + 0.02:
				lip = q
				break
			s += 0.05
	_lie_at = game.player.place(lip - inland * HIPS_OUT, float(_staged.face))
	_lift = HIPS_Y - LYING_Y - game.world.height_at(_lie_at)
	game.player.lift = _lift


## Getting up, he comes up the beach out of the water onto the sand where he
## stands (`_staged.at`), and the body comes down onto its own feet.
func _come_up(u: float) -> void:
	var to: Vector2 = _staged.at
	var at := _lie_at.lerp(to, u)
	game.player.pos = at
	if game.player.hero != null:
		game.player.hero.pos = at
	var ground := game.player.position.y - game.player.lift
	var lying := game.world.height_at(_lie_at) + _lift
	game.player.lift = lerpf(lying, game.world.height_at(to), u) - ground
	if u >= 1.0:
		game.player.lift = 0.0
		game.player.place(to, float(_staged.face))


## Washed up in the tide: the body face down as the sea left it, breathing.
func _lie() -> void:
	var model := game.player.model
	if model == null:
		return
	model.play_action(&"washed", 0.0)


## Held still while he is down: the input the body is driven by this long is none.
func _hold(seconds: float) -> void:
	game.scripted_move = Vector2.ZERO
	game.scripted_seconds = seconds


## The view's height is the wake's while it comes close and draws back.
func owns_zoom() -> bool:
	return _zoomed


## The world heard through water until his eyes are open.
func muffles() -> float:
	if not _first or _staged.is_empty():
		return 0.0
	return 1.0 if _t < 0.0 else 1.0 - float(_eyes_at(_t)[2])


func _story_call(method: StringName, arg: StringName) -> bool:
	var story := game.get_node_or_null(^"49_story")
	return story != null and bool(story.call(method, arg))


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


## While he is down in the tide the view looks down on him, even in a game that
## opens over the shoulder (41_shoulder asks): the shoulder's eye sat in the sand.
func keeps_view_down() -> bool:
	return _first and not _staged.is_empty() and not _stood


## THE WAKE HOLDS THE GLASS from the moment he is put in the tide until it is
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
	_said[beat] = true
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


## `waking`: he is down in the tide and not yet up (not `wake`, which is the
## ring's shards, 19_orbit). `wake:begun`: the page is down and his clock runs.
## `eyes:shut`: nothing yet but the black and the record. `eyes:open`: open for
## good. `woken`: he is on his feet. `wake:staged`: this game put him in the
## tide at all.
func tour_seen(what: StringName) -> bool:
	match what:
		&"waking":
			return not _staged.is_empty() and not _stood
		&"wake:begun":
			return not _staged.is_empty() and _t >= 0.0
		&"eyes:shut":
			return _eyes != null and _eyes.open <= 0.0
		&"eyes:open":
			return not _staged.is_empty() and _eyes == null and _t >= 0.0
		&"woken":
			return _stood
		&"wake:staged":
			return not _staged.is_empty()
	return false
