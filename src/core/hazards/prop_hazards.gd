class_name PropHazards
## What a THING presses a body with, as against the land it stands on
## (docs/LANDSCAPES.md, shared system 3: "within R adds H"). `BiomeDef.hazards`
## stays the authority for what the LAND does; a prop KIND declares here what
## standing beside one adds on top of that: a vent's breath, a fire's warmth,
## the pull of a magnet heap, the hum under a live pylon. Declared on the kind
## and never on the landscape, so a vent presses the same in the Burning, the
## slums and the sulphur jungle, and a landscape that scatters one has said all
## it needs to by scattering it.
##
## A row is `{id, reach, add, weather}`: the hazard (one of `Hazards.IDS`, held
## by tests/hazards/test_prop_hazards.gd), how many tiles out from the prop's
## centre it is felt, what it adds at the prop itself falling straight to 0 at
## `reach`, and the weather FAMILY it needs (`Weather.family`; &"" is any). A
## gated row is scaled by the weather's strength the way `_weather_shift`'s own
## terms are, so a storm just starting does not put the whole of it on.
##
## Pure data. `Hazards.felt` reads it through `Place.near_props`, which
## 52_hazards fills from the tile index (`WorldQuery.props_near`) within
## `reach_most()` of the body every half second; a depleted prop presses nothing,
## and that filter is the system's, so this table never has to know what has
## been taken.
##
## Two rules the numbers were written against.
##
## (1) A CLUSTER IS ONE SOURCE. The props' share of an id is capped at the
## largest `add` among the rows in reach, so a yard of vents presses like a vent
## and never like a furnace, and a pylon's storm row and its everyday row do not
## stack into more than the storm row says. It follows that on a still, clear
## noon the whole is never more than what the land declared plus what the
## nearest thing adds — the landscape's declaration is the base and a prop is a
## step on it, not a second landscape. (2) AN ADD ON ITS OWN STAYS UNDER FELT
## (0.25) unless the thing is the whole reason the pressure exists: a fire's
## warmth on the coast lights no gauge, while a vent in the Burning — where fumes
## are declared at 0.5 on purpose, just under BITE (CLAUDE.md, Pressures) — is
## the difference between air that is noticed and air that is not for breathing:
## 0.5 + 0.25 at the mouth of it, easing back to the land's own 0.5 three tiles
## off. That is the gauge a player reads to find out that a vent is the thing to
## walk round.

const TABLE := {
	# The Burning's vents breathe steam and ash (16_vents draws it); the slums'
	# and the sulphur jungle's are the same kind and the same air.
	PropKind.VENT: [
		{"id": &"fumes", "reach": 3.0, "add": 0.25, "weather": &""},
	],
	# A lit fire is warm to stand by. Its ANSWER to the cold is `Place.fire`
	# (52_hazards reads `Survival.fire_near` for it); this is the other half, the
	# heat itself, which on a hot land is one more thing a camp costs.
	PropKind.FIRE: [
		{"id": &"heat", "reach": 2.0, "add": 0.15, "weather": &""},
	],
	# The scrapwood's own nature (`PropKind.WILD`): the field is a land-wide
	# 0.6 and the heap is where it gathers. 0.12 takes a noon heap to 0.72,
	# biting harder, and not to HARM — a heap is a thing to step round, not a
	# thing that drains you for standing near it.
	PropKind.MAGNET_HEAP: [
		{"id": &"magnetism", "reach": 2.5, "add": 0.12, "weather": &""},
	],
	# A pylon carries the grid the machines still run (`_hour_shift` spends the
	# dead iron's field against the grid's own day). Its everyday hum is small;
	# in a storm the pylon is where the lightning goes, and the storm row is the
	# one that counts, because the cluster rule takes the larger of the two.
	PropKind.PYLON: [
		{"id": &"em", "reach": 2.0, "add": 0.15, "weather": &""},
		{"id": &"em", "reach": 4.0, "add": 0.20, "weather": &"storm"},
	],
	# `_weather_shift` already says a heap of swarf slumps when rain soaks it;
	# a slag heap is the heap, and the ground at its foot is the ground that is
	# not holding.
	PropKind.SLAG_HEAP: [
		{"id": &"collapse", "reach": 2.0, "add": 0.15, "weather": &""},
	],
	# A seal's breathing hole on the frost sea (docs/LANDSCAPES.md §2): the ice
	# round it is thin because the seal keeps it thin, and 0.2 on the land's own
	# 0.4 is a step under BITE at the rim, so a body that walks up to it for the
	# fish reads the gauge before the ice reads the body.
	PropKind.SEAL_HOLE: [
		{"id": &"collapse", "reach": 1.0, "add": 0.2, "weather": &""},
	],
}


## The rows a kind declares; empty for a kind that presses nothing.
static func near(kind: int) -> Array:
	return TABLE.get(kind, [])


## The furthest any row reaches: how far round the body the system has to look.
## Read off the table rather than written beside it, so a row cannot be added
## past the sweep's own radius and press nothing.
static func reach_most() -> float:
	var most := 0.0
	for rows: Array in TABLE.values():
		for row: Dictionary in rows:
			most = maxf(most, float(row.reach))
	return most
