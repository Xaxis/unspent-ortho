class_name HeatFx
## Heat lifting off hot ground at a body, lit and never drawn (docs/LOOK.md: the
## world is lit, not drawn; no ink). Three things, each freeing itself:
##   motes  sparks of ember rising off the ground round the feet, their own
##          light, fading as they climb
##   haze   the air over the ground wavering: a disc on the ground at the feet
##          that shows the frame behind it rippled (heat_haze.gdshader)
##   glow   the ground and the boots warmed from under by a small light
## The heat cue (52_hazards, HazardCues `heat`) puts them out in the cue's own
## ember. Drawn as ink lines, and before that as breath's white vapour, it read
## as a drawing laid on the world. Nothing here is drawn over the body: every
## piece is depth-tested, and no mote rises on the eye's side of it.

## Motes per cue, how high each climbs before it is gone, and how big it is: a
## spark's size under the close eye, and from above never under MOTE_PX of the
## frame, or at play zoom it is a speck nobody sees.
const MOTES := 14
const MOTE_RISE := 1.2
const MOTE_SIZE := 0.05
const MOTE_PX := 9.0
## The ring they rise from, about the feet: inside the body's own width there is
## nothing to see, and further out it is no longer this body's heat.
const RING := Vector2(0.35, 0.85)
## Half the circle about the body, the half toward the eye, grows none: a mote
## rising there would pass in front of the figure.
const EYE_SIDE := 0.5
## The under-glow: a light a little over the ground, bright enough to warm ash
## at noon and too small to read as a lamp.
const GLOW_ENERGY := 2.4
const GLOW_RANGE := 1.9
## Low, so it warms the boots and the ground and not the backs of the knees.
const GLOW_HEIGHT := 0.12
## The haze's radius and how far it pushes the frame at full strength.
const HAZE_RADIUS := 1.1
const HAZE_REACH := 0.004
## Transparent geometry draws in order: after the land and the bodies, with the
## other lit air (FireModel.smoke_material).
const PRIORITY := 11
const HAZE_SHADER := preload("res://src/render/heat_haze.gdshader")

static var _mote_tex: Texture2D


static func lift(parent: Node, at: Vector3, col: Color, seconds: float, seed_value: int) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var cam := parent.get_viewport().get_camera_3d()
	# Which way the eye lies from the body, on the ground.
	var to_eye := Vector2(0.0, 1.0)
	if cam != null:
		var d := cam.global_position - at
		if Vector2(d.x, d.z).length() > 0.01:
			to_eye = Vector2(d.x, d.z).normalized()
		else:
			# Straight overhead: the eye's own down-screen, in the world.
			var b := cam.global_transform.basis.y
			to_eye = -Vector2(b.x, b.z).normalized() if Vector2(b.x, b.z).length() > 0.01 else to_eye
	var size := MOTE_SIZE if MobFx.close_eye(parent) else MobFx.at_least(MOTE_SIZE, MOTE_PX)
	_motes(parent, at, col, seconds, seed_value, to_eye, size)
	_haze(parent, at, seconds, seed_value)
	_glow(parent, at, col, seconds)


static func _motes(parent: Node, at: Vector3, col: Color, seconds: float, seed_value: int, to_eye: Vector2, size: float) -> void:
	var away := to_eye.angle() + PI
	for i in MOTES:
		# Spread over the far half of the circle, never the eye's half.
		var a := away + (Rng.hash01(seed_value, i, 1) - 0.5) * TAU * (1.0 - EYE_SIDE)
		var r := lerpf(RING.x, RING.y, Rng.hash01(seed_value, i, 2))
		var from := at + Vector3(cos(a) * r, 0.05, sin(a) * r)
		var life := seconds * lerpf(0.55, 0.9, Rng.hash01(seed_value, i, 3))
		var wait := (seconds - life) * Rng.hash01(seed_value, i, 4)
		var drift := Vector3((Rng.hash01(seed_value, i, 5) - 0.5) * 0.3, MOTE_RISE * lerpf(0.6, 1.0, Rng.hash01(seed_value, i, 6)), (Rng.hash01(seed_value, i, 7) - 0.5) * 0.3)
		var mi := MeshInstance3D.new()
		mi.mesh = FireModel.smoke_mesh()
		var mat := _mote_material(col)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * size * lerpf(0.7, 1.2, Rng.hash01(seed_value, i, 8))
		parent.add_child(mi)
		mi.global_position = from
		mi.visible = false
		var tw := mi.create_tween()
		tw.tween_interval(wait)
		tw.tween_callback(func() -> void: mi.visible = true)
		tw.set_parallel(true)
		tw.chain().tween_property(mi, "global_position", from + drift, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		# Bright as it leaves the ground, gone by the top of its climb.
		tw.tween_method(func(t: float) -> void:
			mat.albedo_color = Color(col.r, col.g, col.b, (1.0 - t) * minf(1.0, t * 6.0)), 0.0, 1.0, life)
		tw.chain().tween_callback(mi.queue_free)


static func _mote_material(col: Color) -> StandardMaterial3D:
	if _mote_tex == null:
		# A hot core with a short falloff: smoke's long soft one made a spark a
		# blur at arm's length and nothing at all from above.
		var tex := GradientTexture2D.new()
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.9))
		tex.gradient = g
		_mote_tex = tex
	var m := StandardMaterial3D.new()
	m.albedo_texture = _mote_tex
	m.albedo_color = Color(col.r, col.g, col.b, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.render_priority = PRIORITY
	return m


static func _haze(parent: Node, at: Vector3, seconds: float, seed_value: int) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * HAZE_RADIUS * 2.0
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = HAZE_SHADER
	mat.render_priority = PRIORITY
	mat.set_shader_parameter(&"seed", Rng.hash01(seed_value, 9))
	mat.set_shader_parameter(&"reach", HAZE_REACH)
	mat.set_shader_parameter(&"strength", 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at + Vector3(0.0, 0.03, 0.0)
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		mat.set_shader_parameter(&"strength", sin(t * PI)), 0.0, 1.0, seconds)
	tw.tween_callback(mi.queue_free)


static func _glow(parent: Node, at: Vector3, col: Color, seconds: float) -> void:
	var l := OmniLight3D.new()
	# Godot takes light_color as sRGB, which the palette is.
	l.light_color = col
	l.light_energy = 0.0
	l.omni_range = GLOW_RANGE
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = at + Vector3(0.0, GLOW_HEIGHT, 0.0)
	var tw := l.create_tween()
	tw.tween_method(func(t: float) -> void:
		l.light_energy = GLOW_ENERGY * sin(t * PI), 0.0, 1.0, seconds)
	tw.tween_callback(l.queue_free)
