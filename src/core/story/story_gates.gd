class_name StoryGates
## The gates into 2029 (docs/STORY.md §6): the Seeker walks him back through his
## life in order, and each gate is a place of the 2098 story that opens onto the
## same coordinates in the Before (Realm.ERA is this coast tile for tile).
##
##   StoryGates.all(world)    every gate this world can hold: {id, pos, then, opens, open}
##   StoryGates.open(world)   the ones the story has opened by now
##
## Pure and derived, like casting: where a gate stands is the cast of its 2098
## slot, and whether it is open is a beat already landed and felt. Nothing here
## crosses anybody anywhere: the crossing is the realms system's, and so is what
## a gate looks like. The story says only where, and when.

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


## Every gate this world can hold. In the surface world a gate stands where its
## 2098 place was cast; in the era it stands where its 2029 place was, which is
## the same tile, and a gate whose place this world does not have is left out.
static func all(world: WorldData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if world == null:
		return out
	var placed := StoryPlan.cast(world)
	for g: Dictionary in GATES:
		var slot: StringName = g.then if world.realm == Realm.ERA else g.at
		if not placed.has(slot):
			continue
		out.append({"id": g.id, "pos": placed[slot].pos, "then": g.then, "opens": g.opens,
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
