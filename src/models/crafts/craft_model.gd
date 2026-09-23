class_name CraftModel
extends Node3D
## A craft, drawn (docs/VISION.md, docs/LOOK.md). Two meshes and no more:
## one MADE (world.gdshader — hatched, crooked, earth and sand) and one FOUND
## (found.gdshader — ruled, riveted, unhatched violet plate with amber where the
## machine still works). Both idioms stand in one silhouette, which is the whole
## of what MENDED means, and the join is composed on rather than hidden.
##
## Look at them:
##   tools/shot.sh shots/crafts.png --scene=gallery --filter=raft
##   tools/shot.sh shots/crafts/sled.png --craft=hover_sled --seed=1

const Raft := preload("res://src/models/crafts/raft_model.gd")
const Sled := preload("res://src/models/crafts/hover_sled_model.gd")
const Walker := preload("res://src/models/crafts/walker_rig_model.gd")

## How far a wreck lists and settles: the same tilt for all three, because what
## reads as wreckage at 640x360 is the line going off true, not the amount.
const WRECK_ROLL := 0.44
const WRECK_PITCH := 0.16
const WRECK_SINK := 0.09

var kind: StringName = &""
var wrecked := false
var _made: MeshInstance3D
var _found: MeshInstance3D
## (kind, broken) -> [made mesh, found mesh]: a second raft costs no geometry.
static var _cache: Dictionary = {}


static func create(kind_value: StringName) -> CraftModel:
	var m := CraftModel.new()
	m.kind = kind_value
	m.name = "craft_%s" % kind_value
	return m


## `made` is the world material (WorldView.world_material). Left null — as the
## gallery does — the made half takes whatever the scene fills in.
func build(made: Material) -> void:
	_made = MeshInstance3D.new()
	_made.name = "made"
	if made != null:
		_made.material_override = made
	add_child(_made)
	_found = MeshInstance3D.new()
	_found.name = "found"
	_found.material_override = PropModels.found_material()
	add_child(_found)
	_apply()


func set_wrecked(on: bool) -> void:
	if on == wrecked:
		return
	wrecked = on
	_apply()


func _apply() -> void:
	var meshes := _meshes(kind, wrecked)
	if _made != null:
		_made.mesh = meshes[0]
	if _found != null:
		_found.mesh = meshes[1]
	rotation = Vector3(WRECK_PITCH, 0.0, WRECK_ROLL) if wrecked else Vector3.ZERO
	position.y = -WRECK_SINK if wrecked else 0.0


static func _meshes(kind_value: StringName, broken: bool) -> Array:
	var key := "%s|%d" % [kind_value, int(broken)]
	if _cache.has(key):
		return _cache[key]
	var made_kit := MeshKit.new()
	var found_kit := MeshKit.new()
	match kind_value:
		&"raft":
			Raft.found(found_kit, broken)
			Raft.made(made_kit, broken)
		&"hover_sled":
			Sled.found(found_kit, broken)
			Sled.made(made_kit, broken)
		&"walker_rig":
			Walker.found(found_kit, broken)
			Walker.made(made_kit, broken)
		_:
			push_warning("no drawing for craft %s" % kind_value)
	var out: Array = [made_kit.build(), found_kit.build()]
	_cache[key] = out
	return out


## Every craft, whole and wrecked: the wreck is half of what a craft is (it can be
## lost), so it is reviewed beside the thing it was.
static func gallery() -> Array:
	var out: Array = []
	for kind_value: StringName in CraftKinds.ids():
		for broken: bool in [false, true]:
			var m := CraftModel.create(kind_value)
			m.build(null)
			m.set_wrecked(broken)
			var holder := Node3D.new()
			holder.add_child(m)
			out.append({"name": CraftKinds.display_name(kind_value) + (" wrecked" if broken else ""), "node": holder})
	return out
