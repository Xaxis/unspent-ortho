class_name UiSettlementScreen
extends UiScreen
## The holding app (h): what a player can put up where they stand, what they have
## already built, and — in the stolen module's own violet, because it is the
## machines' reading and not the player's — what the place gives off
## (docs/VISION.md §9.4, docs/ART.md §9).
##
## One list and one key. A build row puts the piece up in front of the player; a
## piece row mends it if it is coming apart, and otherwise puts somebody on it or
## takes them off; the stores row carries what the holding has laid by into the
## creel. The row says which of those it will do before it is pressed, so nothing
## on this page is a surprise.
##
## It owns no rules. What a piece costs is `SettlementBuild`, what it does is
## `StructureKind`, and everything that touches the world goes through the
## settlement system (46_settlements), which is handed to it when it is added.

const LIST_TOP := 50
## Pixels the signature block takes at the foot of the spare pane.
const SIGN_H := 96
## Under this share of its strength a piece is worth a hand: the same number the
## settlement system tends by, so the row never promises a verb it will not do.
const MEND_BELOW := 0.95

## The settlement system (46_settlements). Systems have no class_name, so it is
## held as a Node and called by name, the way dev mode's app holds the ui system.
var holdings: Node


func _init() -> void:
	super()
	screen_name = &"holding"
	own_action = &"holding"


func _on_open() -> void:
	scroll = 0
	# What is on the glass must be what the holding has done, not what it had
	# done the last time somebody looked at it.
	if holdings != null:
		@warning_ignore("return_value_discarded")
		holdings.call("settle_up")


func refresh() -> void:
	var rows: Array[Dictionary] = []
	rows.append({"header": "put up here"})
	var inv := game.inventory if game != null else null
	for kind: int in StructureKind.BUILDABLE:
		var why := SettlementBuild.why_not(inv, kind)
		if why == "" and holdings != null:
			why = String(holdings.call("why_not_here", kind))
		rows.append({"id": row_id(kind), "kind": kind, "build": true,
			"enabled": why == "", "why": why, "title": StructureKind.display_name(kind)})
	var place := _place()
	if place == null:
		rows.append({"header": "no holding yet"})
		rows.append({"id": &"none", "enabled": false, "why": "Put something up and this becomes a place.",
			"title": "nothing built"})
	else:
		rows.append({"header": place.name})
		for p in place.pieces:
			rows.append({"id": StringName("piece_%d" % p.id), "piece": p.id, "enabled": true,
				"title": StructureKind.display_name(p.kind)})
		if place.stored() > 0.0:
			rows.append({"id": &"stores", "stores": true, "enabled": true, "title": "take what is laid by"})
	menu.set_rows(rows)
	queue_redraw()


## What a build row is called, for a tour's `choose` and a shot's `--screen`:
## `build_lean_to`, `build_radio_mast`. The kind's own words, so a tour reads as
## a sentence instead of naming a number out of an enum.
static func row_id(kind: int) -> StringName:
	return StringName("build_%s" % StructureKind.display_name(kind).replace(" ", "_").replace("-", "_"))


## The holding this page is about: the one the player is standing in or beside.
func _place() -> Settlement:
	if holdings == null:
		return null
	return holdings.call("here") as Settlement


func _on_confirm(row: Dictionary) -> void:
	if holdings == null:
		refuse("Nothing to build with.")
		return
	var said := ""
	if row.get("build", false):
		said = String(holdings.call("build_here", int(row.kind)))
	elif row.has("piece"):
		said = String(holdings.call("tend", int(row.piece)))
	elif row.get("stores", false):
		said = String(holdings.call("collect_stores"))
	if said.begins_with("!"):
		refuse(said.substr(1))
	else:
		Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
		if said != "":
			say(said)
	refresh()


func _draw() -> void:
	# The slate itself is lit rather than a tab: the holding has no key on the
	# status strip, as dev mode's page has none.
	draw_frame(&"")
	var L := UiSlate.LIST
	UiSlate.title(self, L, "HOLDING")
	UiSlate.spare(self)
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 8
	var lines := UiSlate.line_count(LIST_TOP, L.end.y - 4)
	keep_in_view(lines)
	for n in mini(lines, menu.rows.size() - scroll):
		var i := scroll + n
		var row := menu.rows[i]
		var top := UiSlate.line_top(LIST_TOP, n)
		if row.has("header"):
			UiSlate.heading(self, Vector2i(x0, top), String(row.header), right)
			continue
		var ok := UiMenu.enabled(row)
		var col := UiTheme.TEXT if ok else UiTheme.TEXT_DIM
		if i == menu.index:
			UiSlate.row_bar(self, x0 - 4, right + 3, top, UiTheme.TEXT if ok else UiTheme.WARN)
			col = UiTheme.BRIGHT if ok else UiTheme.TEXT
		UiDraw.text(self, Vector2i(x0 + 4, top), String(row.title), col)
		UiDraw.text_right(self, right, top, _right_of(row), UiTheme.TEXT_DIM)
	if scroll > 0:
		UiDraw.text_right(self, right, LIST_TOP - 11, "↑", UiTheme.TEXT_DIM)
	if scroll + lines < menu.rows.size():
		UiDraw.text_right(self, right, UiSlate.line_top(LIST_TOP, lines) - 2, "↓", UiTheme.TEXT_DIM)
	_draw_spare(UiSlate.SPARE)
	draw_keys([["e", _verb()], ["h", "close"], ["esc", "back"]])


## The word on the key strip for what E would do to the chosen row: the page
## never says "make" over a row that would mend or hire.
func _verb() -> String:
	var row := menu.selected()
	if row.get("build", false):
		return "build"
	if row.get("stores", false):
		return "take"
	var p := _piece_of(row)
	if p == null:
		return "-"
	if p.ruined:
		return "clear"
	if StructureKind.needs_staff(p.kind) and p.staffed_by < 0:
		return "work it"
	if p.condition() < MEND_BELOW:
		return "mend"
	return "leave" if p.staffed_by >= 0 else "-"


## The right-hand column of a row: what it wants, or how it is doing.
func _right_of(row: Dictionary) -> String:
	if row.get("build", false):
		return UiRules.duration(StructureKind.minutes(int(row.kind)))
	if row.get("stores", false):
		var place := _place()
		return "%d" % int(place.stored()) if place != null else ""
	var p := _piece_of(row)
	if p == null:
		return ""
	if p.ruined:
		return "wreck"
	if p.condition() < 0.6:
		return "%d%%" % roundi(p.condition() * 100.0)
	if p.staffed_by >= 0:
		return "worked"
	if StructureKind.needs_staff(p.kind):
		return "idle"
	return ""


func _piece_of(row: Dictionary) -> Structure:
	var place := _place()
	if place == null or not row.has("piece"):
		return null
	return place.piece(int(row.piece))


func _draw_spare(R: Rect2i) -> void:
	var row := menu.selected()
	var x0 := R.position.x + UiSlate.MARGIN_L
	var y := R.position.y + 8
	if row.get("build", false):
		_draw_kind(R, x0, y, int(row.kind))
	elif row.has("piece"):
		_draw_piece(R, x0, y, _piece_of(row))
	elif row.get("stores", false):
		_draw_stores(R, x0, y)
	_draw_signature(R, x0, R.end.y - 6 - SIGN_H)


## What a piece is, what it wants and what it gives back.
func _draw_kind(R: Rect2i, x0: int, y: int, kind: int) -> int:
	UiDraw.text(self, Vector2i(x0, y), StructureKind.display_name(kind).to_upper(), UiTheme.BRIGHT)
	y += 12
	UiDraw.text(self, Vector2i(x0, y), _idiom_words(kind), UiTheme.TEXT_DIM)
	y += 11
	var gives := _gives_words(kind, true)
	if gives != "":
		UiDraw.text(self, Vector2i(x0, y), gives, UiTheme.TEXT)
		y += 11
	y += 4
	var inv := game.inventory if game != null else null
	UiDraw.text(self, Vector2i(x0, y), "WANTS", UiTheme.TEXT_DIM)
	var col_have := R.end.x - UiSlate.MARGIN_R
	UiDraw.text_right(self, col_have, y, "HAVE", UiTheme.TEXT_DIM)
	UiDraw.text_right(self, col_have - 36, y, "WANT", UiTheme.TEXT_DIM)
	y += 11
	UiDraw.hline(self, x0, R.end.x - UiSlate.MARGIN_R, y, UiTheme.FAINT)
	y += 3
	for id: StringName in StructureKind.cost(kind):
		var want := int(StructureKind.cost(kind)[id])
		var have := inv.count(id) if inv != null else 0
		UiIcons.draw_item(self, id, Vector2i(x0, y))
		UiDraw.text(self, Vector2i(x0 + 13, y + 1), UiRules.bare_name(id).to_upper(), UiTheme.TEXT)
		UiDraw.text_right(self, col_have - 36, y + 1, str(want), UiTheme.TEXT)
		UiDraw.text_right(self, col_have, y + 1, str(have), UiTheme.WARN if have < want else UiTheme.TEXT)
		y += 13
	return y


func _idiom_words(kind: int) -> String:
	match StructureKind.idiom(kind):
		StructureKind.Idiom.MENDED: return "machine plate on a made frame"
		StructureKind.Idiom.FOUND: return "taken whole off a machine"
	return "hand work: timber, cord and thatch"


## What a kind is for, in the player's words rather than the table's. `wants` adds
## what it will ask for once it is up, which belongs on the page that is deciding
## whether to build it and nowhere else.
func _gives_words(kind: int, wants: bool) -> String:
	var parts := PackedStringArray()
	if StructureKind.sleeps(kind) > 0:
		parts.append("sleeps %d" % StructureKind.sleeps(kind))
	if StructureKind.store_room(kind) > 0.0:
		parts.append("room for %d more" % roundi(StructureKind.store_room(kind)))
	if StructureKind.makes_power(kind) > 0.0:
		parts.append("makes power")
	if StructureKind.banks(kind) > 0.0:
		parts.append("banks charge")
	if StructureKind.defence(kind) > 0.0:
		parts.append("holds a line")
	if StructureKind.gives_water(kind):
		parts.append("waters the plots")
	for id: StringName in StructureKind.makes(kind):
		parts.append("grows %s" % UiRules.bare_name(id))
	if wants and StructureKind.needs_staff(kind):
		parts.append("wants somebody on it")
	if wants and StructureKind.draw_power(kind) > 0.0:
		parts.append("wants power")
	return ", ".join(parts)


func _draw_piece(R: Rect2i, x0: int, y: int, p: Structure) -> int:
	if p == null:
		return y
	UiDraw.text(self, Vector2i(x0, y), StructureKind.display_name(p.kind).to_upper(), UiTheme.BRIGHT)
	y += 12
	if p.ruined:
		UiDraw.text(self, Vector2i(x0, y), "broken past mending", UiTheme.WARN)
		return y + 12
	_bar(Rect2i(x0, y, 120, 5), p.condition(), UiTheme.TEXT if p.condition() > 0.4 else UiTheme.WARN)
	UiDraw.text(self, Vector2i(x0 + 128, y - 3), "%d%%" % roundi(p.condition() * 100.0), UiTheme.TEXT_DIM)
	y += 13
	if StructureKind.needs_staff(p.kind):
		UiDraw.text(self, Vector2i(x0, y), "worked" if p.staffed_by >= 0 else "nobody on it",
			UiTheme.TEXT if p.staffed_by >= 0 else UiTheme.TEXT_DIM)
		y += 11
	if StructureKind.draw_power(p.kind) > 0.0:
		UiDraw.text(self, Vector2i(x0, y), "powered" if p.powered else "no power", UiTheme.TEXT if p.powered else UiTheme.WARN)
		y += 11
	UiDraw.text(self, Vector2i(x0, y), "working" if p.working() else "idle", UiTheme.TEXT_DIM)
	y += 11
	var gives := _gives_words(p.kind, false)
	if gives != "":
		UiDraw.text(self, Vector2i(x0, y), gives, UiTheme.TEXT_DIM)
		y += 11
	return y


func _draw_stores(R: Rect2i, x0: int, y: int) -> int:
	var place := _place()
	if place == null:
		return y
	UiDraw.text(self, Vector2i(x0, y), "LAID BY", UiTheme.BRIGHT)
	y += 12
	UiDraw.text(self, Vector2i(x0, y), "room for %d, %d in it" % [roundi(place.store_room()), roundi(place.stored())], UiTheme.TEXT_DIM)
	y += 13
	for id: Variant in place.stores:
		var n := int(place.stores[id])
		if n <= 0:
			continue
		UiIcons.draw_item(self, StringName(id), Vector2i(x0, y))
		UiDraw.text(self, Vector2i(x0 + 13, y + 1), UiRules.bare_name(StringName(id)).to_upper(), UiTheme.TEXT)
		UiDraw.text_right(self, R.end.x - UiSlate.MARGIN_R, y + 1, str(n), UiTheme.TEXT)
		y += 13
	if not place.people.is_empty():
		UiDraw.text(self, Vector2i(x0, y + 4), "%d living here%s" % [place.people.size(), ", hungry" if place.hunger > 0.3 else ""],
			UiTheme.WARN if place.hunger > 0.5 else UiTheme.TEXT_DIM)
		y += 15
	return y


## What a machine hears, in the module's violet. This is the one readout on the
## slate that is not the player's own knowledge: it is the stolen display saying
## what the machines' own senses make of the place (docs/ART.md §9).
func _draw_signature(R: Rect2i, x0: int, y: int) -> void:
	var place := _place()
	UiDraw.hline(self, x0, R.end.x - UiSlate.MARGIN_R, y, UiTheme.FAINT)
	y += 5
	UiDraw.text(self, Vector2i(x0, y), "WHAT A MACHINE HEARS", UiTheme.MACHINE[3])
	y += 12
	if place == null:
		UiDraw.text(self, Vector2i(x0, y), "nothing yet", UiTheme.MACHINE[1])
		return
	var sig := place.signature()
	var right := R.end.x - UiSlate.MARGIN_R
	for c in Signature.CHANNELS:
		var v := sig.get_channel(c)
		UiDraw.text(self, Vector2i(x0, y - 1), String(c).replace("_", " "), UiTheme.MACHINE[2] if v > 0.01 else UiTheme.MACHINE[1])
		_bar(Rect2i(right - 84, y + 2, 84, 4), v, UiTheme.MACHINE[3] if v < 0.6 else UiTheme.WARN)
		y += 10
	var total := sig.total()
	UiDraw.text(self, Vector2i(x0, y + 1), "loudest: %s" % (String(sig.loudest()).replace("_", " ") if total > 0.01 else "nothing"),
		UiTheme.MACHINE[3])
	UiDraw.text_right(self, right, y + 1, "%d%%" % roundi(total * 100.0), UiTheme.WARN if total > 0.6 else UiTheme.MACHINE[3])


func _bar(r: Rect2i, share: float, col: Color) -> void:
	UiDraw.rect(self, r, UiTheme.GHOST)
	var w := roundi(float(r.size.x) * clampf(share, 0.0, 1.0))
	if w > 0:
		UiDraw.rect(self, Rect2i(r.position, Vector2i(w, r.size.y)), col)
