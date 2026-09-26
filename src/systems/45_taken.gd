extends GameSystem
## Who the plan has carried off, and where they are being held (`src/core/taken/`,
## docs/VISION.md).
##
## It holds the record and nothing else. The raids package puts somebody on it
## when a snatcher walks out of a yard; the works package's own signal takes them
## off it when the depot goes dark or the region's keeper falls, and whoever gets
## back to a standing holding is on its books again (SETTLE.md S6, and
## docs/STORY.md on what the plan does with people it carries). Neither keeps a copy, so there is one answer
## to "is anybody still being held here" and no two halves of the game can
## disagree about it.
##
## Numbered between the keeper (44) and the settlements (46) because both of the
## packages that write to it run after: a system that is asked for is safer
## before the things that ask.

var taken := Taken.new()


func setup(g: Game) -> void:
	super.setup(g)
	SaveGame.register(&"taken", _save, _load)
	# The two acts that end the plan in a region free anybody it holds there: the
	# yard going dark, or the keeper falling. Both are their packages' own signals,
	# so nothing here has to know what a depot or a keeper is.
	Events.works_broken.connect(_on_works_broken)
	Events.sentinel_fell.connect(_on_sentinel_fell)


## A world where the plan is already holding people (`--carried=N`), so a tour or
## a shot can stand in front of the story a rescue is: it takes hours of real
## play for a raid to take somebody, and the words for it cannot be looked at
## until somebody has been taken.
##
## They are held at the first depot of the plan that has a VILLAGE in its region
## (`Works.sites`), because both halves have to exist for the story to happen: a
## yard to put dark, and somebody left who knew them. Where that yard is, and
## which village, is answered by name (`49_story.tour_place`: `yard`, `asker`),
## never by an index a tour file would have to guess.
##
## With `--holding` too, they are the staged holding's own residents, taken off
## its books the way a raid's snatcher does it, so a tour can walk one home to
## it (tours/taken_home.tour, SETTLE.md S6). Staged a frame late for that: the
## holding is stood up by 46_settlements, which starts after this.
func started() -> void:
	var want: int = game.options.carried if game.options != null else 0
	if want <= 0 or game.world == null or not taken.people.is_empty():
		return
	call_deferred(&"_stage", want)


func _stage(want: int) -> void:
	var region := -1
	var home := ""
	for w: WorksSite in Works.sites(game.world):
		for v: Dictionary in game.world.villages:
			var at: Vector2 = v.get("pos", Vector2.INF)
			if game.world.region_at(floori(at.x), floori(at.y)) == w.region:
				region = w.region
				home = str(v.get("name", ""))
				break
		if region >= 0:
			break
	if region < 0:
		push_warning("--carried: this island has no depot with a village in its region")
		return
	# Silent: it happened before the game opened, and the glass says what is
	# happening now. The line itself is proved where it is really said.
	var holdings := _holdings_system()
	if holdings != null:
		for s: Settlement in holdings.get("places"):
			while want > 0 and not s.people.is_empty():
				var who: int = s.people[0]
				holdings.call("lose_person", s, who)
				@warning_ignore("return_value_discarded")
				taken.take(who, "", s.id, s.name, region, game.clock.minutes - 600.0 if game.clock != null else 0.0)
				want -= 1
	for i in want:
		@warning_ignore("return_value_discarded")
		taken.take(-1, "", -1, home, region, game.clock.minutes - 600.0 if game.clock != null else 0.0)


## Somebody has been carried off. Called by the raids package at the moment the
## snatcher leaves, with the region whose network took them — which is the region
## the holding stands in, because a plan network IS a region
## (`Interference.network`).
func took(who: int, person_name: String, home: int, home_name: String, region: int) -> void:
	if region < 0:
		return
	var t := taken.take(who, person_name, home, home_name, region,
		game.clock.minutes if game.clock != null else 0.0)
	# Said once, here, so a raid does not have to know how to phrase it and the
	# line cannot drift from the record. The words are the story's
	# (`StoryContent.TAKEN`) and they are the only place a player is ever told
	# where the plan takes people, which is what makes a yard worth walking into.
	Events.message.emit(StoryContent.TAKEN.took % Taken.say(t))


## The yard has gone dark and whoever was in it walks out. The same act that is
## half of a chapter's DEFENDED and that quiets the region for good: one thing
## done, three things it means.
func _on_works_broken(region: int, _land: StringName) -> void:
	_free(region)


## The keeper is down: nothing is left to tell the depot anything, and nothing
## told it to keep them either.
func _on_sentinel_fell(region: int, _land: StringName, _how: StringName) -> void:
	_free(region)


func _free(region: int) -> void:
	var out := taken.free_region(region)
	if out.is_empty():
		return
	# THE WALK IS CHOSEN BEFORE ANYTHING IS SAID, and that order is the whole of
	# this comment. Said first, the freed line claimed that everybody "took the
	# road home" — while the one person this system had just stood up was plainly
	# still standing in the yard, in frame, in the same picture as the sentence.
	# A line that says the opposite of what the player can see is worse than no
	# line, because the next person believes the line.
	_start_walk(out)
	# Whoever nobody walks takes the road home by themselves (`freed`), and a
	# holding that still stands has them back on its books.
	for t in out:
		if not t.walking:
			_come_home(t, Escort.destination(_holdings(), game.world.villages, t))
	var names := PackedStringArray()
	for t in out:
		if t.walking:
			# THE TRUE HALF OF THE SAME SENTENCE. They did walk out of the yard;
			# what they have not done is take the road home, and they are standing
			# in frame not doing it. So they are still announced — suppressing the
			# line entirely was the first fix and it was worse, because coming out
			# of a yard is the thing the player just earned.
			_say(&"out", Taken.say(t))
		else:
			names.append(Taken.say(t))
	if names.is_empty():
		return
	var line: String = StoryContent.TAKEN.freed if names.size() == 1 else StoryContent.TAKEN.freed_many
	Events.message.emit(line % ", ".join(names))


# --- walking one of them home (`Escort`) ---------------------------------------

## The folk id of whoever is on the road, and which record they are.
var _led := -1
var _led_who: Taken.TakenPerson = null
## How long they have been further off than `Escort.LOSE_TILES`.
var _behind := 0.0
## Where he was last frame, to tell WALKING away from being MOVED away.
var _was := Vector2.INF


## ONE AT A TIME, and only one: a queue of people trailing a player is a parade,
## and the whole weight of this is that it is a person rather than a column.
## Everybody else freed by the same act walks home by themselves, which is what
## `freed` has always meant and what the story's existing words say about them.
func _start_walk(out: Array) -> void:
	if _led >= 0:
		return
	var folk := _folk()
	if folk == null:
		return
	for t: Taken.TakenPerson in out:
		var to := Escort.destination(_holdings(), game.world.villages, t)
		if not to.is_finite():
			continue
		var yard := _yard_of(t.region)
		if not yard.is_finite():
			continue
		var id: int = folk.call(&"lead", yard, to, Rng.hash01(t.who, t.region, 0x5c0))
		if id < 0:
			continue
		taken.walk(t, to)
		_led = id
		_led_who = t
		_behind = 0.0
		return


func _process(delta: float) -> void:
	if _led < 0 or _led_who == null or game == null or game.player == null:
		return
	var folk := _folk()
	if folk == null:
		return
	var at: Vector2 = folk.call(&"led_at", _led)
	if not at.is_finite():
		_led = -1
		_led_who = null
		return
	# A WARP IS NOT WALKING AWAY. A dev warp, a tour's `at NAME` and a realm
	# crossing all move the player further in one frame than anybody can walk in
	# one, and none of them is the player deciding to leave somebody behind —
	# read as abandonment they would lose the person in every tour that stages
	# anything, silently, which is the kind of proof this project keeps catching
	# itself making. So the walk comes along, and the diegetic rule is untouched:
	# on his own legs he can still only ever leave them.
	var him: Vector2 = game.player.pos
	var jumped := _was.is_finite() and _was.distance_to(him) > Escort.LOSE_TILES
	_was = him
	if jumped:
		folk.call(&"led_to", _led, him)
		_behind = 0.0
		return
	# A machine that gets to them takes them back, and that is a different thing
	# to be told than losing them to the cold — so the record keeps which.
	var by := _snatcher_near(at)
	if by != &"":
		_end_walk(false, at, by)
		return
	_behind = Escort.behind_after(at, him, _behind, delta)
	match Escort.read(at, _led_who.home_at, game.player.pos, _behind):
		Escort.HOME:
			_end_walk(true, at, &"")
		Escort.LOST:
			_end_walk(false, at, &"")


func _end_walk(home: bool, at: Vector2, by: StringName) -> void:
	var folk := _folk()
	if folk != null:
		folk.call(&"led_done", _led)
	if home:
		taken.arrive(_led_who)
		_come_home(_led_who, _led_who.home_at)
		_say(&"home", Taken.say(_led_who))
	else:
		taken.lose(_led_who, at, by)
		# NOT "escort failed". The state is a fact about a person, not a grade on
		# him: what is said is what happened, and he was not asked to be forgiven.
		_say(&"lost_to" if by != &"" else &"lost", Taken.say(_led_who))
	_led = -1
	_led_who = null
	_behind = 0.0


## Put them back on a holding's books (46_settlements `come_home`). A village
## door needs nothing: the village was never keeping count.
func _come_home(t: Taken.TakenPerson, at: Vector2) -> void:
	var holdings := _holdings_system()
	if holdings != null:
		@warning_ignore("return_value_discarded")
		holdings.call(&"come_home", t.home, at, t.who)


func _holdings_system() -> Object:
	for sys in game.systems:
		if sys.has_method(&"come_home") and sys.get("places") is Array:
			return sys
	return null


## `taken:home`: beside the holding the first person carried off from one was
## taken from, for a tour that walks them back to it.
func tour_place(what: String) -> Vector2:
	if what != "taken:home":
		return Vector2.INF
	var holdings := _holdings_system()
	if holdings == null:
		return Vector2.INF
	for t in taken.people:
		for s: Settlement in holdings.get("places"):
			if s.id == t.home:
				return s.centre + Vector2(2.5, 1.5)
	return Vector2.INF


## The nearest hostile machine that is close enough to take them, or &"".
func _snatcher_near(at: Vector2) -> StringName:
	for m in get_tree().get_nodes_in_group(&"mobs"):
		if not bool(m.get("alive")) or not bool(m.get("hostile")):
			continue
		if (m.get("pos") as Vector2).distance_to(at) <= Escort.SNATCH_TILES:
			return StringName(str(m.get("kind")))
	return &""


## Where the yard in that region stands: derived, never saved, the same answer
## the depot system gets (`Works.sites`).
func _yard_of(region: int) -> Vector2:
	for w: WorksSite in Works.sites(game.world):
		if w.region == region:
			return w.pos
	return Vector2.INF


## The player's holdings as `Escort.destination` wants them — keyed on the
## settlement's OWN id, because that is what the raids package files as `home`,
## and standing on whether it has a piece left up. Turned into plain data here so
## the rules stay arguable in a test with no game in it.
func _holdings() -> Array:
	var out: Array = []
	for sys in game.systems:
		var places: Variant = sys.get("places")
		if not (places is Array):
			continue
		for s: Variant in places:
			if not (s is Settlement):
				break
			out.append({"index": (s as Settlement).id, "pos": (s as Settlement).centre,
				"standing": not (s as Settlement).standing().is_empty()})
		if not out.is_empty():
			break
	return out


## Found by what it KEEPS, the way every other system here is: whoever can stand
## somebody up and walk them.
func _folk() -> Object:
	for sys in game.systems:
		if sys.has_method(&"lead") and sys.has_method(&"led_at"):
			return sys
	return null


## Say one of the taken lines. The words are the STORY's and live in
## `StoryContent.TAKEN`; this only knows WHEN each is true.
##
## It held plain fallbacks while those four keys were being written. They are
## gone: a sentence kept in two places is the shape of nearly every long-lived
## bug here, and a fallback that can never fire is the same thing standing still.
func _say(key: StringName, who: String) -> void:
	Events.message.emit(str(StoryContent.TAKEN[key]) % who)


## Whether this region is holding anybody: the question the chapter and the story
## both ask of every region they look at.
func holding(region: int) -> bool:
	return taken.holds_anyone(region)


func tour_seen(what: StringName) -> bool:
	match what:
		&"taken":
			return not taken.held().is_empty()
		&"freed":
			for t in taken.people:
				if t.freed:
					return true
			return false
		&"walking_home":
			return not taken.walking_now().is_empty()
		&"got_home":
			for t in taken.people:
				if t.arrived:
					return true
			return false
		&"lost_on_the_road":
			for t in taken.people:
				if t.lost:
					return true
			return false
	return false


func _save() -> Dictionary:
	return taken.save()


func _load(v: Variant) -> void:
	if v is Dictionary:
		taken.load_from(v)
