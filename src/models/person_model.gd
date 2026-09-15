class_name PersonModel
extends Node3D
## A person built from parts, animated procedurally. About 4.6 heads tall and
## chunky; legs carry the height because walks read from the legs.
## Faces +X at rotation 0 (the same convention as Player.facing).
##
## Colours follow the player base look: skin flesh3, hair sand2, shirt linen2,
## trousers slate1, boots earth1.

@export var skin := Palette.FLESH[3]
@export var hair := Palette.SAND[2]
@export var shirt := Palette.LINEN[2]
@export var trouser := Palette.SLATE[1]
@export var boot := Palette.EARTH[1]

var hips: Node3D
var torso: Node3D
var head: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D

var _phase := 0.0
var _mat: Material


func build(material: Material) -> void:
	_mat = material
	# Proportions in world units for a ~1.35 tall figure.
	var leg_h := 0.52
	var torso_h := 0.44
	hips = _node(self, Vector3(0, leg_h, 0))
	leg_l = _node(hips, Vector3(0, 0, -0.1))
	leg_r = _node(hips, Vector3(0, 0, 0.1))
	for leg: Node3D in [leg_l, leg_r]:
		var k := MeshKit.new()
		k.block(0, -leg_h, 0, 0.16, leg_h * 0.8, 0.14, trouser)
		k.block(0.03, -leg_h, 0, 0.22, 0.12, 0.16, boot)
		_mesh(leg, k)
	torso = _node(hips, Vector3.ZERO)
	var tk := MeshKit.new()
	tk.block(0, 0, 0, 0.26, torso_h, 0.42, shirt, shirt.lerp(Palette.LINEN[3], 0.3))
	tk.block(0, -0.04, 0, 0.27, 0.08, 0.43, Palette.EARTH[2]) # belt
	_mesh(torso, tk)
	head = _node(torso, Vector3(0, torso_h + 0.02, 0))
	var hk := MeshKit.new()
	hk.block(0, 0, 0, 0.26, 0.28, 0.26, skin)
	hk.block(-0.02, 0.2, 0, 0.29, 0.12, 0.3, hair)
	hk.block(-0.1, 0.06, 0, 0.1, 0.16, 0.3, hair)
	hk.block(0.131, 0.13, -0.06, 0.01, 0.04, 0.04, Palette.INK[1]) # eyes
	hk.block(0.131, 0.13, 0.06, 0.01, 0.04, 0.04, Palette.INK[1])
	_mesh(head, hk)
	arm_l = _node(torso, Vector3(0, torso_h - 0.04, -0.27))
	arm_r = _node(torso, Vector3(0, torso_h - 0.04, 0.27))
	for arm: Node3D in [arm_l, arm_r]:
		var ak := MeshKit.new()
		ak.block(0, -0.36, 0, 0.12, 0.36, 0.11, shirt)
		ak.block(0, -0.44, 0, 0.1, 0.09, 0.1, skin)
		_mesh(arm, ak)


## speed: tiles/second actually moved. delta: seconds.
func animate(speed: float, delta: float) -> void:
	if speed > 0.1:
		_phase += delta * speed * 2.2
		var s := sin(_phase * TAU * 0.5)
		leg_l.rotation.z = s * 0.6
		leg_r.rotation.z = -s * 0.6
		arm_l.rotation.z = -s * 0.5
		arm_r.rotation.z = s * 0.5
		hips.position.y = 0.52 + absf(cos(_phase * TAU * 0.5)) * 0.04
		torso.rotation.z = -0.06
	else:
		_phase = 0.0
		for n: Node3D in [leg_l, leg_r, arm_l, arm_r]:
			n.rotation.z = lerpf(n.rotation.z, 0.0, 1.0 - exp(-12.0 * delta))
		hips.position.y = 0.52
		torso.rotation.z = 0.0


func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _mesh(parent: Node3D, k: MeshKit) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	mi.material_override = _mat
	parent.add_child(mi)


static func gallery() -> Array:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/render/world.gdshader")
	var p := PersonModel.new()
	p.build(mat)
	p.rotation.y = -PI * 0.5 # face the camera side (south)
	var w := PersonModel.new()
	w.build(mat)
	w.rotation.y = -PI * 0.25
	w.animate(3.0, 0.12)
	return [{"name": "person", "node": p}, {"name": "person walking", "node": w}]
