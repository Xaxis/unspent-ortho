class_name Cover
## What hides a body short of a wall: what grows where it stands, what the
## ground itself is, and the dark. 0 is standing in the open, 1 is not there.
##
## A line of sight that a house or a ridge blocks outright is Senses' work
## (`line_clear`); this is the rest of it, the heather and the gorse and the
## night, which do not stop a machine seeing you so much as shorten how far.
##
## The lamp undoes it both ways (design pillar, docs/DESIGN.md): its pool is
## the one thing on the coast that gives a body away, so a lit lamp is no cover
## at all, whatever the player is standing in.

## What a prop hides a body in, by kind, when the body is inside its skirt.
const PROPS := {
	PropKind.GORSE: 0.6,
	PropKind.BUSH: 0.5,
	PropKind.REEDS: 0.75,
	PropKind.BONES: 0.3,
	PropKind.CLINTS: 0.45,
	PropKind.PEAT_BANK: 0.5,
	PropKind.BOULDER: 0.65,
	PropKind.STANDING_STONE: 0.5,
	PropKind.WRECK: 0.6,
	PropKind.WRECKAGE: 0.55,
	PropKind.DEBRIS: 0.4,
	PropKind.VEHICLE: 0.6,
	# A car sunk in glass is still a car's worth of wall (docs/LANDSCAPES.md §3).
	PropKind.FUSED_CAR: 0.6,
	PropKind.BARRICADE: 0.55,
	PropKind.FENCE: 0.3,
	PropKind.SLAG_HEAP: 0.55,
	PropKind.STUMP: 0.3,
	PropKind.PINE: 0.35,
	PropKind.SNOW_PINE: 0.4,
	PropKind.BROADLEAF: 0.35,
	PropKind.DEAD_TREE: 0.2,
	PropKind.MEMORIAL: 0.3,
	PropKind.GRAVE: 0.25,
	# A sunken lane between two dry-stone banks: a body walking it is below the
	# banks' tops (docs/LANDSCAPES.md §1). Its `solid` is 0 -- a lane is walked
	# through -- so the skirt this counts inside is the 0.35 x scale floor below
	# plus IN_PROP, about the middle of its four units; the ends of the lane are
	# open, which is true of a lane.
	PropKind.HOLLOW_WAY: 0.45,
	# The frost sea's only cover (docs/LANDSCAPES.md §2): a slab of ice on end
	# is the one thing out there to put your back to, and a hull frozen in is a
	# wall with a hold behind it.
	PropKind.PRESSURE_BLOCK: 0.55,
	PropKind.FROZEN_HULL: 0.6,
}

## What the ground itself hides a body in: heather to the knee, reeds, deep moss.
const GROUNDS := {
	Ground.HEATH: 0.3,
	Ground.MOSS: 0.18,
	Ground.PEAT: 0.2,
	Ground.NEEDLES: 0.15,
	Ground.GRASS: 0.1,
	Ground.BLACKWATER: 0.22,
	Ground.SCREE: 0.12,
	Ground.CLINKER: 0.12,
}

## Crouched, everything counts for this much more: getting down is what puts
## the heather between you and the optics.
const CROUCH_GAIN := 2.1
## Standing up, ground cover alone is worth this share of it: heather to the
## knee hides a body lying in it, not one walking through it.
const STANDING_GROUND := 0.35
## How much of the way to full cover the darkest night is worth on its own.
const DARK_COVER := 0.55
## Within this much of a prop's own radius, the body is in it.
const IN_PROP := 0.9
## Nothing is ever perfectly hidden: a machine right on top of you finds you.
const MOST := 0.92


## Cover at a tile. `dark` 0..1 (Moment.nightfall x weather), `lamp_lit` undoes
## everything. Props come from the query; pass null for ground and dark alone.
static func at(world: WorldData, query: WorldQuery, p: Vector2, crouched: bool, dark: float, lamp_lit: bool) -> float:
	if lamp_lit:
		return 0.0
	var best := 0.0
	if world != null:
		var g := world.ground_at(floori(p.x), floori(p.y))
		best = float(GROUNDS.get(g, 0.0)) * (1.0 if crouched else STANDING_GROUND)
	if query != null:
		for prop in query.props_near(p, 1.5):
			var c: float = PROPS.get(prop.kind, 0.0)
			if c <= 0.0 or (world != null and world.depleted.has(prop.id)):
				continue
			var reach: float = maxf(prop.solid, 0.35 * prop.scale) + IN_PROP
			if p.distance_to(prop.pos) <= reach:
				best = maxf(best, c)
	if crouched:
		best = minf(MOST, best * CROUCH_GAIN)
	# Night is cover of its own, and it stacks with what the body is standing in.
	var night := clampf(dark, 0.0, 1.0) * DARK_COVER
	return clampf(minf(MOST, best + night * (1.0 - best)), 0.0, MOST)
