class_name RoadHold
extends RefCounted
## Where the plan stands on the road out of a chapter (docs/VISION.md §10.3).
##
## `Chapter` says whether a place is answered and its own header says what it
## does NOT do: "whether the way on is actually held, and by what, is the
## placement package's -- diegetic only: a checkpoint with something standing at
## it, a lift with no power, a bridge down; never an invisible wall". This is
## that, for the first of those.
##
##   RoadHold.sites(world) -> Array[HoldSite]
##
## **IT HOLDS THE ROAD, NOT THE REGION.** A barrier round a landscape is a wall
## with a texture on it, and it fails twice: it cannot be walked round, so it is
## an invisible wall wearing a model, and it has to know which way you are going,
## which a thing standing in the mud does not. A checkpoint on the road knows
## nothing about your direction and blocks exactly what it is standing on. So the
## way through an unanswered chapter is one of three, and all three are real:
##
##   ANSWER IT      the plan loses the place, the machines there have nothing
##                  behind them, the boom lifts
##   BREAK IT       it has hit points and can be taken apart, loudly
##   GO ROUND       leave the road and cross the country, which costs what
##                  leaving a road always costs
##
## The chapter is the honest path and never the only one. A gate with no third
## option is a lock, and a lock in a landscape is the message saying no that
## §10.3 forbids.
##
## PURE AND DERIVED, the way `Works.sites`, `Landmarks.sites` and `BlackSite.site`
## are: a function of the world, never saved, so growing the same seed puts the
## hold on the same tile. What has been DONE to one is somebody else's state.


## A crossing worth holding, and which region's plan holds it.
class HoldSite extends RefCounted:
	## The region the barrier STANDS IN, which is the one whose plan keeps it.
	## Not a direction: the tile is in one region and that is the whole of it.
	var region := -1
	## The region the road runs on into.
	var beyond := -1
	## The tile the barrier stands on, at its centre.
	var pos := Vector2.INF
	## The road's heading here, so a barrier lies ACROSS it rather than along it.
	var along := Vector2.RIGHT


## How far along the road from the border the barrier stands. One tile back, so
## it is unambiguously IN the region that keeps it and reads as that landscape's
## own checkpoint rather than as a thing in the seam.
const BACK_FROM_BORDER := 1

## Two crossings nearer than this are one crossing: a road that wanders over a
## border and back should be held once, not three times.
const APART := 12.0


## Every road crossing in a world that a chapter holds, in the order the regions
## are in, so a fresh game and a loaded one list them the same way.
static func sites(world: WorldData) -> Array[HoldSite]:
	var out: Array[HoldSite] = []
	if world == null or world.roads.is_empty():
		return out
	for path: PackedVector2Array in world.roads:
		if path.size() < 2:
			continue
		var prev := -2
		for i in path.size():
			var p: Vector2 = path[i]
			var here := world.region_at(floori(p.x), floori(p.y))
			# Both sides have to be REAL places. A road running out over ground
			# too small to be a region (`region_at` -1) is not leaving a chapter,
			# it is crossing a spur, and holding it would stand a checkpoint in
			# the middle of nowhere.
			if prev >= 0 and here >= 0 and here != prev:
				var s := _hold_at(world, path, i, prev, here)
				if s != null and not _crowded(out, s):
					out.append(s)
			prev = here
	out.sort_custom(func(a: HoldSite, b: HoldSite) -> bool:
		if a.region != b.region:
			return a.region < b.region
		return a.pos.x + a.pos.y * 0.001 < b.pos.x + b.pos.y * 0.001)
	return out


## The barrier for the crossing at `i`, standing back inside the region being
## left. Returns null where there is no road tile to stand it on.
static func _hold_at(world: WorldData, path: PackedVector2Array, i: int, leaving: int, into: int) -> HoldSite:
	var at := -1
	for back in range(1, BACK_FROM_BORDER + 2):
		var j := i - back
		if j < 0:
			break
		var q: Vector2 = path[j]
		if world.region_at(floori(q.x), floori(q.y)) != leaving:
			break
		at = j
		if back >= BACK_FROM_BORDER:
			break
	if at < 0:
		return null
	var s := HoldSite.new()
	s.region = leaving
	s.beyond = into
	var p: Vector2 = path[at]
	s.pos = Vector2(floori(p.x) + 0.5, floori(p.y) + 0.5)
	# The heading is taken from the road either side of the barrier, so a boom
	# lies across the carriageway and not along it.
	var a: Vector2 = path[maxi(at - 1, 0)]
	var b: Vector2 = path[mini(at + 1, path.size() - 1)]
	var run := b - a
	s.along = run.normalized() if run.length() > 0.001 else Vector2.RIGHT
	return s


static func _crowded(out: Array[HoldSite], s: HoldSite) -> bool:
	for o: HoldSite in out:
		if o.pos.distance_to(s.pos) < APART:
			return true
	return false


## The holds a region keeps, which is what a chapter opens when it is answered.
static func of_region(world: WorldData, region_id: int) -> Array[HoldSite]:
	var out: Array[HoldSite] = []
	for s: HoldSite in sites(world):
		if s.region == region_id:
			out.append(s)
	return out
