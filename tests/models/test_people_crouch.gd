extends TestCase
## Crouched, the player must still be a person (docs/ART.md §5: the body reads
## against any ground at any hour at 640x360). Wave A2's art review found the one
## pose that does not: at zoom 6, CLOSER than play, the crouched figure was "a
## formless pale lump with one dark line through it".
##
## From a camera 45 degrees up, a body pitched forward over dropped hips lays
## its back flat across the screen and the head vanishes into it. What reads at
## eleven pixels is asymmetry and a gap, so those are what this holds: the head
## drops and stays clear of the back, the knees lead the hips and come apart,
## and no two limbs land in the same place.


func _posed(crouched: bool) -> PersonModel:
	var p := PersonModel.make({})
	p.crouched = crouched
	# A zero delta poses the skeleton at once and takes the crouch to full.
	p.animate(0.0, 0.0)
	return p


func test_crouching_drops_the_whole_body_a_long_way() -> void:
	var up := _posed(false)
	var down := _posed(true)
	var head_up := up.bone_transform(&"head").origin
	var head_down := down.bone_transform(&"head").origin
	var hips_up := up.bone_transform(&"hips").origin
	var hips_down := down.bone_transform(&"hips").origin
	lt(head_down.y, head_up.y - 0.22, "the head comes down with the hips")
	lt(hips_down.y, hips_up.y - 0.22, "and the hips drop by most of a shin")
	up.free()
	down.free()


func test_the_head_stands_clear_of_the_back_so_the_silhouette_is_not_one_mass() -> void:
	var down := _posed(true)
	var head := down.bone_transform(&"head").origin
	var chest := down.bone_transform(&"spine").origin
	# The person faces +X: the head has to be AHEAD of the chest, or from above
	# the two are the same pixel and the figure has no silhouette at all.
	gt(head.x - chest.x, 0.04, "the head is carried forward of the back")
	down.free()


func test_the_knees_lead_the_hips_and_come_apart() -> void:
	var down := _posed(true)
	var hips := down.bone_transform(&"hips").origin
	var knee_l := down.bone_transform(&"shin_l").origin
	var knee_r := down.bone_transform(&"shin_r").origin
	gt(knee_l.x - hips.x, 0.10, "the lead knee is well in front of the hips")
	gt(knee_r.x - hips.x, 0.04, "and so is the other one")
	# Their right is +Z: knees apart across the body, so the footprint is a
	# triangle and not a single vertical bar.
	gt(absf(knee_l.z - knee_r.z), absf(hips.z) + 0.10, "the knees are apart")
	down.free()


func test_the_two_sides_do_not_land_in_the_same_place() -> void:
	# A symmetric crouch is a blob; one knee further forward than the other is
	# what makes eleven pixels read as a person about to move.
	var down := _posed(true)
	var knee_l := down.bone_transform(&"shin_l").origin
	var knee_r := down.bone_transform(&"shin_r").origin
	gt(absf(knee_l.x - knee_r.x), 0.03, "one knee leads")
	down.free()


func test_a_crouched_body_still_walks_and_still_swings() -> void:
	# The crouch is an offset over whatever the body is doing, not a pose of its
	# own: a stance that cancelled the gait would be a new bug for an old one.
	var p := PersonModel.make({})
	p.crouched = true
	p.animate(0.0, 0.0)
	var still := p.bone_transform(&"thigh_l").origin
	p.animate(2.0, 0.4)
	var moving := p.bone_transform(&"thigh_l").origin
	check(still.distance_to(moving) > 0.0005, "the legs still stride down there")
	p.play_action(&"swing", 0.4)
	p.animate(0.0, 0.1)
	check(p.busy(), "and a swing still goes through")
	p.free()
