extends TestCase
## A BUILDING IS DRAWN IN THE FORM THAT STOPS A BODY (WorldData.built_country).
## A house's `solid` is its form's reach in its village's stock and a ruin's
## walls are its tile's ruin form, so the chunk bake must dress both by the
## same landscape and never by the ecotone at its foot. Dressed at the foot, a
## border house drew a croft round a tower's wall (seed 7 at 512: 10 of 97, a
## 3.02 solid under a 2.02 house) and a ruin a croft round a metropolis stump.

const SEEDS: Array[int] = [1, 3, 7]
const SIZE := 512


## Every house drawn as the form its solid was dealt from.
func test_a_house_is_drawn_in_the_form_it_stands_on() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var m := TerrainMesher.new(w)
		var chunks := {}
		var houses := 0
		var wrong := PackedStringArray()
		for p in w.each_prop():
			if p.kind != PropKind.HOUSE:
				continue
			houses += 1
			var drawn := WorldView.prop_country_of(w, p, _chunk(m, chunks, p.pos))
			var want := BiomeForms.of(drawn).reach(PropModels.variant_of(p, w.seed_value, drawn)) * p.scale
			if absf(want - p.solid) > 1e-4:
				wrong.append("(%.1f,%.1f) drawn %s %.2f, solid %.2f" % [p.pos.x, p.pos.y, BiomeRegistry.names()[drawn], want, p.solid])
		print("  info seed %d: %d houses, %d drawn in another form than their solid" % [s, houses, wrong.size()])
		gt(houses, 20, "seed %d lays villages" % s)
		eq(wrong.size(), 0, "seed %d: houses drawn in another form than stops a body: %s" % [s, "; ".join(wrong.slice(0, 6))])


## Every walled prop drawn in its own land's model, the one its walls are
## fitted to (PropWalls).
func test_a_walled_prop_is_drawn_in_the_form_its_walls_are() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var m := TerrainMesher.new(w)
		var chunks := {}
		var ruins := 0
		var wrong := 0
		for p in w.each_prop():
			if not PropWalls.walled(p.kind):
				continue
			ruins += 1
			var drawn := WorldView.prop_country_of(w, p, _chunk(m, chunks, p.pos))
			var walled := w.built_country(p)
			if PropWalls.shape(p.kind, PropModels.variant_of(p, w.seed_value, drawn), drawn) \
					!= PropWalls.shape(p.kind, PropModels.variant_of(p, w.seed_value, walled), walled):
				wrong += 1
		print("  info seed %d: %d walled props, %d drawn in another form than their walls" % [s, ruins, wrong])
		eq(wrong, 0, "seed %d: walled props drawn in another form than their walls" % s)


## A house the hunters burn stands on its house's ground, in its house's form.
func test_a_burnt_house_keeps_its_houses_ground() -> void:
	var w := WorldGen.generate(7, SIZE)
	var seen := 0
	for p in w.each_prop():
		if p.kind != PropKind.HOUSE:
			continue
		var shell := WorldProp.new(w.next_id(), PropKind.HOUSE_BURNT, p.pos, p.rot, p.scale)
		shell.variant = PropModels.variant_of(p, w.seed_value, w.built_country(p))
		w.add_prop(shell)
		near(shell.solid, p.solid, 1e-4, "the shell at (%.1f,%.1f) stands on its house's ground" % [p.pos.x, p.pos.y])
		seen += 1
		if seen >= 40:
			break
	gt(seen, 20, "seed 7 has houses to burn")


static func _chunk(m: TerrainMesher, chunks: Dictionary, at: Vector2) -> TerrainMesher.Chunk:
	var key := Vector2i(floori(at.x) / TerrainMesher.CHUNK, floori(at.y) / TerrainMesher.CHUNK)
	if not chunks.has(key):
		chunks[key] = m.build(key.x, key.y)
	return chunks[key]
