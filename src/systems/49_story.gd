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
## (docs/STORY.md §13).

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
var _cast: Node = null
## The journal on the slate (UiJournalScreen): what has been found, kept.
var journal: UiJournalScreen
var _ui: Node
var _journal_down := false
## The first morning is still to be said (StoryContent.OPENING).
var _opening := false


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
	_wall_the_site()
	Events.sentinel_fell.connect(_on_sentinel_fell)
	Events.settlement_founded.connect(_on_settlement_founded)
	Events.raid_ended.connect(_on_raid_ended)


func started() -> void:
	# The journal goes on the slate here and not in setup: the ui system is loaded
	# after this one (90 after 49) and does not exist while setup runs.
	for s in game.systems:
		if s.name == "90_ui":
			_ui = s
	if _ui != null:
		journal = UiJournalScreen.new()
		_ui.call("add_app", journal)
	_stage()
	# The first morning is said on the first FRAME, not here: the slate's message
	# line is built by 90_ui, which starts after this one, and a line said into
	# the gap is a line nobody sees.
	_opening = not Story.began
	Story.began = true


## The first thing the game says, on the first morning only (StoryContent.OPENING).
## Through the message line, which holds its words until the glass is quiet, so
## it cannot arrive over a fight or under a page. A loaded game has heard it.
func _open_the_game() -> void:
	_opening = false
	for line: String in StoryContent.OPENING:
		Events.message.emit(line)


## `--read=ID` and `--talk=ID[:NODE]`: the words on the glass for a writer to look
## at, without walking to the one sign in the world that happens to carry them;
## `--beats=ID,ID`, what he already knows. Staging only — a normal start names none.
func _stage() -> void:
	var o := game.options
	if o == null:
		return
	# `--beats`: a story that happened long ago, so whoever waits on it is there.
	for b: String in o.beats.split(",", false):
		if StoryContent.BEATS.has(StringName(b)):
			Story.beat(StringName(b), -INF)
		else:
			push_warning("--beats: %s is not a beat" % b)
	if o.read != "" and StoryContent.FRAGMENTS.has(StringName(o.read)):
		open_reading(StringName(o.read), false)
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


## A fragment's words on the glass, as if read off the thing that holds them: for
## a writer (`--read`, dev mode's words page). `found` marks it read, which a
## writer looking at a page usually does not want.
func open_reading(id: StringName, found: bool) -> void:
	if not StoryContent.FRAGMENTS.has(id):
		return
	reading = id
	view.reading = StoryFragments.lines(id)
	view.reading_title = StoryFragments.title_of(id)
	game.talking = true
	_hush(true)
	if found:
		@warning_ignore("return_value_discarded")
		Story.read(id)
	view.refresh()


func _exit_tree() -> void:
	if Events.took.is_connected(_on_took):
		Events.took.disconnect(_on_took)
	if Events.works_broken.is_connected(_on_works_broken):
		Events.works_broken.disconnect(_on_works_broken)
	if Events.sentinel_fell.is_connected(_on_sentinel_fell):
		Events.sentinel_fell.disconnect(_on_sentinel_fell)
	if Events.settlement_founded.is_connected(_on_settlement_founded):
		Events.settlement_founded.disconnect(_on_settlement_founded)
	if Events.raid_ended.is_connected(_on_raid_ended):
		Events.raid_ended.disconnect(_on_raid_ended)


## The journal's key, read as 46_settlements reads the holding's: it opens the
## journal over the world and closes it again. It never opens over a conversation
## or another app, whose keys it would take.
func _read_journal_key() -> void:
	var now := InputMap.has_action(&"journal") and Input.is_action_pressed(&"journal")
	var pressed := (now and not _journal_down) or (InputMap.has_action(&"journal") and Input.is_action_just_pressed(&"journal"))
	_journal_down = now
	if not pressed or journal == null or _ui == null:
		return
	if journal.is_open:
		@warning_ignore("return_value_discarded")
		journal.handle(&"journal")
	elif not game.input_blocked():
		@warning_ignore("return_value_discarded")
		_ui.call("open_screen", &"journal")


func _process(delta: float) -> void:
	if _opening:
		_open_the_game()
	if game != null and game.clock != null:
		Story.now = game.clock.minutes
	if game == null or game.player == null:
		return
	_read_journal_key()
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
	if use_pressed and not _use_already_spent():
		_open_what_is_in_front()


## A system numbered before this one may have already spent this press. A shaft
## does: it takes the key AND moves the player, so without this the press that
## carried somebody underground also read the first thing at the bottom of the
## ladder. It is asked rather than known, so a new thing the key can mean adds
## no line here.
func _use_already_spent() -> bool:
	for sys in game.systems:
		if sys.has_method(&"use_spent") and bool(sys.call(&"use_spent")):
			return true
	return false


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
	var id := StoryFragments.held_by(game.world, prop)
	return id == &"" or Story.knows(id)


func _edge_to(q: WorldProp) -> float:
	return q.pos.distance_to(game.player.pos) - q.solid


func _person_in_front() -> Dictionary:
	# Villagers and named people alike: the one key answers whoever is in front.
	var folk: Array = _folk_rows() + _cast_rows()
	var from: Vector2 = game.player.pos
	var ahead := Vector2.from_angle(game.player.facing)
	# THREE RANKS, and distance only ever decides inside one of them. A street of
	# thirty puts somebody between him and whoever he walked up to every second,
	# so the key answers the most SPECIFIC person in reach, exactly as `use`
	# answers the most specific thing:
	#
	#   a NAMED person of the cast, who has words nobody else in the world has;
	#   then anybody who lives here, who has their trade's words or the region's;
	#   then somebody with nothing to say, so the key is never simply dropped.
	#
	# Without the first rank a frame of the one clerk the story is about showed a
	# door-keeper reciting the region's errand, and `at cast:pell` could not put
	# him in front of anybody in a crowd (tours/locals.tour, which is the only
	# reason it was caught: `await met:pell` is what a NAMED talk records).
	var named: Dictionary = {}
	var named_d := REACH
	var best: Dictionary = {}
	var best_d := REACH
	var mute: Dictionary = {}
	var mute_d := REACH
	for row: Dictionary in folk:
		if StringName(str(row.get("state", &"out"))) == &"in":
			continue
		var at: Vector2 = row.get("pos", Vector2.INF)
		var to := at - from
		var d := to.length()
		if d < 0.01 or d > REACH:
			continue
		if d > CLOSE and ahead.dot(to / d) < AHEAD:
			continue
		if StringName(str(row.get("character", &""))) != &"":
			if d < named_d:
				named = row.duplicate()
				named["_d"] = d
				named_d = d
			continue
		if StoryProps.talk_for(row, game) == &"":
			if d < mute_d:
				mute = row.duplicate()
				mute["_d"] = d
				mute_d = d
			continue
		if d < best_d:
			best = row.duplicate()
			best["_d"] = d
			best_d = d
	if not named.is_empty():
		return named
	return best if not best.is_empty() else mute


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
	# Somebody who lives here, and this region has something to ask of him or to
	# thank him for (StorySubarc): that comes before their trade's own words.
	if StringName(str(row.get("character", &""))) == &"" and not row.has("talk"):
		var look := subarc_look()
		var asked := StorySubarc.talk(look, StorySubarc.raised(look))
		if not asked.is_empty():
			# Whoever it is, they are what their trade is: a cutter, a digger.
			var theirs := StoryProps.talk_for(row, game)
			if theirs != &"":
				asked["title"] = str(StoryContent.TALKS[theirs].get("title", asked.title))
			talk = StoryTalk.of_made(asked)
			view.talk = talk
			view.choice = 0
			game.talking = true
			_hush(true)
			Events.sfx.emit(&"ui_slate_switch", Vector3.ZERO)
			view.refresh()
			return
	var id := StoryProps.talk_for(row, game)
	var character := StringName(str(row.get("character", &"")))
	if id == &"":
		# Nobody has anything written for this one yet. Say so in the world's own
		# flat voice rather than opening an empty page.
		Events.hint.emit("They have nothing to say to you.", "no_talk")
		return
	talk = StoryTalk.start(id)
	if talk.over:
		talk = null
		return
	if character != &"":
		@warning_ignore("return_value_discarded")
		Story.meet(character)
	view.talk = talk
	view.choice = 0
	game.talking = true
	_hush(true)
	Events.sfx.emit(&"ui_slate_switch", Vector3.ZERO)
	view.refresh()


func _start_reading(prop: WorldProp) -> void:
	var id := StoryFragments.held_by(game.world, prop)
	if id == &"":
		Events.hint.emit("Nothing on it that can still be read.", "no_read")
		return
	# A thing that answers (`talk`): reading it is being spoken to.
	var answers := StringName(str(StoryContent.FRAGMENTS[id].get("talk", &"")))
	if answers != &"":
		@warning_ignore("return_value_discarded")
		Story.read(id)
		_start_talk({"talk": answers})
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
		# A conversation may close onto a page (`after`): the channel closes onto
		# how it ended, composed from everything he chose.
		var after := StringName(str(StoryContent.TALKS.get(talk.id, {}).get("after", &"")))
		_close()
		if after != &"":
			open_reading(after, true)
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


# --- what was done to the player (docs/STORY.md §13) -------------

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
			_witnessed(StoryContent.WITNESS_ON[&"filed"])
			_note(&"filed")
		# The signet is his own old password, copied; it only means that once he
		# knows he had one.
		if game.clock != null and game.clock.minutes < body.spoof_until and Story.landed(StoryContent.SIGNET_AFTER):
			_witnessed(StoryContent.WITNESS_ON[&"signet"])
	# Below the world or above it, not the Before: 2029 is his own past, and
	# landing a revelation on the crossing held back the one Hannah's scene is for.
	if game.world != null and game.world.realm != Realm.SURFACE and game.world.realm != Realm.ERA:
		_witnessed(StoryContent.WITNESS_ON[&"other_realm"])
	if _hunted_here():
		_witnessed(StoryContent.WITNESS_ON[&"hunted"])
	# The three memories the secret is hidden in, all back: which version he holds.
	var secret := StorySecret.version()
	if secret != &"":
		_witnessed(secret)


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
		_witnessed(StoryContent.WITNESS_ON[&"record"])


func _on_works_broken(_region: int, land: StringName) -> void:
	_witnessed(StoryContent.WITNESS_ON[&"works_dark"])
	Story.note(&"works_dark", land, Story.now)


func _on_sentinel_fell(_region: int, land: StringName, _how: StringName) -> void:
	Story.note(&"keeper_fell", land, Story.now)
	# The memory the keeper was holding comes back with it (StoryContent.KEEPER_MEMORY).
	var d := BiomeRegistry.get_def(land)
	if d != null and StoryContent.KEEPER_MEMORY.has(d.sentinel):
		_witnessed(StoryContent.KEEPER_MEMORY[d.sentinel].memory)


## A holding put up is seen from far off; so is one held, or lost.
func _on_settlement_founded(_id: int) -> void:
	_note(&"founded")


func _on_raid_ended(_id: int, outcome: StringName) -> void:
	if outcome == &"held":
		_note(&"raid_held")
	elif outcome == &"razed":
		_note(&"razed")


## Going below is seen: a shaft is a place people watch.
func realm_changed(_from: StringName, to: StringName) -> void:
	if to == Realm.UNDERGROUND:
		_note(&"went_below")
	_wall_the_site()


## The THRESHOLD platform is a wall in the water (`BlackSite.blocks`), handed over
## the way a landmark's tower and a depot's deck are: a prop's own `solid` is one
## circle and a deck is square, and nothing out there may be TAKEN, heard or
## sheltered under. Re-handed on every crossing, because `set_blocks` replaces an
## owner's set whole and the era's sea is not this one's.
func _wall_the_site() -> void:
	if game == null or game.query == null or game.world == null:
		return
	var walls: Array[Vector3] = []
	for b: Vector3 in BlackSite.blocks(game.world):
		walls.append(b)
	game.query.set_blocks(&"black_site", walls)


## Something the world saw him do, where he is standing (StoryLedger).
func _note(act: StringName) -> void:
	if game.world == null or game.player == null:
		return
	var d := BiomeRegistry.at(game.world, game.player.pos)
	Story.note(act, d.id if d != null else &"", Story.now)


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

## The named people 49_cast has stood in the world (StoryCast).
func _cast_rows() -> Array:
	if _cast == null or not is_instance_valid(_cast):
		for sys in game.systems:
			var script := sys.get_script() as Script
			if script != null and script.resource_path.ends_with("49_cast.gd"):
				_cast = sys
				break
	return _cast.get("people") if _cast != null else []


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


## Where a tour stands to reach a story place by name (98_tour's `at KIND:NAME`):
## `gate:ID` is a gate into 2029 (StoryGates), in whichever year he is in, on the
## nearest ground a body can stand on beside it.
##
## `rescue:asker` is the village of the region the plan is holding somebody in —
## where the people who knew them live, and so where a rescue is asked for and
## thanked for; `rescue:yard`, `rescue:yard_breaker` and `rescue:yard_coolant`
## are that region's depot and its housings. Both sides of it are named by the
## RECORD rather than by an index, because `place works` is the first depot
## anywhere on the island and the plan does not take people to it out of
## politeness.
func tour_place(what: String) -> Vector2:
	if game.world == null:
		return Vector2.INF
	if what.begins_with("rescue:"):
		var which := what.substr(7)
		if which == "asker":
			return _village_of(_held_region())
		# Beside whoever of that village is nearest, close enough that the key
		# answers them whichever way he is turned. It is a second step on purpose:
		# a village is a place and is there at once, and the people in it are
		# streamed, so a tour stands at the village, lets it fill, and then stands
		# beside somebody.
		if which == "somebody":
			return _beside_folk()
		if not which.begins_with("yard"):
			return Vector2.INF
		var region := _held_region()
		for w: WorksSite in Works.sites(game.world):
			if w.region != region:
				continue
			var part := Works.PART_NAMES.find(StringName(which.trim_prefix("yard_")))
			return _beside(w.part(maxi(0, part)), [0.0, 0.8, 1.2])
		return Vector2.INF
	if not what.begins_with("gate:"):
		return Vector2.INF
	var id := StringName(what.substr(5))
	for g: Dictionary in StoryGates.all(game.world):
		if g.id == id:
			return _beside(g.pos, [0.0, 0.8, 1.2])
	return Vector2.INF


## A spot within reach of the nearest villager, inside `StoryProps.CLOSE` so the
## key answers them without the tour having to aim.
func _beside_folk() -> Vector2:
	var from: Vector2 = game.player.pos
	var best := Vector2.INF
	var best_d := INF
	for row: Dictionary in _folk_rows():
		if StringName(str(row.get("state", &"out"))) == &"in":
			continue
		var at: Vector2 = row.get("pos", Vector2.INF)
		var d := at.distance_to(from)
		if d < best_d:
			best_d = d
			best = at
	if best == Vector2.INF:
		return Vector2.INF
	return _beside(best, [0.9, 1.2, 1.4])


## Somewhere a body can stand at `at`, trying each ring out in turn; `at` itself
## when none of them is standable, because a tour that lands nowhere says so
## better than one that silently stands somewhere else.
func _beside(at: Vector2, rings: Array) -> Vector2:
	for r: float in rings:
		for i in 12:
			var p := at + Vector2.from_angle(TAU * i / 12.0) * r
			if game.query.standable(floori(p.x), floori(p.y)):
				return Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)
	return at


## Whether this region has said something of that kind to him: any goal when
## `goal` is empty, and one named goal otherwise. `tail` is "" for the asking and
## ":said" for the thanks.
func _region_heard(goal: String, tail: String) -> bool:
	var region := subarc_look().region
	if region < 0:
		return false
	for g: StringName in StorySubarc.GOALS:
		if goal != "" and String(g) != goal:
			continue
		if Story.heard(StringName("%d:%s%s" % [region, g, tail])):
			return true
	return false


## The region the plan is holding somebody in, held or since freed: a rescue is
## answered by the yard going dark, so by the time anybody thanks him for it
## there is nobody being held to look for.
func _held_region() -> int:
	var carried := _system("45_taken")
	var record: Taken = carried.get("taken") if carried != null else null
	if record == null:
		return -1
	for t: Taken.TakenPerson in record.people:
		return t.region
	return -1


## Somewhere to stand in the village of that region, if it has one.
func _village_of(region: int) -> Vector2:
	if region < 0:
		return Vector2.INF
	for v: Dictionary in game.world.villages:
		var at: Vector2 = v.get("pos", Vector2.INF)
		if game.world.region_at(floori(at.x), floori(at.y)) == region:
			return _beside(at, [1.5, 2.5, 3.5])
	return Vector2.INF


## What the region under the player looks like to the story, for the rules that
## decide what it asks of him (StorySubarc). Gathered here because the state is
## the landmarks' and the works' own, and the rules may not go looking for it.
func subarc_look() -> StorySubarcLook:
	var look := StorySubarcLook.new()
	if game.world == null:
		return look
	look.region = game.world.region_at(floori(game.player.pos.x), floori(game.player.pos.y))
	if look.region < 0:
		return look
	var d := BiomeRegistry.at(game.world, game.player.pos)
	look.land = d.id if d != null else &""
	for w: WorksSite in Works.sites(game.world):
		if w.region == look.region:
			look.works = w.pos
			look.works_name = _mark_name(w.pos)
			var works := _system("34_works")
			var st: WorksState = works.call("state", look.region) if works != null else null
			look.works_dark = st != null and st.broken()
	# Who the plan is holding at that yard (`src/core/taken/`, unspent-ortho-cb).
	# The first thing a region asks about, because a yard stops being a number the
	# moment somebody's neighbour is inside it, and the one the others wait behind.
	var carried := _system("45_taken")
	var record: Taken = carried.get("taken") if carried != null else null
	if record != null:
		for t: Taken.TakenPerson in record.held_in(look.region):
			look.held.append(Taken.say(t))
		for t: Taken.TakenPerson in record.freed_in(look.region):
			look.freed.append(Taken.say(t))
	# What the plan has lost here, which is the only thing that ends a region's
	# danger (docs/VISION.md §10, unspent-ortho-cb): the yard dark or the keeper down.
	var keepers := _system("44_sentinels")
	if keepers != null:
		for st: SentinelState in keepers.get("_states"):
			if st.region == look.region and st.fallen:
				look.keeper_down = true
	look.answered = Chapters.answered_here(game)
	var net := Interference.network(game.world, game.player.pos)
	var disposition := _system("32_disposition")
	var file: Interference = disposition.get("interference") if disposition != null else null
	look.level = file.level_name(net) if file != null else &"calm"
	var marks := _system("22_landmarks")
	var state: Variant = marks.get("state") if marks != null else null
	for l: LandmarkSite in Landmarks.sites(game.world):
		if l.region != look.region:
			continue
		var def := Landmarks.by_id(l.kind)
		look.landmarks.append({"id": l.id, "kind": l.kind,
			"name": def.display_name if def != null else String(l.kind),
			"pos": l.pos,
			"found": state != null and bool(state.call("is_found", l.id)),
			"opened": state != null and bool(state.call("is_opened", l.id))})
	return look


## What the people here call the ground a yard works: the machines' own mark on
## it, which worldgen already recorded beside the work (GenWorks).
const MARK_NAMES := {&"cut": "the cut", &"scorch": "the burn", &"quarry": "the quarry", &"bores": "the bore field"}


func _mark_name(at: Vector2) -> String:
	var best := ""
	var near := INF
	for m: Dictionary in game.world.landmarks:
		if not m.has("mark"):
			continue
		var d: float = (m.get("pos", Vector2.INF) as Vector2).distance_to(at)
		if d < near and MARK_NAMES.has(m.mark):
			near = d
			best = str(MARK_NAMES[m.mark])
	return best if best != "" else "the works"


func _system(named: String) -> Node:
	for s in game.systems:
		if s.name == named:
			return s
	return null


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
	if what.begins_with("journal:"):
		return journal != null and journal.is_open and journal.section() == StringName(what.substr(8))
	if what == &"asked":
		return not StorySubarc.raised(subarc_look()).is_empty()
	if what.begins_with("asked:"):
		var said := StorySubarc.raised(subarc_look())
		return not said.is_empty() and String(said.goal) == what.substr(6)
	# ASKED AND THANKED ARE ABOUT THE REGION, never about what it is asking NOW.
	# A question answered out of its own existence proves nothing: the moment
	# somebody thanks him the region goes back to wanting the next thing, so
	# reading the thanks off `raised()` was true for one frame and then false
	# for good — a green step that proved the opposite of its name.
	if what == &"heard_ask" or what.begins_with("heard_ask:"):
		return _region_heard(what.substr(10), "")
	if what == &"thanked" or what.begins_with("thanked:"):
		return _region_heard(what.substr(8), ":said")
	# The region under him is holding somebody. 45_taken's `taken` is the same
	# question of the whole world; this one is the one a sub-arc is raised from.
	if what == &"held_here":
		return not subarc_look().held.is_empty()

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
