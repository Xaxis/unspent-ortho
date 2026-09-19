class_name Chapter
extends RefCounted
## A REGION is a chapter, and a chapter is explored, mined and defended before the
## way on opens (owner, 2026-09-18, docs/VISION.md §10).
##
## This file is the RULES only: pure, headless, no nodes, and it INVENTS NOTHING.
## Every one of the three demands is read off state the game already keeps for its
## own reasons, which is the whole argument for the shape:
##
##   EXPLORED   the region's landmarks, against `LandmarkState.found` — the same
##              set that puts a place on the player's map for good.
##   MINED      the region's own ore props that are in `WorldData.depleted` — the
##              world edit list a save already carries. Nothing counts takings; a
##              prop that is gone is gone, and it is gone in the save.
##   DEFENDED   the region's keeper down (`SentinelState`) or its depot broken
##              (`WorksState`), either of which `44_sentinels` and `34_works`
##              already treat as the plan losing the place for good.
##
## So a chapter cannot drift from the world: there is no second counter to keep in
## step, nothing new in the save, and a player who did the work before anybody
## wrote this file has already answered the chapter. That last one is the test of
## whether a progression system is honest — if it needs its own bookkeeping, it is
## a quest log wearing a landscape's clothes.
##
## WHAT IS NOT HERE. Whether the way on is actually held, and by what, is the
## placement package's (§10.3: diegetic only — a checkpoint with something
## standing at it, a lift with no power, a bridge down; never an invisible wall).
## What a chapter SAYS is the story's. This answers one question — is this place
## answered, and what is it still asking — and nothing else.

## The share of a region's landmarks that must be FOUND. Not all of them: a
## chapter is answered by having been through the place, and one site that
## happened to land behind a cliff must not hold a landscape shut. A region with
## no landmarks at all has this demand met, which is the honest reading of "its
## landmarks are found".
const EXPLORE_SHARE := 0.67

## The share of a region's own ore that must be taken. A share and never a count,
## because a region's ore rises with its size, and a number that is right for a
## three-thousand-tile pinewood is a grind in a coast and a formality in a spur.
const MINE_SHARE := 0.25
## However big the region, never ask for more than this many, and never fewer
## than one. The ceiling is what stops a huge landscape being a mining shift; the
## floor is what stops a small one being answered by walking past a seam.
const MINE_MOST := 12
const MINE_LEAST := 3


## Which prop kinds count as this region's OWN raws: the ore its landscape
## declares. `BiomeDef.ore` is rows of [kind, chance], and a landscape that
## declares none asks nothing — which is correct for a place with nothing under
## it rather than a hole in the rule.
static func ore_kinds(world: WorldData, region_id: int) -> Array[int]:
	var out: Array[int] = []
	var def := _def_of(world, region_id)
	if def == null:
		return out
	for row: Variant in def.ore:
		var r: Array = row
		if r.size() > 0 and not out.has(int(r[0])):
			out.append(int(r[0]))
	return out


## Every site id the region holds, in `Landmarks.sites`' own order.
static func landmark_ids(world: WorldData, region_id: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: LandmarkSite in Landmarks.sites(world):
		if s.region == region_id:
			out.append(s.id)
	return out


## How many of this region's ore props stand in it at all, and how many of them
## the player has taken. Counted off `WorldData.depleted`, which is the save's own
## world-edit list, so this is the same number after a save and a load.
static func ore_standing(world: WorldData, region_id: int) -> int:
	return int(_standing_counts(world).get(region_id, 0))


## What STANDS is counted once per world, for every region at once, because
## nothing can change it: a prop never moves and worldgen never adds one, so the
## answer is a property of the world and not of the moment it is asked in. Only
## what has been TAKEN changes, and that is `ore_taken` off the small `depleted`
## set. `Landmarks.sites` remembers per world for exactly this reason.
##
## IT WAS ASKED AS THOUGH IT WERE CHEAP. The sweep this replaces walked every
## prop in the world, calling `region_at` on each, ONCE PER REGION that keeps a
## hold — and `24_holds` asks every region that keeps one, once a second. Measured
## on a 1300-tile world: 224 ms inside a single physics tick, landing as a 150 ms
## hitch every second while the median frame stayed at 8.3 ms (#126). That is the
## shape the owner called "laggy and jumpy", and an average cannot see it.
##
## Note what the earlier fix did and did not do: moving this off the per-frame
## path (#122) took the game from 5-12 fps to a healthy median with a stall once
## a second. The cost was rescheduled, not removed. **Work that is too expensive
## to do every frame is usually too expensive to do at all** — the question to ask
## is not how often to pay it, but why it is being recomputed when its inputs
## cannot have moved.
static var _standing_world: WorldData = null
static var _standing: Dictionary = {}


static func _standing_counts(world: WorldData) -> Dictionary:
	if world == null:
		return {}
	if world == _standing_world:
		return _standing
	var kinds_of := {}
	var out := {}
	for p: WorldProp in world.props:
		var r := world.region_at(floori(p.pos.x), floori(p.pos.y))
		if r < 0:
			continue
		if not kinds_of.has(r):
			kinds_of[r] = ore_kinds(world, r)
		var kinds: Array = kinds_of[r]
		if kinds.has(p.kind):
			out[r] = int(out.get(r, 0)) + 1
	# The world is held rather than keyed by instance id: an id freed and handed
	# out again would serve another world's counts, and the realms package keeps
	# every world it raises alive anyway, so this costs nothing.
	_standing_world = world
	_standing = out
	return out


## Only the tests want this; a running game counts once per world for its life.
static func forget() -> void:
	_standing_world = null
	_standing = {}


## Taken, off the depleted set — which is small, so this is cheap enough to ask
## whenever something is taken rather than every frame.
static func ore_taken(world: WorldData, region_id: int) -> int:
	var kinds := ore_kinds(world, region_id)
	if kinds.is_empty():
		return 0
	var n := 0
	for id: Variant in world.depleted:
		var i := int(id)
		if i < 0 or i >= world.props.size():
			continue
		var p: WorldProp = world.props[i]
		if kinds.has(p.kind) and world.region_at(floori(p.pos.x), floori(p.pos.y)) == region_id:
			n += 1
	return n


## How many this chapter asks for: a share of what stands there, held between the
## floor and the ceiling, and never more than there is to take.
static func ore_wanted(standing: int) -> int:
	if standing <= 0:
		return 0
	return clampi(roundi(float(standing) * MINE_SHARE), mini(MINE_LEAST, standing), mini(MINE_MOST, standing))


## Everything about one chapter, in one dictionary, for whoever is asking — the
## way on, the slate, a test, dev mode. `found` is `LandmarkState.found`;
## `keeper_down` and `yard_broken` are the two halves of DEFENDED, which the
## sentinel and works systems already answer for a region.
##
## `answered` is the only field anything should gate on. The rest is what a place
## is still asking, which somebody has to be able to say out loud.
static func read(world: WorldData, region_id: int, found: Dictionary,
		keeper_down: bool, yard_broken: bool) -> Dictionary:
	if world == null:
		return {"region": region_id, "explored": false, "seen": 0, "landmarks": 0, "want_seen": 0,
			"mined": false, "taken": 0, "ore": 0, "want_ore": 0,
			"defended": false, "keeper_down": false, "yard_broken": false, "answered": false}
	var ids := landmark_ids(world, region_id)
	var seen := 0
	for id: StringName in ids:
		if found.has(id):
			seen += 1
	# A region with no landmarks has been explored by being crossed: the demand is
	# "you have been here", and there is nothing here to have been at.
	var want_seen := ceili(float(ids.size()) * EXPLORE_SHARE)
	var explored := ids.is_empty() or seen >= want_seen
	var standing := ore_standing(world, region_id)
	var taken := ore_taken(world, region_id)
	var want_ore := ore_wanted(standing)
	var mined := want_ore <= 0 or taken >= want_ore
	var defended := keeper_down or yard_broken
	return {
		"region": region_id,
		"explored": explored, "seen": seen, "landmarks": ids.size(), "want_seen": want_seen,
		"mined": mined, "taken": taken, "ore": standing, "want_ore": want_ore,
		"defended": defended, "keeper_down": keeper_down, "yard_broken": yard_broken,
		"answered": explored and mined and defended,
	}


## The landscape a region is made of, or null for a region nobody laid.
static func _def_of(world: WorldData, region_id: int) -> BiomeDef:
	if world == null:
		return null
	for r: Dictionary in world.regions:
		if int(r.get("id", -1)) == region_id:
			return BiomeRegistry.get_def(StringName(str(r.get("type", &""))))
	return null
