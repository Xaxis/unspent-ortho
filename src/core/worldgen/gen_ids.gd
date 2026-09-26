class_name GenIds
## The last step of generation: give every prop its section id,
## (section << WorldData.ORDINAL_BITS) | ordinal, where the ordinal is the order
## the prop was laid among its own section's props. Generation lays props in one
## world-wide order and indexes them densely while it works; this reorders
## `props` section by section and rewrites every id the world keeps (the grid's
## lines, the treads' prop lists), so nothing after generation sees a dense id.


static func run(w: WorldData) -> void:
	var across := WorldSections.across(w.size)
	var sections := across * across
	var count := PackedInt32Array()
	count.resize(sections)
	var sec := PackedInt32Array()
	sec.resize(w.props.size())
	for i in w.props.size():
		var s := WorldSections.of(w.props[i].pos)
		var k := clampi(s.y, 0, across - 1) * across + clampi(s.x, 0, across - 1)
		sec[i] = k
		count[k] += 1
	var start := PackedInt32Array()
	start.resize(sections + 1)
	for k in sections:
		start[k + 1] = start[k] + count[k]
		assert(count[k] < (1 << WorldData.ORDINAL_BITS), "a section holds more props than an ordinal counts")
	var fill := start.duplicate()
	var out: Array[WorldProp] = []
	out.resize(w.props.size())
	var new_id := PackedInt32Array()
	new_id.resize(w.props.size())
	for i in w.props.size():
		var k := sec[i]
		var p := w.props[i]
		new_id[i] = (k << WorldData.ORDINAL_BITS) | (fill[k] - start[k])
		out[fill[k]] = p
		fill[k] += 1
	for i in w.props.size():
		w.props[i].id = new_id[i]
	w.props = out
	w.section_start = start
	w.table = PropTable.of(out)
	var remap := func(old: int) -> int: return new_id[old] if old >= 0 and old < new_id.size() else old
	for line: Dictionary in w.lines:
		if line.has("props"):
			var ids := PackedInt32Array(line["props"])
			for j in ids.size():
				ids[j] = remap.call(ids[j])
			line["props"] = ids
	# A tread's props were laid together, a span of dense ids; as section ids
	# they are a list.
	for m: Dictionary in w.landmarks:
		if m.get("kind") == &"tread" and m.get("props") is Vector2i:
			var span: Vector2i = m["props"]
			var ids := PackedInt32Array()
			for old in range(span.x, span.y):
				ids.append(new_id[old])
			m["props"] = ids
	var moved := {}
	for old: int in w.depleted:
		moved[remap.call(old)] = w.depleted[old]
	w.depleted = moved
