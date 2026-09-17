class_name DevPageGive
extends DevPage
## Things: every item by its group, how many are carried, and e gives them (a
## piece of gear or a module is fitted as well, as --fit fits it).

## The scan window on the panel, a side: a picture, so it kept its size on screen.
const SCAN := 192
const AMOUNTS: Array[int] = [1, 5, 20]
const GROUPS: Array[StringName] = [&"tool", &"found", &"kit", &"food", &"good", &"material"]

var _amount := 1


func heading() -> String:
	return "THINGS"


func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = [item(&"amount", "give at a time", str(_amount), {"steps": true})]
	for g in GROUPS:
		var first := true
		for id: StringName in Items.DEFS:
			if Items.group(id) != g:
				continue
			if first:
				out.append(header(String(g)))
				first = false
			var n := game.inventory.count(id)
			out.append(item(id, Items.display_name(id), str(n) if n > 0 else ""))
	return out


func confirm(row: Dictionary) -> void:
	if row.id == &"amount":
		side(row, 1)
		return
	report(DevCheats.give(game, row.id, _amount))


func side(row: Dictionary, dir: int) -> void:
	if row.id != &"amount":
		return
	_amount = AMOUNTS[posmod(AMOUNTS.find(_amount) + dir, AMOUNTS.size())]
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func keys(row: Dictionary) -> Array:
	if row.get("id") == &"amount":
		return [["a d", "change"], ["esc", "back"]]
	return [["e", "give %d" % _amount], ["esc", "back"]]


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var id: StringName = screen.menu.selected().get("id", &"")
	if id == &"amount" or Items.def(id).is_empty():
		return
	var d := Items.def(id)
	var y := r.position.y + 16
	y = panel_heading(ci, r, y, Items.display_name(id))
	# The scan is a picture of the thing, so it kept its size on the glass; the
	# words beside it are type, and stand clear of its right edge.
	UiSlate.scan_box(ci, Rect2i(panel_x(r) + 8, y, SCAN, SCAN), id)
	var x := panel_x(r) + 8 + SCAN + 24
	var ty := y
	for pair: Array in [["group", str(d.get("group", ""))], ["bulk", UiRules.num(float(d.get("bulk", 0.0)))], ["carried", str(game.inventory.count(id))]]:
		UiDraw.text(ci, Vector2i(x, ty), pair[0], UiTheme.TEXT_DIM)
		UiDraw.text(ci, Vector2i(x + 100, ty), pair[1], UiTheme.TEXT)
		ty += UiTheme.LINE
	y += SCAN + 36
	var says := PackedStringArray()
	if d.has("verb") and str(d.verb) != "":
		says.append("works: %s" % d.verb)
	if d.has("dmg"):
		says.append("blow %d" % int(d.dmg))
	if d.has("feeds"):
		says.append("feeds %s h" % UiRules.num(float(d.feeds)))
	if d.has("slot"):
		says.append("worn: %s" % d.slot)
	if bool(d.get("module", false)):
		says.append("a module")
	if d.has("resist") and not (d.resist as Dictionary).is_empty():
		var keep := PackedStringArray()
		for h: Variant in d.resist:
			keep.append(str(h))
		says.append("keeps off %s" % ", ".join(keep))
	if d.has("ability"):
		says.append("gives %s" % d.ability)
	for s in says:
		y = panel_line(ci, r, y, s, UiTheme.TEXT)
