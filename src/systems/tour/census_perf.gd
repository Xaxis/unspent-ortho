## `perf census [N]`: every drawn geometry in the game, summed by what it is, the N
## biggest by triangles (default 12). A frame's `primitives` say how much and the
## layer probes (FoliagePerf) what one layer costs; this says WHERE the triangles
## are, when most of them are in nothing a layer names (the pinewood over the
## shoulder: 3M primitives, its chunks' props and leaves 0.2M of them).
##
## What is loaded and shown, not what the camera kept: no frustum culling, so a
## ring of chunks behind the camera counts. A MultiMesh counts its visible
## instances. `casts` is how much of it also goes into a shadow pass.

static func perf(_tour: Node, game: Node, parts: PackedStringArray) -> bool:
	var top := parts[2].to_int() if parts.size() > 2 else 12
	var tris := {}
	var casts := {}
	var nodes := {}
	for n: Node in game.get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var t := triangles(g)
		if t == 0:
			continue
		var key := _what(g)
		tris[key] = int(tris.get(key, 0)) + t
		nodes[key] = int(nodes.get(key, 0)) + 1
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casts[key] = int(casts.get(key, 0)) + t
	var keys := tris.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(tris[a]) > int(tris[b]))
	var total := 0
	for k: Variant in keys:
		total += int(tris[k])
	print("tour census: %d triangles shown in %d kinds of geometry" % [total, keys.size()])
	for k: Variant in keys.slice(0, top):
		print("tour census: %8d tris (%d cast) in %d nodes  %s" % [tris[k], casts.get(k, 0), nodes[k], k])
	return true


static func triangles(g: GeometryInstance3D) -> int:
	if g is MeshInstance3D:
		return _mesh_triangles((g as MeshInstance3D).mesh)
	if g is MultiMeshInstance3D:
		var mm := (g as MultiMeshInstance3D).multimesh
		if mm == null:
			return 0
		var shown := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		return _mesh_triangles(mm.mesh) * shown
	return 0


static func _mesh_triangles(m: Mesh) -> int:
	if m == null or not (m is ArrayMesh or m is PrimitiveMesh):
		return 0
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		var v: Variant = a[Mesh.ARRAY_VERTEX]
		if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty():
			t += (idx as PackedInt32Array).size() / 3
		elif v is PackedVector3Array:
			t += (v as PackedVector3Array).size() / 3
	return t


## A geometry's kind: its name and its parent's, with the numbers taken out, so
## every chunk's `props` is one row and every machine's legs another.
static func _what(g: Node) -> String:
	var parent := g.get_parent()
	var p: String = String(parent.name) if parent != null else ""
	var rx := RegEx.create_from_string("[0-9_-]+$|_-?[0-9]+_-?[0-9]+")
	return "%s/%s" % [rx.sub(String(p), "", true), rx.sub(String(g.name), "", true)]
