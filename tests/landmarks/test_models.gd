extends TestCase
## The drawn landmarks, held to what their own header claims (docs/VISION.md §3,
## docs/ART.md). A thousand lines of geometry went in with no test of any kind
## against them, under a header that said "the tests hold them to the first two"
## when nothing under tests/ so much as named the file.
##
## Four rules, and every kind answers all four:
##   IT IS TALL ENOUGH TO BE READ FROM WHERE IT SAYS IT CAN BE. `LandmarkDef.sees`
##   is a promise about the picture, and the picture is the play camera's:
##   `Landmarks.read_reach` turns the rig's own numbers into the furthest a thing
##   of that height is still in frame over most of the compass.
##   IT COSTS WHAT A MACHINE COSTS. The Figures contract budgets a machine six
##   draw calls; a landmark is a bigger thing standing on its own, so it gets ten,
##   and nothing may quietly grow past that.
##   IT IS A THING, NOT A FIELD. Nothing spreads so far that the silhouette is
##   lost inside it.
##   IT CAN BE OPENED. A player has to be able to stand within `OPEN_REACH` of
##   its cache without walking into the mass of it.

## What a landmark may cost to draw, in surfaces. Every kind is one FOUND mesh,
## one lamps mesh, one MADE mesh and the cache's three, and the ones that use
## fewer draw an empty mesh for the rest.
const DRAW_BUDGET := 10
## The camera the game really plays at, asked of the rig rather than written down.
const ASPECT := 16.0 / 9.0


func _rig() -> Dictionary:
	var rig := CameraRig.new()
	var out := {"view_height": rig.view_height, "pitch_deg": rig.pitch_deg}
	rig.free()
	return out


func test_no_kind_claims_to_be_read_from_further_than_the_camera_shows() -> void:
	var rig := _rig()
	for d: LandmarkDef in Landmarks.all():
		var m := LandmarkModels.measure(d.id)
		var reach := Landmarks.read_reach(rig.view_height, rig.pitch_deg, ASPECT, float(m.high))
		lt(d.sees, reach + 0.01, "%s says it reads from %.0f tiles; at %.1f units tall the camera shows it to %.1f"
			% [d.id, d.sees, float(m.high), reach])
		print("landmark %s: %.1f tall, %d draws, reads to %.1f, claims %.0f"
			% [d.id, float(m.high), int(m.draws), reach, d.sees])


func test_every_kind_stands_above_what_is_round_it() -> void:
	# The tallest ordinary prop in the game is a fire tower at 4.2 (docs/ART.md);
	# a landmark that is not clear of that is not a silhouette, it is scenery.
	for d: LandmarkDef in Landmarks.all():
		var m := LandmarkModels.measure(d.id)
		gt(float(m.high), 4.6, "%s does not stand above the props round it" % d.id)
		lt(float(m.wide), 12.0, "%s is a field, not a thing: its own shape is lost in it" % d.id)


func test_none_of_them_costs_more_than_a_landmark_is_worth() -> void:
	for d: LandmarkDef in Landmarks.all():
		var m := LandmarkModels.measure(d.id)
		lt(float(m.draws), float(DRAW_BUDGET) + 0.5, "%s draws %d times" % [d.id, int(m.draws)])


## Two runs of the same kind on the same seed build the same thing: the models
## take a seed and nothing else, so a landmark redrawn when the player walks back
## to it is the landmark they walked away from.
func test_a_kind_is_the_same_model_every_time_it_is_built() -> void:
	for d: LandmarkDef in Landmarks.all():
		var a := LandmarkModels.measure(d.id, 5)
		var b := LandmarkModels.measure(d.id, 5)
		near(float(a.high), float(b.high), 1e-5, "%s is the same height twice" % d.id)
		eq(int(a.draws), int(b.draws), "%s costs the same twice" % d.id)


# --- the mass of one -------------------------------------------------------------

func test_every_kind_has_a_mass_that_stops_a_body() -> void:
	for d: LandmarkDef in Landmarks.all():
		var mass := LandmarkModels.blocks(d.id)
		check(not mass.is_empty(), "%s is walk-through: nothing in it stops a body" % d.id)
		for c: Vector3 in mass:
			gt(c.z, 0.05, "%s has a wall with no radius" % d.id)


## THE CACHE CAN BE REACHED. It stands at (`CACHE_OUT`, 0) in the model's own
## frame, and a player has to get within `OPEN_REACH` of it from somewhere: the
## grown hulk's belly and the evaporator's boom both lie across that ground, and
## a mass drawn without checking would have made those two places impossible to
## open with nothing failing.
func test_a_player_can_stand_within_reach_of_every_cache() -> void:
	const BODY := 0.34
	for d: LandmarkDef in Landmarks.all():
		var mass := LandmarkModels.blocks(d.id)
		var cache := Vector2(Landmarks.CACHE_OUT, 0.0)
		var room := 0
		for i in 64:
			var a := TAU * i / 64.0
			for r: float in [0.6, 1.2, 1.8, 2.4, 2.7]:
				var p := cache + Vector2.from_angle(a) * r
				var clear := true
				for c: Vector3 in mass:
					if Vector2(c.x, c.y).distance_to(p) < c.z + BODY:
						clear = false
						break
				if clear:
					room += 1
		gt(float(room), 8.0, "%s: there is nowhere to stand and open its cache" % d.id)


## And a landmark's own mass never reaches the cache itself, or the locker is
## drawn inside a wall.
func test_nothing_is_drawn_on_top_of_its_own_cache() -> void:
	for d: LandmarkDef in Landmarks.all():
		var cache := Vector2(Landmarks.CACHE_OUT, 0.0)
		for c: Vector3 in LandmarkModels.blocks(d.id):
			gt(Vector2(c.x, c.y).distance_to(cache), c.z, "%s stands on its own cache" % d.id)
