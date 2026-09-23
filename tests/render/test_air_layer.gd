extends TestCase
## The volumetric air is a LAYER ON THE GROUND, not a column from the eye
## (src/render/sky_light.gd, AIR_HIGH).
##
## The bug it guards: Godot integrates an Environment's volumetric density along
## the whole ray from the camera, so the light a lamp sent up crossed
## `CameraRig.distance` of air -- 30 units above the world under ortho, 14.4
## under the lens. A number that changes nothing in the orthographic projection
## decided how dark a night was: the moss took 30% off a lit tube at arm's
## length, and pressing Z brightened every foggy night by 8-18 luma.
##
## Headless there is no fog to look at, so this holds the PROPERTY that made the
## bug: nothing about the air may depend on how far back the camera stands, and
## no density may be left on the Environment for the eye's ray to integrate.
## The pictures are the six-scene sheets in the commit that landed this.

const Lights := preload("res://src/systems/15_lights.gd")
const NIGHT := 23.0


func _sky_with_camera(back: float) -> Array:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	tree.root.add_child(cam)
	cam.current = true
	var sky := SkyLight.new()
	tree.root.add_child(sky)
	sky.focus = Vector3(40.0, 1.5, 40.0)
	cam.global_position = sky.focus + Vector3(0.0, 0.84, 0.54).normalized() * back
	cam.look_at(sky.focus)
	sky.set_hour(NIGHT)
	sky.compose()
	return [sky, cam]


func _layer(sky: SkyLight) -> FogVolume:
	for c: Node in sky.get_children():
		if c is FogVolume:
			return c
	return null


func test_no_density_is_left_for_the_eyes_ray_to_integrate() -> void:
	var sc := _sky_with_camera(30.0)
	var sky: SkyLight = sc[0]
	var e := sky.env.environment
	eq(e.volumetric_fog_density, 0.0, "the Environment carries no volumetric density at night")
	var layer := _layer(sky)
	check(layer != null, "the air is a FogVolume the sky owns")
	if layer != null:
		gt((layer.material as FogMaterial).density, 0.0, "and the layer carries the night's air")
		near(layer.global_position.y + layer.size.y * 0.5, sky.focus.y + SkyLight.AIR_HIGH, 1e-3,
			"its top stands AIR_HIGH over the ground at the focus")
		check(layer.global_position.y - layer.size.y * 0.5 < sky.focus.y, "and it reaches below the ground there")
	sky.free()
	(sc[1] as Node).free()


func test_the_same_night_from_two_camera_distances_has_the_same_air() -> void:
	var near_sc := _sky_with_camera(14.4)
	var near_sky: SkyLight = near_sc[0]
	var nl := _layer(near_sky)
	var near_d := (nl.material as FogMaterial).density if nl != null else -1.0
	var near_env := near_sky.env.environment.volumetric_fog_density
	near_sky.free()
	(near_sc[1] as Node).free()
	var far_sc := _sky_with_camera(60.0)
	var far_sky: SkyLight = far_sc[0]
	var fl := _layer(far_sky)
	var far_d := (fl.material as FogMaterial).density if fl != null else -2.0
	var far_env := far_sky.env.environment.volumetric_fog_density
	far_sky.free()
	(far_sc[1] as Node).free()
	near(near_d, far_d, 1e-6, "the layer's density does not move with the camera (%f, %f)" % [near_d, far_d])
	near(near_env, far_env, 1e-6, "nor does anything left on the Environment")
	eq(near_env, 0.0, "and there is nothing left there to integrate")


func test_stolen_neon_scatters_into_the_mist_and_a_street_lamp_barely() -> void:
	var neon := Lights.fog_scatter({"kind": PropKind.HOUSE, "neon": Vector3(0.55, 1.0, 0.35)})
	var shack := Lights.fog_scatter({"kind": PropKind.SHACK})
	var machine := Lights.fog_scatter({"mob": true, "kind": -1})
	var lamp := Lights.fog_scatter({"kind": PropKind.LAMP})
	var fire := Lights.fog_scatter({"kind": PropKind.FIRE})
	gt(neon, lamp, "a stolen tube bleeds into the mist more than a street lamp")
	gt(shack, lamp, "and so does a shack's wired-in light")
	gt(machine, lamp, "and a machine's own light")
	eq(lamp, fire, "a lamp and a fire throw their light down alike")
	lt(lamp, 0.5, "and a warm light barely scatters, or a street of them turns the dark to haze")
