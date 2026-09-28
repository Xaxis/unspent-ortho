class_name DevPageArcView
extends DevPage
## One arc as a graph (docs/ROADMAP.md, "Tools track", T3), opened with e on a
## chosen beat of the story map: Godot's own GraphEdit, dressed as the slate's
## glass. Its beats run left to right in the arc's order along a bright line;
## under each, what can land it, with every line said and who says it where;
## over it, the gate into 2029 it opens, or the region's asks it is the end of.
## A door says what must be known before it opens ("once known"), and where that
## is a beat of this arc a line runs from it to the door. Every node names the
## line of source that made it, and e puts that line on the clipboard.
##
## tab and c walk the nodes in order, the arrows look across, the zoom keys
## scale, esc goes back to the map with the chosen beat as it was.

const COL_W := 470
const ROW_H := 230
const NODE_W := 420

var arc: StringName = &""
var graph: StoryArcGraph
## The node chosen, and the GraphNode drawn for each node id.
var chosen: StringName = &""
var shown: Dictionary = {}
## The line of source e last put on the clipboard (a headless run has no clipboard).
var copied := ""

var _edit: GraphEdit
var _order: Array[StringName] = []


func of(arc_id: StringName, beat: StringName = &"") -> DevPageArcView:
	arc = arc_id
	chosen = StringName("beat:%s" % beat) if beat != &"" else &""
	return self


func heading() -> String:
	return str(StoryContent.ARCS.get(arc, {}).get("title", arc)).to_upper()


func wide() -> bool:
	return true


static func area() -> Rect2i:
	var top := UiDevScreen.LIST_TOP + 10
	var b := UiSlate.BODY
	return Rect2i(b.position.x + UiSlate.MARGIN_L, top, b.size.x - UiSlate.MARGIN_L - UiSlate.MARGIN_R, b.end.y - top - 8)


func enter() -> void:
	if _edit != null or game == null:
		return
	graph = StoryArcGraph.build(StoryMap.of(game.world), arc)
	var r := area()
	_edit = GraphEdit.new()
	_edit.position = Vector2(r.position)
	_edit.size = Vector2(r.size)
	_edit.theme = slate_theme()
	_edit.show_grid = false
	_edit.minimap_enabled = false
	_edit.show_menu = false
	_edit.right_disconnects = false
	_edit.focus_mode = Control.FOCUS_NONE
	_edit.zoom_min = 0.35
	_edit.zoom_max = 1.6
	screen.add_child(_edit)
	var colour := arc_colour()
	for n: Dictionary in graph.nodes:
		var gn := _node(n, colour)
		_edit.add_child(gn)
		shown[n.id] = gn
		_order.append(n.id)
	for e: Dictionary in graph.edges:
		var from: GraphNode = shown.get(e.from)
		var to: GraphNode = shown.get(e.to)
		if from != null and to != null:
			@warning_ignore("return_value_discarded")
			_edit.connect_node(from.name, 0, to.name, 0)
	if chosen == &"" or not shown.has(chosen):
		chosen = _order[0] if not _order.is_empty() else &""
	_edit.zoom = 0.8
	_show_chosen()


func leave() -> void:
	if _edit != null and is_instance_valid(_edit):
		_edit.queue_free()
	_edit = null
	shown.clear()
	_order.clear()


func arc_colour() -> Color:
	var i := StoryContent.arcs().find(arc)
	return DevPageStoryMap.ARC_COLOURS[i % DevPageStoryMap.ARC_COLOURS.size()] if i >= 0 else UiTheme.TEXT


## A graph node for `n`: its title in the arc's colour (a beat) or the slate's
## text (the rest), each line with who says it, and its source in violet.
func _node(n: Dictionary, colour: Color) -> GraphNode:
	var gn := GraphNode.new()
	gn.name = String(n.id).replace(":", "_")
	gn.title = str(n.title)
	gn.position_offset = Vector2(n.col * COL_W, n.row * ROW_H)
	gn.custom_minimum_size = Vector2(NODE_W, 0)
	gn.resizable = false
	gn.draggable = true
	gn.selectable = true
	var kind: StringName = n.kind
	var head := colour if kind == &"beat" else (UiTheme.MACHINE[3] if kind == &"gate" else UiTheme.TEXT)
	gn.add_theme_color_override("title_color", head)
	var first := true
	for l: Array in n.lines:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(NODE_W - 24, 0)
		var who := str(l[0])
		row.text = ("%s:  %s" % [who, str(l[1])]) if who != "" else str(l[1])
		row.add_theme_color_override("font_color", UiTheme.TEXT if who == "" or kind != &"beat" else UiTheme.TEXT_DIM)
		gn.add_child(row)
		if first:
			# Port 0: into a beat from the left, out of it to the right; a door or a
			# gate leaves from its right and comes in on its left.
			var port := colour if kind == &"beat" else UiTheme.FAINT
			gn.set_slot(0, true, 0, port, true, 0, port)
			first = false
	var src := Label.new()
	src.text = str(n.source)
	src.add_theme_color_override("font_color", UiTheme.MACHINE[3])
	gn.add_child(src)
	if first:
		gn.set_slot(0, true, 0, UiTheme.FAINT, true, 0, UiTheme.FAINT)
	return gn


# --- keys -----------------------------------------------------------------------------

func handle(action: StringName) -> bool:
	if _edit == null:
		return false
	match action:
		&"inventory", &"craft":
			var at := _order.find(chosen)
			at = clampi(at + (1 if action == &"inventory" else -1), 0, _order.size() - 1)
			chosen = _order[at]
			Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
			_show_chosen()
			return true
		&"up", &"down", &"left", &"right":
			var d := {&"up": Vector2(0, -1), &"down": Vector2(0, 1), &"left": Vector2(-1, 0), &"right": Vector2(1, 0)}[action] as Vector2
			_edit.scroll_offset += d * 80.0
			return true
		&"zoom_in", &"zoom_out":
			_edit.zoom = clampf(_edit.zoom * (1.2 if action == &"zoom_in" else 1.0 / 1.2), _edit.zoom_min, _edit.zoom_max)
			_show_chosen()
			return true
		&"confirm":
			var n := graph.node(chosen)
			if not n.is_empty():
				copied = str(n.source)
				DisplayServer.clipboard_set(copied)
				report("On the clipboard: %s" % str(n.source))
			return true
	return false


## The chosen node selected, and the view brought round to it.
func _show_chosen() -> void:
	for id: StringName in shown:
		(shown[id] as GraphNode).selected = id == chosen
	var gn: GraphNode = shown.get(chosen)
	if gn == null:
		return
	# The view is in graph units times zoom; stand the node a third in from the left.
	var want := (gn.position_offset + gn.size * 0.5) * _edit.zoom - Vector2(_edit.size.x * 0.35, _edit.size.y * 0.4)
	_edit.scroll_offset = want


## --dev=story_map:BEAT then e, or a tour: a node by its id or by its beat's.
func pick(what: StringName) -> bool:
	for id: StringName in [what, StringName("beat:%s" % what)]:
		if shown.has(id):
			chosen = id
			_show_chosen()
			return true
	return false


func keys(_row: Dictionary) -> Array:
	return [[PlayerSettings.cap_of(&"inventory") + " " + PlayerSettings.cap_of(&"craft"), "node"],
		[PlayerSettings.cap_of([&"move_up", &"move_left", &"move_down", &"move_right"]), "look"],
		[PlayerSettings.cap_of([&"zoom_out", &"zoom_in"]), "scale"], ["e", "copy its line"], ["esc", "the map"]]


func draw_wide(_ci: CanvasItem) -> void:
	pass


# --- the slate's dress for Godot's graph ---------------------------------------------------------

static var _theme: Theme


## GraphEdit and GraphNode in the slate's own glass, phosphor and violet: the
## editor's grey never shows.
static func slate_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := UiTheme.theme().duplicate() as Theme
	var glass := StyleBoxFlat.new()
	glass.bg_color = UiTheme.GLASS
	glass.border_color = UiTheme.FAINT
	glass.set_border_width_all(0)
	t.set_stylebox("panel", "GraphEdit", glass)
	t.set_stylebox("panel_focus", "GraphEdit", glass)
	var body := StyleBoxFlat.new()
	body.bg_color = UiTheme.GLASS_SPARE
	body.border_color = UiTheme.FAINT
	body.set_border_width_all(2)
	body.set_content_margin_all(10)
	body.anti_aliasing = false
	var lit := body.duplicate() as StyleBoxFlat
	lit.border_color = UiTheme.BRIGHT
	lit.bg_color = UiTheme.GLASS_LIT
	var bar := StyleBoxFlat.new()
	bar.bg_color = UiTheme.GLASS_ROW
	bar.border_color = UiTheme.FAINT
	bar.set_border_width_all(2)
	bar.border_width_bottom = 0
	bar.set_content_margin_all(8)
	bar.anti_aliasing = false
	var bar_lit := bar.duplicate() as StyleBoxFlat
	bar_lit.border_color = UiTheme.BRIGHT
	t.set_stylebox("panel", "GraphNode", body)
	t.set_stylebox("panel_selected", "GraphNode", lit)
	t.set_stylebox("titlebar", "GraphNode", bar)
	t.set_stylebox("titlebar_selected", "GraphNode", bar_lit)
	t.set_color("title_color", "GraphNode", UiTheme.TEXT)
	t.set_font("title_font", "GraphNode", UiFont.font())
	t.set_color("font_color", "Label", UiTheme.TEXT)
	t.set_color("grid_major", "GraphEdit", UiTheme.GHOST)
	t.set_color("grid_minor", "GraphEdit", UiTheme.GLASS_ROW)
	t.set_color("selection_fill", "GraphEdit", Color(UiTheme.PHOSPHOR[1], 0.2))
	t.set_color("selection_stroke", "GraphEdit", UiTheme.TEXT)
	t.set_color("activity", "GraphEdit", UiTheme.BRIGHT)
	t.set_constant("separation", "GraphNode", 4)
	# The graph's own scroll bars, as a hairline of phosphor with a lit grip.
	var track := StyleBoxFlat.new()
	track.bg_color = UiTheme.GLASS_ROW
	track.set_content_margin_all(3)
	var grip := StyleBoxFlat.new()
	grip.bg_color = UiTheme.FAINT
	var grip_lit := StyleBoxFlat.new()
	grip_lit.bg_color = UiTheme.TEXT_DIM
	for bar_kind: String in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", bar_kind, track)
		t.set_stylebox("scroll_focus", bar_kind, track)
		t.set_stylebox("grabber", bar_kind, grip)
		t.set_stylebox("grabber_highlight", bar_kind, grip_lit)
		t.set_stylebox("grabber_pressed", bar_kind, grip_lit)
	_theme = t
	return t
