extends RefCounted
## THE HATCH OVER A DEPOT'S HALL (docs/interiors): what a player walks up to on
## the yard's back end. A low housing of plate, sloped to shed the rain, its door
## a dark way down with a steady strip over it -- the machines keep their own
## doors lit. Built in the hatch's own frame: +X is the way out of the door, the
## ground at y 0; 21_doors stands it at the threshold's host, turned by `rot`.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")
## The housing's reach from its middle, what stops a body (21_doors hands it to
## the query as a circle).
const REACH := 0.85
## The housing's drawn box in its own frame (lo, hi on x and z) and its height,
## for the shoulder camera's probe (21_doors `sight_boxes`).
const LO := Vector2(-1.0, -0.8)
const HI := Vector2(1.05, 0.8)
const TOP := 1.6


## `mat` is the world's MADE material, for the dark in the doorway.
static func node(mat: Material) -> Node3D:
	var k := Kit.new()
	var f := k.found
	# The housing: longer than wide, its roof falling to the back.
	f.box(Vector3(-1.0, 0.0, -0.8), Vector3(0.7, 1.35, 0.8), P.PLATE[2], P.PLATE[3])
	f.quad(Vector3(-1.0, 1.35, -0.8), Vector3(0.7, 1.55, -0.8), Vector3(0.7, 1.55, 0.8), Vector3(-1.0, 1.35, 0.8), P.PLATE[3])
	# The roof's two end gables, each one triangle, wound to face out.
	f.tri(Vector3(0.7, 1.35, -0.8), Vector3(0.7, 1.55, -0.8), Vector3(-1.0, 1.35, -0.8), P.PLATE[2])
	f.tri(Vector3(-1.0, 1.35, 0.8), Vector3(0.7, 1.55, 0.8), Vector3(0.7, 1.35, 0.8), P.PLATE[2])
	# The door: a heavy frame round a dark opening, a step before it.
	f.box(Vector3(0.7, 0.0, -0.55), Vector3(0.82, 1.3, -0.42), P.PLATE[1])
	f.box(Vector3(0.7, 0.0, 0.42), Vector3(0.82, 1.3, 0.55), P.PLATE[1])
	f.box(Vector3(0.7, 1.18, -0.55), Vector3(0.82, 1.3, 0.55), P.PLATE[1])
	var dark := GroundColors.made(Color(0.03, 0.03, 0.04), GroundColors.TAR)
	k.made.quad(Vector3(0.705, 0.0, -0.42), Vector3(0.705, 1.18, -0.42), Vector3(0.705, 1.18, 0.42), Vector3(0.705, 0.0, 0.42), dark)
	f.box(Vector3(0.7, 0.0, -0.6), Vector3(1.05, 0.08, 0.6), P.PLATE[1], P.PLATE[2])
	# Its own light, over the door.
	f.box(Vector3(0.72, 1.36, -0.32), Vector3(0.8, 1.42, 0.32), Works.STRIP)
	# Plates riveted on its flanks, one gone to rust.
	k.plate(Vector3(-0.9, 0.2, 0.805), Vector3(0.55, 0.2, 0.805), Vector3(0.55, 1.2, 0.805), Vector3(-0.9, 1.2, 0.805), P.PLATE[3], P.PLATE[1], P.PLATE[4])
	k.plate(Vector3(0.55, 0.2, -0.805), Vector3(-0.9, 0.2, -0.805), Vector3(-0.9, 1.2, -0.805), Vector3(0.55, 1.2, -0.805), P.PLATE[2].lerp(P.RUST[2], 0.4), P.RUST[1], P.PLATE[4])
	var root := Node3D.new()
	root.name = "hatch"
	var fm := MeshInstance3D.new()
	fm.mesh = f.build()
	fm.material_override = PropModels.found_material()
	root.add_child(fm)
	var mm := MeshInstance3D.new()
	mm.mesh = k.made.build()
	mm.material_override = mat
	root.add_child(mm)
	return root
