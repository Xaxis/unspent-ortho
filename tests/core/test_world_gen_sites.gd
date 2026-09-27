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
## The island, and the island again with its biggest tipper's tips taken away:
## [before, after, the landscape, where its tips stood]. Grown once for the file.
static var _pair: Array = []


static func _two() -> Array:
	if not _pair.is_empty():
		return _pair
	var before := WorldGen.generate(SEED, SIZE)
	var tips_of := {}
	for m in _sites(before):
		if m.kind == &"tip":
			tips_of[int(m.country)] = int(tips_of.get(int(m.country), 0)) + 1
	var gone := -1
	for cc: int in tips_of:
		if gone < 0 or int(tips_of[cc]) > int(tips_of[gone]):
			gone = cc
	var tips: Array[Vector2] = []
	for m in _sites(before):
		if m.kind == &"tip" and int(m.country) == gone:
			tips.append(m.pos)
	var after: WorldData = null
	if gone >= 0:
		var def := BiomeRegistry.by_index(gone)
		var had: Variant = def.sites.get("tips")
		def.sites["tips"] = 0
		after = WorldGen.generate(SEED, SIZE)
		def.sites["tips"] = had
	_pair = [before, after, gone, tips]
	return _pair


static func _far(m: Dictionary, gone: int, tips: Array[Vector2]) -> bool:
	if m.kind == &"tip" and int(m.country) == gone:
		return false
	for t in tips:
		if t.distance_to(m.pos) < GenScatter.PLACES_APART * 2.0:
			return false
	return true


func test_a_landscape_s_sites_do_not_move_another_s() -> void:
	var two := _two()
	var before: WorldData = two[0]
	var after: WorldData = two[1]
	var gone: int = two[2]
	var tips: Array[Vector2] = two[3]
	check(gone >= 0, "some landscape lays tips on seed %d" % SEED)
	if gone < 0:
		return
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


## A PLACE THAT STAYS KEEPS ITS FURNITURE. One stream furnished every place in
## turn, so with a few tips fewer at the head of the list every circle, wreck and
## ruin after them was laid out again. Keyed on the place itself, a place that
## did not move stands among the same furniture: the kinds only a place lays
## (`FURNITURE`), not the scatter's or the works' round it, which draw on streams
## of their own.
func test_a_place_that_stays_keeps_what_stands_round_it() -> void:
	var two := _two()
	var before: WorldData = two[0]
	var after: WorldData = two[1]
	var gone: int = two[2]
	var tips: Array[Vector2] = two[3]
	if gone < 0:
		fail("no landscape lays tips on seed %d" % SEED)
		return
	var there := {}
	for m in _sites(after):
		there["%s@%s" % [m.kind, m.pos]] = true
	var same := 0
	var changed: Array[String] = []
	for m in _sites(before):
		if not _far(m, gone, tips) or not there.has("%s@%s" % [m.kind, m.pos]):
			continue
		if _round(before, m.pos) == _round(after, m.pos):
			same += 1
		else:
			changed.append("%s@%s" % [m.kind, m.pos])
	print("sites: %d places kept their furniture, %d changed it" % [same, changed.size()])
	gt(float(same), 10.0, "enough places stayed to tell")
	# Measured: 28 of 28 kept on the keyed streams, 1 of 28 on the shared one.
	eq(changed.size(), 0, "no place changed its furniture: %s" % ", ".join(changed.slice(0, 6)))


## What `GenScatter._landmarks` lays round a place and nothing else lays.
const FURNITURE: Array[int] = [PropKind.TIP, PropKind.WRECK, PropKind.STANDING_STONE,
	PropKind.RUIN, PropKind.VENT, PropKind.CAIRN]


static func _round(w: WorldData, at: Vector2) -> PackedStringArray:
	var out: PackedStringArray = []
	for r in w.table.size():
		var q: Vector2 = w.table.pos[r]
		if FURNITURE.has(int(w.table.kind[r])) and q.distance_to(at) <= 8.0:
			out.append("%d@%.2f,%.2f" % [w.table.kind[r], q.x, q.y])
	out.sort()
	return out
