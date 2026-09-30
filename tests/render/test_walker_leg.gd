extends TestCase
## THE LEG UP CLOSE (colossus_leg_model.gd, ROADMAP slice 3 step 7b): the patch a
## climber's hands are on is drawn with a rung or a shelf at every hold the climb
## hangs him from, in the pitch's bone's own frame, and stays within a budget a
## frame can afford.

const Def := preload("res://src/core/colossus/colossus_def.gd")
const Leg := preload("res://src/models/colossus_leg_model.gd")

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
