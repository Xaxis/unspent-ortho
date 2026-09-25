class_name GenForm
## Stage 2b: a region's FORM, the land at the scale of a region rather than of
## a walk. Solved once on the coarse grid after layout (the territory is known)
## and before relief (which adds it), for every landscape that declares
## `BiomeDef.form`; nothing here names a landscape.
##
## THE SPINE. Relief noise works at 58-92 tiles and a landscape is thousands
## across, so on its own a region is the same swell repeated. A form raises the
## land with its distance from the sea, measured to the far side of its own
## territory on its own body: flat at the shore, highest where the land is
## farthest from any coast. That crest is the spine, the backbone every coast
## of the region drains from, so the watershed is the spine by construction.
## Along it, a slow noise at `wave` tiles (times `body_k`) sinks passes between
## tops, so the crest reads as a range and not a wall.
##
## Writes `GenContext.form_e`: levels to add, on the coarse grid, blended by
## the type's soft membership so it fades across a border rather than stopping
## on one. Empty (no cost downstream) when no landscape declares a form.

## Salt of the pass noise.
const PASS_SALT := 311


static func run(c: GenContext) -> void:
	c.form_e = PackedFloat32Array()
	var formed: Array[int] = []
	for cc: int in c.land_types:
		if not c.defs[cc].form.is_empty():
			formed.append(cc)
	if formed.is_empty():
		return
	var cw := c.cw
	var cn := cw * cw
	var step := GenContext.STEP
	var size := c.size
	var land := PackedByteArray()
	land.resize(cn)
	var sea := PackedByteArray()
	sea.resize(cn)
	var body := PackedInt32Array()
	body.resize(cn)
	for gy in cw:
		for gx in cw:
			var k := gy * cw + gx
			var x := mini(size - 1, gx * step + step / 2)
			var y := mini(size - 1, gy * step + step / 2)
			var i := y * size + x
			if c.land[i] != 0:
				land[k] = 1
				body[k] = c.w.continent_at(x, y)
			else:
				sea[k] = 1
	# How far each cell is from the nearest sea, in tiles.
	var d := GenFields.distance8(sea, cw)
	for k in cn:
		d[k] *= step
	var out := PackedFloat32Array()
	out.resize(cn)
	for cc: int in formed:
		var f: Dictionary = c.defs[cc].form
		var crest := float(f.get(&"crest", 0.0))
		var rise := float(f.get(&"rise", 1.0))
		var passes := float(f.get(&"passes", 0.0))
		var wave := float(f.get(&"wave", 300.0)) * maxf(1.0, c.body_k)
		var soft := c.soft[cc]
		# The farthest this landscape reaches from the sea on each body: the
		# height of its spine.
		var most := {}
		for k in cn:
			if land[k] != 0 and soft[k] > 0.5:
				most[body[k]] = maxf(float(most.get(body[k], 0.0)), d[k])
		var pass_n := GenFields.sample(GenFields.noise(c.s, PASS_SALT + cc, 1.0 / wave, 2), cw, step)
		for k in cn:
			var sk := soft[k]
			if land[k] == 0 or sk <= 0.0:
				continue
			var top := float(most.get(body[k], 0.0))
			if top <= 0.0:
				continue
			var t := clampf(d[k] / top, 0.0, 1.0)
			# A pass is a dip in the crest, deepest on the spine itself.
			var sag := passes * maxf(0.0, -pass_n[k]) * t
			out[k] += sk * crest * (pow(t, rise) - sag)
	c.form_e = out
