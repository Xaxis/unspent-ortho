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
	_index(w)
	var got: Variant = w.section_props.get(s)
	return got as Array[WorldProp] if got != null else [] as Array[WorldProp]


## The grid's cable spans leaving a mast in section `s`: (from, to) prop ids.
static func spans_in(w: WorldData, s: Vector2i) -> Array[Vector2i]:
	_index(w)
	var got: Variant = w.section_spans.get(s)
	return got as Array[Vector2i] if got != null else [] as Array[Vector2i]


## File one prop added after the index was made.
static func file(w: WorldData, p: WorldProp) -> void:
	if not w.sectioned:
		return
	var s := of(p.pos)
	if not w.section_props.has(s):
		w.section_props[s] = [] as Array[WorldProp]
	(w.section_props[s] as Array[WorldProp]).append(p)


static func _index(w: WorldData) -> void:
	if w.sectioned:
		return
	w.sectioned = true
	for p: WorldProp in w.each_prop():
		var s := of(p.pos)
		if not w.section_props.has(s):
			w.section_props[s] = [] as Array[WorldProp]
		(w.section_props[s] as Array[WorldProp]).append(p)
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
