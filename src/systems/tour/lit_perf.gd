## `perf lit`: every shown local light and the shown geometry it reaches (a box its
## range touches, on a layer its cull mask takes). The Compatibility renderer the
## web draws with gives each geometry a list of at most
## rendering/limits/opengl/max_lights_per_object lights and runs every pixel of it
## through the whole list, so a lamp beside a house shades the whole of the chunk's
## ground. Counts only, the same on any load: lights shown, light-geometry pairs,
## the triangles those pairs shade, the most lights on one geometry, and how many
## geometries are past the cap (their extra lights are dropped, not drawn).
## 01_warm_lights' black stand-ins reach every geometry on purpose (a material's
## program never changes with the lights a scene brings): they are counted apart,
## and still take their two places under the cap.

const _CENSUS := preload("res://src/systems/tour/census_perf.gd")


static func perf(_tour: Node, game: Node, _parts: PackedStringArray) -> bool:
	var c := count(game.get_tree().root)
	print("tour lit: %d lights shown (and %d black), %d geometries lit, %d light-geometry pairs (and %d black), %d triangle-lights, most %d on one (cap %d), %d past the cap" % [
		c.lights, c.black, c.lit, c.pairs, c.black_pairs, c.shaded, c.most, c.cap, c.over])
	return true


## The counts under `root`, as `perf lit` prints them.
static func count(root: Node) -> Dictionary:
	var lights: Array[Light3D] = []
	var black := 0
	for n: Node in root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l is DirectionalLight3D or not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		lights.append(l)
		if l.light_color == Color.BLACK:
			black += 1
	var c := {lights = lights.size() - black, black = black, lit = 0, pairs = 0, black_pairs = 0, shaded = 0, most = 0, over = 0,
		cap = int(ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object", 8))}
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var box := g.global_transform * g.get_aabb()
		var on := 0
		var dark := 0
		for l in lights:
			if l.light_cull_mask & g.layers == 0:
				continue
			var r := (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
			var at := l.global_position
			if at.distance_to(at.clamp(box.position, box.end)) <= r:
				if l.light_color == Color.BLACK:
					dark += 1
				else:
					on += 1
		c.black_pairs += dark
		if on + dark > int(c.cap):
			c.over += 1
		if on == 0:
			continue
		c.lit += 1
		c.pairs += on
		c.shaded += _CENSUS.triangles(g) * mini(on, int(c.cap) - dark)
		c.most = maxi(int(c.most), on)
	return c
