class_name SurvivalMarks
## The drawn vocabulary of taking and making (docs/LOOK.md): ink ticks, stipple
## dots, flecks of stuff, and the small tokens of what you took that hop into
## your hands. Shared meshes built once; a Pool is a MultiMesh of one mark.
##
##   SurvivalMarks.material()          the mark material (unlit, no depth, sky-tinted)
##   SurvivalMarks.overlay()           the same, drawn over whatever stands in front (ink bursts, sparks)
##   SurvivalMarks.dot() / tick() / shard()
##   SurvivalMarks.glyph_for(&"timber") -> &"log";  SurvivalMarks.glyph(&"log") -> ArrayMesh
##   var p := SurvivalMarks.Pool.new(SurvivalMarks.dot(), 64, SurvivalMarks.material(), parent)
##   p.put(i, pos, size, colour);  p.put_xf(i, xf, colour);  p.hide(i)
##
## Colour alpha on the mark materials: 1 its own colour tinted by the sky, 0.5
## (CONTRAST) ink or paper by what is drawn behind, 0 its own light (sparks, embers).

## A mark colour meaning "ink or paper, whichever reads on what is behind it" (mark.gdshaderinc).
const CONTRAST := Color(0.0, 0.0, 0.0, 0.5)

const GLYPHS: Array[StringName] = [&"log", &"stone", &"lime", &"ore_iron", &"ore_copper", &"ore_tin", &"coal",
	&"brim", &"plate", &"shell", &"green", &"weed", &"resin", &"turf", &"tool", &"lump"]

static var _mat: ShaderMaterial
static var _over: ShaderMaterial
static var _found: ShaderMaterial
static var _dot: ArrayMesh
static var _tick: ArrayMesh
static var _shard: ArrayMesh
static var _glyphs: Dictionary = {}


class Pool:
	var mm: MultiMesh
	var node: MultiMeshInstance3D
	var size: int

	## `anchored`: each mark can name the world point whose backdrop picks its
	## CONTRAST colour (put_xf's `anchor`), so a moving stroke keeps one colour.
	func _init(mesh: Mesh, n: int, mat: Material, parent: Node, anchored: bool = false) -> void:
		size = n
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = anchored
		mm.mesh = mesh
		mm.instance_count = n
		node = MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 16384.0
		parent.add_child(node)
		for i in n:
			hide(i)

	func put(i: int, pos: Vector3, s: float, col: Color) -> void:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), pos))
		mm.set_instance_color(i, col)

	func put_xf(i: int, xf: Transform3D, col: Color, anchor: Vector3 = Vector3.INF) -> void:
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, col)
		if mm.use_custom_data:
			var on := anchor.is_finite()
			mm.set_instance_custom_data(i, Color(anchor.x, anchor.y, anchor.z, 1.0) if on else Color(0, 0, 0, 0))

	func hide(i: int) -> void:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -1000, 0)))


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://src/systems/survival_fx/mark.gdshader")
		# After the full-screen outline pass, which would otherwise paint over them.
		_mat.render_priority = 10
	return _mat


## The ruler's material for FOUND pieces (plate tokens and flecks off machines' leavings).
static func found_material() -> ShaderMaterial:
	if _found == null:
		_found = ShaderMaterial.new()
		_found.shader = preload("res://src/render/found.gdshader")
	return _found


## FOUND glyphs are drawn by the ruler, not the hand.
static func is_found_glyph(mesh: Mesh) -> bool:
	return _glyphs.get(&"plate", null) == mesh


static func overlay() -> ShaderMaterial:
	if _over == null:
		_over = ShaderMaterial.new()
		_over.shader = preload("res://src/systems/survival_fx/mark_over.gdshader")
		_over.render_priority = 11
	return _over


## A dot of radius 1: an octahedron, round enough at one or two pixels.
static func dot() -> ArrayMesh:
	if _dot == null:
		var k := MeshKit.new()
		var c := Color.WHITE
		var px := Vector3.RIGHT
		var nx := Vector3.LEFT
		var pz := Vector3.BACK
		var nz := Vector3.FORWARD
		var up := Vector3.UP
		var dn := Vector3.DOWN
		for pair: Array in [[px, pz], [pz, nx], [nx, nz], [nz, px]]:
			k.tri(up, pair[0], pair[1], c)
			k.tri(dn, pair[1], pair[0], c)
		_dot = k.build()
	return _dot


## An ink tick: a thin three-sided bar from the origin to +Y 1, radius 1.
## Scale its X and Z by the stroke's thickness and Y by its length.
static func tick() -> ArrayMesh:
	if _tick == null:
		var k := MeshKit.new()
		k.prism(0, 0, 0, 1.0, 1.0, 1.0, 3, Color.WHITE, Color(0, 0, 0, 0), 0.0, true)
		_tick = k.build()
	return _tick


## A flake of stuff: a lopsided tetrahedron about 1 across, so its tumble shows two tones.
static func shard() -> ArrayMesh:
	if _shard == null:
		var k := MeshKit.new()
		var a := Vector3(-0.5, -0.2, -0.35)
		var b := Vector3(0.55, -0.25, -0.1)
		var c := Vector3(-0.1, -0.15, 0.5)
		var d := Vector3(0.05, 0.4, 0.0)
		k.tri(a, b, d, Color.WHITE)
		k.tri(b, c, d, Color(0.82, 0.82, 0.82))
		k.tri(c, a, d, Color(0.9, 0.9, 0.9))
		k.tri(a, c, b, Color(0.7, 0.7, 0.7))
		_shard = k.build()
	return _shard


## A thin stroke from `a` to `b`, `thick` tiles across.
static func stroke_xf(a: Vector3, b: Vector3, thick: float) -> Transform3D:
	var axis := b - a
	var length := axis.length()
	if length < 1e-4:
		return Transform3D(Basis().scaled(Vector3.ZERO), a)
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	return Transform3D(Basis(side * thick, axis, fwd * thick), a)


## Which token a taken or made item hops into your hands as.
static func glyph_for(item: StringName) -> StringName:
	match item:
		&"timber", &"driftwood", &"haft", &"stave":
			return &"log"
		&"stone":
			return &"stone"
		&"limestone", &"lime", &"salt", &"kelp_ash":
			return &"lime"
		&"iron_ore", &"iron":
			return &"ore_iron"
		&"copper_ore", &"copper":
			return &"ore_copper"
		&"tin_ore", &"tin":
			return &"ore_tin"
		&"coal", &"charcoal":
			return &"coal"
		&"brimstone":
			return &"brim"
		&"scrap":
			return &"plate"
		&"mussels", &"whelks":
			return &"shell"
		&"samphire", &"berries", &"reeds", &"gorse_cut", &"crottle":
			return &"green"
		&"wrack":
			return &"weed"
		&"resin", &"pitch", &"oil":
			return &"resin"
		&"peat":
			return &"turf"
	if Items.has_edge(item):
		return &"tool"
	return &"lump"


static func glyph(name: StringName) -> ArrayMesh:
	if not _glyphs.has(name):
		var k := MeshKit.new()
		match name:
			&"log":
				# A length of wood, bark dark, the sawn end pale and a little proud.
				var a := Vector3(-0.17, 0.04, -0.03)
				var e := Vector3(0.17, 0.07, 0.04)
				k.strut(a, e, 0.038, 6, Palette.EARTH[2])
				var dir := (e - a).normalized()
				k.push(Transform3D(Basis(dir.cross(Vector3.UP).normalized(), dir, dir.cross(dir.cross(Vector3.UP)).normalized() * -1.0), e))
				k.prism(0, 0, 0, 0.036, 0.014, 0.032, 6, Palette.SAND[4], Palette.SAND[5])
				k.pop()
			&"stone":
				k.rock(0, 0, 0, 0.09, 0.11, 11, Palette.STONE[4], 5)
			&"lime":
				k.rock(0, 0, 0, 0.09, 0.09, 12, Palette.LINEN[5], 5)
			&"ore_iron":
				k.rock(0, 0, 0, 0.09, 0.11, 13, Palette.SLATE[3], 5)
				k.rock(0.03, 0.06, 0.03, 0.045, 0.06, 14, Palette.RUST[4], 4)
			&"ore_copper":
				k.rock(0, 0, 0, 0.09, 0.11, 15, Palette.SLATE[3], 5)
				k.rock(0.03, 0.06, 0.03, 0.045, 0.06, 16, Palette.SPRUCE[4], 4)
			&"ore_tin":
				k.rock(0, 0, 0, 0.09, 0.11, 17, Palette.SLATE[3], 5)
				k.rock(0.03, 0.06, 0.03, 0.045, 0.06, 18, Palette.RIME[5], 4)
			&"coal":
				k.rock(0, 0, 0, 0.08, 0.1, 19, Palette.INK[3], 5)
			&"brim":
				k.rock(0, 0, 0, 0.08, 0.1, 20, Palette.COPPER[4], 5)
			&"plate":
				# FOUND: a bent, exact piece of plate, both faces drawn.
				k.style = Ink.NONE
				k.style2 = Ink.NONE
				var pts: Array[Vector3] = [Vector3(-0.12, 0.02, -0.08), Vector3(0.1, 0.05, -0.1), Vector3(0.13, 0.09, 0.08), Vector3(-0.08, 0.05, 0.1)]
				k.quad(pts[3], pts[2], pts[1], pts[0], Palette.PLATE[4])
				k.quad(pts[0], pts[1], pts[2], pts[3], Palette.PLATE[2])
				k.strut(pts[1], pts[2], 0.012, 3, Palette.RUST[3])
			&"shell":
				k.prism(-0.02, 0, 0, 0.06, 0.05, 0.035, 4, Palette.BRINE[1], Palette.INK[3], 0.3)
				k.prism(0.07, 0, 0.04, 0.045, 0.04, 0.025, 4, Palette.BRINE[2], Palette.LINEN[4], 1.1)
			&"green":
				for i in 4:
					var a := float(i) / 4.0 * TAU + 0.4
					k.strut(Vector3(0, 0, 0), Vector3(cos(a) * 0.08, 0.16 + i * 0.015, sin(a) * 0.08), 0.02, 3, Palette.MOSS[4] if i % 2 else Palette.MOSS[3])
			&"weed":
				k.strut(Vector3(-0.1, 0.02, 0), Vector3(0.0, 0.08, 0.04), 0.03, 3, Palette.EARTH[3])
				k.strut(Vector3(0.0, 0.08, 0.04), Vector3(0.1, 0.03, -0.02), 0.03, 3, Palette.MOSS[2])
			&"resin":
				k.prism(0, 0, 0, 0.06, 0.13, 0.0, 5, Palette.COPPER[4], Color(0, 0, 0, 0), 0.2)
			&"turf":
				# A cut sod: a lopsided dark lump, torn on one side, with its grass still on it.
				k.rock(0, 0, 0, 0.1, 0.08, 22, Palette.EARTH[1], 6)
				k.rock(0.05, 0.0, 0.03, 0.06, 0.06, 23, Palette.EARTH[2], 5)
				for i in 4:
					var a := float(i) / 4.0 * TAU + 0.7
					var root := Vector3(cos(a) * 0.04, 0.07, sin(a) * 0.035)
					k.strut(root, root + Vector3(cos(a) * 0.04, 0.07 + i * 0.01, sin(a) * 0.03), 0.014, 3, Palette.MOSS[3] if i % 2 else Palette.MOSS[4])
			&"tool":
				k.strut(Vector3(-0.13, 0.02, 0.0), Vector3(0.08, 0.06, 0.0), 0.022, 4, Palette.EARTH[3])
				k.strut(Vector3(0.06, 0.02, -0.07), Vector3(0.1, 0.1, 0.07), 0.03, 3, Palette.STONE[4])
			_:
				k.rock(0, 0, 0, 0.08, 0.09, 21, Palette.SAND[4], 5)
		_glyphs[name] = k.build()
	return _glyphs[name]
