class_name GenDigest
## What generation records for readers that must not walk the whole world to
## answer: a streamed world holds only some sections, so a count over every prop
## is taken once here, where every prop exists, and kept on the WorldData.
## (Later, the plan and each section's digest supply the same numbers.)


static func run(w: WorldData) -> void:
	w.ore_standing = ore_standing(w)
	w.ore_counted = true


## Region id -> how many props of that region's own ore kinds stand in it.
static func ore_standing(w: WorldData) -> Dictionary:
	var kinds_of := {}
	var out := {}
	for p: WorldProp in w.props:
		var r := w.region_at(floori(p.pos.x), floori(p.pos.y))
		if r < 0:
			continue
		if not kinds_of.has(r):
			kinds_of[r] = Chapter.ore_kinds(w, r)
		var kinds: Array = kinds_of[r]
		if kinds.has(p.kind):
			out[r] = int(out.get(r, 0)) + 1
	return out
