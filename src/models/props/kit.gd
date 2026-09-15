extends RefCounted
## The two pens a prop is drawn with (docs/ART.md law 3): `made` for
## world.gdshader (hatched, by hand, uneven) and `found` for found.gdshader
## (ruled, clean, exact). Builders put each part in the kit it belongs to, and
## draw with the shapes below: nothing here makes a plain box or a smooth cone.
##
## MADE shapes jitter from a seed, so every copy differs; FOUND shapes never do.

var made := MeshKit.new()
var found := MeshKit.new()


func _init() -> void:
	found.style = Ink.NONE
	found.style2 = Ink.NONE


static func j(seed_value: int, i: int, amount: float) -> float:
	return (Rng.hash01(seed_value, i, 0x5eed) - 0.5) * 2.0 * amount


static func tone(col: Color, k: float) -> Color:
	return Color(minf(1.0, col.r * k), minf(1.0, col.g * k), minf(1.0, col.b * k), col.a)


## Set the hatch hand of the MADE pen (Ink.*) and its sway (0 rigid).
func hand(style: int, sway: float = 0.0, phase: float = 0.0) -> void:
	made.style = style
	made.style2 = style
	made.sway = sway
	made.sway_phase = phase


func still() -> void:
	made.sway = 0.0


# --- MADE shapes -------------------------------------------------------------

## A thin tapering spike from a to b, one segment, no cap: roots, twigs.
func spike(a: Vector3, b: Vector3, r: float, sides: int, col: Color) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 1e-5:
		return
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	made.push(Transform3D(Basis(side, up, side.cross(up)), a))
	made.prism(0, 0, 0, r, length, 0.0, sides, col)
	made.pop()


## A tapered, slightly bent limb from a to b: trunks, branches, posts, logs.
func limb(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col: Color, bend: Vector3 = Vector3.ZERO) -> void:
	var mid := a.lerp(b, 0.5) + bend
	_frustum(a, mid, r0, lerpf(r0, r1, 0.5), sides, col)
	_frustum(mid, b, lerpf(r0, r1, 0.5), r1, sides, col)


func _frustum(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col: Color) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 1e-5:
		return
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	made.push(Transform3D(Basis(side, up, fwd), a))
	made.prism(0, 0, 0, r0, length, r1, sides, col, Color(0, 0, 0, 0), 0.3, false)
	made.pop()


## A faceted stone: an irregular base ring, a smaller leaning top ring and a
## broken top. Never a sphere, never a cube. `lean` tips the top toward +x.
func stone(cx: float, y0: float, cz: float, r: float, h: float, seed_value: int, col: Color, sides: int = 6, lean: float = 0.0, top_col: Color = Color(0, 0, 0, 0)) -> void:
	var tc := col if top_col.a == 0.0 else top_col
	var lo: Array[Vector3] = []
	var mid: Array[Vector3] = []
	var hi: Array[Vector3] = []
	var rot := Rng.hash01(seed_value, 99) * TAU
	var tx := lean * h + j(seed_value, 97, r * 0.15)
	var tz := j(seed_value, 98, r * 0.15)
	for i in sides:
		var a := rot + float(i) / sides * TAU + j(seed_value, i, 0.35)
		var rr := r * (0.8 + Rng.hash01(seed_value, i, 1) * 0.35)
		lo.append(Vector3(cx + cos(a) * rr * 0.92, y0, cz + sin(a) * rr * 0.92))
		mid.append(Vector3(cx + cos(a) * rr + tx * 0.4, y0 + h * (0.45 + j(seed_value, i, 0.1)), cz + sin(a) * rr + tz * 0.4))
		var rt := rr * (0.45 + Rng.hash01(seed_value, i, 2) * 0.25)
		hi.append(Vector3(cx + cos(a + 0.2) * rt + tx, y0 + h * (0.88 + j(seed_value, i + 20, 0.1)), cz + sin(a + 0.2) * rt + tz))
	for i in sides:
		var n := (i + 1) % sides
		made.quad(lo[n], lo[i], mid[i], mid[n], tone(col, 0.96))
		made.quad(mid[n], mid[i], hi[i], hi[n], col)
	var apex := Vector3(cx + tx * 1.05, y0 + h, cz + tz)
	for i in sides:
		made.tri(apex, hi[(i + 1) % sides], hi[i], tc)


## A lumpy faceted clump: crowns, bushes, heather, turf banks. Two rings, so
## the underside turns away from the light and takes the hatching.
func clump(cx: float, y0: float, cz: float, r: float, h: float, seed_value: int, col: Color, sides: int = 7) -> void:
	var rot := Rng.hash01(seed_value, 51) * TAU
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for i in sides:
		var a := rot + float(i) / sides * TAU + j(seed_value, i, 0.3)
		var rr := r * (0.75 + Rng.hash01(seed_value, i, 3) * 0.45)
		lo.append(Vector3(cx + cos(a) * rr, y0 + h * (0.35 + j(seed_value, i + 7, 0.08)), cz + sin(a) * rr))
		var a2 := a + PI / sides
		var r2 := rr * (0.55 + Rng.hash01(seed_value, i, 4) * 0.2)
		hi.append(Vector3(cx + cos(a2) * r2, y0 + h * (0.78 + j(seed_value, i + 9, 0.08)), cz + sin(a2) * r2))
	var top := Vector3(cx + j(seed_value, 40, r * 0.2), y0 + h, cz + j(seed_value, 41, r * 0.2))
	var bottom := Vector3(cx, y0, cz)
	for i in sides:
		var n := (i + 1) % sides
		made.tri(bottom, lo[i], lo[n], tone(col, 0.85))
		made.tri(lo[n], lo[i], hi[i], col)
		made.tri(lo[n], hi[i], hi[n], tone(col, 1.03))
		made.tri(top, hi[n], hi[i], tone(col, 1.05))


## One tier of a conifer: a jagged star of drooping branch tips round an
## off-centre apex. Never a smooth cone. The camera never sees under a tier, so
## only the lowest (`under` alpha > 0) gets a darker skirt, for its shadow rim.
func tier(cx: float, y_rim: float, cz: float, r: float, rise: float, points: int, droop: float, seed_value: int, col: Color, under: Color) -> void:
	var rot := Rng.hash01(seed_value, 61) * TAU
	var ring: Array[Vector3] = []
	for i in points * 2:
		var a := rot + float(i) / (points * 2) * TAU + j(seed_value, i, 0.12)
		if i % 2 == 0:
			var rr := r * (0.8 + Rng.hash01(seed_value, i, 5) * 0.4)
			ring.append(Vector3(cx + cos(a) * rr, y_rim - droop * (0.7 + Rng.hash01(seed_value, i, 6) * 0.6), cz + sin(a) * rr))
		else:
			var rn := r * (0.42 + Rng.hash01(seed_value, i, 7) * 0.12)
			ring.append(Vector3(cx + cos(a) * rn, y_rim + droop * 0.15, cz + sin(a) * rn))
	var apex := Vector3(cx + j(seed_value, 62, r * 0.12), y_rim + rise, cz + j(seed_value, 63, r * 0.12))
	var hub := Vector3(cx, y_rim - droop * 0.2, cz)
	var n := ring.size()
	for i in n:
		var m := (i + 1) % n
		made.tri(apex, ring[m], ring[i], col if i % 2 == 0 else tone(col, 0.93))
		if under.a > 0.0 and i % 2 == 0:
			made.tri(hub, ring[i], ring[(i + 2) % n], under)


## A small two-sided triangle: a fleck of flower, ember, shell, chip.
func fleck(p: Vector3, a: Vector3, b: Vector3, col: Color) -> void:
	made.tri(p, a, b, col)
	made.tri(p, b, a, col)


## A flat blade standing from base to tip, seen from both sides: grass, reed,
## flame, frond.
func blade(base: Vector3, tip: Vector3, width: float, angle: float, col: Color) -> void:
	var side := Vector3(cos(angle), 0.0, sin(angle)) * width * 0.5
	made.tri(base - side, base + side, tip, col)
	made.tri(base + side, base - side, tip, tone(col, 0.92))


## A hand-built block: corners jittered by `rough`, the top `taper`ed and
## leaning `lean` toward +x. Walls, chimneys, slabs, planks.
func slab(cx: float, y0: float, cz: float, w: float, h: float, d: float, seed_value: int, col: Color, top_col: Color = Color(0, 0, 0, 0), rough: float = 0.03, taper: float = 0.0, lean: float = 0.0) -> void:
	var p: Array[Vector3] = []
	for i in 8:
		var sx := -0.5 if (i & 1) == 0 else 0.5
		var sy := 0.0 if (i & 2) == 0 else 1.0
		var sz := -0.5 if (i & 4) == 0 else 0.5
		var shrink := 1.0 - taper * sy
		p.append(Vector3(cx + sx * w * shrink + j(seed_value, i * 3, rough) + lean * sy * h, y0 + sy * h + (j(seed_value, i * 3 + 2, rough) if sy > 0.0 else 0.0), cz + sz * d * shrink + j(seed_value, i * 3 + 1, rough)))
	var tc := col if top_col.a == 0.0 else top_col
	made.quad(p[2], p[6], p[7], p[3], tc)
	made.quad(p[4], p[5], p[7], p[6], col)
	made.quad(p[1], p[0], p[2], p[3], tone(col, 0.97))
	made.quad(p[5], p[1], p[3], p[7], tone(col, 0.98))
	made.quad(p[0], p[4], p[6], p[2], col)


## A wall face as a quad on a plane, a hair proud of it: doors, windows, marks.
func face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	made.quad(a, b, c, d, col)


## A sagging line from a to b as n pieces: rope, wire, fishing line (MADE).
func sag(a: Vector3, b: Vector3, dip: float, n: int, thick: float, col: Color) -> void:
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector3.DOWN * dip * 4.0 * t * (1.0 - t)
		made.strut(prev, p, thick, 3, col)
		prev = p


# --- FOUND shapes ------------------------------------------------------------

## An exact post or tube between a and b, n-sided, no taper.
func rod(a: Vector3, b: Vector3, r: float, sides: int, col: Color) -> void:
	found.strut(a, b, r, sides, col)


## An exact block with chamfered corners, centred on (cx, cz), standing on y0.
## Eight sides, so it never reads as a box.
func chamfer(cx: float, y0: float, cz: float, w: float, h: float, d: float, cut: float, col: Color, top_col: Color = Color(0, 0, 0, 0)) -> void:
	var tc := col if top_col.a == 0.0 else top_col
	var hw := w * 0.5
	var hd := d * 0.5
	var pts: Array[Vector2] = [Vector2(hw - cut, -hd), Vector2(hw, -hd + cut), Vector2(hw, hd - cut), Vector2(hw - cut, hd),
		Vector2(-hw + cut, hd), Vector2(-hw, hd - cut), Vector2(-hw, -hd + cut), Vector2(-hw + cut, -hd)]
	var y1 := y0 + h
	var inset := minf(cut, h * 0.3)
	for i in 8:
		var a := pts[i]
		var b := pts[(i + 1) % 8]
		found.quad(Vector3(cx + b.x, y0, cz + b.y), Vector3(cx + a.x, y0, cz + a.y), Vector3(cx + a.x, y1 - inset, cz + a.y), Vector3(cx + b.x, y1 - inset, cz + b.y), col)
		# A bevel round the top edge.
		var ai := a * (1.0 - inset / maxf(hw, hd))
		var bi := b * (1.0 - inset / maxf(hw, hd))
		found.quad(Vector3(cx + b.x, y1 - inset, cz + b.y), Vector3(cx + a.x, y1 - inset, cz + a.y), Vector3(cx + ai.x, y1, cz + ai.y), Vector3(cx + bi.x, y1, cz + bi.y), tone(col, 1.08))
	var centre := Vector3(cx, y1, cz)
	for i in 8:
		var a := pts[i] * (1.0 - inset / maxf(hw, hd))
		var b := pts[(i + 1) % 8] * (1.0 - inset / maxf(hw, hd))
		found.tri(centre, Vector3(cx + b.x, y1, cz + b.y), Vector3(cx + a.x, y1, cz + a.y), tc)


## A flat exact panel on the plane of quad (a, b, c, d), with a darker rim and
## rivets at its corners: plate taken off a machine.
func plate(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, rim: Color, rivet: Color) -> void:
	var n := (c - b).cross(a - b).normalized() * 0.006
	found.quad(a + n, b + n, c + n, d + n, rim)
	var centre := (a + b + c + d) * 0.25
	var k := 0.86
	var ai := centre.lerp(a, k) + n * 2.0
	var bi := centre.lerp(b, k) + n * 2.0
	var ci := centre.lerp(c, k) + n * 2.0
	var di := centre.lerp(d, k) + n * 2.0
	found.quad(ai, bi, ci, di, col)
	var u := (b - a).normalized() * 0.014
	var v := (d - a).normalized() * 0.014
	for p: Vector3 in [ai, bi, ci, di]:
		var q := centre.lerp(p, 0.88) + n * 3.0
		found.quad(q - u - v, q + u - v, q + u + v, q - u + v, rivet)


## A cable from a to b hanging `dip` at its middle (FOUND: the grid's).
func cable(a: Vector3, b: Vector3, dip: float, n: int, thick: float, col: Color) -> void:
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector3.DOWN * dip * 4.0 * t * (1.0 - t)
		found.strut(prev, p, thick, 3, col)
		prev = p


## A ring of exact struts: hoops, coils, flanges.
func hoop(c: Vector3, r: float, n: int, thick: float, col: Color, axis: Vector3 = Vector3.UP) -> void:
	var ax := axis.normalized()
	var u := ax.cross(Vector3.FORWARD if absf(ax.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var v := ax.cross(u)
	for i in n:
		var a0 := float(i) / n * TAU
		var a1 := float(i + 1) / n * TAU
		found.strut(c + (u * cos(a0) + v * sin(a0)) * r, c + (u * cos(a1) + v * sin(a1)) * r, thick, 4, col)


## Set the sway of every MADE vertex from index `start` by height: 0 at or
## below y0, `w` at y1 and above. Keeps bases planted while tips move.
func sway_by_height(start: int, y0: float, y1: float, w: float) -> void:
	for i in range(start, made.vertex_count()):
		var y := made.verts[i].y
		var t := clampf((y - y0) / maxf(y1 - y0, 1e-4), 0.0, 1.0)
		# Never exactly 0: a zero weight would read as rigid, patchy geometry.
		made.uv2s[i] = Vector2(maxf(w * t, 0.0001), made.uv2s[i].y)
