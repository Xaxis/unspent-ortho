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
## World units per screen pixel at the play camera, in the BASE's own rows -- the
## modern form (tests/render/test_found_drawn.gd). It read 14.0 / 360.0, the old
## floor's, while the constants under test are pixels of 1080 rows: a mark came
## out three times its real size against a part measured correctly, and the gate
## below then read 42% of a harvester's working part covered instead of 14%.
const TEXEL := 15.0 / 1080.0


## The play camera's own angles, off the rig rather than written out again.
static func camera_axes() -> Array[Vector3]:
	var rig := CameraRig.new()
	var b := Basis.from_euler(Vector3(deg_to_rad(-rig.pitch_deg), deg_to_rad(rig.yaw_deg), 0.0))
	rig.free()
	return [b.x, b.y]


## How wide a machine really stands on screen, in pixels of the 1080-row frame,
## at the bearing that shows it WIDEST -- the world may deal it any of them, and
## the widest is the only one a mark can be asked to stay under. (Seen edge-on a
## lineman is 32.7 px and nothing legible fits inside that; the band's LEAST_PX
## is the deliberate answer, and this is where you would see it bite.)
static func body_px(kind: StringName) -> float:
	var axes := camera_axes()
	var unit: float = MobFx.px(1.0)
	var m := FigureModel.create(kind) as MachineModel
	m.settle()
	var widest := 0.0
	for b in 8:
		var turn := Basis(Vector3.UP, TAU * float(b) / 8.0)
		var lo := INF
		var hi := -INF
		for key: StringName in m.surfaces:
			var mi: MeshInstance3D = m.surfaces[key]
			if mi == null:
				continue
			for p: Vector3 in m.posed_triangles(mi):
				var x := (turn * p).dot(axes[0]) / unit
				lo = minf(lo, x)
				hi = maxf(hi, x)
		if lo <= hi:
			widest = maxf(widest, hi - lo)
	m.free()
	return widest


## How wide the FIGHT thinks that machine is: twice its roster radius, which is
## what it places and reaches with, and what a mark on it is now sized by.
static func body_world(kind: StringName) -> float:
	return 2.0 * float(Roster.row(kind).get("radius", 0.4))


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
	# `texel` IS A STATIC ON MobFx, so a test that sets it and walks away rewrites
	# the pen's scale for every test that runs after it IN THE SAME PROCESS. Left
	# set, `MobFx.flash_radius` floors at `pen_px(4.0)` and a 0.8-tall body comes
	# out flashing 0.76 of itself -- which is `tests/render/test_marks.gd` failing
	# in another directory for a reason nothing in its own file mentions, and only
	# in a gate shard that happens to run this file first. It passes alone, and it
	# passes in a full single-process run where the order differs, which is what
	# made it look intermittent rather than caused.
	# `tests/fight/test_mob_view.gd` already keeps this discipline (`was`, restore);
	# this file set the global and did not put it back.
	var was := MobFx.texel
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
	MobFx.texel = was


func test_no_mark_that_lands_on_a_body_is_bigger_than_the_body() -> void:
	# A record of a blow is drawn ON the thing it proves and may never be the thing
	# standing in front of it. This test used to assert that against the sentence
	# "the smallest machine in the roster is about 78 px across" -- and 78 was 26
	# multiplied by three when the frame's rows tripled. Nobody had ever taken the
	# number. Taken here, through the real rig at every bearing, the roster runs
	# from a lineman 32.7 px edge-on to a harvester at 354.2: ELEVEN TO ONE, which
	# is why the single absolute floor it was guarding could not be right for both
	# ends and came out at 66 px on a runner 51.5 wide.
	#
	# So the rule is `MobFx.on_body`, and this measures what it produces rather
	# than what anyone remembers.
	MobFx.texel = 15.0 / float(UiBase.SIZE.y)
	var least := INF
	var who := &""
	for kid in KINDS:
		var across := body_world(kid)
		var wide := body_px(kid)
		if wide < least:
			least = wide
			who = kid
		# The two marks that land ON the struck body. MACHINE_HIT is the largest
		# size any caller asks for, so if that fits, every smaller one does.
		var burst_px := MobFx.on_body(MACHINE_HIT, across) / MobFx.px(1.0)
		var clang_px := MobFx.on_body(1.0, across) / MobFx.px(1.0)
		lt(burst_px, wide, "%s: a burst is %.0f px on a body %.0f px across" % [kid, burst_px, wide])
		lt(clang_px, wide, "%s: a clang is %.0f px on the same" % [kid, clang_px])
	gt(least, 12.0, "the narrowest machine (%s) is %.0f px at its widest bearing" % [who, least])


func test_the_band_is_a_share_of_the_body_with_a_floor_under_it() -> void:
	# The construction, not a sample of it: whatever a caller asks for, a mark on a
	# body is at most BODY_SHARE of that body -- and at least LEAST_PX, which wins
	# only when the body is too small for both rules to hold at once.
	MobFx.texel = 15.0 / float(UiBase.SIZE.y)
	var big := MobFx.on_body(99.0, 2.4)
	near(big, 2.4 * MobFx.BODY_SHARE, 1e-4, "a huge ask is cut to the body's share")
	var small := MobFx.on_body(0.01, 2.4)
	near(small, MobFx.px(MobFx.LEAST_PX), 1e-4, "a tiny ask is lifted to the floor")
	lt(MobFx.BODY_SHARE, 1.0, "a mark never covers the whole body")
	# A gull-sized body: the floor wins, deliberately, and it is bigger than the
	# body. That is the trade -- a mark too small to see is not a record.
	gt(MobFx.on_body(0.5, 0.2), 0.2 * MobFx.BODY_SHARE, "on something tiny the floor wins")


## The tell is the one mark drawn before anything has happened, read at the edge
## of vision while the player is deciding to dodge. Shrunk into the hit marks'
## budget it became a single thin bar beside the machine; and drawn in INK[0] on
## a FOUND body — which is now deliberately darker than the ground it stands on —
## it had almost no contrast at all. It is a fan, it is big enough to be a fan,
## and every stroke is backed by page.
func test_a_tell_is_a_fan_that_reads_on_a_dark_body() -> void:
	gt(MobFx.TELL_PX, 87.0, "a tell is %.0f px at its smallest" % MobFx.TELL_PX)
	# Not so big that it becomes the frame: it is still smaller than the swing.
	lt(MobFx.TELL_PX, MobFx.STREAK_PX, "and smaller than a swing's speed lines")
	# More than the one pixel every other mark gets, so it reads on a hull; and
	# not so much that the page swallows the pen (at 2.6 the fan read as three
	# white lozenges with a slit down each).
	gt(MobFx.TELL_HALO, 1.4, "%.1f px of paper round each stroke" % MobFx.TELL_HALO)
	lt(MobFx.TELL_HALO, 2.2, "and the ink still leads")
	var code: String = MobFx._shader(&"over").code
	check(code.contains("uniform float mark_halo"), "the halo is the shader's, not a constant")
	check(code.contains("return inked(e, mark_halo);"), "the tell's strokes take it")
	MobFx.texel = TEXEL
	var root := Node3D.new()
	tree.root.add_child(root)
	MobFx.tell(root, Vector3(3, 1, 3), Vector3.UP, 0.3, 1, 0.8, MobFx.FLICK_DOWN)
	var mi := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mat := mi.material_override as ShaderMaterial
	eq(float(mat.get_shader_parameter(&"mark_halo")), MobFx.TELL_HALO, "set on the mark")
	root.queue_free()


## THE HEART, AT THE PEN THE GAME ACTUALLY DRAWS WITH.
##
## `BURST_OPEN` says nothing is inked inside a fraction of the radius, and the
## test above measures against that fraction -- but it measures an analytic ring,
## so it cannot see the strokes MEET. They can, because the quad's radius R is in
## pens and shrinks as the pen widens, while a stroke's width does not: seven
## roots that were 12.5 pens apart at PEN 1 are 3.7 apart at PEN 3, and a root
## 1.5 wide with a pen of paper on each flank is 5.0 across. That is the filled
## paper star this file was written to prevent, and at PEN 3 with the old taper
## it came back -- measured on the frame, the ground showing inside the heart of
## a plain burst fell from 99% to 55%.
##
## So this is the arithmetic of it, and it is the reason the taper runs thin-to-
## heavy rather than the other way. Anything that moves PEN, the stroke count,
## the taper or the halo now has to face it.
func test_the_bursts_roots_clear_each_other_at_the_pen_it_is_drawn_with() -> void:
	# `BURST_OPEN` says nothing is inked inside a fraction of the radius, and the
	# test above measures against that fraction -- but it measures an analytic ring
	# and cannot see the strokes MEET. They can, because the quad's radius is in
	# PENS and shrinks both when the pen widens and when the body it lands on is
	# small, while a stroke's width does neither.
	#
	# BOTH ends of that bit. At PEN 1 on the old absolute floor a burst's roots
	# stood 12.5 pens apart; at PEN 3 they are 3.7; and on the NARROWEST machine in
	# the roster, where `on_body` makes the quad smaller again, they would be 1.3.
	# Measured on the frame, the ground inside a plain burst's heart fell from 99%
	# to 55% on the first of those. So the shader draws as many strokes as clear at
	# whatever size it is given, and this holds it to that at the size the game
	# really asks for -- the SMALLEST body in the roster, which is the worst case.
	MobFx.texel = 15.0 / float(UiBase.SIZE.y)
	var tightest := INF
	var who := &""
	for kid in KINDS:
		var across := body_world(kid)
		if across < tightest:
			tightest = across
			who = kid
	var r: float = MobFx.on_body(MACHINE_HIT, tightest) / MobFx.pen_px(1.0) * 0.5
	var r0: float = MobFx.BURST_OPEN * MobFx.BURST_SHORT * (r - 2.0)
	var wide: float = 2.0 * (MobFx.BURST_ROOT + MobFx.MARK_HALO)
	var fits := clampi(int(floor(TAU * r0 / wide)), 3, MobFx.BURST_STROKES)
	gt(r0, 0.0, "the tightest burst (%s) has a heart at all" % who)
	# What the shader will draw there, and that it clears -- except at the floor of
	# three, which is deliberate: below that a burst stops being one.
	if fits > 3:
		gt(TAU * r0 / float(fits), wide, "%s: %d strokes, roots %.2f pens apart, %.2f wide" % [who, fits, TAU * r0 / float(fits), wide])
	lt(float(fits), float(MobFx.BURST_STROKES) + 0.5, "never more than the full count")
	# And the full count IS reached on a big body, or the rule has quietly become
	# "always three".
	var big: float = MobFx.on_body(MACHINE_HIT, 2.4) / MobFx.pen_px(1.0) * 0.5
	var big0: float = MobFx.BURST_OPEN * MobFx.BURST_SHORT * (big - 2.0)
	eq(clampi(int(floor(TAU * big0 / wide)), 3, MobFx.BURST_STROKES), MobFx.BURST_STROKES, "a harvester still gets the whole burst")
	# The shader and this share one rule, not two copies of it.
	var code: String = MobFx._shader(&"over").code
	check(code.contains("int strokes = clamp(int(floor(TAU * root / (2.0 * (BURST_ROOT + MARK_HALO)))), 3, BURST_STROKES);"),
		"the shader counts its strokes the way this does")


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
