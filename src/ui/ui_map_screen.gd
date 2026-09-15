class_name UiMapScreen
extends UiScreen
## The notebook map (M): only the land the player has seen, drawn in ink and
## wash across both pages and the fold. Arrows look around a step at a time
## (held keys repeat, per the menu standard); E changes the scale; M or Esc close.

## The map's window on the spread, in screen pixels.
const MAP_RECT := Rect2i(30, 44, 580, 280)
const PAN_STEP := 12
const SCALES: Array[int] = [1, 2, 3]

var explored: UiExplored
var data: UiMapData
var map_scale := 2
## Map pixel (tile * map_scale) under the window's top-left pixel.
var origin_px := Vector2i.ZERO

var _rect: ColorRect
var _overlay: Control
var _material: ShaderMaterial
var _seen_tex: ImageTexture


func _init() -> void:
	super()
	screen_name = &"map"
	own_action = &"map"
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/ui/map.gdshader")
	_rect = ColorRect.new()
	_rect.name = "map"
	_rect.position = Vector2(MAP_RECT.position)
	_rect.size = Vector2(MAP_RECT.size)
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_overlay = Control.new()
	_overlay.name = "marks"
	_overlay.size = Vector2(640, 360)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _on_open() -> void:
	if game == null:
		return
	if data == null:
		data = UiMapData.new(game.world)
	data.ensure()
	if explored == null:
		explored = UiExplored.new(game.world.size)
	_seen_tex = ImageTexture.create_from_image(Image.create_from_data(explored.size, explored.size, false, Image.FORMAT_L8, explored.mask))
	_material.set_shader_parameter("ground_tex", data.ground)
	_material.set_shader_parameter("level_tex", data.level)
	_material.set_shader_parameter("coast_tex", data.coast)
	_material.set_shader_parameter("marks_tex", data.marks)
	_material.set_shader_parameter("palette_tex", data.palette)
	_material.set_shader_parameter("seen_tex", _seen_tex)
	_material.set_shader_parameter("rect_size", Vector2(MAP_RECT.size))
	_material.set_shader_parameter("world_size", float(game.world.size))
	centre_on(game.player.pos)


## Put tile-space point `p` in the middle of the window.
func centre_on(p: Vector2) -> void:
	origin_px = Vector2i(roundi(p.x * map_scale), roundi(p.y * map_scale)) - MAP_RECT.size / 2
	_apply()


func handle(action: StringName) -> bool:
	if not is_open:
		return false
	match action:
		&"up": _pan(Vector2i(0, -PAN_STEP))
		&"down": _pan(Vector2i(0, PAN_STEP))
		&"left": _pan(Vector2i(-PAN_STEP, 0))
		&"right": _pan(Vector2i(PAN_STEP, 0))
		&"confirm":
			var centre := (Vector2(origin_px) + Vector2(MAP_RECT.size) * 0.5) / map_scale
			map_scale = SCALES[(SCALES.find(map_scale) + 1) % SCALES.size()]
			centre_on(centre)
			Events.sfx.emit(&"menu_move", Vector3.ZERO)
		_:
			return super(action)
	return true


func _pan(d: Vector2i) -> void:
	origin_px += d
	_apply()


func _apply() -> void:
	if game != null:
		# Keep some of the world in the window: stop a half-window past its edge.
		var world_px := game.world.size * map_scale
		var half := MAP_RECT.size / 2
		origin_px.x = clampi(origin_px.x, -half.x, maxi(-half.x, world_px - half.x))
		origin_px.y = clampi(origin_px.y, -half.y, maxi(-half.y, world_px - half.y))
	_material.set_shader_parameter("origin_px", Vector2(origin_px))
	_material.set_shader_parameter("scale", float(map_scale))
	queue_redraw()
	_overlay.queue_redraw()


## Screen position of tile-space point p.
func to_screen(p: Vector2) -> Vector2i:
	return MAP_RECT.position + Vector2i(floori(p.x * map_scale), floori(p.y * map_scale)) - origin_px


func _draw() -> void:
	UiNotebook.spread(self, 37)
	UiNotebook.title(self, UiNotebook.LEFT, "map", 21)
	if game == null:
		return
	var R := UiNotebook.RIGHT
	var p := game.player.pos
	var c := game.world.country_at(floori(p.x), floori(p.y))
	var place := Country.NAMES[c]
	UiDraw.text_right(self, R.end.x - 16, R.position.y + 11, "%s   %s" % [place, game.clock.label()], UiTheme.INK_SOFT)
	UiNotebook.footer(self, UiNotebook.LEFT, "wasd look     e scale     m close     esc")
	UiDraw.text_right(self, R.end.x - 16, R.end.y - 14, "%d%% of the coast seen" % roundi(explored.fraction() * 100.0) if explored != null else "", UiTheme.FADED)


func _draw_overlay() -> void:
	var ci := _overlay
	var r := MAP_RECT
	# The fold runs through the map: shade it as the pages do.
	var gx := UiNotebook.LEFT.end.x
	for i in 5:
		var a := 0.34 - i * 0.065
		UiDraw.vline(ci, gx - 1 - i, r.position.y, r.end.y - 1, Color(UiTheme.PAPER_EDGE, a))
		UiDraw.vline(ci, gx + 4 + i, r.position.y, r.end.y - 1, Color(UiTheme.PAPER_EDGE, a * 0.8))
	UiDraw.rect(ci, Rect2i(gx, r.position.y, 4, r.size.y), Color(UiTheme.PAPER_DEEP, 0.75))
	UiDraw.vline(ci, gx + 1, r.position.y, r.end.y - 1, Color(UiTheme.PAPER_EDGE, 0.8))
	# A drawn border, ruled twice.
	UiNotebook.box(ci, r.grow(2), UiTheme.INK, 5)
	UiNotebook.box(ci, r.grow(4), Color(UiTheme.INK, 0.45), 6)
	if game == null:
		return
	# Villages the player has seen: a house mark and the name, lettered on a clearing.
	for v in game.world.villages:
		var vp: Vector2 = v.pos
		if explored == null or not explored.seen(floori(vp.x), floori(vp.y)):
			continue
		var s := to_screen(vp)
		if not r.grow(-4).has_point(s):
			continue
		var name := String(v.name).to_lower()
		var w := UiFont.width(name)
		var tx := clampi(s.x - w / 2, r.position.x + 2, r.end.x - w - 2)
		var ty := s.y + 6
		if ty + 10 > r.end.y:
			ty = s.y - 16
		UiDraw.rect(ci, Rect2i(tx - 2, ty - 1, w + 4, 11), Color(UiTheme.PAPER, 0.85))
		UiDraw.text(ci, Vector2i(tx, ty), name, UiTheme.INK)
		UiDraw.rect(ci, Rect2i(s.x - 3, s.y - 3, 7, 7), UiTheme.PAPER)
		UiDraw.frame(ci, Rect2i(s.x - 2, s.y - 2, 5, 5), UiTheme.INK)
		UiDraw.px(ci, s.x, s.y, UiTheme.ACCENT)
	# You are here: an accent cross in a paper clearing.
	var me := to_screen(game.player.pos)
	if r.has_point(me):
		UiDraw.rect(ci, Rect2i(me.x - 4, me.y - 4, 9, 9), Color(UiTheme.PAPER, 0.7))
		for i in range(-3, 4):
			UiDraw.px(ci, me.x + i, me.y + i, UiTheme.ACCENT)
			UiDraw.px(ci, me.x + i, me.y - i, UiTheme.ACCENT)
			UiDraw.px(ci, me.x + i + (1 if i < 3 else 0), me.y + i, UiTheme.ACCENT)
			UiDraw.px(ci, me.x + i + (1 if i < 3 else 0), me.y - i, UiTheme.ACCENT)
	# North, in the corner, the way it is always drawn.
	var nx := r.end.x - 14
	var ny := r.position.y + 6
	UiDraw.rect(ci, Rect2i(nx - 5, ny - 2, 13, 26), Color(UiTheme.PAPER, 0.8))
	UiDraw.text(ci, Vector2i(nx - 1, ny), "N", UiTheme.INK)
	UiDraw.vline(ci, nx + 1, ny + 11, ny + 21, UiTheme.INK)
	UiDraw.hline(ci, nx, nx + 2, ny + 12, UiTheme.INK)
	UiDraw.hline(ci, nx - 1, nx + 3, ny + 13, UiTheme.INK)
