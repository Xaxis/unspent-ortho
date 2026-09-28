extends TestCase
## Terraces and straits are a section's to lay (streamed worldgen S4g). A section
## levels its tiles from one tile of the world round them (`GenRelief.
## terrace_square`), and cuts its straits from `GenBodies.STRAIT_MARGIN` round
## them with the plan's set of continents (`GenBodies.deepen_square`), exactly as
## the whole world does.

const CORE := 64


func test_a_section_terraces_its_tiles_as_the_whole_world_does() -> void:
	for s: int in [1, 42]:
		GenRelief.keeping = true
		var w := WorldGen.plan(s, 512).w
		GenRelief.keeping = false
		var b: Dictionary = GenRelief.before
		GenRelief.before = {}
		var size := w.size
		var whole := PackedInt32Array()
		whole.resize(size * size)
		GenRelief.terrace_square(b.elev, b.land, b.water, whole, size)
		var judged := 0
		for i in whole.size():
			if b.land[i] != 0 and whole[i] != clampi(floori(b.elev[i]), 1, GenRelief.MAX_LEVEL):
				judged += 1
		gt(judged, 20, "seed %d: spikes and pits were levelled (%d)" % [s, judged])
		eq(_tiled(b, whole, size, 1, false, {}), 0, "seed %d: every section terraces as the whole world does" % s)


## THE STRAIT IS BUILT, because the shipped worlds keep their continents' shelves
## apart already and cut nothing: two continents whose shelves meet across a
## wavy strait of shallow water, inlets and lagoons along both shores so the
## flood that decides whose shelf a tile is has ties to settle.
func test_a_section_cuts_its_straits_as_the_whole_world_does() -> void:
	var size := 320
	var level := PackedInt32Array()
	level.resize(size * size)
	var continent := PackedByteArray()
	continent.resize(size * size)
	for y in size:
		var mid := 160.0 + sin(y / 13.0) * 14.0 + sin(y / 5.0) * 3.0
		for x in size:
			var i := y * size + x
			var l := -1
			var id := 0
			if y > 8 and y < size - 8 and x > 8 and x < size - 8:
				if x < mid - 3.0:
					l = 3
					id = 1
				elif x > mid + 4.0:
					l = 2
					id = 2
				else:
					l = 0
				# Inlets and lagoons of shallow water inside both shores.
				if l > 0 and Rng.hash01(7, x / 6, y / 6, 0x57A) < 0.08:
					l = 0
					id = 0
			level[i] = l
			continent[i] = id
	var big := {1: true, 2: true}
	var b := {"level": level, "continent": continent}
	var whole: PackedInt32Array = GenFields.snapshot(level)
	GenBodies.deepen_square(whole, continent, big, size)
	var cut := 0
	for i in whole.size():
		if whole[i] != level[i]:
			cut += 1
	gt(cut, 200, "the strait was cut (%d tiles)" % cut)
	eq(_tiled(b, whole, size, GenBodies.STRAIT_MARGIN, true, big), 0, "every section cuts the strait as the whole world does")


## Tiles of every section's core that come out differently from `whole` when the
## section is laid from its own window, `margin` round it: terraced, or with
## `straits` cut.
static func _tiled(b: Dictionary, whole: PackedInt32Array, size: int, margin: int, straits: bool, big: Dictionary) -> int:
	var bad := 0
	var side := CORE + margin * 2
	for gy in ceili(float(size) / CORE):
		for gx in ceili(float(size) / CORE):
			var ox := gx * CORE - margin
			var oy := gy * CORE - margin
			var level := PackedInt32Array()
			level.resize(side * side)
			level.fill(-1)
			var elev := PackedFloat32Array()
			elev.resize(side * side)
			elev.fill(-1.0)
			var land := PackedByteArray()
			land.resize(side * side)
			var water := PackedByteArray()
			water.resize(side * side)
			var continent := PackedByteArray()
			continent.resize(side * side)
			for y in side:
				var wy := oy + y
				if wy < 0 or wy >= size:
					continue
				for x in side:
					var wx := ox + x
					if wx < 0 or wx >= size:
						continue
					var i := wy * size + wx
					var k := y * side + x
					if straits:
						level[k] = b.level[i]
						continent[k] = b.continent[i]
					else:
						elev[k] = b.elev[i]
						land[k] = b.land[i]
						water[k] = b.water[i]
			if straits:
				GenBodies.deepen_square(level, continent, big, side)
			else:
				GenRelief.terrace_square(elev, land, water, level, side)
			for y in CORE:
				var wy := gy * CORE + y
				if wy >= size:
					continue
				for x in CORE:
					var wx := gx * CORE + x
					if wx >= size:
						continue
					if level[(margin + y) * side + margin + x] != whole[wy * size + wx]:
						bad += 1
	return bad
