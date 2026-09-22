class_name FlierView
extends Node3D
## The machines that cross overhead (docs/VISION.md, the owner's direction for
## the Slums: "flying machines"). Nothing in this game flew until now — every
## body walks or swims, and `crosses: &"fly"` had been in the roster's
## vocabulary since M2 with no row using it.
##
## THESE ARE NOT BODIES. They are not fought, not targeted, not spawned and not
## culled; nothing here touches `FightSim`, a `MobState` or the hero, and no
## roster row is read. They are the plan's traffic.
##
## WHAT THE PLAYER ACTUALLY SEES OF ONE IS THE LIGHT IT DROPS, not the machine.
## At this camera a thing nineteen units up is a small shape at the edge of the
## frame and deep inside the near depth of field; the beam it puts on the street
## is the whole of the cue, and it is what says the thing is real and how high it
## is. Two corrections were taken off frames to get there and both are written
## where they belong (`flier_shade.gdshader`): it began as a bar of SHADE, which
## is right in daylight and nothing at all on a night street, and then as a soft
## pool wide enough to read as weather.
##
## THEY FLY THE MACHINES' OWN BEARING. `GenWorks.bearing(seed)` is the line every
## ruled work on the island lies on — turf cut in rows, drainage, the survey
## posts — so the traffic runs on the same grid as everything else the plan laid.
## That is the fiction and it is also what makes the arithmetic easy: the fliers
## are a LATTICE on that bearing, lanes `LANE` apart across it and a machine
## every `APART` along it, the whole lattice sliding at one speed.
##
## SO A FLIER'S POSITION IS A PURE FUNCTION of (seed, lane, index, world
## minutes). Nothing integrates, nothing is saved, nothing accumulates: two shots
## of one moment are one picture, a tour's `same A B TOL` holds, and a player who
## walks away and comes back finds the traffic where it should have got to. A
## per-frame integration would have been easier to write and would have made
## every frame of this layer unreproducible.
##
## The promise the rest of the depth layer keeps is kept here by construction:
## these are drawn with the world's own material, and `world.gdshader`'s
## `tall_cut` opens anything BUILT above 3.0 units that would cover the player.
## A flier is eight units up and is not the land, so it stipples out over your
## head without this file saying a word about it.

## Lanes across the bearing, and machines along it, in tiles. Wide enough that
## two are never in one frame from the same lane, close enough that the sky is
## never empty over a city.
const LANE := 21.0
const APART := 26.0
## Tiles a minute. A world minute is short, so this is a machine crossing the
## frame in about twenty seconds of world time: present, never darting.
const SPEED := 1.35
## How high they fly, and how much one lane differs from the next. Clear of the
## tallest thing anybody builds (a spire is 16.3) so nothing ever clips a roof.
const HIGH := 19.0
const HIGH_STEP := 3.1
## Tiles from the focus a flier is built at all. Wider than the frame's own
## corner so one is never seen to appear.
const REACH := 26.0

## The beam it puts on the street, in tiles, and how strong.
##
## Measured off a frame of the city, not chosen: at 5.5 the pool was a tenth of
## the frame across, and anything that wide and that soft is read as weather
## whatever colour it is. A beam narrow enough to be a beam is the point — the
## street should brighten under one spot and go dark again as it passes.
const SHADE := 3.2
## Raised with the narrowing, because the two are one decision: the same light
## through a third of the area has to be stronger per tile or the machine reads
## as further away rather than better focused.
const SHADE_DARK := 0.95

## Material ids (matter.gdshaderinc), as `ForeKinds` names them.
const M_SWARF := 56
## The stolen-neon mark: lit when the light goes, on the MACHINES' power, so a
## strike stutters the traffic exactly as it stutters everything else of theirs.
const M_NEON := 34

const Works := preload("res://src/models/props/works.gd")

var world: WorldData
var camera: Camera3D
## How many may stand in the air at once. 0 turns the layer off entirely, which
## is every landscape that has not asked for it.
var budget := 0
## How many were within REACH at all, before the frame had its say. `drawn` on
## its own could not tell "no traffic near" from "all of it off the glass", and
## those want opposite fixes -- the same lie #116 was.
var considered := 0
## How many had the HULL ITSELF on the glass, not just the beam it lays on the
## street. The two differ by the whole of #138: the shade sits at ground level so
## it carries no height term, while a hull 19 to 26.6 units up is above the top
## edge at every distance ahead. Counting them apart is what says whether
## "crosses overhead" is a thing a player ever actually sees.
var hulls := 0
var drawn := 0

static var _mesh: ArrayMesh = null
static var _shade_mesh: ArrayMesh = null

var _pool: Array[MeshInstance3D] = []
var _shades: Array[MeshInstance3D] = []
var _live := 0
var _mat: ShaderMaterial
var _shade_mat: ShaderMaterial


func setup(w: WorldData, cam: Camera3D, mat: ShaderMaterial) -> void:
	world = w
	camera = cam
	_mat = mat
	_shade_mat = ShaderMaterial.new()
	_shade_mat.shader = preload("res://src/render/depth/flier_shade.gdshader")
	# 11: over the ground and the track marks (9), under the people (10, who draw
	# after what was once the outline pass) and under MobFx (12). A shadow lies ON
	# the street, so anything standing in the street is in front of it. It is set
	# on the MATERIAL and not in the shader, which is where this project sets it
	# everywhere else — transparent world geometry at the default 0 is not dimmed,
	# it is ABSENT.
	_shade_mat.render_priority = 11


func rebind(w: WorldData) -> void:
	world = w


## Where flier (lane, index) is at `minutes`, in tiles. Pure.
static func at(seed_value: int, lane: int, index: int, minutes: float) -> Vector2:
	var b := GenWorks.bearing(seed_value)
	var along := Vector2.from_angle(b)
	var across := Vector2(-along.y, along.x)
	# Each lane is offset along the bearing by its own share, so the lattice is
	# not a rank of machines flying in step.
	var skew := Rng.hash01(seed_value, lane, 0x71) * APART
	var run := fposmod(float(index) * APART + skew + minutes * SPEED, APART * 1024.0)
	return across * (float(lane) * LANE) + along * run


## How high that one flies.
static func high_of(seed_value: int, lane: int) -> float:
	return HIGH + float(posmod(lane, 3)) * HIGH_STEP + Rng.hash01(seed_value, lane, 0x72) * 1.4


## Put the traffic near `focus` in the air. Called every frame; cheap, because
## the lattice is arithmetic and the meshes are two shared ArrayMeshes.
func follow(focus: Vector2, minutes: float) -> void:
	if world == null or budget <= 0:
		_hide_from(0)
		return
	var b := GenWorks.bearing(world.seed_value)
	var along := Vector2.from_angle(b)
	var across := Vector2(-along.y, along.x)
	# Which lanes and which places along them could be in reach at all.
	var lane_mid := roundi(focus.dot(across) / LANE)
	var lanes := ceili(REACH / LANE)
	var n := 0
	considered = 0
	hulls = 0
	for dl in range(-lanes, lanes + 1):
		if n >= budget:
			break
		var lane := lane_mid + dl
		var skew := Rng.hash01(world.seed_value, lane, 0x71) * APART
		var run_mid := (focus.dot(along) - skew - minutes * SPEED) / APART
		for di in range(-1, 2):
			if n >= budget:
				break
			var index := roundi(run_mid) + di
			var p := at(world.seed_value, lane, index, minutes)
			if p.distance_to(focus) > REACH:
				continue
			considered += 1
			# A radius is not the frame. Every lane class flies 19 to 26.6 units
			# up, and at 57 degrees of pitch height and away-distance BOTH carry a
			# thing up the screen and add, so no lane has a hull inside the top
			# edge at any distance AHEAD of the player (task #138, and the rule is
			# measured in tests/render/test_read_reach.gd). Slots used to go to
			# whatever lane order reached first, so most of the budget was spent on
			# traffic nobody could see.
			if not _in_frame(p, high_of(world.seed_value, lane)):
				continue
			_place(n, p, high_of(world.seed_value, lane), b)
			n += 1
	_hide_from(n)
	drawn = n
	_live = n


## Is any of this one in the picture -- the hull, OR the shade it lays on the
## ground? BOTH, and the second is not a nicety: the shade sits at ground level,
## so its screen position carries no height term and it is still in frame long
## after the hull has left the top edge. This file's own header says the beam on
## the street "is the whole of the cue", so a filter that asked only about the
## hull would throw away the cue along with it.
##
## Asked of the camera this view was already handed at `setup` rather than worked
## out from constants, because the frame moves: zoom, the target lean, and the
## third-person glide (#121) all change it. No camera (a headless run) keeps
## everything, which is what this did before.
func _in_frame(p: Vector2, high: float) -> bool:
	if camera == null or world == null:
		return true
	var vp := camera.get_viewport()
	if vp == null:
		return true
	var rect := vp.get_visible_rect().size
	# Pixels per world unit, asked of the camera: the view's height in units maps
	# to the viewport's height in pixels, and a zoom moves it.
	var px := rect.y / maxf(camera.size, 1e-3)
	var ground := world.height_at(p)
	var seen := false
	for k in 2:
		var at_y := (ground + high) if k == 0 else (ground + 0.06)
		var s := camera.unproject_position(Vector3(p.x, at_y, p.y))
		if s.y >= 0.0 and s.y <= rect.y and s.x >= -SHADE * px and s.x <= rect.x + SHADE * px:
			seen = true
			if k == 0:
				hulls += 1
	return seen


func _hide_from(from: int) -> void:
	for i in range(from, _live):
		_pool[i].visible = false
		_shades[i].visible = false
	_live = mini(_live, from)


func _place(i: int, p: Vector2, high: float, bearing: float) -> void:
	var node := _slot(i)
	var ground := world.height_at(p)
	node.global_transform = Transform3D(Basis(Vector3.UP, -bearing), Vector3(p.x, ground + high, p.y))
	node.visible = true
	# The shadow lies on the ground under it, not on the machine's own plane, and
	# it is what the eye actually reads at this camera.
	var sh := _shade_slot(i)
	sh.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(SHADE, 1.0, SHADE)),
		Vector3(p.x, ground + 0.06, p.y))
	sh.visible = true


func _slot(i: int) -> MeshInstance3D:
	while _pool.size() <= i:
		var m := MeshInstance3D.new()
		m.mesh = mesh()
		m.material_override = _mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(m)
		_pool.append(m)
	return _pool[i]


func _shade_slot(i: int) -> MeshInstance3D:
	while _shades.size() <= i:
		var m := MeshInstance3D.new()
		m.mesh = shade_mesh()
		m.material_override = _shade_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_shades.append(m)
	return _shades[i]


## The machine itself, built once and shared: a lifting body with two ducts, a
## belly that is the only part a player ever sees properly, and the plan's own
## strip and beacon along it. Small on purpose — what says "city" is that there
## are several of them on one bearing, not that any one of them is a spectacle.
static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var k := MeshKit.new()
	var hull := Palette.PLATE[1]
	hull.a = M_SWARF / 255.0
	var dark := Palette.PLATE[3]
	dark.a = M_SWARF / 255.0
	var lamp := Palette.LENS[2]
	lamp.a = M_NEON / 255.0
	# The body: a flattened hull, chamfered, nose along +X.
	k.box(Vector3(-0.9, -0.16, -0.42), Vector3(0.7, 0.16, 0.42), hull, dark)
	k.box(Vector3(0.62, -0.10, -0.26), Vector3(1.05, 0.08, 0.26), dark)
	# Two ducts, because one reads as a fish and three as a toy.
	for s in 2:
		var z := 0.52 * (1.0 if s == 0 else -1.0)
		k.prism(-0.12, -0.20, z, 0.30, 0.20, 0.27, 8, dark, hull)
		k.strut(Vector3(-0.12, 0.0, z * 0.45), Vector3(-0.12, 0.0, z * 0.82), 0.07, 4, hull)
	# The strip along the belly and the beacon under the nose: the machines' own
	# light, so it burns when the light goes and stutters under a strike.
	k.box(Vector3(-0.78, -0.19, -0.07), Vector3(0.52, -0.15, 0.07), lamp)
	k.prism(0.86, -0.17, 0.0, 0.07, -0.05, 0.05, 6, lamp)
	_mesh = k.build()
	return _mesh


## The bar of shade it drags along the street: a unit disc, drawn by
## flier_shade.gdshader, scaled by SHADE.
static func shade_mesh() -> ArrayMesh:
	if _shade_mesh != null:
		return _shade_mesh
	var k := MeshKit.new()
	# The machines' cold, so the one thing crossing a sodium street in the colour
	# `palette.gd` reserves for them is a machine.
	var c := Works.STRIP
	c.a = SHADE_DARK
	var n := 16
	for i in n:
		var a0 := float(i) / n * TAU
		var a1 := float(i + 1) / n * TAU
		k.tri(Vector3.ZERO, Vector3(cos(a1), 0.0, sin(a1)), Vector3(cos(a0), 0.0, sin(a0)), c)
	_shade_mesh = k.build()
	return _shade_mesh


## Only the tests want this; a running game shares the two meshes for its life.
static func forget() -> void:
	_mesh = null
	_shade_mesh = null
