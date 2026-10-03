## `perf lit`: every shown local light and the shown geometry it reaches (a box its
## range touches, on a layer its cull mask takes). The Compatibility renderer the
## web draws with gives each geometry a list of at most
## rendering/limits/opengl/max_lights_per_object lights and runs every pixel of it
## through the whole list, so a lamp beside a house shades the whole of the chunk's
## ground. Counts only, the same on any load: lights shown, light-geometry pairs,
## the triangles those pairs shade, the most lights on one geometry, and how many
## geometries are past the cap (their extra lights are dropped, not drawn).

const _CENSUS := preload("res://src/systems/tour/census_perf.gd")


static func perf(_tour: Node, game: Node, _parts: PackedStringArray) -> bool:
	var c := count(game.get_tree().root)
	print("tour lit: %d lights shown, %d geometries lit, %d light-geometry pairs, %d triangle-lights, most %d on one (cap %d), %d past the cap" % [
		c.lights, c.lit, c.pairs, c.shaded, c.most, c.cap, c.over])
	return true


## The counts under `root`, as `perf lit` prints them.
static func count(root: Node) -> Dictionary:
	var lights: Array[Light3D] = []
	for n: Node in root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l is DirectionalLight3D or not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		lights.append(l)
	var c := {lights = lights.size(), lit = 0, pairs = 0, shaded = 0, most = 0, over = 0,
		cap = int(ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object", 8))}
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var box := g.global_transform * g.get_aabb()
		var on := 0
		for l in lights:
			if l.light_cull_mask & g.layers == 0:
				continue
			var r := (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
			var at := l.global_position
			if at.distance_to(at.clamp(box.position, box.end)) <= r:
				on += 1
		if on == 0:
			continue
		c.lit += 1
		c.pairs += on
		c.shaded += _CENSUS.triangles(g) * mini(on, int(c.cap))
		c.most = maxi(int(c.most), on)
		if on > int(c.cap):
			c.over += 1
	return c
