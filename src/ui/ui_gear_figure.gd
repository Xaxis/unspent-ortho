class_name UiGearFigure
extends Control
## The body on the gear page: the player's own figure, the one that walks the
## coast, wearing what the loadout holds, scanned onto the slate's glass (owner,
## 2026-09-17: "the fully rendered character ... wearing real gear").
##
## It is the real `PersonModel` (and a folded `GlideWingModel` when the wing is
## worn) standing in a world of its own inside a SubViewport, lit by its own two
## lights so the hour and the weather outside never darken it, and drawn through
## the scan: value to the slate's phosphor steps, the violet of FOUND plate to the
## module's violet, dithered at whole pixels. So whatever the people model becomes
## under the lit world, this page shows it, and never a second drawing of a body.
##
##   wear(spec, held, wing)      dress it; a change runs the scan down it again
##   turn_to(yaw)                ease round to show a side (the back slot turns it)
##   nudge(dir)                  a step round by hand
##   point_of(bone, offset)      where a part of the body is on the page (design units)
##
## Cost: nothing while the page is shut, and nothing on an open page while the
## figure stands still — the viewport renders once when the body is dressed, laid
## out or turned, and not otherwise; the model is not built until the page opens.

## Viewport pixels to one of the slate's. At 1 the figure is drawn in the slate's
## own pixels, like every other thing on the glass.
const RES := 1
## What the camera holds, in the model's units: a standing body and a little
## room above the head and below the feet, and more above when the folded wing
## stands up off the back. [height held, height looked at]
const FRAME_BODY := Vector2(1.95, 0.9)
const FRAME_WING := Vector2(2.45, 1.12)
## A little from above, as the game's own camera sees a person, but near enough
## level that the face and the chest are the page's.
const PITCH := deg_to_rad(9.0)
## How fast it turns to a side it is asked for, and how far a nudge turns it.
const TURN_RATE := 5.0
const NUDGE := deg_to_rad(30.0)
## Seconds the scan line takes down the figure when what it wears changes.
const SCAN_SECONDS := 0.55
const SCAN := preload("res://src/ui/ui_gear_scan.gdshader")
## Render layers: the figure as seen, and its FOUND mask.
const SEEN_LAYER := 1
const MASK_LAYER := 2

var viewport: SubViewport
var model: PersonModel
var wing: GlideWingModel
var camera: Camera3D
## The same body again, flat white where it is FOUND and black where it is MADE,
## on a layer only its own camera sees: the scan reads which pixels are machine
## parts off this, not off a colour that the lit world is going to change.
var mask: SubViewport
var mask_model: PersonModel
var mask_wing: GlideWingModel
var mask_camera: Camera3D
var yaw := 0.45
var yaw_to := 0.45
## 0..1 down the figure; 1 is no scan running.
var scan := 1.0
## The value range the scan spreads over the phosphor steps, read off the
## rendered figure itself so a body in shadow still fills the steps.
var levels := Vector2(0.06, 0.8)

## The world's MADE material, for the wing's frame (the gear page hands it over).
var made: Material
var _look: Dictionary = {}
var _held: StringName = &""
var _wing := false
var _levels_due := -1
## Frames the body still has to be drawn for.
var _dirty := 2
var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SCAN
	material = _mat


## Build the little world on first use: a page nobody opens costs nothing.
func _ensure() -> void:
	if viewport != null:
		return
	viewport = SubViewport.new()
	viewport.name = "figure_world"
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	# The tier decides antialiasing (Quality), as it does for the world.
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][clampi(int(Quality.current().get("msaa", 0)), 0, 3)]
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y))) * RES
	add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.66)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	# Key light high and to the figure's right as the page sees it, a cool fill
	# from behind the other shoulder so the outline never drops into the glass.
	var key := DirectionalLight3D.new()
	key.name = "key"
	key.light_energy = 1.25
	key.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(55.0), 0.0)
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.name = "rim"
	rim.light_energy = 0.55
	rim.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(200.0), 0.0)
	viewport.add_child(rim)
	camera = _camera(SEEN_LAYER)
	viewport.add_child(camera)
	camera.current = true
	model = _body("body")
	viewport.add_child(model)
	model.build(PersonModel.material())
	wing = _wing_on(model)
	# The mask shares the little world and draws only its own layer.
	mask = SubViewport.new()
	mask.name = "found_mask"
	mask.transparent_bg = true
	mask.msaa_3d = Viewport.MSAA_DISABLED
	mask.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mask.size = viewport.size
	add_child(mask)
	mask.world_3d = viewport.find_world_3d()
	mask_camera = _camera(MASK_LAYER)
	mask.add_child(mask_camera)
	mask_camera.current = true
	mask_model = _body("mask")
	viewport.add_child(mask_model)
	mask_model.build(PersonModel.material())
	mask_wing = _wing_on(mask_model)
	_dress_both()
	_mat.set_shader_parameter("found_mask", mask.get_texture())


static func _camera(layer: int) -> Camera3D:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.near = 0.1
	c.far = 40.0
	c.cull_mask = 1 << (layer - 1)
	return c


static func _body(n: String) -> PersonModel:
	var m := PersonModel.new()
	m.name = n
	return m


func _wing_on(body: PersonModel) -> GlideWingModel:
	var w := GlideWingModel.new()
	w.name = "wing"
	body.add_child(w)
	w.build(made)
	w.position = Vector3(-0.14, 0.92, 0.0)
	w.rotation = Vector3(0.0, PI * 0.5, 0.0)
	w.visible = false
	return w


## Dress the seen body and its mask alike, then lay each on its own layer: the
## mask's FOUND mesh flat white, everything else on it flat black.
func _dress_both() -> void:
	for b: PersonModel in [model, mask_model]:
		if b == null:
			continue
		if not _look.is_empty():
			b.set_look(_look)
		b.set_held(_held)
		b.rotation.y = yaw
	if wing != null:
		wing.visible = _wing
	if mask_wing != null:
		mask_wing.visible = _wing
	_layer(model, SEEN_LAYER, false)
	_layer(mask_model, MASK_LAYER, true)
	_frame()


static var _white: StandardMaterial3D
static var _black: StandardMaterial3D


static func _flat(white: bool) -> StandardMaterial3D:
	if _white == null:
		_white = StandardMaterial3D.new()
		_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_white.albedo_color = Color.WHITE
		_black = StandardMaterial3D.new()
		_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_black.albedo_color = Color.BLACK
	return _white if white else _black


## Every mesh under `body` onto `layer`; for the mask, FOUND meshes (the rig's
## found surface, the wing's plate) white and the rest black, and no shadow twin.
static func _layer(body: PersonModel, layer: int, is_mask: bool) -> void:
	if body == null:
		return
	var found_mesh: MeshInstance3D = null
	if body.rig != null:
		found_mesh = body.rig.meshes[SkinRig.FOUND]
	for n: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.layers = 1 << (layer - 1)
		if not is_mask:
			continue
		if body.rig != null and mi == body.rig.shadow:
			mi.visible = false
			continue
		mi.material_override = _flat(mi == found_mesh or mi.name == "plate")


## Hold the body, or the body and the wing standing off its back, in the frame.
func _frame() -> void:
	var f := FRAME_WING if _wing else FRAME_BODY
	var look_at := Vector3(0.0, f.y, 0.0)
	var dist := 8.0
	for c: Camera3D in [camera, mask_camera]:
		if c == null:
			continue
		c.size = f.x
		c.look_at_from_position(look_at + Vector3(dist * cos(PITCH), dist * sin(PITCH), 0.0), look_at, Vector3.UP)


func place(r: Rect2i) -> void:
	position = Vector2(r.position)
	size = Vector2(r.size)
	if viewport != null:
		viewport.size = r.size * RES
		mask.size = r.size * RES
	_dirty = 2


## Dress the figure. A change in what it wears runs the scan down it again, so a
## piece put on is seen going on.
func wear(spec: Dictionary, held: StringName, wing_on: bool) -> void:
	var same := not _look.is_empty() and var_to_str(PersonLook.normalize(spec)) == var_to_str(PersonLook.normalize(_look)) \
			and held == _held and wing_on == _wing
	_look = spec.duplicate(true)
	_held = held
	_wing = wing_on
	if same:
		return
	scan = 0.0
	_levels_due = 3
	_dirty = 2
	if model != null:
		_dress_both()


## What the figure is dressed in, holds, and whether the wing is on it.
func worn() -> Dictionary:
	return _look


func held() -> StringName:
	return _held


func wing_worn() -> bool:
	return _wing


func turn_to(y: float) -> void:
	yaw_to = y


func nudge(dir: int) -> void:
	yaw_to += NUDGE * dir


## Where `bone` (plus `offset` in its own frame) is on the page, in the design
## units this control is laid out in, or Vector2.INF before the figure exists.
func point_of(bone: StringName, offset: Vector3 = Vector3.ZERO) -> Vector2:
	if model == null or camera == null or not model.is_inside_tree():
		return Vector2.INF
	var local := model.bone_transform(bone) * offset
	var at := model.global_transform * local
	return position + camera.unproject_position(at) / float(RES)


## Whether that point is on the side of the body the glass sees: a mark for the
## back is not drawn over the chest.
func faces_glass(bone: StringName, offset: Vector3 = Vector3.ZERO) -> bool:
	if model == null or camera == null or not model.is_inside_tree():
		return false
	var at := model.global_transform * (model.bone_transform(bone) * offset)
	var middle := model.global_transform * model.bone_transform(&"spine").origin
	return (at - middle).dot(camera.global_transform.basis.z) > -0.03


## Finish the scan at once (a shot, a test): the figure as it stands, not halfway
## through being read.
func settle() -> void:
	scan = 1.0
	_mat.set_shader_parameter("scan", scan)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if viewport != null:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			mask.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_ensure()
	# The body is only drawn again when something about it moved: it turned, it was
	# dressed, it was laid out. A still figure on an open page costs the GPU nothing.
	var turning := absf(angle_difference(yaw, yaw_to)) > 0.002
	if turning:
		yaw = lerp_angle(yaw, yaw_to, 1.0 - exp(-TURN_RATE * delta))
		model.rotation.y = yaw
		mask_model.rotation.y = yaw
		_dirty = maxi(_dirty, 1)
	if _dirty > 0:
		_dirty -= 1
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		mask.render_target_update_mode = SubViewport.UPDATE_ONCE
	if scan < 1.0:
		scan = minf(1.0, scan + delta / SCAN_SECONDS)
	if _levels_due >= 0:
		_levels_due -= 1
		# A headless run draws nothing to read back.
		if _levels_due < 0 and DisplayServer.get_name() != "headless":
			_read_levels()
	_mat.set_shader_parameter("scan", scan)
	_mat.set_shader_parameter("lo", levels.x)
	_mat.set_shader_parameter("hi", levels.y)
	queue_redraw()


func _draw() -> void:
	if viewport == null:
		return
	draw_texture_rect(viewport.get_texture(), Rect2(Vector2.ZERO, size), false)


## Spread the figure's own values over the steps: the darkest and brightest few
## hundredths of what was drawn, so a body lit low still reads in every step.
func _read_levels() -> void:
	var img := viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return
	var values: PackedFloat32Array = []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				values.append(c.r * 0.3 + c.g * 0.55 + c.b * 0.15)
	if values.size() < 32:
		return
	values.sort()
	var lo := values[int(values.size() * 0.03)]
	var hi := values[int(values.size() * 0.97)]
	if hi - lo > 0.05:
		levels = Vector2(lo, hi)
