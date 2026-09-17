extends TestCase
## The body made at the start of a game (AvatarState, 33_avatar): the walking
## figure wears it, gear goes on over it, a save brings it back, and it is never
## part of what makes a save refused (WorldStamp).

const Sx := preload("res://tests/save/save_fixture.gd")


static func _made() -> Dictionary:
	var look := PersonLook.BASE.duplicate(true)
	look["build"] = &"tall"
	look["hair_style"] = &"long"
	look["hair"] = &"red"
	look["skin"] = &"fair"
	look["beard"] = &"full"
	look["shirt"] = "moss:3"
	return look


func test_the_body_made_is_the_body_that_walks_and_gear_goes_on_over_it() -> void:
	Sx.use_root("avatar-walks")
	var o := BootOptions.parse(["--seed=1", "--size=48", "--hour=12", "--fit=oilskin,hat_brim"])
	o.avatar = _made()
	var g := Sx.game(tree, [], o)
	var look: Dictionary = g.player.model.look
	eq(look.build, &"tall", "the build chosen")
	eq(look.hair_style, &"long")
	eq(look.skin, &"fair")
	eq(str(look.shirt), "moss:3", "the shirt's colour")
	eq(look.coat, &"oilskin", "and the oilskin fitted, over that body")
	eq(look.hat, &"brim")
	check((look.gear as Array).has(&"slate"), "the slate still on the wrist")
	eq(AvatarState.of(g).look.build, &"tall", "the body is kept apart from the gear on it")
	check(not AvatarState.of(g).look.has("kit"), "which the body itself never carries")
	Sx.end(g)
	Sx.finish()


func test_a_save_brings_the_body_back_and_never_refuses_for_it() -> void:
	Sx.use_root("avatar-save")
	var o := BootOptions.parse(["--seed=1", "--size=48", "--hour=12"])
	o.avatar = _made()
	var a := Sx.game(tree, [], o)
	var stamp := WorldStamp.current()
	eq(str(Sx.system(a, "05_save").call("save_to", 1)), "", "saved")
	Sx.end(a)
	var ob := BootOptions.new()
	eq(SaveSlots.options_for(1, ob), "", "the slot boots: a chosen body is no reason to refuse it")
	var b := Sx.game(tree, [], ob)
	eq(b.player.model.look.build, &"tall", "the same body, loaded")
	eq(b.player.model.look.hair, &"red")
	eq(WorldStamp.current(), stamp, "and the stamp is the world's alone")
	Sx.end(b)
	Sx.finish()


func test_without_a_page_the_body_is_the_base_or_the_look_asked_for() -> void:
	Sx.use_root("avatar-base")
	var g := Sx.game(tree, ["--seed=1", "--size=48"])
	eq(g.player.model.look.build, PersonLook.BASE.build, "a game nobody made a body for wakes as the base body")
	Sx.end(g)
	var h := Sx.game(tree, ["--seed=1", "--size=48", "--look=heavy,cap"])
	eq(h.player.model.look.build, &"heavy", "--look is the body asked for")
	eq(h.player.model.look.hat, &"cap")
	Sx.end(h)
	Sx.finish()
