class_name AbilityJump
extends Ability
## A person's jump (owner, 2026-09-17). Not gear: everybody has legs. It is an
## ability all the same, because an `AbilityMotion` is the one thing that may put
## a body where walking could not, and a jump onto a ledge is exactly that — so
## it rides the same door as the wing and the rope rather than opening a second.
##
## The arc is `Jump.plan`'s, planned whole at the press: this only decides
## whether the body may leave the ground now, and hands the plan over.

## Real seconds between jumps: enough that a held key does not machine-gun them,
## short enough that landing and going again reads as one movement.
const COOLDOWN := 0.12
## A jump costs breath, a share of a dodge: a way up a ledge in a fight, never a
## way of fighting.
const WIND := FightRules.DODGE_COST * 0.4


func _init() -> void:
	id = &"jump"
	name = "jump"
	action = &"jump"
	cooldown = COOLDOWN
	wind = WIND
	note = "space  up a ledge, over a gap"


func refusal(ctx: AbilityCtx) -> StringName:
	var b := ctx.body()
	if b == null or ctx.game == null or ctx.game.player == null:
		return &"nothing"
	var player := ctx.game.player
	# A raft and a sled carry the body; stepping off one is the ride key's, and a
	# jump off a deck would be how a channel is crossed without it.
	if player.ride != null:
		return &"riding"
	var hero: Hero = player.hero
	if hero != null:
		if hero.swimming:
			return &"swimming"
		if hero.airborne:
			return &"airborne"
		if hero.held():
			return &"held"
		if hero.health <= 0:
			return &"nothing"
		var now := player.sim.now if player.sim != null else 0.0
		if hero.committed(now) or hero.stunned(now):
			return &"swinging"
	if Time.get_ticks_msec() / 1000.0 < b.busy_until:
		return &"busy"
	return &""


func on_press(ctx: AbilityCtx) -> bool:
	var player := ctx.game.player
	var moving := player.intent_move.length() > 0.05
	var dir := ctx.heading()
	var pace := Tuning.RUN_SPEED if player.intent_run and moving else Tuning.WALK_SPEED
	var plan := Jump.plan(ctx.game.world, ctx.game.query, ctx.pos(), dir, Jump.speed_for(moving, pace))
	# THE SAME KEY CLIMBS (mechanics improvement 5a): at a rock face too tall for
	# the jump to land on, the press is a climb instead. One key for "get up
	# that", so there is nothing new to teach but the face itself.
	if plan.kind != Jump.UP:
		var hero: Hero = player.hero
		var c := Climb.plan(ctx.game.world, ctx.game.query, ctx.pos(), dir, hero.wind if hero != null else FightRules.WIND)
		if c != null and c.levels > Jump.UP_LEVELS:
			if hero != null:
				hero.wind = maxf(0.0, hero.wind - c.wind)
			ctx.motion = AbilityMotion.climb_face(c)
			ctx.draw(&"climb", {"plan": c, "at": ctx.pos()})
			return true
	ctx.motion = AbilityMotion.jump(plan)
	ctx.draw(&"jump", {"plan": plan, "at": ctx.pos()})
	return true
