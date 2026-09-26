extends RefCounted
## A HOME in any landscape whose houses have no room of their own (docs/interiors,
## the homes design): the cottage's plans and bones (cottage.gd), kept by one of
## the households the landscape declares (`BiomeDef.home`), in the landscape's
## own timber, cloth and clay (BiomeDressing, as every cottage already is). A
## landscape that declares none is furnished as the coast is.
##
## So every village door opens, and a house in the snowfield is a trapper's and
## one in the bonelands a bone-carver's, without a file per landscape: what is
## in the rooms is data, drawn from the one catalogue of pieces
## (src/models/interior/furnish.gd). Laid in the canonical frame: the way in is
## in the south wall (+y).

const Cottage := preload("res://src/content/interiors/cottage.gd")


static func make() -> InteriorKind:
	var k := Cottage.make()
	k.id = &"home"
	k.by_land = true
	k.recipe = load("res://src/content/interiors/home.gd")
	return k


## `land` -1 (asked with no landscape): kept as the coast's are.
static func lay(rng: RandomNumberGenerator, land: int = -1) -> InteriorLayout:
	return Cottage.lay_with(rng, households_of(land))


## Who may keep a home in `land`: its declaration, else the coast's.
static func households_of(land: int) -> Dictionary:
	var d := BiomeRegistry.by_index(land) if land >= 0 else null
	if d != null:
		var hh: Dictionary = d.home.get("households", {})
		if not hh.is_empty():
			return hh
	return Cottage.COAST
