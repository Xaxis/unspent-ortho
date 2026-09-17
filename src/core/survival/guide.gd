class_name Guide
## The first hour's guide, as pure rules over a running game: the one-line
## goal (what to want next) and the key hints, each with the moment it applies
## and the use that retires it. The guide system (58_guide) says them on the
## teaching channel (`Events.hint`), which is dropped rather than queued: a
## lesson is said in its moment or not at all, so 58_guide says nothing while
## the glass is hushed, and holds a lesson whose moment is "the fight is over"
## until it lifts. The slate shows `goal` standing on the HUD and the hint on
## its key row (90_ui).
##
##   goal(game) -> String                     the want now: a fire, charcoal, a haft, plate, a pick,
##                                            food, light; or the ore once there is a pick
##   hint_for(game, retired) -> Dictionary    the first hint that applies and is not retired:
##                                            {id: StringName, line: String, key: String} or {}
##   HINTS                                    id -> [line, key] for every hint
##
## Hints retire on use (58_guide marks them): walk (moved), take (took), fire
## (a fire made), make (something made at a station), carry (the carrying page
## opened), dodge (a dodge), side (a blow reached a working part), lamp (lit),
## runner/worker (said once when one is first in view).

const HINTS := {
	&"walk": ["WASD walks, Shift runs.", "wasd"],
	&"take": ["E takes what is in front of you.", "e"],
	&"fire": ["E twice on open ground lays a fire.", "e"],
	&"make": ["C makes things at the fire. Long work cooks while you go.", "c"],
	&"carry": ["I shows what you carry. Leave what you do not need.", "i"],
	&"lamp": ["Night. F lights the lamp.", "f"],
	&"dodge": ["It winds up before it strikes: K gets you out of the way.", "k"],
	&"side": ["Plate rings. Strike the side that is lit, while it is spent.", "j"],
	&"runner": ["A runner. It hunts. Its drive is at its back: let it bite past you, then strike behind.", ""],
	&"worker": ["A worker on its round. Keep out of its path and it leaves you be.", ""],
}

## Load over this share of the creel asks for the carrying page.
const CARRY_SHARE := 0.6
## Nightfall past which the lamp is asked for.
const LAMP_NIGHTFALL := 0.4
## Tiles within which a body counts as seen for its hint (the camera shows about 13 across).
const SIGHT := 13.0


static func goal(game: Game) -> String:
	var inv := game.inventory
	var now := game.clock.minutes
	if game.body.hunger_level(now) >= 2:
		return "Eat something: mussels off the rocks, or berries."
	if FightRules.nightfall(game.clock.hour()) >= LAMP_NIGHTFALL and not game.body.lamp_lit and inv.has(&"lamp"):
		return "Light the lamp against the dark."
	if inv.has(&"pick"):
		return "Take the pick to the ore in the rock."
	var fire := _fire(game)
	if fire == null:
		if Survival._makeable_build(game, &"fire").is_empty():
			return "A fire before dark: three driftwood and two stones."
		return "A fire before dark: lay it on open ground."
	var at := fire_name(game, fire)
	if not _cooking_or_has(game, &"charcoal"):
		if inv.count(&"driftwood") < 4 and inv.count(&"deadwood") < 4:
			return "Charcoal for a pick: four driftwood or dead wood, burnt at %s." % at
		return "Charcoal for a pick: set it going at %s (c)." % at
	if not inv.has(&"haft"):
		return "A haft, whittled from wood."
	if inv.count(&"scrap") == 0:
		return "Plate for a pick: turn over the tip."
	return "A pick, made at %s." % at


static func hint_for(game: Game, retired: Dictionary) -> Dictionary:
	for id: StringName in _applicable(game):
		if not retired.has(id):
			return {"id": id, "line": HINTS[id][0], "key": HINTS[id][1]}
	return {}


## The hints that fit the moment, most pressing first.
static func _applicable(game: Game) -> Array[StringName]:
	var out: Array[StringName] = []
	var sim := game.player.sim if game.player != null else null
	if sim != null:
		for m in sim.mobs:
			if not m.alive or m.removed:
				continue
			# Said as a hunter first comes on, before it is close enough to hush the page
			# (a line said in a fight waits until it is over, out of its moment).
			if m.machine and not m.indifferent() and m.roused() and Senses.chebyshev(m.pos, sim.hero.pos) > Survival.THREAT_RADIUS:
				out.append(&"dodge")
			var seen := m.pos.distance_to(sim.hero.pos) <= SIGHT
			if seen and m.first_meeting and not m.roused():
				out.append(&"runner")
			if seen and m.patrol and m.indifferent():
				out.append(&"worker")
	if FightRules.nightfall(game.clock.hour()) >= LAMP_NIGHTFALL and not game.body.lamp_lit and game.inventory.has(&"lamp"):
		out.append(&"lamp")
	if game.inventory.bulk() > game.inventory.creel() * CARRY_SHARE:
		out.append(&"carry")
	if Survival.use_target(game) != null:
		out.append(&"take")
	if _fire(game) == null and not Survival._makeable_build(game, &"fire").is_empty():
		out.append(&"fire")
	if Survival.station_near(game) != &"":
		out.append(&"make")
	out.append(&"walk")
	return out


## The fire the goal means: the nearest of the fires the player built and any
## fire within FIRE_NEAR tiles (a village's), or null.
const FIRE_NEAR := 12.0


static func _fire(game: Game) -> WorldProp:
	var best := Survival.fire_near(game, FIRE_NEAR)
	var p := game.player.pos
	for q in SurvivalState.of(game).built:
		if q.kind != PropKind.FIRE or game.world.depleted.has(q.id):
			continue
		if best == null or q.pos.distance_to(p) < best.pos.distance_to(p):
			best = q
	return best


## Where the goal sends the player, by name: "the village fire" (a fire in a
## village), "your fire" (one the player laid), else "the fire".
static func fire_name(game: Game, fire: WorldProp) -> String:
	if fire == null:
		return "a fire"
	for v in game.world.villages:
		if (v.pos as Vector2).distance_to(fire.pos) <= Survival.VILLAGE_RADIUS:
			return "the village fire"
	if SurvivalState.of(game).built.has(fire):
		return "your fire"
	return "the fire"


static func _cooking_or_has(game: Game, id: StringName) -> bool:
	if game.inventory.has(id):
		return true
	for job in Survival.cooking(game):
		if (job.makes as Dictionary).has(id):
			return true
	return false
