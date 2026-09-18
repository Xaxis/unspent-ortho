extends TestCase
## Every walkable ground says what it is MADE OF, and the failure is silent.
##
## A ground's mark code (`GroundColors.mark`, stored in a vertex colour's alpha)
## picks its material row, its pigment and its wear. `world.gdshader` dispatches
## on it:
##
##   40..59  ground_mark + ground_wear + works_mark + survey_mark
##   61..70  strata
##    1..16  glowing (embers, flame)
##   17..32  a lamp
##      34   stolen neon
##       0   NOTHING -- no branch in the shader matches it
##
## So `PLAIN` (0) is not "a plain material", it is NO material: the wash is laid
## down and nothing is done to it. A ground with no row in `_base_mark` takes
## PLAIN and draws as a flat untreated sheet, at every hour, in every landscape
## that names it, and no error is raised anywhere.
##
## `Ground.FLOOR` was in that state for its whole life. It had a WASH in the
## shared table (`P.STONE[2]`) and no mark, which is the asymmetry worth naming:
## somebody decided what colour a floor is and nobody decided what it is made
## of, and a colour with no material still renders.
##
## THE STATED CAUSE WAS WRONG AND IT IS WORTH RECORDING WHY. The slums file
## carried a note that `GroundColors.PLAIN` and `GroundColors.GLOW` are both 0,
## so "an unmarked ground falls through to PLAIN -- which IS GLOW". They are
## both 0, but nothing can confuse them: the shader's glow branch is guarded
## `m >= 1 && m <= 16`, and `GLOW` is only ever spent as `GLOW + clampi(..., 1,
## 16)`, so code 0 can never be produced by the glow door nor consumed by it.
## The symptom the slums measured was real; the mechanism named for it was not.
## What an unmarked ground loses is its MATERIAL, not its darkness.

const PLAIN := GroundColors.PLAIN


## The shared table: every ground a body can stand on has a material.
func test_every_walkable_ground_has_a_mark_of_its_own() -> void:
	var bare: Array[String] = []
	for g: int in Ground.COUNT:
		if Ground.is_water(g):
			continue
		if GroundColors._base_mark(g) == PLAIN:
			bare.append(Ground.NAMES[g])
	eq(bare, [] as Array[String],
		"a ground with no mark draws as a flat untreated wash and says nothing: %s" % [bare])


## And water is left alone deliberately, so this test cannot be "fixed" by
## giving everything a row: the chart draws water, not a ground material.
func test_water_is_the_only_thing_left_without_one() -> void:
	for g: int in Ground.COUNT:
		if not Ground.is_water(g):
			continue
		eq(GroundColors._base_mark(g), PLAIN,
			"%s is drawn by the water chart and must not take a ground material" % Ground.NAMES[g])


## The live question, which is the one that actually breaks: every ground any
## landscape NAMES resolves to a material once that landscape's own overrides
## (`BiomeDef.ground_marks`) are applied. A landscape may name a ground the
## shared table has never heard of.
func test_no_landscape_names_a_ground_that_resolves_to_nothing() -> void:
	var bad: Array[String] = []
	for i: int in BiomeRegistry.land_indices():
		var d := BiomeRegistry.by_index(i)
		if d == null:
			continue
		var named := {}
		for g: int in d.grounds.keys():
			named[g] = true
		named[d.plain_ground] = true
		if d.village_square_ground >= 0:
			named[d.village_square_ground] = true
		for g: int in named.keys():
			if Ground.is_water(g):
				continue
			if GroundColors.mark(g, i) == PLAIN:
				bad.append("%s names %s" % [d.id, Ground.NAMES[g]])
	eq(bad, [] as Array[String],
		"a landscape's own ground with no material draws flat wherever that landscape lies: %s" % [bad])
