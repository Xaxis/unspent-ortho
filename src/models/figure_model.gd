class_name FigureModel
extends Node3D
## Base for every animated non-human figure: machines and animals. Faces +X at
## rotation.y = 0 (set rotation.y = -facing).
##
## Contract used by fight/mobs (do not change signatures without updating both):
##   FigureModel.create(kind)   kind is a roster id tail, e.g. &"watcher", &"dog".
##                              Loads res://src/models/machines/<kind>.gd or
##                              res://src/models/animals/<kind>.gd (a script that
##                              extends FigureModel and overrides build()); falls
##                              back to a placeholder block so nothing crashes.
##   set_pose(pose)             &"stand" &"walk" &"alert" &"windup" &"strike"
##                              &"hurt" &"dead" (unknown poses are ignored)
##   animate(delta, speed)      speed in tiles/s actually moved
##   set_part_lit(lit)          the working part's light (off = hurt or dead)
##   flare_part()               brief flare when a blow reaches the working part
##   part_side                  &"front" &"back" &"left" &"right" &"none"
##   height                     world units, for hit effects and labels

var kind: StringName = &""
var pose: StringName = &"stand"
var part_side: StringName = &"front"
var height := 1.2
var material: Material


static func create(kind_id: StringName, mat: Material = null) -> FigureModel:
	var m: FigureModel = null
	for dir: String in ["res://src/models/machines/", "res://src/models/animals/"]:
		var path := dir + String(kind_id) + ".gd"
		if ResourceLoader.exists(path):
			m = (load(path) as GDScript).new()
			break
	if m == null:
		m = FigureModel.new()
	m.kind = kind_id
	m.material = mat if mat != null else _default_material()
	m.build()
	return m


static func _default_material() -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/render/world.gdshader")
	return mat


## Override. Default: a violet block with an amber part on the front (+X).
func build() -> void:
	var k := MeshKit.new()
	k.block(0, 0, 0, 0.8, 1.0, 0.8, Palette.FOUND[2], Palette.FOUND[3])
	k.block(0.41, 0.5, 0, 0.04, 0.25, 0.3, Palette.LENS[2])
	add_mesh(k)


func set_pose(p: StringName) -> void:
	pose = p


func animate(_delta: float, _speed: float) -> void:
	pass


func set_part_lit(_lit: bool) -> void:
	pass


func flare_part() -> void:
	pass


## Helper for subclasses: add a MeshKit as a child mesh on `parent` (default self).
func add_mesh(k: MeshKit, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	mi.material_override = material
	(parent if parent != null else self).add_child(mi)
	return mi
