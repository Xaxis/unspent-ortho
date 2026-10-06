class_name ConstantLights
extends RefCounted
## THE LIGHT STATE THAT NEVER CHANGES (01_warm_lights says why): a shadowless
## directional light, an omni and a spot, BLACK, reaching past any world's edge,
## so every material is drawn with all three in its base pass on every frame and
## the program that draws it is the same whatever lights a scene brings.
##
## THE TITLE STANDS THEM TOO. A program is built per light state, and the title
## drew its coast in the other one (no local light at all), so every world,
## water, foliage and sky program it had built was built again in the new game's
## first frames, on the press: on the web a build the page waits on. With the
## same three under the title, the coast's programs are the game's.
##
##   var lights := ConstantLights.stand(parent)   # [omni, spot, dir], under parent
##   ConstantLights.follow(lights, focus)         # every frame, over the focus

## Past any world's edge from wherever the camera is, so the lights reach
## everything on every frame, the first one back outside a room included (the
## camera's focus is still the room's then).
const REACH := 100000.0


static func stand(parent: Node) -> Array[Light3D]:
	var omni := OmniLight3D.new()
	omni.name = "constant_omni"
	omni.omni_range = REACH
	var spot := SpotLight3D.new()
	spot.name = "constant_spot"
	spot.spot_range = REACH
	spot.spot_angle = 170.0
	var dir := DirectionalLight3D.new()
	dir.name = "constant_dir"
	dir.rotation = Vector3(-PI * 0.3, 0.4, 0.0)
	var lights: Array[Light3D] = [omni, spot, dir]
	for l: Light3D in lights:
		l.light_energy = 1.0
		l.light_color = Color.BLACK
		l.light_volumetric_fog_energy = 0.0
		l.shadow_enabled = false
		parent.add_child(l)
	return lights


## The omni just over `focus` and the spot high above it, looking down: what the
## camera looks at is always inside both.
static func follow(lights: Array[Light3D], focus: Vector3) -> void:
	lights[0].position = focus + Vector3(0.0, 3.0, 0.0)
	lights[1].position = focus + Vector3(0.0, 40.0, 0.0)
	lights[1].rotation = Vector3(-PI * 0.5, 0.0, 0.0)
