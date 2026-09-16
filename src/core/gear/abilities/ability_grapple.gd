class_name AbilityGrapple
extends Ability
## A magnet line off the boots: it takes hold of something solid ahead, or of a
## ledge, and pulls the body to it over ground a walk could not climb. What it
## can reach is what the land already holds, so a player learns to read props
## and lips as handholds.

const RANGE := 8.0
## How wide a cone ahead the line will look in, in radians either side.
const CONE := 0.7
## A prop is only worth hooking if it has this much body to take a line: a post,
## a sign, a mast, a wreck. Tufts and wrack have nothing to hold.
const SOLID := 0.1
const SPEED := 14.0
const COOLDOWN := 2.6
const WIND := 200.0
## Levels above the body that count as a ledge to be pulled onto.
const LEDGE_LEVELS := 2


func _init() -> void:
	id = &"grapple"
	name = "grapple"
	action = &"ability_grapple"
	cooldown = COOLDOWN
	wind = WIND
	note = "t  to a hold"


## What the line would take hold of: {pos: Vector2, height: float, what: StringName}
## or {} if nothing is in range. Pure.
static func anchor(world: WorldData, query: WorldQuery, at: Vector2, dir: Vector2) -> Dictionary:
	if world == null or dir.length() < 0.01:
		return {}
	var d := dir.normalized()
	var best: Dictionary = {}
	var best_d := INF
	if query != null:
		for p: WorldProp in query.props_near(at, RANGE):
			if p.solid < SOLID:
				continue
			var to := p.pos - at
			var away := to.length()
			if away < 1.2 or away > RANGE or absf(to.angle_to(d)) > CONE:
				continue
			if away < best_d:
				best_d = away
				best = {"pos": p.pos, "height": world.height_at(p.pos), "what": &"prop"}
	# A lip of rock in front is as good a hold as a post.
	var here := world.level_at(floori(at.x), floori(at.y))
	var travelled := 1.5
	while travelled <= RANGE:
		var q := at + d * travelled
		var tx := floori(q.x)
		var ty := floori(q.y)
		if not _inside(world, q):
			break
		var l := world.level_at(tx, ty)
		if l - here >= LEDGE_LEVELS and (query == null or query.standable(tx, ty)):
			if travelled < best_d:
				return {"pos": q, "height": world.height_at(q), "what": &"ledge"}
			break
		travelled += 0.5
	return best


static func _inside(world: WorldData, p: Vector2) -> bool:
	return p.x >= 1.0 and p.y >= 1.0 and p.x <= world.size - 2.0 and p.y <= world.size - 2.0


func refusal(ctx: AbilityCtx) -> StringName:
	var b := ctx.body()
	if b == null or ctx.game == null:
		return &"nothing"
	if b.grip > 0:
		return &"held"
	if anchor(ctx.game.world, ctx.game.query, ctx.pos(), ctx.heading()).is_empty():
		return &"no_anchor"
	return &""


func on_press(ctx: AbilityCtx) -> bool:
	var a := anchor(ctx.game.world, ctx.game.query, ctx.pos(), ctx.heading())
	if a.is_empty():
		return false
	var at := ctx.pos()
	var target: Vector2 = a.pos
	var short := 0.9 if a.what == &"prop" else 0.0
	ctx.motion = AbilityMotion.grapple(at, target, SPEED, short, ctx.game.world.height_at(at), float(a.height))
	# The mark on the anchor is held for as long as the pull runs, so the hold is
	# on screen from the press to the arrival.
	ctx.draw(&"grapple", {"at": at, "to": target, "what": a.what, "seconds": ctx.motion.seconds})
	return true
