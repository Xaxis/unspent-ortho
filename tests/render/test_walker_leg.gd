extends TestCase
## THE LEG UP CLOSE (colossus_leg_model.gd, ROADMAP slice 3 step 7b): the patch a
## climber's hands are on is drawn with a rung or a shelf at every hold the climb
## hangs him from, in the pitch's bone's own frame, lies ON the machine it is
## drawn over, and stays within a budget a frame can afford.

const Def := preload("res://src/core/colossus/colossus_def.gd")
const Leg := preload("res://src/models/colossus_leg_model.gd")
const Model := preload("res://src/models/colossus_model.gd")
const FootModel := preload("res://src/models/colossus_foot_model.gd")

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
	# The thigh, the shin at the knee, and the drum: the pitches climbed on a leg.
	for p: int in [0, 1, 2, 3]:
		var k := Leg.build(def, climb, p)
		for i in climb.holds_in(p):
			var h := climb.hold_at(p, i)
			var at := climb.surface_at(def, p, h.x * WalkerClimb.LEVEL, h.y, Leg.PROUD)
			# Within the part's own half-diagonal: a rung's, or a ledge's shelf's.
			var part := Vector3(Leg.SHELF.x, 0.12, Leg.SHELF.y) if climb.is_stance(i) else Vector3(Leg.RUNG.x, 0.06, Leg.RUNG.y)
			lt(_nearest(k, at, Leg.Model.RIM), part.length() + 0.05, "pitch %d hold %d: a rung or a shelf where he hangs" % [p, i])
		lt(float(k.verts.size() / 3), float(BUDGET), "pitch %d: %d triangles" % [p, k.verts.size() / 3])


func test_the_patch_covers_the_pitch_and_is_the_seeds() -> void:
	var def: RefCounted = Def.tripod(&"C")
	var a := Leg.build(def, WalkerClimb.begin(0, 1), 2)
	var b := Leg.build(def, WalkerClimb.begin(0, 1), 2)
	eq(a.verts, b.verts, "one seed, one patch")
	var climb := WalkerClimb.begin(0, 1)
	var foot := climb.surface_at(def, 2, -Leg.MARGIN, 0.0, 0.0)
	var head := climb.surface_at(def, 2, float(WalkerClimb.PITCHES[2].levels) * WalkerClimb.LEVEL + Leg.MARGIN, 0.0, 0.0)
	lt(_nearest(a, foot), 0.5, "it reaches below the pitch's foot")
	lt(_nearest(a, head), 0.5, "and above its head")


## The plate faces out, away from the bone's axis: its normals are what the sun
## lights, and a skin wound inward would be lit from inside the leg.
func test_the_skin_faces_out_of_the_leg() -> void:
	var def: RefCounted = Def.tripod(&"C")
	var climb := WalkerClimb.begin(0, 1)
	for p: int in [0, 2]:
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
	var climb := WalkerClimb.begin(0, 1)
	var far := Model.build(def, true).surface_get_arrays(0)
	var drum := PackedVector3Array()
	# The stub's cage rides the shin, not the foot, so where it stands against the
	# drum turns with the leg: the foot's own parts are what the drum pitch is on.
	for part: StringName in FootModel.PARTS:
		if part != &"stub":
			drum.append_array(FootModel.build(def, part).verts)
	for p in WalkerClimb.PITCHES.size():
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
			check(proud <= 0.02 and proud >= -LIES_WITHIN, "pitch %s at %.0f m up, %.0f across: the body is %s the patch's skin" % [
				WalkerClimb.PITCHES[p].id, s.x, s.y, "nowhere behind" if is_inf(hit) else "%+.2f m out of" % proud])


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
