class_name DevPageKit
extends DevPage
## A setting that is a list: what a new game carries (counts), what it wears
## (on or off), or what a build makes (on or off). Every change is an edit of
## the configuration in use.

var setting := ""


func for_setting(id: String) -> DevPageKit:
	setting = id
	return self


func heading() -> String:
	return str(ConfigSchema.row(setting).get("label", setting)).to_upper()


func _kind() -> String:
	return str(ConfigSchema.row(setting).kind)


func _choices() -> Array:
	match _kind():
		"kit":
			return ConfigChoices.kit_items()
		"fit":
			return ConfigChoices.fit_items()
	return ConfigSchema.TARGETS.duplicate()


func rows() -> Array[Dictionary]:
	var v: Variant = GameConfig.value(setting)
	var out: Array[Dictionary] = []
	var group := &""
	for c: Variant in _choices():
		var id := StringName(str(c))
		if _kind() != "targets" and Items.group(id) != group:
			group = Items.group(id)
			out.append(header(String(group)))
		var text := Items.display_name(id) if _kind() != "targets" else ConfigChoices.target_name(String(id))
		var value := ""
		if _kind() == "kit":
			var n := int((v as Dictionary).get(String(id), 0))
			value = str(n) if n > 0 else ""
		else:
			value = "yes" if (v as Array).has(String(id)) else ""
		out.append(item(id, text, value, {"steps": true}))
	return out


func confirm(row: Dictionary) -> void:
	side(row, 1)


func side(row: Dictionary, dir: int) -> void:
	var id := String(row.id)
	var v: Variant = GameConfig.value(setting)
	if _kind() == "kit":
		var kit: Dictionary = (v as Dictionary).duplicate()
		var n := clampi(int(kit.get(id, 0)) + dir, 0, 99)
		if n == 0:
			kit.erase(id)
		else:
			kit[id] = n
		v = kit
	else:
		var list: Array = (v as Array).duplicate()
		if list.has(id):
			list.erase(id)
		else:
			list.append(id)
		v = list
	var why := GameConfig.set_value(setting, v)
	if why != "":
		refuse(why)
		return
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func keys(_row: Dictionary) -> Array:
	if _kind() == "kit":
		return [["a d", "fewer, more"], ["esc", "back"]]
	return [["e", "on or off"], ["esc", "back"]]


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var y := r.position.y + 8
	y = panel_heading(ci, r, y, str(ConfigSchema.row(setting).label), true)
	y = panel_wrapped(ci, r, y, str(ConfigSchema.row(setting).note), UiTheme.TEXT)
	y = panel_pair(ci, r, y, "now", ConfigChoices.show(setting, GameConfig.value(setting)))
	var id: StringName = screen.menu.selected().get("id", &"")
	if _kind() != "targets" and not Items.def(id).is_empty():
		UiSlate.scan_box(ci, Rect2i(panel_x(r) + 4, y + 10, 64, 64), id)
