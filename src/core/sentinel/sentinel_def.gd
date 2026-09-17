class_name SentinelDef
extends RefCounted
## One sentinel DESIGN: the keeper a landscape type has, and never another type's
## (docs/VISION.md §3). One design per landscape; every region of that type grows
## its own instance from it, varied by the terrain it stands in, what it guards
## and which of its phases the player gets to see.
##
## A design is one file under `src/core/sentinel/designs/`, discovered by
## `Sentinels`, and a landscape claims it by name in `BiomeDef.sentinel`. Nothing
## in the spine knows a landscape or a sentinel by name.

## The design id a landscape names in `BiomeDef.sentinel`.
var id: StringName = &""
## The landscape type it keeps (a BiomeDef id). Held to the registry by tests.
var land: StringName = &""
## What it is called while the story is unwritten, and why it is the shape it is.
var display_name := ""
var note := ""
## The roster id of its body: a row in `src/content/roster.gd` like any other
## machine, so FightSim, the senses, the disposition system and the enemy read all
## take it as what it is — a machine, only bigger.
var kind: StringName = &""
## Tiles it holds. The score reads this off the live body (CLAUDE.md, the score
## row): inside it, the landscape's motif plays.
var reach := 26.0
## Landmark kinds (GenWorks records them) it stands at, best first: a keeper keeps
## the plan's own work. With none of them in its region it stands at the centre.
var stations: Array[StringName] = []
## Prop kinds within `reach` that feed it (PropKind ids): the plan's works, which
## a player can break or rob to leave it dark (SentinelWay.STARVE).
var feeds: Array[int] = []
## Phases, in order, strongest first (`at` descending; the first is 1.0).
var phases: Array[SentinelPhase] = []
## The three ways it can be taken (docs/VISION.md §3; tests hold the count at three).
var ways: Array[SentinelWay] = []
## Its drop table's source id (src/core/loot/drops.gd) and the elite material only
## this keeper gives (src/core/loot/materials.gd).
var drops: StringName = &""
var core: StringName = &""
## What is left where it stood once it has fallen: a hulk in the land, salvageable,
## saved with the world (PropKind). -1 for nothing.
var hulk := -1


func phase_at(fraction: float) -> int:
	var best := 0
	for i in phases.size():
		if fraction <= phases[i].at:
			best = i
	return best


func phase(i: int) -> SentinelPhase:
	return phases[clampi(i, 0, phases.size() - 1)]


func way_of(kind_wanted: int) -> SentinelWay:
	for w in ways:
		if w.kind == kind_wanted:
			return w
	return null


func has_way(kind_wanted: int) -> bool:
	return way_of(kind_wanted) != null


## The way with this id (SentinelWay.id(): force founder starve spoof), as a save
## records it. Null when this design does not offer it.
func way_named(way_id: StringName) -> SentinelWay:
	for w in ways:
		if w.id() == way_id:
			return w
	return null
