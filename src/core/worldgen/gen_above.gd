class_name GenAbove
extends RefCounted
## GROUND ABOVE THE GROUND, GROWN (docs/ABOVE.md S3): a landscape that declares
## `BiomeDef.above.roof` is roofed. Its halls stand under a lid of rock, not open
## to a dark sky as a stack of terraces, and daylight comes down only through the
## holes: the dome's tears (Dome.tear_in, the light columns 11_dome draws) and the
## shafts to the world above (Portals). The last stage: the levels, the props and
## the shafts are final, so a roof can clear all of them.
##
## THE ROOF IS TERRACED, never a smooth field (docs/ABOVE.md, the S3 cost target):
## its underside is the highest floor within `clear` tiles (reckoned by BLOCK
## blocks, so at least that) plus `room` levels, rounded UP to a multiple of
## `step`. A roof whose height changed at every tile
## would have no core and take the span mesher's slow path on every chunk; a
## terraced one is level plateaus, a hall a plateau, each drawn as a few quads.
##
## Keys of `above.roof`:
##   room   levels of headroom at least, over the highest floor within `clear`
##   clear  tiles round a tile whose floor the roof must clear
##   step   levels the plateaus step by
##   thick  levels of rock in the lid
##   tear   tiles round a dome tear left open
##   shaft  tiles round a shaft's mouth left open
## Every roofed tile stands at least `room` levels over its own floor, so a
## person (FightSim.HERO_TALL) walks everywhere they walked before.

const KIND_ROOF := 1
## Tiles a side of the blocks a roof's plateaus are laid by.
const BLOCK := 4


static func run(w: WorldData) -> void:
	var roofs := {}
	for d: BiomeDef in BiomeRegistry.all():
		if d.above.has("roof"):
			roofs[d.index] = d.above["roof"]
	if roofs.is_empty():
		return
	var n := w.size
	var roofed := PackedByteArray()
	roofed.resize(n * n)
	var any := false
	for i in n * n:
		if roofs.has(int(w.country[i])) and w.level[i] > 0:
			roofed[i] = 1
			any = true
	if not any:
		return
	# One declaration serves: the realms that have a roof have one landscape.
	var r: Dictionary = roofs.values()[0]
	var room := int(r.get("room", 6))
	var clear := int(r.get("clear", 3))
	var step := maxi(1, int(r.get("step", 4)))
	var thick := int(r.get("thick", 4))
	# The highest floor over BLOCK-square blocks, then over each block and its
	# neighbours out to `clear`: every tile's roof clears the floors within
	# `clear` of it, and a block is one plateau (more of the roof core, a few
	# quads to draw), for a pass over the tiles and one over the blocks.
	var nb := ceili(float(n) / BLOCK)
	var bmax := PackedInt32Array()
	bmax.resize(nb * nb)
	for y in n:
		var by := y / BLOCK
		for x in n:
			var l := w.level[y * n + x]
			var bi := by * nb + x / BLOCK
			if l > bmax[bi]:
				bmax[bi] = l
	var reach := ceili(float(clear) / BLOCK)
	var bunder := PackedInt32Array()
	bunder.resize(nb * nb)
	for by in nb:
		for bx in nb:
			var m := 0
			for dy in range(-reach, reach + 1):
				var yy := by + dy
				if yy < 0 or yy >= nb:
					continue
				for dx in range(-reach, reach + 1):
					var xx := bx + dx
					if xx >= 0 and xx < nb:
						m = maxi(m, bmax[yy * nb + xx])
			bunder[by * nb + bx] = ceili(float(m + room) / step) * step
	# The holes: the dome's tears and the shafts' mouths.
	var tear := float(r.get("tear", 3.0))
	var shaft := float(r.get("shaft", 3.5))
	var open := PackedByteArray()
	open.resize(n * n)
	var cells := ceili(float(n) / Dome.CELL)
	for cy in cells:
		for cx in cells:
			var t := Dome.tear_in(w.seed_value, cx, cy)
			if t != Vector2.INF:
				_open_disc(open, n, t, tear)
	for p: Portal in Portals.in_world(w):
		_open_disc(open, n, p.pos, shaft)
	# Section by section (WorldData.OH_SECTION), each put whole.
	var sec := WorldData.OH_SECTION
	var secs := ceili(float(n) / sec)
	for sy in secs:
		for sx in secs:
			var bytes := PackedByteArray()
			var lo := Vector2i(n, n)
			var hi := Vector2i(-1, -1)
			for y in range(sy * sec, mini(n, (sy + 1) * sec)):
				var by := y / BLOCK
				for x in range(sx * sec, mini(n, (sx + 1) * sec)):
					var i := y * n + x
					if roofed[i] == 0 or open[i] == 1:
						continue
					if bytes.is_empty():
						bytes.resize(sec * sec * 3)
					var u := mini(bunder[by * nb + x / BLOCK], 254)
					var o := ((y - sy * sec) * sec + x - sx * sec) * 3
					bytes[o] = u + 1
					bytes[o + 1] = mini(u + thick, 255)
					bytes[o + 2] = KIND_ROOF
					lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
					hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			if not bytes.is_empty():
				w.put_overhead_section(sx * sec, sy * sec, bytes, Rect2i(lo, hi - lo + Vector2i.ONE))


static func _open_disc(open: PackedByteArray, n: int, at: Vector2, r: float) -> void:
	for y in range(floori(at.y - r), ceili(at.y + r) + 1):
		for x in range(floori(at.x - r), ceili(at.x + r) + 1):
			if x < 0 or y < 0 or x >= n or y >= n:
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(at) <= r:
				open[y * n + x] = 1
