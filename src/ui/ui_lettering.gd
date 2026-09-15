class_name UiLettering
## Display lettering for the title: letters built from pen strokes (lines and
## arcs on a 14x22 design grid), rasterized once to a pixel mask whose edge is
## cut by hand, a pixel in or out wherever the pen wavered. Drawn as a texture
## at whole-pixel positions, tinted by modulate.

const GRID_W := 14.0
const GRID_H := 22.0

## Strokes per letter on the design grid: ["l", x0, y0, x1, y1] or
## ["a", cx, cy, r, from_deg, to_deg] (screen angles: 0 east, 90 south).
const STROKES := {
	"U": [["l", 2, 2, 2, 14], ["a", 7, 14.5, 5, 180, 0], ["l", 12, 14, 12, 2]],
	"N": [["l", 2, 20, 2, 2], ["l", 2, 2, 12, 20], ["l", 12, 20, 12, 2]],
	"S": [["a", 7, 6.6, 4.6, -20, -270], ["a", 7, 15.4, 4.6, -90, 160]],
	"P": [["l", 2, 20, 2, 2], ["l", 2, 2, 7, 2], ["a", 7, 6.5, 4.5, -90, 90], ["l", 7, 11, 2, 11]],
	"E": [["l", 2, 2, 2, 20], ["l", 2, 2, 12, 2], ["l", 2, 11, 10, 11], ["l", 2, 20, 12, 20]],
	"T": [["l", 1, 2, 13, 2], ["l", 7, 2, 7, 20]],
	"A": [["l", 1.5, 20, 7, 2], ["l", 7, 2, 12.5, 20], ["l", 4, 13, 10, 13]],
	"O": [["a", 7, 11, 5.5, 0, 360]],
	"I": [["l", 7, 2, 7, 20]],
	"R": [["l", 2, 20, 2, 2], ["l", 2, 2, 7, 2], ["a", 7, 6.5, 4.5, -90, 90], ["l", 7, 11, 2, 11], ["l", 6, 11, 12, 20]],
	"D": [["l", 2, 2, 2, 20], ["l", 2, 2, 4, 2], ["l", 2, 20, 4, 20], ["a", 4, 11, 9, -90, 90]],
	" ": [],
}

static var _cache := {}


## Pixel width of `text` lettered `height` pixels tall.
static func width(text: String, height: int) -> int:
	var s := height / GRID_H
	var gap := maxi(2, roundi(3.0 * s))
	return roundi(GRID_W * s) * text.length() + gap * (text.length() - 1)


## A white mask of the text (alpha = ink) as a texture, cached.
static func texture(text: String, height: int, seed: int) -> ImageTexture:
	var key := "%s|%d|%d" % [text, height, seed]
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(mask(text, height, seed))
	_cache[key] = tex
	return tex


static func mask(text: String, height: int, seed: int) -> Image:
	var s := height / GRID_H
	var cell := roundi(GRID_W * s)
	var gap := maxi(2, roundi(3.0 * s))
	var img := Image.create_empty(maxi(1, width(text, height)), height, false, Image.FORMAT_LA8)
	img.fill(Color(1, 1, 1, 0))
	var pen := 2.15 * s
	for i in text.length():
		var strokes: Array = STROKES.get(text[i], [])
		var ox := i * (cell + gap)
		for y in height:
			for x in cell:
				var p := Vector2(x + 0.5, y + 0.5) / s
				var d := INF
				for st: Array in strokes:
					d = minf(d, _dist(p, st))
				# The hand-cut edge: the pen wanders by a pixel, in runs, not per pixel noise.
				var wobble := (Rng.hash01(seed, ox + x / 2, y / 2, i) - 0.5) * 0.9 / s
				if d * s < pen + wobble * s:
					img.set_pixel(ox + x, y, Color(1, 1, 1, 1))
	return img


## Draw lettering with its top-left at `at`.
static func draw(ci: CanvasItem, text: String, at: Vector2i, height: int, col: Color, seed: int) -> void:
	ci.draw_texture(texture(text, height, seed), Vector2(at), col)


static func _dist(p: Vector2, st: Array) -> float:
	if st[0] == "l":
		var a := Vector2(st[1], st[2])
		var b := Vector2(st[3], st[4])
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(1e-6, ab.length_squared()), 0.0, 1.0)
		return p.distance_to(a + ab * t)
	var c := Vector2(st[1], st[2])
	var r: float = st[3]
	var from := deg_to_rad(float(st[4]))
	var to := deg_to_rad(float(st[5]))
	var ang := (p - c).angle()
	var lo := minf(from, to)
	var hi := maxf(from, to)
	# Is the point's angle within the swept range (in any turn)?
	var k := ang
	while k < lo:
		k += TAU
	while k > lo + TAU:
		k -= TAU
	if k <= hi:
		return absf(p.distance_to(c) - r)
	var e0 := c + Vector2.from_angle(from) * r
	var e1 := c + Vector2.from_angle(to) * r
	return minf(p.distance_to(e0), p.distance_to(e1))
