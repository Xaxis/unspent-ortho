class_name TargetRead
## What a body reads as when the player puts the slate on it (owner,
## 2026-09-16): its health, what it can do, what it has noticed and what it is
## doing about the player. Pure, so a test reads a body without a frame drawn.
##
##   TargetRead.of(mob, from, moment, world, query)  -> the full read
##   TargetRead.tag(mob, now)                        -> what the wordless tag shows
##
## Everything here is read off the simulation the fight already runs. Nothing
## is invented for the panel: the awareness is StealthQuery's answer (the one
## door every sense goes through), the thinking is the body's own mood, blow
## phase and disposition, and the numbers are the roster's own.

## Pips a health bar is drawn in, whatever a body's life is.
const PIPS := 5
## Suspicion at or under this is a body that has noticed nothing.
const CALM := 0.05


## What any subject reads as: a fight body in full, a person as a person.
static func of_subject(s: TargetSubject, from: Vector2, moment: Moment, world: WorldData = null, query: WorldQuery = null, now: float = 0.0) -> Dictionary:
	if s.body != null:
		return of(s.body, from, moment, world, query, now)
	if not s.place.is_empty():
		return of_place(s, from)
	return of_person(s, from)


## A PLACE: a depot, a place worth the walk. No health, no signature, nothing it
## is thinking — what a player wants off a works is what it is, how far the plan
## has got here and how many of its housings are still shut, and off a landmark
## what the place was and whether its cache has been opened.
##
## Every one of those is worked out by the system that owns the place and handed
## over in the row, so this file goes on knowing nothing about depots.
static func of_place(s: TargetSubject, from: Vector2) -> Dictionary:
	var row := s.place
	return {
		"id": s.id,
		"kind": s.kind,
		"name": s.name,
		"role": str(row.get("role", "a place")),
		"machine": bool(row.get("machine", false)),
		"person": false,
		"place": true,
		"disposition": "",
		"distance": s.here().distance_to(from),
		"health": 0,
		"max_health": 0,
		"fraction": 1.0,
		"pips": [],
		"stats": row.get("stats", []),
		"powers": PackedStringArray(),
		"awareness": {"suspicion": 0.0, "sure": false, "sees": false, "hears": false,
			"word": str(row.get("notices", "it does not look up"))},
		"thinking": str(row.get("thinking", "")),
		"open": false,
		"part": "none",
		"part_at_you": false,
	}


## A villager: no health, no working part, nothing that fights. What a player
## wants off a person is who they are and what they are doing, and the slate says
## that much and no more — a person is not a signature the stolen module reads.
static func of_person(s: TargetSubject, from: Vector2) -> Dictionary:
	var row := s.folk
	var stats: Array = []
	var village: Variant = row.get("village")
	if village != null and int(village) >= 0:
		stats.append(["village", str(int(village))])
	var tool: Variant = row.get("tool")
	if tool != null and String(tool) != "":
		stats.append(["carries", words(StringName(str(tool)))])
	return {
		"id": s.id,
		"kind": s.kind,
		"name": s.name,
		"role": "one of the last people",
		"machine": false,
		"person": true,
		"disposition": "",
		"distance": s.here().distance_to(from),
		"health": 0,
		"max_health": 0,
		"fraction": 1.0,
		"pips": [],
		"stats": stats,
		"powers": PackedStringArray(),
		"awareness": {"suspicion": 0.0, "sure": false, "sees": false, "hears": false, "word": "a person, not a machine"},
		"thinking": doing(row),
		"open": false,
		"part": "none",
		"part_at_you": false,
	}


## What a villager is doing, off their own row (35_folk): out on their round,
## walking home, or indoors.
static func doing(row: Dictionary) -> String:
	match StringName(str(row.get("state", &"out"))):
		&"home":
			return "walking home"
		&"in":
			return "indoors"
	var work: Variant = row.get("work")
	if work != null and String(work) != "":
		return "at their work"
	return "about the village"


## The whole read. `from` is the player; `moment` what the fight knows about
## the hour, the weather and what the player is doing about being noticed.
static func of(m: MobState, from: Vector2, moment: Moment, world: WorldData = null, query: WorldQuery = null, now: float = 0.0) -> Dictionary:
	var row := m.row
	return {
		"id": m.id,
		"kind": m.kind,
		"name": words(m.kind),
		"role": String(m.role),
		"machine": m.machine,
		"disposition": String(m.disposition),
		"distance": m.pos.distance_to(from),
		"health": m.health,
		"max_health": m.max_health,
		"fraction": m.health_fraction(),
		"pips": pips(m.health_fraction()),
		"stats": stats(m, from),
		"powers": powers(m),
		"awareness": awareness(m, from, moment, world, query),
		"thinking": thinking(m, now),
		# What it is FOR, in the plan's own terms (StoryContent.TESTIMONY): the
		# story's one line on this panel, and "" for anything not of the plan.
		"testimony": String(StoryContent.testimony(m.role, row).get("says", "")),
		"open": m.spent(now) or m.part_dark(now),
		"part": String(row.get("part", &"none")),
		"part_at_you": FightRules.reaches(row.get("part", &"none"), m.pos, m.facing, from),
	}


## The kind as words: "dog.feral" is a feral dog's row, and reads as one.
static func words(kind: StringName) -> String:
	return String(kind).replace(".", " ").replace("_", " ")


## A health bar of PIPS cells: how many are full, and how full the next one is.
static func pips(fraction: float) -> Array:
	var f := clampf(fraction, 0.0, 1.0)
	var whole := floori(f * PIPS)
	var part := f * PIPS - whole
	if whole >= PIPS:
		return [PIPS, 0.0]
	return [whole, part]


## The numbers a player fights by, in the order they matter in a fight.
static func stats(m: MobState, from: Vector2) -> Array:
	var row := m.row
	var out: Array = []
	var bite: Variant = row.get("bite", {})
	if bite is Dictionary and not (bite as Dictionary).is_empty():
		var b: Dictionary = bite
		out.append(["blow", "%d at %s" % [int(b.get("dmg", 1)), tiles(float(b.get("reach", 1.0)))]])
		var swing: Array = b.get("swing", [])
		if swing.size() >= 2:
			out.append(["tell", "%d ms" % int(swing[0])])
	elif int(row.get("touch", 0)) > 0:
		out.append(["touch", "%d" % int(row.get("touch", 0))])
	out.append(["speed", "%s, %s at you" % [_num(float(row.get("pace", 1.0))), _num(float(row.get("dash", row.get("pace", 1.0))))]])
	var part := String(row.get("part", &"none"))
	if part != "none" and part != "":
		out.append(["part", "%s%s" % [part, ", at you" if FightRules.reaches(row.get("part", &"none"), m.pos, m.facing, from) else ""]])
	out.append(["senses", "sees %s, hears %s" % [_num(float(row.get("sees", 0))), _num(float(row.get("hears", 0)))]])
	var nerve := int(row.get("nerve", 100))
	if nerve < 100:
		out.append(["nerve", "runs under %d%%" % nerve])
	return out


## What it can do to the player, in plain words. Only what the roster declares.
static func powers(m: MobState) -> PackedStringArray:
	var row := m.row
	var out := PackedStringArray()
	if row.has("then"):
		out.append("a second act")
	if bool(row.get("guarded", false)):
		out.append("throws blows off its front")
	if bool(row.get("through", false)):
		out.append("runs through you")
	match String(row.get("approach", &"rush")):
		"charge":
			out.append("charges in a line")
		"dart":
			out.append("comes to take and go")
		"errand":
			out.append("keeps to its round")
		"throw":
			out.append("throws down a lane")
	var hits: Dictionary = row.get("hits", {})
	if bool(hits.get("files", false)):
		out.append("files you with the plan")
	if int(hits.get("food", 0)) > 0 or int(hits.get("hurts", 0)) > 0:
		out.append("takes what you carry")
	var bite: Variant = row.get("bite", {})
	if bite is Dictionary and int((bite as Dictionary).get("grip", 0)) > 0:
		out.append("holds you")
	if float(row.get("takes", 0.0)) > 0.0:
		out.append("carries you off")
	if int(row.get("racket", 0)) > 0:
		out.append("heard %d tiles off" % int(row.get("racket", 0)))
	if bool(row.get("sight_only", false)):
		out.append("eyes only, no ears")
	if bool(row.get("stagger", false)):
		out.append("a blow staggers it")
	return out


## What it has noticed: how sure it is, and whether it can see or hear the
## player where they stand right now (StealthQuery, the one door).
static func awareness(m: MobState, from: Vector2, moment: Moment, world: WorldData, query: WorldQuery) -> Dictionary:
	var sees := false
	var hears := false
	if world != null and query != null and moment != null:
		sees = StealthQuery.sees(m.row, m.pos, from, moment, world, query, m.facing)
		hears = StealthQuery.hears(m.row, m.pos, from, moment)
	var sure := m.suspicion >= 1.0 or m.roused()
	var word := "has not noticed you"
	if sure:
		word = "sure of you"
	elif m.suspicion > CALM:
		word = "wondering"
	elif sees or hears:
		word = "about to"
	return {"suspicion": m.suspicion, "sure": sure, "sees": sees, "hears": hears, "word": word}


## What it is doing about the player, in one plain line: its mood, what its
## blow is doing, and what its place in the plan makes of them.
static func thinking(m: MobState, now: float = 0.0) -> String:
	if not m.alive:
		return "down"
	match m.mood:
		MobState.ATTACKING:
			match m.blow_phase(now):
				&"windup":
					return "winding up"
				&"active":
					return "striking"
				&"recovery", &"cooldown":
					return "spent, its part open"
			return "on you"
		MobState.CHASING:
			return "coming for you"
		MobState.FLEEING:
			return "making for home"
		MobState.ALERTED:
			if now < m.look_until:
				return "looking where the noise was"
			return "up on its feet, looking"
	if m.crowded_since >= 0.0:
		return "held up on its round"
	if m.disturbed:
		return "it took that badly"
	if m.at_work():
		if m.watchful():
			return "at its work, looking up often"
		return "at its work, not minding you"
	if m.mood == MobState.WORKING:
		return "on its round"
	return "standing"


## The wordless tag every body carries: health pips and one glyph for how much
## it has noticed (0 nothing, 1 stirring, 2 sure, 3 coming for you).
static func tag(m: MobState, now: float = 0.0) -> Dictionary:
	var notice := 0
	if m.mood == MobState.CHASING or m.mood == MobState.ATTACKING:
		notice = 3
	elif m.suspicion >= 1.0 or m.mood == MobState.ALERTED:
		notice = 2
	elif m.suspicion > CALM:
		notice = 1
	return {
		"pips": pips(m.health_fraction()),
		"notice": notice,
		"machine": m.machine,
		"hurt": m.health < m.max_health,
		"open": m.spent(now),
		"dead": not m.alive,
	}


## A distance in words: one tile is never "1 tiles".
static func tiles(n: float) -> String:
	var s := _num(n)
	return "%s tile%s" % [s, "" if s == "1" else "s"]


static func _num(f: float) -> String:
	return str(int(f)) if is_equal_approx(f, roundf(f)) else str(snappedf(f, 0.1))
