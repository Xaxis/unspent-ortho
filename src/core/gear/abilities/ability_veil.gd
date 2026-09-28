class_name AbilityVeil
extends Ability
## The drip-warden's core, turned (mod_veil): it lets the drip fall. A curtain
## of water stands across the way ahead for FightSim.VEIL_MS that machines
## cannot see through (FightSim.veils): a dart that loses you leaves with its flock, a
## thrower cannot aim across it, a hunter goes to where it last saw you. Bodies,
## blows and sound pass as through air, so it hides you and never holds anything
## back.
##
## ITS COST: it falls on you. You are wet through by WET more (Body.wet), and the
## lamp you carry is put out and will not light again while the water falls
## (Body.doused_until), so in the dark it blinds you as much as them. And it is a
## relic: worn, it warms the region (G9 relic heat).

const COOLDOWN := 30.0
const CHARGES := 2
const WET := 0.3


func _init() -> void:
	id = &"veil"
	name = "veil"
	action = &"ability_veil"
	cooldown = COOLDOWN
	charges = CHARGES
	lasts = FightSim.VEIL_MS / 1000.0
	note = "1  a curtain of water"


static func _sim(ctx: AbilityCtx) -> FightSim:
	return ctx.game.player.sim if ctx.game != null and ctx.game.player != null else null


func refusal(ctx: AbilityCtx) -> StringName:
	if _sim(ctx) == null or ctx.body() == null:
		return &"nothing"
	return &""


func on_press(ctx: AbilityCtx) -> bool:
	var sim := _sim(ctx)
	sim.veil(ctx.heading())
	var b := ctx.body()
	b.wet = minf(1.0, b.wet + WET)
	b.lamp_lit = false
	# A world minute a real second (docs/DESIGN.md's clock): out while it falls.
	b.doused_until = ctx.minutes() + FightSim.VEIL_MS / 1000.0
	ctx.draw(&"veil", {"at": ctx.pos(), "dir": ctx.heading(), "seconds": FightSim.VEIL_MS / 1000.0})
	return true
