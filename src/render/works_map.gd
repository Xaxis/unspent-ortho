class_name WorksMap
extends RefCounted
## Where the machines have cut the land, as a map world.gdshader reads: one
## texel per tile, a channel per kind of work, 0..1 with a feathered edge so the
## shader can tear the region's rim raggedly (the chaos) while it rules the
## rows, cuts, benches and bores inside exactly along the survey bearing (the
## order). Baked once from the landmarks GenWorks records ({pos, dir, half,
## mark}); decor reads the same bytes.
##
## Channels:
##   R  cut     turf cut in rows (turf, heath), drainage cuts (fen, peat, mud),
##              harvester tracks (needles)
##   G  scorch  burnt and poisoned ground, whatever it was
##   B  quarry  benches cut in the grid (pavement, rock, gravel, turf)
##   A  bores   an exact grid of drill holes and the survey's paint lines

const CHANNEL := {&"cut": 0, &"scorch": 1, &"quarry": 2, &"bores": 3}
## Tiles over which a work's edge fades out.
const FEATHER := 1.5

var size := 0
var bytes := PackedByteArray()
## One byte per tile: 255 where a stretch of the survey runs (GenWorks.survey_sections).
var lines := PackedByteArray()
## GenWorks.survey_phase: where the survey's two families of lines sit.
var phase := Vector2.ZERO
## The survey bearing as a unit vector (GenWorks.bearing).
var dir := Vector2.RIGHT


static func bake(w: WorldData) -> WorksMap:
	var m := WorksMap.new()
	m.size = w.size
	m.bytes.resize(w.size * w.size * 4)
	m.dir = Vector2.from_angle(GenWorks.bearing(w.seed_value))
	for lm in w.landmarks:
		if not lm.has("mark"):
			continue
		var ch: int = CHANNEL.get(lm.mark, -1)
		if ch < 0:
			continue
		m._paint(lm.pos, lm.get("dir", Vector2.RIGHT), lm.get("half", Vector2(4, 4)), ch)
	m.lines.resize(w.size * w.size)
	m.phase = GenWorks.survey_phase(w.seed_value)
	for sec: Array in GenWorks.survey_sections(w.seed_value, w.size):
		m._line(w, sec[0], sec[1])
	return m


## Where a stretch of the survey survives: a band the shader rules its exact
## line inside. Villages keep it out of their squares.
func _line(w: WorldData, a: Vector2, b: Vector2) -> void:
	var d := (b - a).normalized()
	var nrm := Vector2(-d.y, d.x)
	var length := a.distance_to(b)
	var t := 0.0
	while t <= length:
		for s: float in [-1.5, -0.75, 0.0, 0.75, 1.5]:
			var q := a + d * t + nrm * s
			var x := floori(q.x)
			var y := floori(q.y)
			if x < 0 or y < 0 or x >= size or y >= size:
				continue
			if w.ground[y * size + x] == Ground.ROAD:
				continue
			lines[y * size + x] = 255
		t += 0.5
	for v in w.villages:
		var vp: Vector2 = v.pos
		if Geometry2D.get_closest_point_to_segment(vp, a, b).distance_to(vp) < 14.0:
			var r := 14
			for y in range(maxi(0, floori(vp.y) - r), mini(size, floori(vp.y) + r + 1)):
				for x in range(maxi(0, floori(vp.x) - r), mini(size, floori(vp.x) + r + 1)):
					lines[y * size + x] = 0


## A rotated rectangle into one channel: full inside, fading over FEATHER.
func _paint(centre: Vector2, d: Vector2, half: Vector2, ch: int) -> void:
	var nrm := Vector2(-d.y, d.x)
	var outer := half + Vector2(FEATHER, FEATHER)
	var nu := ceili(outer.x * 2.5)
	var nv := ceili(outer.y * 2.5)
	for iu in range(-nu, nu + 1):
		var u := outer.x * iu / nu
		var along := centre + d * u
		for iv in range(-nv, nv + 1):
			var v := outer.y * iv / nv
			var q := along + nrm * v
			var x := floori(q.x)
			var y := floori(q.y)
			if x < 0 or y < 0 or x >= size or y >= size:
				continue
			var e := maxf(absf(u) - half.x, absf(v) - half.y)
			var k := clampi(roundi((1.0 - clampf(e / FEATHER, 0.0, 1.0)) * 255.0), 0, 255)
			var i := (y * size + x) * 4 + ch
			if k > bytes[i]:
				bytes[i] = k


## 0..1 of channel ch at tile (x, y).
func at(x: int, y: int, ch: int) -> float:
	if x < 0 or y < 0 or x >= size or y >= size:
		return 0.0
	return bytes[(y * size + x) * 4 + ch] / 255.0


func texture() -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes))


## Hand the map to a world material (world.gdshader).
func bind(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("works_map", texture())
	mat.set_shader_parameter("works_inv_size", 1.0 / maxf(1.0, float(size)))
	mat.set_shader_parameter("works_dir", dir)
	mat.set_shader_parameter("works_lines", ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_R8, lines)))
	mat.set_shader_parameter("works_survey", Vector4(phase.x, phase.y, GenWorks.SURVEY_ALONG, GenWorks.SURVEY_ACROSS))
