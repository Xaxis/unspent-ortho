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

## Seconds between looks at the player's own state (channel 4). What is watched
## changes on the scale of a fight or a crossing, never a frame.
const WITNESS_EVERY := 0.5

## What the last look saw, so a beat lands on the change and not on the state:
## being filed once is news; having been filed is not, every half second.
var _filed_seen := -1
var _witness_in := 0.0
## The machine the slate has been held on, and for how long (TESTIFY_SECONDS).
var _read_id := -1
var _read_for := 0.0
var _testified := false
var _target: Node

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
	Events.took.connect(_on_took)
	Events.works_broken.connect(_on_works_broken)


## `--read=ID` and `--talk=ID[:NODE]`: the words on the glass for a writer to look
## at, without walking to the one sign in the world that happens to carry them.
## Staging only — a normal start names neither.
func started() -> void:
	var o := game.options
	if o == null:
		return
	if o.read != "" and StoryContent.FRAGMENTS.has(StringName(o.read)):
		var id := StringName(o.read)
		reading = id
		view.reading = StoryFragments.lines(id)
		view.reading_title = StoryFragments.title_of(id)
		game.talking = true
		_hush(true)
		view.refresh()
	elif o.talk != "":
		var parts := o.talk.split(":")
		talk = StoryTalk.start(StringName(parts[0]))
		if talk.over:
			talk = null
			return
		if parts.size() > 1 and StoryContent.TALKS[talk.id].nodes.has(StringName(parts[1])):
			talk.node = StringName(parts[1])
		view.talk = talk
		view.choice = 0
		game.talking = true
		_hush(true)
		view.refresh()


func _exit_tree() -> void:
	if Events.took.is_connected(_on_took):
		Events.took.disconnect(_on_took)
	if Events.works_broken.is_connected(_on_works_broken):
		Events.works_broken.disconnect(_on_works_broken)


func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	_witness_in -= delta
	if _witness_in <= 0.0:
		_witness_in = WITNESS_EVERY
		_witness()
	_hear_testimony(delta)
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
	# THE GROUND UNDER YOUR HANDS WINS WHEN IT IS NEARER. This system's reach is
	# generous on purpose, so a notice five tiles off was outranking the driftwood
	# the player was standing on and facing: the key meant "pick this up" and the
	# game answered with a page. `use` is still most-specific-first — a person or
	# a notice you are AT beats the ground — but "in front of" is not "nearer
	# than", and only one of the three can be under your hands.
	var take := Survival.use_target(game)
	if take != null:
		var take_d := _edge_to(take)
		if take_d < person_d and take_d < prop_d:
			return
		# ONE THING THAT IS BOTH. A relay and a survey post have words on them AND
		# are the plan's works, so the same prop answers both readers at exactly
		# the same distance and the read was winning every time — which made two
		# of the six plan works impossible to rob for the rest of the game, and
		# the wick that feeds the lamp comes off a relay. So: the words the FIRST
		# time, because a thing is only read once, and the parts every time after.
		if take == prop and _already_read(prop):
			return
	if person_d <= prop_d and not person.is_empty():
		_start_talk(person)
	elif prop != null:
		_start_reading(prop)


## Whether the words on this thing have already been read. A fragment is picked
## deterministically from the prop, so asking twice asks about the same words.
func _already_read(prop: WorldProp) -> bool:
	if prop == null:
		return true
	var id := StoryFragments.pick(StoryProps.kind_of(prop.kind),
		BiomeRegistry.at(game.world, prop.pos).id, game.world.seed_value, prop.id)
	return id == &"" or Story.knows(id)


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


# --- what was done to the player (docs/STORY.md §7, channels 3 and 4) -------------

## The player's own state as evidence. Each of these is a thing that happened to
## them or that they did — never where they walked — and each lands its beat on
## the CHANGE, once (StoryContent.WITNESSED lists them in words).
func _witness() -> void:
	var body := game.body
	if body != null:
		if _filed_seen < 0:
			_filed_seen = body.filed
		elif body.filed > _filed_seen:
			_filed_seen = body.filed
			_witnessed(&"clerk_written")
		# The signet is a forged key; it only means that once the player knows a
		# key was ever forged.
		if game.clock != null and game.clock.minutes < body.spoof_until and Story.landed(&"key_accepted"):
			_witnessed(&"key_carried")
	if game.world != null and game.world.realm != Realm.SURFACE:
		_witnessed(&"branches")
	if _hunted_here():
		_witnessed(&"unattested")


func _hunted_here() -> bool:
	var d: Node = null
	for s in game.systems:
		if s.name == "32_disposition":
			d = s
	if d == null or game.world == null:
		return false
	var interference: Interference = d.get("interference")
	if interference == null:
		return false
	var net := Interference.network(game.world, game.player.pos)
	return interference.level_name(net) == &"hunted"


func _on_took(item: StringName, _count: int) -> void:
	if item == &"record":
		_witnessed(&"clerk_record")


func _on_works_broken(_region: int, _land: StringName) -> void:
	_witnessed(&"went_in_dark")


## A beat the world handed the player rather than a page they read: nothing else
## would tell them it landed, so its line is said, once, on the glass.
func _witnessed(id: StringName) -> void:
	if Story.beat(id):
		Events.message.emit(StoryContent.beat_says(id))


## Machines, by being watched: the slate held on one for TESTIFY_SECONDS lands
## what reading it tells (StoryContent.TESTIMONY). The words are on the read panel
## the whole time; the beat is the player having stopped to look.
func _hear_testimony(delta: float) -> void:
	var m := _locked_body()
	if m == null:
		_read_id = -1
		_read_for = 0.0
		return
	if m.id != _read_id:
		_read_id = m.id
		_read_for = 0.0
		_testified = false
	_read_for += delta
	if _testified or _read_for < StoryContent.TESTIFY_SECONDS:
		return
	var said := StoryContent.testimony(m.role, m.row)
	if said.is_empty():
		return
	if bool(said.get("roused", false)) and not m.roused():
		return
	_testified = true
	for b: StringName in said.get("beats", []):
		Story.beat(b)


func _locked_body() -> MobState:
	if _target == null or not is_instance_valid(_target):
		_target = null
		for s in game.systems:
			if s.name == "42_target":
				_target = s
	if _target == null:
		return null
	var locked := _target.get("locked") as TargetSubject
	if locked == null or locked.body == null or not locked.body.alive:
		return null
	return locked.body


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
	if what == &"testimony":
		var m := _locked_body()
		return m != null and not StoryContent.testimony(m.role, m.row).is_empty()
	return false


## Hold the HUD's message line while somebody is talking: two sets of words at
## the bottom of the glass at once is the thing docs/ART.md §9 is most against.
## Nothing is lost — UiMessages.quiet keeps them waiting and says them after,
## which is what it already does for a fight.
func _hush(on: bool) -> void:
	if game.hud != null and game.hud.messages != null:
		game.hud.messages.quiet = on
