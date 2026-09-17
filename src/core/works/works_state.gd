class_name WorksState
extends RefCounted
## What has been done to one depot, and the only part of a works that is saved.
## Where it stands is derived from the island every time (`Works.sites`); this is
## the history the island cannot hold.

## The region the depot serves, which is what a save keys on: prop ids and tile
## coordinates move when worldgen changes, a region id does not.
var region := -1
## One flag per working part, in `Works.PART_NAMES` order.
var parts: Array[bool] = [false, false, false]
## World minutes the last part went, INF while it still works; and the world day
## it went, which is the stage the plan never got past here.
var dark_at := INF
var dark_day := 1.0
## World minutes the player was last at it with their hands on something: what
## makes the yard press on a region for a while after (see 34_works).
var stirred_at := -INF
## Tufts the land has already put back over the yard, so greening is laid once.
var tufts := 0
## True once the props in the yard have been marked spent: a broken works is
## broken for the sentinel that fed on it too, and that is done exactly once.
var stripped := false


func broken() -> bool:
	for p in parts:
		if not p:
			return false
	return true


func broken_count() -> int:
	var n := 0
	for p in parts:
		if p:
			n += 1
	return n


## Hours it has stood dark at world minute `minutes` (0 while it works).
func dark_hours(minutes: float) -> float:
	if dark_at == INF:
		return 0.0
	return maxf(0.0, (minutes - dark_at) / 60.0)


func save() -> Dictionary:
	var flags: Array = []
	for p in parts:
		flags.append(p)
	return {"region": region, "parts": flags, "dark_at": SaveCodec.num(dark_at),
		"dark_day": dark_day, "tufts": tufts, "stripped": stripped}


static func from_save(d: Dictionary) -> WorksState:
	var s := WorksState.new()
	s.region = SaveCodec.to_int(d.get("region", -1))
	var flags: Array = d.get("parts", [])
	for i in mini(flags.size(), s.parts.size()):
		s.parts[i] = bool(flags[i])
	s.dark_at = SaveCodec.to_num(d.get("dark_at", INF))
	s.dark_day = float(d.get("dark_day", 1.0))
	s.tufts = SaveCodec.to_int(d.get("tufts", 0))
	s.stripped = bool(d.get("stripped", false))
	return s
