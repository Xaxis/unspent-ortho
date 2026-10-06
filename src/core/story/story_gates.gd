class_name StoryGates
## The gates into 2029 (docs/STORY.md): the Seeker walks him back through his
## life in order, and each gate is a place of the 2098 story that opens onto the
## same coordinates in the Before (Realm.ERA is this coast tile for tile).
##
##   StoryGates.all(world)    every gate this world can hold: {id, pos, then, opens, open}
##   StoryGates.open(world)   the ones the story has opened by now
##   StoryGates.stand_of(row) where the gate of a cast slot's row stands
##
## Pure and derived, like casting: where a gate stands is worked out with the cast
## of its 2098 slot, and whether it is open is a beat already landed and felt.
## Nothing here crosses anybody anywhere: the crossing is the realms system's, and
## so is what a gate looks like. The story says only where, and when.
##
## A GATE STANDS BESIDE ITS PLACE, NEVER IN IT (GateStand). A slot is cast at its
## place's heart, which is where the place's own mass stands, and the lab's gate
## stood in the middle of the yard's raised deck: nothing of it showed under the
## plate and nobody could walk into its reach. The spot is worked out once, with
## the surface's casting, and kept in the slot's row; the Before's twin slot is a
## copy of that row, so the gate is one spot in both years however differently
## they are dressed.

## In the order he is walked through them.
const GATES: Array[Dictionary] = [
	# The kitchen at night: open once he knows his body has no past.
	{"id": &"gate_home", "at": &"home", "then": &"then_home", "opens": &"body_new"},
	# Cairn: open once the oldest machines have taken his passwords.
	{"id": &"gate_lab", "at": &"the_yard", "then": &"then_lab", "opens": &"built_halcyon"},
	# A table facing the door: open once he knows he had two employers.
	{"id": &"gate_meet", "at": &"the_camp", "then": &"then_meet", "opens": &"was_cia"},
	# The table he died on: open once he knows what it was.
	{"id": &"gate_site", "at": &"the_black_site", "then": &"then_site", "opens": &"threshold"},
]


## Every gate this world can hold. In the surface world a gate stands beside where
## its 2098 place was cast; in the era it stands beside where its 2029 place was,
## which is the same tile and the same spot, and a gate whose place this world
## does not have is left out.
static func all(world: WorldData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if world == null:
		return out
	var placed := StoryPlan.cast(world)
	for g: Dictionary in GATES:
		var slot: StringName = g.then if world.realm == Realm.ERA else g.at
		if not placed.has(slot):
			continue
		out.append({"id": g.id, "pos": stand_of(placed[slot]), "then": g.then, "opens": g.opens,
			"open": StoryPacing.felt(g.opens)})
	return out


## The gates the story has opened: a gate waits for its revelation to be felt,
## not only landed, so the way back into his life never opens on top of the news
## that sent him there.
static func open(world: WorldData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in all(world):
		if bool(g.open):
			out.append(g)
	return out


## Where the gate of a cast slot's row stands: its `gate`, worked out with the
## casting (GateStand.of), or the place itself for a row cast without one.
static func stand_of(row: Dictionary) -> Vector2:
	return row.get("gate", row.get("pos", Vector2.INF))
