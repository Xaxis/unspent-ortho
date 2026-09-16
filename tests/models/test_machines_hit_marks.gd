extends TestCase
## Hit marks against the thing they are proving (art review wave N, finding 11):
## a filled paper star 28 px across sat on the machine's head and a solid wedge
## below it, and between them they hid most of the amber working part at the one
## moment the player most needed to see it. docs/ART.md §7 asks for a SHORT ink
## burst and sparks off plate as two or three bright pixels.
##
## The burst is now an open figure: no filled core, strokes thrown outward from
## MobFx.BURST_OPEN of its radius. That fraction is compiled into the shader as
## OPEN and measured here against every machine's real working part, so the two
## can never drift apart.

const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"runner"]
## What 40_fight passes for a blow landing in a machine's working part.
const MACHINE_HIT := 1.1
## One screen pixel at the game's default view height (14 units over 360 px).
const TEXEL := 14.0 / 360.0


static func camera_axes() -> Array[Vector3]:
	var b := Basis.from_euler(Vector3(deg_to_rad(-57.0), deg_to_rad(45.0), 0.0))
	return [b.x, b.y]


## [part pixels on screen, pixels the burst's ink could possibly touch]: the ring
## between its open heart and its outer reach, measured about the point the mark
## is pinned to (40_fight draws it at part_position()).
static func part_under_a_burst(m: MachineModel, clear: float, outer: float) -> Array:
	var mi: MeshInstance3D = m.surfaces.get(&"part")
	if mi == null:
		return [0, 0]
	var axes := camera_axes()
	var centre := m.model_space(m.part_anchor).origin if m.part_anchor != null else Vector3.ZERO
	var seen := {}
	var tris := m.posed_triangles(mi)
	for t in range(0, tris.size(), 3):
		var p: Array[Vector2] = []
		for i in 3:
			var d := tris[t + i] - centre
			p.append(Vector2(d.dot(axes[0]), d.dot(axes[1])) / TEXEL)
		var area := (p[1] - p[0]).cross(p[2] - p[0])
		if absf(area) < 1e-6:
			continue
		for y in range(floori(minf(p[0].y, minf(p[1].y, p[2].y))), ceili(maxf(p[0].y, maxf(p[1].y, p[2].y))) + 1):
			for x in range(floori(minf(p[0].x, minf(p[1].x, p[2].x))), ceili(maxf(p[0].x, maxf(p[1].x, p[2].x))) + 1):
				var q := Vector2(x + 0.5, y + 0.5)
				var w0 := (p[1] - p[0]).cross(q - p[0]) / area
				var w1 := (p[2] - p[1]).cross(q - p[1]) / area
				var w2 := (p[0] - p[2]).cross(q - p[2]) / area
				if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
					seen[Vector2i(x, y)] = true
	var under := 0
	for key: Vector2i in seen:
		var r := Vector2(key.x + 0.5, key.y + 0.5).length()
		if r >= clear and r <= outer:
			under += 1
	return [seen.size(), under]


## The burst's ink lives in the ring between its open heart and the quad's edge.
## Nothing is drawn inside the heart, so this is an upper bound on how much of the
## working part the mark could possibly be standing in front of — and the real
## figure is a fraction of it, because the ring holds seven thin strokes and not
## a disc.
func test_a_burst_leaves_the_working_part_showing() -> void:
	MobFx.texel = TEXEL
	var clear := MobFx.burst_clear_px(MACHINE_HIT)
	var outer := MobFx.at_least(MACHINE_HIT, MobFx.BURST_PX) / TEXEL * 0.5
	gt(clear, 6.0, "a burst's open heart is %.1f px of radius" % clear)
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		m.settle()
		var got := part_under_a_burst(m, clear, outer)
		m.free()
		gt(float(got[0]), 4.0, "%s has a part on screen" % kid)
		var share := float(got[1]) / float(got[0])
		lt(share, 0.34, "%s: the mark could cover %.0f%% of its part (%d of %d px)" % [kid, share * 100.0, int(got[1]), int(got[0])])


func test_no_mark_is_bigger_than_a_machine_is_wide() -> void:
	# A mark is read and gone. It may never be the biggest thing in the frame:
	# the smallest machine in the roster is about 26 px across at gameplay zoom.
	for got: Array in [["burst", MobFx.BURST_PX], ["clang", MobFx.CLANG_PX], ["tell", MobFx.TELL_PX], ["ring", MobFx.RING_PX], ["puff", MobFx.PUFF_PX]]:
		lt(float(got[1]), 27.0, "%s is %.0f px at its smallest" % got)
	# And the two that land on a struck body are the ones held tightest.
	lt(MobFx.BURST_PX, 24.0, "burst")
	lt(MobFx.CLANG_PX, 22.0, "clang")


func test_the_shader_and_the_gate_share_one_open_heart() -> void:
	# The number the test measures against is the number the shader draws with.
	var code: String = MobFx._shader(&"over").code
	check(code.contains("#define OPEN %0.4f" % MobFx.BURST_OPEN), "the shader is compiled with OPEN")
	check(not code.contains("return paper_out();\n\t\t}\n\t\te = r - star"), "no filled star survives at the heart of a burst")
	check(code.contains("mix(OPEN, 0.84, pr)"), "the burst's strokes start outside the open heart")


func test_a_tell_can_be_aimed_at_the_part_it_is_warning_about() -> void:
	eq(MobFx.FLICK_DOWN, Vector2(0.0, 1.0), "down the screen")
	eq(MobFx.FLICK_UP, Vector2(0.0, -1.0), "up the screen")
	var root := Node3D.new()
	tree.root.add_child(root)
	MobFx.texel = TEXEL
	MobFx.tell(root, Vector3(3, 1, 3), Vector3.UP, 0.3, 1, 0.8, MobFx.FLICK_DOWN)
	MobFx.tell(root, Vector3(3, 1, 3), Vector3.UP, 0.3, 2, 0.8)
	var marks := root.find_children("*", "MeshInstance3D", true, false)
	eq(marks.size(), 2, "two marks")
	var aimed := (marks[0] as MeshInstance3D).material_override as ShaderMaterial
	var plain := (marks[1] as MeshInstance3D).material_override as ShaderMaterial
	eq(aimed.get_shader_parameter(&"dir"), MobFx.FLICK_DOWN, "aimed at the part")
	eq(plain.get_shader_parameter(&"dir"), MobFx.FLICK_UP, "over a body, as before")
	# Aimed down the fan hangs above the thing; it must clear the part it marks.
	gt((marks[0] as MeshInstance3D).global_position.y, 1.0, "the fan stands above what it points at")
	root.queue_free()
