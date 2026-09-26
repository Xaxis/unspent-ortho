class_name WorldSections
## The world in SECTIONS: squares of SIZE tiles, the unit a streamed world
## loads and drops (the streaming design). Readers that want the props of an
## area ask for the sections it covers instead of walking every prop.
##
## Today every section is resident and this is an index over the world's own
## list, made once per world; props added later are filed by
## `WorldData.add_prop`. The store that streams sections takes this file's place
## and keeps the same answers.

## Tiles on a side: 8 x 8 terrain chunks, 2 x 2 far blocks, so neither straddles
## a section.
const SIZE := 256


## Sections across a world of `size` tiles.
static func across(size: int) -> int:
	return ceili(float(size) / SIZE)


## The section a tile-space point lies in.
static func of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x) / SIZE, floori(p.y) / SIZE)


## The props standing in section `s`, in id order.
static func props_in(w: WorldData, s: Vector2i) -> Array[WorldProp]:
	var out: Array[WorldProp] = []
	for row in rows_in(w, s):
		out.append(w.prop_at(row))
	return out


## The table rows of the props standing in section `s`, in id order: what a
## reader holds instead of the props themselves.
static func rows_in(w: WorldData, s: Vector2i) -> PackedInt32Array:
	_index(w)
	var got: Variant = w.section_rows.get(s)
	return got as PackedInt32Array if got != null else PackedInt32Array()


## The grid's cable spans leaving a mast in section `s`: (from, to) prop ids.
static func spans_in(w: WorldData, s: Vector2i) -> Array[Vector2i]:
	_index(w)
	var got: Variant = w.section_spans.get(s)
	return got as Array[Vector2i] if got != null else [] as Array[Vector2i]


## File one prop added after the index was made.
static func file(w: WorldData, p: WorldProp) -> void:
	if not w.sectioned:
		return
	var row := w.row_of_id(p.id)
	if row >= 0:
		_file(w, of(p.pos), row)


static func _file(w: WorldData, s: Vector2i, row: int) -> void:
	var rows: PackedInt32Array = w.section_rows.get(s, PackedInt32Array())
	rows.append(row)
	w.section_rows[s] = rows


static func _index(w: WorldData) -> void:
	if w.sectioned:
		return
	w.sectioned = true
	w.sync_table()
	var pos := w.table.pos
	for row in w.table.size():
		_file(w, of(pos[row]), row)
	# Each span is filed with the mast it leaves from, as it is drawn.
	for line: Dictionary in w.lines:
		if not line.has("props"):
			continue
		var ids := PackedInt32Array(line["props"])
		for j in ids.size() - 1:
			var a := w.prop(ids[j])
			if a == null or w.prop(ids[j + 1]) == null:
				continue
			var s := of(a.pos)
			if not w.section_spans.has(s):
				w.section_spans[s] = [] as Array[Vector2i]
			(w.section_spans[s] as Array[Vector2i]).append(Vector2i(ids[j], ids[j + 1]))
