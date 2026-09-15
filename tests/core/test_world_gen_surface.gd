extends TestCase
## Grounds read as washes: big patches with long edges, no specks, no stair
## notches, each country's grounds kept to that country, villages and pools
## drawn as places rather than stamps. Uses the cached default-size worlds.

const Worlds := preload("res://tests/core/test_world_gen.gd")


static func _line(g: int) -> bool:
	return Ground.is_water(g) or g == Ground.ROAD or g == Ground.ICE


func test_grounds_are_washes_not_salad() -> void:
	# Edge tiles: field tiles (not water, road or ice) touching another field
	# ground. Specks: patches of one ground of four tiles or fewer.
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var size := w.size
		var n := size * size
		var land := PackedFloat32Array()
		land.resize(Country.COUNT)
		var field := PackedFloat32Array()
		field.resize(Country.COUNT)
		var edge := PackedFloat32Array()
		edge.resize(Country.COUNT)
		for y in range(1, size - 1):
			for x in range(1, size - 1):
				var i := y * size + x
				if w.level[i] <= 0:
					continue
				var c := w.country[i]
				land[c] += 1.0
				var g := w.ground[i]
				if _line(g):
					continue
				field[c] += 1.0
				for j: int in [i - 1, i + 1, i - size, i + size]:
					var h := w.ground[j]
					if h != g and not _line(h):
						edge[c] += 1.0
						break
		var specks := PackedFloat32Array()
		specks.resize(Country.COUNT)
		var sizes := PackedInt32Array()
		var lines := PackedByteArray()
		lines.resize(n)
		for i in n:
			lines[i] = 1 if w.level[i] <= 0 or _line(w.ground[i]) else 0
		var label := GenFields.patches(w.ground, lines, size, sizes)
		for i in n:
			if label[i] == i and sizes[i] <= 4:
				specks[w.country[i]] += 1.0
		for c: int in Country.LAND:
			lt(edge[c] / field[c], 0.25, "seed %d %s edge share" % [s, Country.NAMES[c]])
			lt(specks[c] * 1000.0 / land[c], 10.0, "seed %d %s specks per 1000 tiles" % [s, Country.NAMES[c]])


func test_no_stair_notches_or_chequers() -> void:
	# A field tile enclosed on three sides by one other field ground is a notch;
	# a 2x2 of two grounds touching only corner to corner is a chequer. Both
	# draw as tile stairs.
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var size := w.size
		var notches := 0
		var chequers := 0
		var field := 0
		for y in range(1, size - 1):
			for x in range(1, size - 1):
				var i := y * size + x
				var g := w.ground[i]
				if w.level[i] <= 0 or _line(g):
					continue
				field += 1
				var counts := {}
				for j: int in [i - 1, i + 1, i - size, i + size]:
					var h := w.ground[j]
					if h != g and not _line(h):
						counts[h] = int(counts.get(h, 0)) + 1
				for h: int in counts:
					if counts[h] >= 3:
						notches += 1
				var r := w.ground[i + 1]
				var d := w.ground[i + size]
				var dr := w.ground[i + size + 1]
				if not _line(r) and not _line(d) and not _line(dr) and g == dr and r == d and g != r:
					chequers += 1
		lt(float(notches) / field, 0.001, "seed %d notches %d" % [s, notches])
		lt(float(chequers) / field, 0.0005, "seed %d chequers %d" % [s, chequers])


func test_snow_and_ash_keep_to_their_countries() -> void:
	# Snow creeps down ridges and ash drifts over the rim, inside the ecotone:
	# never more than 3% of another country.
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var land := PackedFloat32Array()
		land.resize(Country.COUNT)
		var snow := PackedFloat32Array()
		snow.resize(Country.COUNT)
		var ash := PackedFloat32Array()
		ash.resize(Country.COUNT)
		for i in w.ground.size():
			if w.level[i] <= 0:
				continue
			var c := w.country[i]
			land[c] += 1.0
			if w.ground[i] == Ground.SNOW:
				snow[c] += 1.0
			elif w.ground[i] == Ground.ASH:
				ash[c] += 1.0
		for c: int in Country.LAND:
			if c != Country.SNOWFIELD:
				lt(snow[c] / land[c], 0.03, "seed %d snow in %s" % [s, Country.NAMES[c]])
			if c != Country.BURNING:
				lt(ash[c] / land[c], 0.03, "seed %d ash in %s" % [s, Country.NAMES[c]])


func test_heath_drapes_across_terraces() -> void:
	# Heath is drawn from smooth float elevation, not from the integer level:
	# where a terrace edge crosses heath, the heath carries on over it.
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var size := w.size
		var across := 0.0
		var both := 0.0
		for y in range(1, size - 1):
			for x in range(1, size - 1):
				var i := y * size + x
				if w.country[i] != Country.COAST or w.level[i] <= 0:
					continue
				for j: int in [i + 1, i + size]:
					if absi(w.level[j] - w.level[i]) != 1 or _line(w.ground[j]) or _line(w.ground[i]):
						continue
					var hi := w.ground[i] == Ground.HEATH
					var hj := w.ground[j] == Ground.HEATH
					if hi or hj:
						across += 1.0
						if hi and hj:
							both += 1.0
		gt(both / maxf(1.0, across), 0.6, "seed %d heath carried over terrace edges" % s)


func test_pools_are_round_rimmed_and_clear_of_houses() -> void:
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var size := w.size
		var n := size * size
		var not_pool := PackedByteArray()
		not_pool.resize(n)
		for i in n:
			not_pool[i] = 0 if w.ground[i] == Ground.BLACKWATER else 1
		var sizes := PackedInt32Array()
		var label := GenFields.patches(w.ground, not_pool, size, sizes)
		var pools := 0
		for i in n:
			if label[i] == i:
				pools += 1
				gt(sizes[i], 9, "seed %d blackwater pool at %d,%d tiles" % [s, i % size, i / size])
		gt(pools, 4, "seed %d blackwater pools in the Moss" % s)
		# A rim of peat or mud round the black water.
		var shore := 0.0
		var rimmed := 0.0
		for y in range(1, size - 1):
			for x in range(1, size - 1):
				var i := y * size + x
				var g := w.ground[i]
				if _line(g) or w.level[i] <= 0:
					continue
				if w.ground[i - 1] == Ground.BLACKWATER or w.ground[i + 1] == Ground.BLACKWATER or w.ground[i - size] == Ground.BLACKWATER or w.ground[i + size] == Ground.BLACKWATER:
					shore += 1.0
					if g == Ground.PEAT or g == Ground.MUD:
						rimmed += 1.0
		gt(rimmed / maxf(1.0, shore), 0.9, "seed %d blackwater rimmed with peat or mud" % s)
		for p in w.props:
			if p.kind != PropKind.HOUSE:
				continue
			var reach := ceili(p.solid + 3.0)
			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var g := w.ground_at(floori(p.pos.x) + dx, floori(p.pos.y) + dy)
					if g == Ground.BLACKWATER and Vector2(dx, dy).length() <= p.solid + 3.0:
						fail("seed %d blackwater within 3 tiles of a house at %s" % [s, p.pos])


func test_villages_stand_in_clearings_with_a_square() -> void:
	# No scree, rock, clinker, shingle, mud or peat in a village's core; a
	# square of trodden ground in its middle, not a road splat.
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		for v in w.villages:
			var vp: Vector2 = v.pos
			var square := 0
			var total := 0
			for dy in range(-10, 11):
				for dx in range(-10, 11):
					var x := floori(vp.x) + dx
					var y := floori(vp.y) + dy
					var d := Vector2(x + 0.5, y + 0.5).distance_to(vp)
					var g := w.ground_at(x, y)
					if d < 8.0 and g in [Ground.SCREE, Ground.ROCK, Ground.CLINKER, Ground.SHINGLE, Ground.MUD, Ground.PEAT]:
						fail("seed %d village %s has %s in its core" % [s, v.name, Ground.NAMES[g]])
					if d < 2.5:
						total += 1
						if g == Ground.GRAVEL or g == Ground.GRASS or g == Ground.ROAD:
							square += 1
			gt(float(square) / total, 0.9, "seed %d village %s square" % [s, v.name])
