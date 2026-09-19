extends GameSystem
## Who the plan has carried off, and where they are being held (`src/core/taken/`,
## docs/VISION.md §9.5).
##
## It holds the record and nothing else. The raids package puts somebody on it
## when a snatcher walks out of a yard; the works package's own signal takes them
## off it when the depot goes dark. Neither keeps a copy, so there is one answer
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
	# The one act that frees anybody: the yard that was holding them going dark.
	# It is the works package's own signal, so nothing here has to know what a
	# depot is or watch for one being broken.
	Events.works_broken.connect(_on_works_broken)


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
func started() -> void:
	var want: int = game.options.carried if game.options != null else 0
	if want <= 0 or game.world == null or not taken.people.is_empty():
		return
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
	var out := taken.free_region(region)
	if out.is_empty():
		return
	var names := PackedStringArray()
	for t in out:
		names.append(Taken.say(t))
	var line: String = StoryContent.TAKEN.freed if out.size() == 1 else StoryContent.TAKEN.freed_many
	Events.message.emit(line % ", ".join(names))


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
	return false


func _save() -> Dictionary:
	return taken.save()


func _load(v: Variant) -> void:
	if v is Dictionary:
		taken.load_from(v)
