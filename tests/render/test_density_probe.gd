extends TestCase
## How much world is in a screen, asked of the camera rather than of a radius.
##
## #106 records the Slums as the densest landscape in the game and still "about
## two buildings a screen". That number was formed through the ORTHOGRAPHIC
## frame, which reaches 8.9 tiles ahead of the player whatever a thing's height
## (`tests/render/test_read_reach.gd`). So it may be a fact about what the camera
## could show rather than about what worldgen laid, and the two have never been
## separated. This separates them, and it is deliberately capable of returning
## the unflattering answer: if VISIBLE under the lens is not materially larger at
## the same standpoint, the thinness is worldgen's and the lever is `GenScatter`.
##
## Three numbers per standpoint, per category:
##
##   LAID     what worldgen put within REACH of the standpoint (off `world.props`)
##   VISIBLE  what the camera actually holds, asked with `unproject_position`
##   UNSEEN   LAID - VISIBLE: the world that exists and is never looked at
##
## **NO FRAME IS RENDERED.** `unproject_position` wants a camera in a sized
## viewport, not a drawn picture, so this is arithmetic over world data and costs
## one headless process. It also means chunk streaming cannot confound it: the
## question is what worldgen LAID against what the CAMERA HOLDS, and neither
## waits on a mesh.
##
## TWO DEFINITIONS OF VISIBLE, REPORTED SEPARATELY, because the difference
## between them IS the projection's signature and an average would delete it. A
## pitched parallel camera loses a thing's TOP first and its feet last, so for
## anything tall `foot in frame` and `any part in frame` diverge under ortho and
## converge under the lens.
##
## THE GUARD THAT MAKES THE LENS NUMBER HONEST: `is_position_behind` before every
## `unproject_position`. Under ortho it changes nothing, because parallel rays
## project a point behind the camera to its true screen position. Under
## perspective a point BEHIND the camera maps to a MIRRORED position that can
## land inside the rect, so without the guard the lens count inflates — in
## exactly the direction this probe is hoping for. Nothing else in `src/` does
## this except `gallery.gd` and `bolt_draw.gd`; `flier_view._in_frame` and
## `holo_view._in_frame` are both bare and are correct only while the game is
## orthographic.
##
## `camera.size` appears nowhere below. It is world-units-per-screen-HEIGHT and
## only a parallel projection has such a number — the same shape as `world_px`.

## How far out "laid near this standpoint" reaches. `HoloView` gathers on 24, and
## it is a plausible walk rather than a render distance.
const REACH := 24.0
const SEEDS: Array[int] = [1, 4, 7]
const SIZE := 384


func _camera(lens: StringName, at: Vector2, ground: float) -> Camera3D:
	var vp := SubViewport.new()
	vp.size = UiBase.SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(vp)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.05
	cam.far = 500.0
	var pitch := CameraRig.PITCH_DEG
	var back := 30.0
	if lens == &"persp":
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = CameraRig.LENS_FOV
		pitch = CameraRig.LENS_PITCH
		back = CameraRig.lens_back()
	else:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = CameraRig.VIEW_HEIGHT
	cam.rotation = Vector3(deg_to_rad(-pitch), deg_to_rad(45.0), 0.0)
	vp.add_child(cam)
	# The rig frames the player, so the standpoint is what the camera looks AT.
	cam.position = Vector3(at.x, ground, at.y) + cam.global_transform.basis.z * back
	return cam


## Is a world point inside the frame? The behind-camera guard comes FIRST.
func _seen(cam: Camera3D, p: Vector3, rect: Vector2) -> bool:
	if cam.is_position_behind(p):
		return false
	var s := cam.unproject_position(p)
	return s.x >= 0.0 and s.x <= rect.x and s.y >= 0.0 and s.y <= rect.y


## A house's real height, off `BiomeForms.FORMS` — core data, no model built.
func _high_of(w: WorldData, p: WorldProp) -> float:
	var c := w.country_at(int(p.pos.x), int(p.pos.y))
	var forms := BiomeForms.of(c)
	if forms == null:
		return 1.0
	return forms.fact(maxi(p.variant, 0), BiomeForms.HIGH, 1.0)


func test_what_a_screen_actually_holds() -> void:
	print("")
	print("REACH %.0f tiles, size %d, viewport %dx%d" % [REACH, SIZE, UiBase.SIZE.x, UiBase.SIZE.y])
	print("%-5s %-18s %-5s %-6s %6s %6s %6s %6s" % ["seed", "landscape", "from", "lens", "LAID", "foot", "anypt", "unseen"])
	var examined := 0
	for seed_value: int in SEEDS:
		var w: WorldData = BootWorld.world(seed_value, SIZE)
		if w == null or w.villages.is_empty():
			continue
		# One village per COUNTRY, so a dense landscape cannot stand in for a thin
		# one -- #106's numbers came from a single seed and a single place.
		var seen_country := {}
		for v: Dictionary in w.villages:
			var cc := int(v.get("country", -1))
			if cc < 0 or seen_country.has(cc):
				continue
			seen_country[cc] = true
			var centre: Vector2 = v.get("pos", Vector2.ZERO)
			var land := BiomeRegistry.by_index(cc)
			var land_id: String = String(land.id) if land != null else "?"
			# TWO STANDPOINTS, and the second is the one that answers #106. Standing
			# in a village's own centre, both cameras hold nearly all of a compact
			# village, so the binding constraint is the village's SIZE and not the
			# frame -- that measures "can you see this village". The offset standpoint
			# is a player WALKING, which is the case the density claim is about.
			for step: float in [0.0, 14.0]:
				var at: Vector2 = centre + Vector2(0.707, 0.707) * step
				var ground := w.height_at(at)
				var houses: Array[WorldProp] = []
				for p: WorldProp in w.props:
					if p.kind == PropKind.HOUSE and p.pos.distance_to(at) <= REACH:
						houses.append(p)
				for lens: StringName in [&"ortho", &"persp"]:
					var cam := _camera(lens, at, ground)
					var rect := Vector2(UiBase.SIZE)
					var foot := 0
					var anypt := 0
					for p: WorldProp in houses:
						var base := Vector3(p.pos.x, w.height_at(p.pos), p.pos.y)
						var f := _seen(cam, base, rect)
						if f:
							foot += 1
						if f or _seen(cam, base + Vector3(0.0, _high_of(w, p), 0.0), rect):
							anypt += 1
						examined += 1
					# A LAID of zero is PRINTED, never skipped: a landscape given no
					# buildings is the most informative row in the table, and a skipped
					# row and a zero row read identically afterwards.
					print("%-5d %-18s %-5s %-6s %6d %6d %6d %6d" % [seed_value, land_id,
						"mid" if step == 0.0 else "walk", lens,
						houses.size(), foot, anypt, houses.size() - anypt])
					cam.get_parent().queue_free()
	# An instrument that examined nothing prints a clean table of zeros and looks
	# exactly like a finding. Fail instead.
	gt(examined, 0, "the probe examined no buildings at all, so its table means nothing")
