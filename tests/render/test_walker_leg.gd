extends TestCase
## THE LEG UP CLOSE (colossus_leg_model.gd, ROADMAP slice 3 step 7b): the patch a
## climber's hands are on is drawn with a rung or a shelf at every hold the climb
## hangs him from, in the pitch's bone's own frame, lies ON the machine it is
## drawn over, and stays within a budget a frame can afford.

const Def := preload("res://src/core/colossus/colossus_def.gd")
const Leg := preload("res://src/models/colossus_leg_model.gd")
const Model := preload("res://src/models/colossus_model.gd")
const FootModel := preload("res://src/models/colossus_foot_model.gd")
const Treads := preload("res://src/core/colossus/colossus_treads.gd")

## Triangles one pitch's patch may cost.
const BUDGET := 6000


## The nearest vertex of `k` to `p`, of colour `only` if given (the hardware is
## RIM and nothing else is).
func _nearest(k: MeshKit, p: Vector3, only := Color(0, 0, 0, 0)) -> float:
	var best := INF
	for i in k.verts.size():
		if only.a > 0.0 and not k.colors[i].is_equal_approx(only):
			continue
		best = minf(best, k.verts[i].distance_to(p))
	return best


func test_every_hold_has_something_to_hold() -> void:
	var def: RefCounted = Def.tripod(&"C")
	var climb := WalkerClimb.begin(0, 1)
	# Every pitch on a leg: the cable, the drum, the shin at the knee, the thigh.
	for p in WalkerClimb.PITCHES.size():
		if int(WalkerClimb.PITCHES[p].bone) == WalkerClimb.HUB:
			continue
		var hangs := WalkerClimb.PITCHES[p].has("hang")
		var k := Leg.build(def, climb, p)
		for i in climb.holds_in(p):
			var h := climb.hold_at(p, i)
			var at := climb.surface_at(def, p, h.x * WalkerClimb.LEVEL, h.y, Leg.PROUD)
			# Within the part's own half-diagonal: a rung's or a clamp's, or a
			# ledge's shelf's or a cable's seat's.
			var part := Vector3(Leg.SHELF.x, 0.12, Leg.SHELF.y) if climb.is_stance(i) else Vector3(Leg.RUNG.x, 0.06, Leg.RUNG.y)
			if hangs:
				part = Vector3(Leg.SEAT.x, 0.08, Leg.SEAT.y) if climb.is_stance(i) else Vector3(Leg.CLAMP.x, 0.08, Leg.CLAMP.y)
			lt(_nearest(k, at, Leg.Model.RIM), part.length() + 0.05, "pitch %d hold %d: a rung or a shelf where he hangs" % [p, i])
		lt(float(k.verts.size() / 3), float(BUDGET), "pitch %d: %d triangles" % [p, k.verts.size() / 3])


func test_the_patch_covers_the_pitch_and_is_the_seeds() -> void:
	var def: RefCounted = Def.tripod(&"C")
	var thigh := WalkerClimb.pitch_of(&"thigh")
	var a := Leg.build(def, WalkerClimb.begin(0, 1), thigh)
	var b := Leg.build(def, WalkerClimb.begin(0, 1), thigh)
	eq(a.verts, b.verts, "one seed, one patch")
	var climb := WalkerClimb.begin(0, 1)
	var foot := climb.surface_at(def, thigh, -Leg.MARGIN, 0.0, 0.0)
	var head := climb.surface_at(def, thigh, float(WalkerClimb.PITCHES[thigh].levels) * WalkerClimb.LEVEL + Leg.MARGIN, 0.0, 0.0)
	lt(_nearest(a, foot), 0.5, "it reaches below the pitch's foot")
	lt(_nearest(a, head), 0.5, "and above its head")


## The plate faces out, away from the bone's axis: its normals are what the sun
## lights, and a skin wound inward would be lit from inside the leg.
func test_the_skin_faces_out_of_the_leg() -> void:
	var def: RefCounted = Def.tripod(&"C")
	var climb := WalkerClimb.begin(0, 1)
	for p: int in [WalkerClimb.pitch_of(&"drum"), WalkerClimb.pitch_of(&"thigh")]:
		var k := Leg.build(def, climb, p)
		var outward := 0
		var n := mini(k.verts.size(), 300)
		for i in n:
			var v := k.verts[i]
			if k.normals[i].dot(Vector3(v.x, 0.0, v.z).normalized()) > 0.5:
				outward += 1
		gt(float(outward), n * 0.9, "pitch %d: the skin's normals point out of the leg (%d of %d)" % [p, outward, n])


## THE PATCH LIES ON THE BODY. Looked at from outside, along every pitch's line
## and out to the patch's edges and ends, the first thing of the machine behind
## it (the far body near to, L1; on the drum, the near foot) is the surface the
## patch is laid on, a hand's breadth under its skin: never standing out of it
## (a sleeve, a flange, a beacon swallowing the pitch) and never far behind it
## (a pitch hung in the air beside the machine).
const LIES_WITHIN := 0.3
## How far out the patch is looked at from: past the widest thing a leg wears.
const LOOK_FROM := 3000.0


func test_the_patch_lies_on_the_body() -> void:
	var def: RefCounted = Def.tripod(&"C")
	var far := Model.build(def, true).surface_get_arrays(0)
	var drum := PackedVector3Array()
	# The stub's cage rides the shin, not the foot, so where it stands against the
	# drum turns with the leg: the foot's own parts are what the drum pitch is on.
	for part: StringName in FootModel.PARTS:
		if part != &"stub":
			drum.append_array(FootModel.build(def, part).verts)
	# Every leg's: a leg's own pitches are the same in its bone's frame, but the
	# hatch is on the hub a flat round from that leg's own hip.
	# The cable hangs free of it below the belt: test_the_cable_hangs_clear.
	for leg in 3:
		for p in WalkerClimb.PITCHES.size():
			if WalkerClimb.PITCHES[p].has("hang"):
				continue
			if leg == 0 or int(WalkerClimb.PITCHES[p].bone) == WalkerClimb.HUB:
				_lies_on(def, far, drum, WalkerClimb.begin(leg, 1), p)


## THE CABLE HANGS CLEAR OF THE FOOT (WalkerClimb FOOT_TURN): from the belt's foot
## down to the tread, everything a body on it reaches stays CLEAR off the near
## foot's every part (the toe under it, its heel joint, its pad, the pad's
## claws), and its foot is in the crater the middle toe stands in, beside the
## pad and short of its rim.
const CLEAR := 1.5


func test_the_cable_hangs_clear_of_the_foot() -> void:
	var def: RefCounted = Def.tripod(&"C")
	var climb := WalkerClimb.begin(0, 1)
	var cable := WalkerClimb.pitch_of(&"cable")
	var foot := PackedVector3Array()
	for part: StringName in FootModel.PARTS:
		if part != &"stub":
			foot.append_array(FootModel.build(def, part).verts)
	var hang := WalkerClimb.BELT_Y - float(WalkerClimb.PITCHES[cable].from)
	var nearest := INF
	var up := 0.0
	while up < hang - 1.0:
		var at := climb.surface_at(def, cable, up, 0.0, Leg.PROUD)
		var tris := _tris_in(foot, AABB(at, Vector3.ZERO).grow(CLEAR * 4.0))
		for i in range(0, tris.size(), 3):
			var on := Geometry3D.get_closest_point_to_segment(at, tris[i], tris[i + 1])
			nearest = minf(nearest, minf(at.distance_to(_closest_on_tri(at, tris[i], tris[i + 1], tris[i + 2])), at.distance_to(on)))
		up += 1.0
	gt(nearest, CLEAR, "hanging, the cable keeps clear of the foot (nearest %.2f m)" % nearest)
	var base := climb.surface_at(def, cable, 0.0, 0.0, 0.0)
	var pad: Vector3 = def.toe(1)
	var centre := Vector2(cos(pad.x), sin(pad.x)) * pad.y
	var off := Vector2(base.x, base.z).distance_to(centre)
	gt(off, Treads.floor_r(Vector3(0.0, 0.0, pad.z)), "its foot is out past the crater's floor, beside the pad (%.1f m from its middle)" % off)
	lt(off, Treads.rim_r(Vector3(0.0, 0.0, pad.z)), "and inside the crater's rim")


## The nearest point to `p` on triangle a, b, c.
static func _closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b - a).cross(c - a)
	if n.length() < 1e-6:
		return a
	n = n.normalized()
	var q := p - n * (p - a).dot(n)
	var inside := (b - a).cross(q - a).dot(n) >= 0.0 and (c - b).cross(q - b).dot(n) >= 0.0 and (a - c).cross(q - c).dot(n) >= 0.0
	if inside:
		return q
	var best := Geometry3D.get_closest_point_to_segment(p, a, b)
	for e: Array in [[b, c], [c, a]]:
		var o := Geometry3D.get_closest_point_to_segment(p, e[0], e[1])
		if p.distance_to(o) < p.distance_to(best):
			best = o
	return best


func _lies_on(def: RefCounted, far: Array, drum: PackedVector3Array, climb: WalkerClimb, p: int) -> void:
	var foot := int(WalkerClimb.PITCHES[p].bone) == WalkerClimb.FOOT
	var top := float(WalkerClimb.PITCHES[p].levels) * WalkerClimb.LEVEL
	var box := AABB(climb.surface_at(def, p, 0.0, 0.0, 0.0), Vector3.ZERO)
	var samples: Array[Vector3] = []
	for up: float in [-Leg.MARGIN, 0.0, top * 0.5, top, top + Leg.MARGIN]:
		for across: float in [-Leg.HALF_W, -Leg.HALF_W * 0.5, 0.0, Leg.HALF_W * 0.5, Leg.HALF_W]:
			samples.append(Vector3(up, across, 0.0))
			var at := Leg._at(def, climb, p, up, across, 0.0)
			box = box.expand(at).expand(at + Vector3(at.x, 0.0, at.z).normalized() * LOOK_FROM)
	box = box.grow(1.0)
	var tris := _tris_in(drum if foot else _bone_tris(far, climb.bone_index(p)), box)
	for s: Vector3 in samples:
		var at := Leg._at(def, climb, p, s.x, s.y, 0.0)
		var out := Vector3(at.x, 0.0, at.z).normalized()
		var hit := _first_hit(tris, at + out * LOOK_FROM, -out)
		var proud := LOOK_FROM - hit
		check(proud <= 0.02 and proud >= -LIES_WITHIN, "leg %d pitch %s at %.0f m up, %.0f across: the body is %s the patch's skin" % [
			climb.leg, WalkerClimb.PITCHES[p].id, s.x, s.y, "nowhere behind" if is_inf(hit) else "%+.2f m out of" % proud])


## The triangles of the far body skinned to `bone`.
static func _bone_tris(arrays: Array, bone: int) -> PackedVector3Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var c: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var out := PackedVector3Array()
	for i in range(0, v.size(), 3):
		if int(c[i * 4]) == bone:
			out.append_array([v[i], v[i + 1], v[i + 2]])
	return out


static func _tris_in(tris: PackedVector3Array, box: AABB) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(0, tris.size(), 3):
		var b := AABB(tris[i], Vector3.ZERO).expand(tris[i + 1]).expand(tris[i + 2])
		if b.grow(0.01).intersects(box):
			out.append_array([tris[i], tris[i + 1], tris[i + 2]])
	return out


static func _first_hit(tris: PackedVector3Array, from: Vector3, dir: Vector3) -> float:
	var best := INF
	for i in range(0, tris.size(), 3):
		var h: Variant = Geometry3D.ray_intersects_triangle(from, dir, tris[i], tris[i + 1], tris[i + 2])
		if h != null:
			best = minf(best, from.distance_to(h as Vector3))
	return best


## EVERY PLATE CARRIES ITS OWN FRAME, so its wear (found.gdshader `plate_detail`)
## is laid on its lines and walks with the leg: each face of a plate says its
## width, the height of it that shows, and which part of it the face is, and
## every vertex of it is somewhere on that plate. The skin and the hardware carry
## none, and the patch's material asks for plate wear.
func test_every_plate_carries_its_own_frame() -> void:
	var def: RefCounted = Def.tripod(&"C")
	var climb := WalkerClimb.begin(0, 1)
	var k := Leg.build(def, climb, WalkerClimb.pitch_of(&"thigh"))
	var parts := {}
	var off := 0
	for i in k.verts.size():
		var part := int(k.custom0[i * 4 + 3] + 0.5)
		parts[part] = int(parts.get(part, 0)) + 1
		if part == 0:
			continue
		var w := k.custom0[i * 4]
		var uv := k.uv2s[i]
		if w <= 0.0 or uv.x < -0.01 or uv.x > w + 0.01 or uv.y < -0.01 or uv.y > Leg.PANEL.y + Leg.LAP + 0.01:
			off += 1
	for part: int in [int(Leg.FACE), int(Leg.BEVEL), int(Leg.LIP)]:
		gt(float(parts.get(part, 0)), 0.0, "part %d is laid" % part)
	gt(float(parts.get(0, 0)), 0.0, "and the skin and the hardware carry no plate")
	eq(off, 0, "every plate vertex is on its own plate")
	eq(float(Leg.material().get_shader_parameter("plate_detail")), 1.0, "and the patch wears its plates' own wear")


## UP CLOSE THE PLATE IS LIT AS FORM, AND ONLY UP CLOSE (Leg.NEAR_LIFT): the
## patch wears the lift and its fill; the far body takes the same rule only while
## a climb is live (ColossusView.lift_near) and gives it back after; and the
## lift is gone well short of the nearest any eye on the ground comes to the
## drum, so from the ground the walker is the dark mass it always was.
func test_the_near_plate_is_lifted_only_up_close() -> void:
	var mat := Leg.material()
	eq(mat.get_shader_parameter("near_lift"), Leg.NEAR_LIFT, "the patch wears the lift")
	eq(float(mat.get_shader_parameter("near_fill")), Leg.NEAR_FILL, "and its fill")
	var def: RefCounted = Def.tripod(&"C")
	var climb := WalkerClimb.begin(0, 1)
	var foot := climb.surface_at(def, WalkerClimb.pitch_of(&"drum"), 0.0, 0.0, 0.0)
	gt(float(def.ankle_up) + foot.y, Leg.NEAR_LIFT.z * 1.5, "the drum's foot stands well past the lift from the ground")
	var view: Node3D = load("res://src/render/colossus/colossus_view.gd").new()
	tree.root.add_child(view)
	view.setup([def], 7, 1300)
	var lifted := func(want: float) -> int:
		var n := 0
		for c: Node in view.get_children():
			var v: Variant = ((c as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("near_lift")
			if v != null and is_equal_approx((v as Vector4).x, want):
				n += 1
		return n
	eq(lifted.call(Leg.NEAR_LIFT.x), 0, "the far body is not lifted before a climb")
	view.call(&"lift_near", true)
	eq(lifted.call(Leg.NEAR_LIFT.x), view.get_child_count(), "while one is live both its bodies are")
	view.call(&"lift_near", false)
	eq(lifted.call(0.0), view.get_child_count(), "and after it, neither is")
	view.free()
