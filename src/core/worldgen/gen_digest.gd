class_name GenDigest
## What generation records for readers that must not walk the whole world to
## answer: a streamed world holds only some sections, so a count over every prop
## is taken once here, where every prop exists, and kept on the WorldData.
## (Later, the plan and each section's digest supply the same numbers.)


const Treads := preload("res://src/core/colossus/colossus_treads.gd")


static func run(w: WorldData) -> void:
	w.ore_standing = ore_standing(w)
	w.ore_counted = true


## Region id -> how many props of that region's own ore kinds stand in it: not
## the ones a walker's pads crush before he ever arrives (Treads.crushed), which
## were never there for him to mine. Read off the table, so it is asked once the
## ids are final (WorldGen.finish runs it after GenIds).
static func ore_standing(w: WorldData) -> Dictionary:
	var kinds_of := {}
	var out := {}
	var crushed := Treads.crushed(w)
	w.sync_table()
	var t := w.table
	for row in t.size():
		var at: Vector2 = t.pos[row]
		var r := w.region_at(floori(at.x), floori(at.y))
		if r < 0 or crushed.has(t.id[row]):
			continue
		if not kinds_of.has(r):
			kinds_of[r] = Chapter.ore_kinds(w, r)
		var kinds: Array = kinds_of[r]
		if kinds.has(int(t.kind[row])):
			out[r] = int(out.get(r, 0)) + 1
	return out
