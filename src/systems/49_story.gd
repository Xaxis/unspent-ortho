extends GameSystem
## The story, in play (docs/STORY.md): talking to somebody, reading a thing, and
## remembering what was found and said.
##
## Numbered before survival on purpose. `use` is one key and three things could
## answer it — a person in front of you, a sign in front of you, or the ground
## under your hands — so the one that is most specific answers first, and while a
## conversation is up `game.talking` stands every other reader down through
## `Game.input_blocked()`.
##
## Nothing here opens by itself. A line is said because the player pressed a key
## standing in front of somebody, and never because they walked onto a tile
## (docs/STORY.md §3).

## How far a person or a thing can be and still be talked to or read. Generous
## on purpose: a villager walks their own round, and a key pressed at somebody
## who has just taken a step should still reach them.
const REACH := StoryProps.REACH
## How far off straight ahead it may be, as a dot product — and anything closer
## than CLOSE counts whichever way the player happens to be turned, the way
## Survival.use_target already treats a thing you are pressed against.
const AHEAD := 0.1
const CLOSE := StoryProps.CLOSE

var view: UiTalkView
var talk: StoryTalk
## The fragment being read, or &"".
var reading: StringName = &""

var _use_down := false
var _up_down := false
var _down_down := false
var _back_down := false
var _folk: Node


func setup(g: Game) -> void:
	super.setup(g)
	name = "49_story"
	Story.forget()
	SaveGame.register(&"story", _save, _load)
	view = UiTalkView.new()
	view.name = "talk"
	view.game = g
	add_child(view)


func _process(_delta: float) -> void:
	if game == null or game.player == null:
		return
	var use_down := InputMap.has_action(&"use") and Input.is_action_pressed(&"use")
	var use_pressed := use_down and not _use_down
	_use_down = use_down
	if view.showing():
		_read_talk_keys(use_pressed)
		return
	if game.input_blocked():
		return
	if use_pressed:
		_open_what_is_in_front()


# --- starting ------------------------------------------------------------------

## Whatever is nearest and in front: a person, or a thing with something written
## on it. Not people first — standing at a notice with somebody two tiles behind
## it started a conversation with their back, which is not what the key meant.
## Nothing is offered that the player is not facing, unless they are pressed
## against it, exactly as `Survival.use_target` treats a thing at the boot.
func _open_what_is_in_front() -> void:
	var person := _person_in_front()
	var prop := _readable_in_front()
	var person_d: float = person.get("_d", INF) if not person.is_empty() else INF
	var prop_d := _edge_to(prop) if prop != null else INF
	if person_d <= prop_d and not person.is_empty():
		_start_talk(person)
	elif prop != null:
		_start_reading(prop)


func _edge_to(q: WorldProp) -> float:
	return q.pos.distance_to(game.player.pos) - q.solid


func _person_in_front() -> Dictionary:
	var folk := _folk_rows()
	var from: Vector2 = game.player.pos
	var ahead := Vector2.from_angle(game.player.facing)
	var best: Dictionary = {}
	var best_d := REACH
	for row: Dictionary in folk:
		if StringName(str(row.get("state", &"out"))) == &"in":
			continue
		var at: Vector2 = row.get("pos", Vector2.INF)
		var to := at - from
		var d := to.length()
		if d > best_d or d < 0.01:
			continue
		if d > CLOSE and ahead.dot(to / d) < AHEAD:
			continue
		best = row.duplicate()
		best["_d"] = d
		best_d = d
	return best


func _readable_in_front() -> WorldProp:
	var from: Vector2 = game.player.pos
	var ahead := Vector2.from_angle(game.player.facing)
	var best: WorldProp = null
	var best_d := REACH + 1.0
	for q: WorldProp in game.query.props_near(from, REACH + 2.0):
		if StoryProps.kind_of(q.kind) == &"":
			continue
		var to := q.pos - from
		var d := to.length() - q.solid
		if d > REACH or d > best_d:
			continue
		if d > CLOSE and to.length() > 0.01 and ahead.dot(to.normalized()) < AHEAD:
			continue
		best = q
		best_d = d
	return best


func _start_talk(row: Dictionary) -> void:
	var id := StoryProps.talk_for(row, game)
	if id == &"":
		# Nobody has anything written for this one yet. Say so in the world's own
		# flat voice rather than opening an empty page.
		Events.hint.emit("They have nothing to say to you.", "no_talk")
		return
	talk = StoryTalk.start(id)
	if talk.over:
		talk = null
		return
	view.talk = talk
	view.choice = 0
	game.talking = true
	_hush(true)
	Events.sfx.emit(&"ui_slate_switch", Vector3.ZERO)
	view.refresh()


func _start_reading(prop: WorldProp) -> void:
	var kind := StoryProps.kind_of(prop.kind)
	var id := StoryFragments.pick(kind, BiomeRegistry.at(game.world, prop.pos).id,
		game.world.seed_value, prop.id)
	if id == &"":
		Events.hint.emit("Nothing on it that can still be read.", "no_read")
		return
	reading = id
	view.reading = StoryFragments.lines(id)
	view.reading_title = StoryFragments.title_of(id)
	game.talking = true
	_hush(true)
	Story.read(id)
	Events.sfx.emit(&"ui_slate_ping", Vector3.ZERO)
	view.refresh()


# --- while it is up -------------------------------------------------------------

func _read_talk_keys(use_pressed: bool) -> void:
	var back := InputMap.has_action(&"pause") and Input.is_action_pressed(&"pause")
	var back_pressed := back and not _back_down
	_back_down = back
	if back_pressed:
		_close()
		return
	if talk == null:
		# A thing being read: any of the keys puts it down.
		if use_pressed:
			_close()
		return
	var up := InputMap.has_action(&"move_up") and Input.is_action_pressed(&"move_up")
	var down := InputMap.has_action(&"move_down") and Input.is_action_pressed(&"move_down")
	var up_pressed := up and not _up_down
	var down_pressed := down and not _down_down
	_up_down = up
	_down_down = down
	var count := talk.replies().size()
	if count > 0 and (up_pressed or down_pressed):
		view.choice = posmod(view.choice + (1 if down_pressed else -1), count)
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		view.refresh()
		return
	if not use_pressed:
		return
	if not talk.pick(view.choice):
		_close()
		return
	view.choice = 0
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
	view.refresh()


func _close() -> void:
	talk = null
	reading = &""
	view.talk = null
	view.reading = PackedStringArray()
	view.choice = 0
	game.talking = false
	_hush(false)
	Events.sfx.emit(&"ui_slate_back", Vector3.ZERO)
	view.refresh()


# --- the rest -------------------------------------------------------------------

func _folk_rows() -> Array:
	if _folk == null or not is_instance_valid(_folk):
		for s in game.systems:
			var script := s.get_script() as Script
			if script != null and script.resource_path.ends_with("35_folk.gd"):
				_folk = s
				break
	return _folk.get("folk") if _folk != null else []


func _save() -> Variant:
	return Story.save_state()


func _load(v: Variant) -> void:
	if v is Dictionary:
		Story.load_state(v)


## What a tour may await of the story.
func tour_seen(what: StringName) -> bool:
	if what == &"talking":
		return talk != null
	if what == &"reading":
		return reading != &""
	if what.begins_with("knows:"):
		return Story.knows(StringName(what.substr(6)))
	if what.begins_with("beat:"):
		return Story.landed(StringName(what.substr(5)))
	return false


## Hold the HUD's message line while somebody is talking: two sets of words at
## the bottom of the glass at once is the thing docs/ART.md §9 is most against.
## Nothing is lost — UiMessages.quiet keeps them waiting and says them after,
## which is what it already does for a fight.
func _hush(on: bool) -> void:
	if game.hud != null and game.hud.messages != null:
		game.hud.messages.quiet = on
