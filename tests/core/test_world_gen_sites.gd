extends TestCase
## Siting is per region (streamed worldgen, S3): the darts a region throws for a
## kind of place are its own, so what one landscape lays never moves the places
## of another. That is what lets a section be laid from the plan alone.

const SEED := 7
const SIZE := 512


static func _sites(w: WorldData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in w.landmarks:
		if bool(m.get("site", false)):
			out.append(m)
	return out


## TAKE ONE LANDSCAPE'S TIPS AWAY AND THE REST OF THE ISLAND STAYS. One stream for
## every site made each dart depend on every dart before it anywhere: a tip fewer
## in one landscape moved the circles, ruins and vents of all the others (24 of
## 26 far from the gone tips, measured). Keyed per kind and region, a place moves
## only through what it is kept apart from: a site near a gone tip, a chain of
## those, and the island's ruins, whose quota is the island's (2 to 7 of them),
## so a dart that a gone tip refused can take a ruin's place elsewhere. That is
## siting, which the plan does whole: 3 of 31 moved (measured), never the island.
func test_a_landscape_s_sites_do_not_move_another_s() -> void:
	var before := WorldGen.generate(SEED, SIZE)
	var tips_of := {}
	for m in _sites(before):
		if m.kind == &"tip":
			tips_of[int(m.country)] = int(tips_of.get(int(m.country), 0)) + 1
	var gone := -1
	for cc: int in tips_of:
		if gone < 0 or int(tips_of[cc]) > int(tips_of[gone]):
			gone = cc
	check(gone >= 0, "some landscape lays tips on seed %d" % SEED)
	if gone < 0:
		return
	var tips: Array[Vector2] = []
	for m in _sites(before):
		if m.kind == &"tip" and int(m.country) == gone:
			tips.append(m.pos)
	var def := BiomeRegistry.by_index(gone)
	var had: Variant = def.sites.get("tips")
	def.sites["tips"] = 0
	var after := WorldGen.generate(SEED, SIZE)
	def.sites["tips"] = had
	var there := {}
	for m in _sites(after):
		there["%s@%s" % [m.kind, m.pos]] = true
	var kept := 0
	var moved: Array[String] = []
	for m in _sites(before):
		if m.kind == &"tip" and int(m.country) == gone:
			continue
		var near := false
		for t in tips:
			near = near or t.distance_to(m.pos) < GenScatter.PLACES_APART * 2.0
		if near:
			continue
		if there.has("%s@%s" % [m.kind, m.pos]):
			kept += 1
		else:
			moved.append("%s@%s" % [m.kind, m.pos])
	gt(float(kept), 10.0, "enough places far from %s's %d tips to tell" % [BiomeRegistry.name_of(gone), tips.size()])
	lt(float(moved.size() * 4), float(kept) + 0.5, "at most a fifth of %d far places moved, not the island: %s" % [kept + moved.size(), ", ".join(moved.slice(0, 6))])
