class_name UiSavesScreen
extends UiScreen
## The saves app (from home): slots, each with a picture of where it was made,
## when and where. The saves package fills it through SlateFeeds (&"saves"):
## the feed says what is in each slot, the act saves or loads. Until then the
## slots are empty and confirming says why.

const LIST_TOP := 50
const ROW_PITCH := 24

var _feed: Dictionary = {}
var _thumbs := {}


func _init() -> void:
	super()
	screen_name = &"saves"
	own_action = &""


func refresh() -> void:
	_feed = SlateFeeds.feed(&"saves", game)
	_thumbs.clear()
	var rows: Array[Dictionary] = []
	for s: Dictionary in _feed.get("slots", []):
		rows.append({"id": StringName(s.get("id", &"")), "slot": s})
	menu.set_rows(rows)
	queue_redraw()


func _on_confirm(row: Dictionary) -> void:
	var said := SlateFeeds.act(&"saves", game, row.id)
	if said.begins_with("!"):
		refuse(said.substr(1))
	else:
		Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
		if said != "":
			say(said)
	refresh()


func _thumb(slot: Dictionary) -> ImageTexture:
	var id := StringName(slot.get("id", &""))
	if _thumbs.has(id):
		return _thumbs[id]
	var img: Variant = slot.get("thumb")
	var tex: ImageTexture = null
	if img is Image:
		tex = ImageTexture.create_from_image(img)
	_thumbs[id] = tex
	return tex


func _draw() -> void:
	draw_frame()
	var L := UiSlate.LIST
	var R := UiSlate.SPARE
	UiSlate.title(self, L, "SAVES")
	UiSlate.spare(self)
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 8
	for i in menu.rows.size():
		var s: Dictionary = menu.rows[i].slot
		var top := LIST_TOP + i * ROW_PITCH
		var chosen := i == menu.index
		if chosen:
			UiDraw.rect(self, Rect2i(x0 - 4, top - 2, right - x0 + 7, ROW_PITCH - 3), UiTheme.GLASS_LIT)
			UiDraw.rect(self, Rect2i(x0 - 4, top - 1, 2, ROW_PITCH - 5), UiTheme.TEXT)
		var empty := bool(s.get("empty", false))
		UiDraw.text(self, Vector2i(x0 + 2, top), "%02d" % (i + 1), UiTheme.TEXT_DIM)
		UiDraw.text(self, Vector2i(x0 + 20, top), "empty" if empty else String(s.get("title", "")), UiTheme.TEXT_DIM if empty else (UiTheme.BRIGHT if chosen else UiTheme.TEXT))
		if not empty:
			UiDraw.text(self, Vector2i(x0 + 20, top + 10), "%s   %s" % [s.get("when", ""), s.get("place", "")], UiTheme.TEXT_DIM)
	var px := R.position.x + UiSlate.MARGIN_L
	var chosen_slot: Dictionary = menu.selected().get("slot", {})
	var box := Rect2i(px, R.position.y + 10, SlateFeeds.THUMB.x * 2, SlateFeeds.THUMB.y * 2)
	UiSlate.brackets(self, box.grow(3), UiTheme.TEXT_DIM, 6)
	var tex := _thumb(chosen_slot) if not chosen_slot.is_empty() else null
	if tex != null:
		draw_texture_rect(tex, Rect2(box), false)
	else:
		# No picture: the glass's own snow, fixed, dim.
		for y in range(box.position.y, box.end.y, 2):
			for x in range(box.position.x, box.end.x, 2):
				if Rng.hash01(x, y, 0, 0x5a0) < 0.14:
					UiDraw.px(self, x, y, UiTheme.GHOST if Rng.hash01(x, y, 1, 0x5a0) < 0.7 else UiTheme.FAINT)
		UiDraw.text_centred(self, box.position.x + box.size.x / 2, box.position.y + box.size.y / 2 - 5, "NO PICTURE", UiTheme.TEXT_DIM)
	var ty := box.end.y + 12
	if not chosen_slot.is_empty() and not bool(chosen_slot.get("empty", false)):
		UiDraw.text(self, Vector2i(px, ty), String(chosen_slot.get("title", "")), UiTheme.BRIGHT)
		UiDraw.text(self, Vector2i(px, ty + 11), String(chosen_slot.get("when", "")), UiTheme.TEXT)
		UiDraw.text(self, Vector2i(px, ty + 22), String(chosen_slot.get("place", "")), UiTheme.TEXT_DIM)
	elif not SlateFeeds.has_feed(&"saves"):
		UiSlate.wrapped(self, Vector2i(px, ty), R.end.x - 12 - px, "no save module is wired into the slate yet", UiTheme.TEXT_DIM)
	draw_keys([["e", "save" if bool(_feed.get("can_save", false)) else "choose"], ["esc", "back"]])
