extends Node3D
## THE LEG UNDER A CLIMBER'S HANDS (ROADMAP slice 3 step 7b): the patch of the
## pitch being climbed, in real space and honest size (src/models/
## colossus_leg_model.gd has what it is made of), set on the bone that pitch is on
## so the gait carries it, and the body hanging from it, with it. The far body
## goes on being drawn round it: the patch lies SKIN proud of the flat it is on
## (WalkerClimb.surface_at), so where the patch ends the machine goes on.
##
## Reached by path, never by class_name (43_climb preloads it).
##
## BUILT ON A WORKER, UPLOADED A SURFACE A FRAME, as the near foot is
## (colossus_foot.gd): the first frame a pitch is wanted starts one task that
## builds its patch, SPAN metres either way of the body up it; the frame after it
## is done, it goes to the renderer. The next pitch is asked for while he rides up
## inside the bone to it, so arriving at its foot waits on nothing.
##
## Its vertices are laid about the pitch's own foot, not the bone's root: a shin's
## pitch is two kilometres down the bone, and a float that far out holds a
## millimetre where the plate needs a tenth of one.
##
##   update(def, climb, pose, night)   draw `climb`'s pitch on `pose`; a null
##                                      climb hides it

const LegModel := preload("res://src/models/colossus_leg_model.gd")

## How far up and down the pitch from the body a patch is built, metres. Every
## pitch today is shorter, so each is built whole; a longer one is built again
## as the body nears an end of what is built.
const SPAN := 60.0

## Patches on the renderer by key (`_key`): {pitch, lo, hi, origin, mesh}.
var _built: Dictionary = {}
## The task building one, the key it is for, and what it hands back.
var _task := -1
var _task_key := ""
var _task_out: Dictionary = {}
## Patches whose arrays are done, by key, waiting for their frame to upload.
var _waiting: Dictionary = {}
var _mi: MeshInstance3D
var _mat: ShaderMaterial
var _said := -1.0
## For --stats and the proof: what this frame drew and what it has uploaded.
var drawn := false
var uploaded := 0
var triangles := 0


func _ready() -> void:
	_mat = PropModels.found_material().duplicate() as ShaderMaterial
	# The patch lays its plates in geometry, four by six metres, seams and lips
	# and all; the world's ruled panels would only cut across them.
	_mat.set_shader_parameter("ruled", 0.0)
	_mat.set_shader_parameter("relief", 0.4)
	_mat.set_shader_parameter("wear_take", 0.3)
	_mi = MeshInstance3D.new()
	_mi.name = "patch"
	_mi.material_override = _mat
	_mi.visible = false
	add_child(_mi)


func update(def: RefCounted, climb: WalkerClimb, pose: Dictionary, night: float) -> void:
	_claim(false)
	_upload_one()
	drawn = false
	if climb == null or pose.is_empty():
		_mi.visible = false
		return
	var p := climb.pitch
	var up := climb.hold_at(p, climb.hold).x * WalkerClimb.LEVEL
	var key := _key(p, up)
	_want(def, climb, p, up, key)
	# Riding up inside the bone, the next pitch is built before he gets there.
	if climb.state == WalkerClimb.RIDE and p + 1 < WalkerClimb.PITCHES.size():
		_want(def, climb, p + 1, 0.0, _key(p + 1, 0.0))
	# He never climbs back down to a pitch he has ridden up from.
	for k: String in _built.keys():
		if int(_built[k].pitch) < p:
			_built.erase(k)
	var b: Dictionary = _built.get(key, _built_near(p, up))
	if b.is_empty():
		_mi.visible = false
		return
	if _mi.mesh != b.mesh:
		_mi.mesh = b.mesh
		triangles = (b.mesh as ArrayMesh).surface_get_array_len(0) / 3 if (b.mesh as ArrayMesh).get_surface_count() > 0 else 0
	var bone: Transform3D = (pose.bones as Array)[climb.bone_index(p)]
	_mi.global_transform = bone * Transform3D(Basis.IDENTITY, b.origin)
	_mi.visible = true
	drawn = true
	var n := snappedf(night, 0.01)
	if n != _said:
		_said = n
		_mat.set_shader_parameter("glow_scale", lerpf(0.2, 1.0, n))


## Which built patch covers `up` metres up pitch `p`: the pitch, and which SPAN
## band of it (every pitch today has only band 0).
static func _key(p: int, up: float) -> String:
	return "%d:%d" % [p, floori(maxf(up, 0.0) / SPAN)]


## A patch of pitch `p` already built that still holds `up`, while the one for
## its band is on its way.
func _built_near(p: int, up: float) -> Dictionary:
	for k: String in _built:
		var b: Dictionary = _built[k]
		if int(b.pitch) == p and up >= float(b.lo) and up <= float(b.hi):
			return b
	return {}


func _want(def: RefCounted, climb: WalkerClimb, p: int, up: float, key: String) -> void:
	if _built.has(key) or _waiting.has(key) or _task >= 0:
		return
	var top := float(WalkerClimb.PITCHES[p].levels) * WalkerClimb.LEVEL
	var band := floorf(maxf(up, 0.0) / SPAN) * SPAN
	var lo := maxf(-LegModel.MARGIN, band - SPAN)
	var hi := minf(top + LegModel.MARGIN, band + SPAN * 2.0)
	var origin := climb.surface_at(def, p, 0.0, 0.0, 0.0)
	_task_key = key
	_task_out = {"pitch": p, "lo": lo, "hi": hi, "origin": origin}
	var out := _task_out
	# The worker reads a climb of its own: the holds are the leg's and the seed's
	# alone, and the one in play is being stepped on this thread meanwhile.
	var its := WalkerClimb.begin(climb.leg, climb.seed_value)
	_task = WorkerThreadPool.add_task(func() -> void:
		var k := LegModel.build_span(def, its, p, lo, hi, LegModel.HALF_W)
		for i in k.verts.size():
			k.verts[i] -= origin
		out["kit"] = k, true, "colossus leg")


## A POOL TASK IS CLAIMED, ALWAYS, as colossus_foot.gd says why: waited for the
## frame it is done, and waited out if this node goes first.
func _claim(wait: bool) -> void:
	if _task < 0 or (not wait and not WorkerThreadPool.is_task_completed(_task)):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_waiting[_task_key] = _task_out


func _exit_tree() -> void:
	_claim(true)


## One built patch a frame from the worker's arrays to the renderer.
func _upload_one() -> void:
	if _waiting.is_empty():
		return
	var key: String = _waiting.keys()[0]
	var b: Dictionary = _waiting[key]
	_waiting.erase(key)
	b.mesh = (b.kit as MeshKit).build()
	b.erase("kit")
	_built[key] = b
	uploaded += 1


## Everything built is let go (a climb over, a world changed).
func clear() -> void:
	_claim(true)
	_built.clear()
	_waiting.clear()
	_mi.mesh = null
	_mi.visible = false
