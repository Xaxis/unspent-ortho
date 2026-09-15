extends RefCounted
## Shapes shared by the prop builders. MADE shapes come out uneven: corners
## jittered, faces leaning, rings of irregular radius. FOUND shapes use MeshKit's
## exact box/prism/strut directly.
##
## Every helper keeps the colour's alpha (PropModels' sway/glow codes).


static func j(seed_value: int, i: int, amount: float) -> float:
	return (Rng.hash01(seed_value, i, 0x5eed) - 0.5) * 2.0 * amount


static func tone(col: Color, k: float) -> Color:
	return Color(minf(1.0, col.r * k), minf(1.0, col.g * k), minf(1.0, col.b * k), col.a)


## A box whose 8 corners are pushed about by `amount` (world units) and whose top
## leans: stone courses, planks, peat blocks, walls.
static func rough_box(k: MeshKit, cx: float, y0: float, cz: float, w: float, h: float, d: float, col: Color, top: Color, seed_value: int, amount: float = 0.04) -> void:
	var p: Array[Vector3] = []
	for i in 8:
		var sx := -0.5 if (i & 1) == 0 else 0.5
		var sy := 0.0 if (i & 2) == 0 else 1.0
		var sz := -0.5 if (i & 4) == 0 else 0.5
		var jy := j(seed_value, i * 3 + 2, amount) if sy > 0.0 else 0.0
		p.append(Vector3(cx + sx * w + j(seed_value, i * 3, amount), y0 + sy * h + jy, cz + sz * d + j(seed_value, i * 3 + 1, amount)))
	var tc := col if top.a == 0.0 else top
	# indices: bit0 x, bit1 y, bit2 z
	k.quad(p[2], p[6], p[7], p[3], tc) # top
	k.quad(p[4], p[5], p[7], p[6], col) # +z
	k.quad(p[1], p[0], p[2], p[3], col) # -z
	k.quad(p[5], p[1], p[3], p[7], tone(col, 0.97)) # +x
	k.quad(p[0], p[4], p[6], p[2], tone(col, 1.02)) # -x


## A lumpy low-poly mass (crown, bush, rock) that keeps the colour's alpha code.
## Facets differ by a small tone so the form reads under flat light.
static func blob(k: MeshKit, cx: float, y0: float, cz: float, r: float, h: float, seed_value: int, col: Color, sides: int = 6, waist: float = 0.45) -> void:
	var ring: Array[Vector3] = []
	var mid := y0 + h * waist
	for i in sides:
		var a := float(i) / sides * TAU + Rng.hash01(seed_value, i) * 0.5
		var rr := r * (0.72 + Rng.hash01(seed_value, i, 1) * 0.4)
		ring.append(Vector3(cx + cos(a) * rr, mid + (Rng.hash01(seed_value, i, 2) - 0.5) * h * 0.25, cz + sin(a) * rr))
	var apex := Vector3(cx + (Rng.hash01(seed_value, 9) - 0.5) * r * 0.45, y0 + h, cz + (Rng.hash01(seed_value, 10) - 0.5) * r * 0.45)
	var base := Vector3(cx, y0, cz)
	for i in sides:
		var nxt := (i + 1) % sides
		k.tri(apex, ring[nxt], ring[i], tone(col, 0.94 + Rng.hash01(seed_value, i, 3) * 0.12))
		k.tri(base, ring[i], ring[nxt], tone(col, 0.8))


## A cone tier of a conifer: irregular ring, apex off-centre.
static func tier(k: MeshKit, cx: float, y0: float, cz: float, r: float, y1: float, seed_value: int, col: Color, sides: int = 7, lean: Vector2 = Vector2.ZERO) -> void:
	var ring: Array[Vector3] = []
	for i in sides:
		var a := float(i) / sides * TAU + Rng.hash01(seed_value, i, 4) * 0.35
		var rr := r * (0.78 + Rng.hash01(seed_value, i, 5) * 0.34)
		ring.append(Vector3(cx + cos(a) * rr, y0 + (Rng.hash01(seed_value, i, 6) - 0.5) * 0.08, cz + sin(a) * rr))
	var apex := Vector3(cx + lean.x, y1, cz + lean.y)
	for i in sides:
		var nxt := (i + 1) % sides
		k.tri(apex, ring[nxt], ring[i], tone(col, 0.95 + Rng.hash01(seed_value, i, 7) * 0.1))
	# The dark underside skirt shows at the rim from a steep camera.
	var c0 := Vector3(cx, y0 + 0.06, cz)
	for i in sides:
		k.tri(c0, ring[i], ring[(i + 1) % sides], tone(col, 0.62))


## A flat double-sided triangle standing from base to tip: a blade, a flame, a leaf.
static func blade(k: MeshKit, base: Vector3, tip: Vector3, width: float, angle: float, col: Color) -> void:
	var side := Vector3(cos(angle), 0.0, sin(angle)) * width * 0.5
	k.tri(base - side, base + side, tip, col)
	k.tri(base + side, base - side, tip, tone(col, 0.9))


## A ring of `n` short struts: hoops, coils, flanges.
static func ring(k: MeshKit, c: Vector3, r: float, n: int, thick: float, col: Color, vertical_axis: Vector3 = Vector3.UP) -> void:
	var axis := vertical_axis.normalized()
	var ax := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var ay := axis.cross(ax)
	for i in n:
		var a0 := float(i) / n * TAU
		var a1 := float(i + 1) / n * TAU
		k.strut(c + (ax * cos(a0) + ay * sin(a0)) * r, c + (ax * cos(a1) + ay * sin(a1)) * r, thick, 4, col)


## A sagging cable from a to b, as n straight pieces.
static func cable(k: MeshKit, a: Vector3, b: Vector3, sag: float, n: int, thick: float, col: Color) -> void:
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		k.strut(prev, p, thick, 3, col)
		prev = p
