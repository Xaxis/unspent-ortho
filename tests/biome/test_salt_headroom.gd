extends TestCase
## The Salt Flats has no headroom, and this is the rule that keeps it honest.
##
## `neon_grade` is ONE value for the whole frame: SkyLight averages every
## landscape in view, and `sky.gdshaderinc` then scales the graded colour by
## (1 - grade.x), which is a GAIN. So a frame holding the flat and the coast
## lifts the flat's washes by the average of 1.24 and 1.55, not by its own 1.24
## — and a wash drawn near the page on the flat comes back OVER the page across
## the border, clipped, holding no second wash, no shade step, no plate rim, no
## hatch and no ink. 18.6% of shots/tour/biomes/15-coast-salt-flats.png was pure
## white before this rule; the snowfield, the landscape ART §3 calls "the page
## itself", has none.
##
## So: nothing this landscape draws may clip under the worst lift any registered
## neighbour can put on it. Add a darker landscape and this test says so.

const SaltProps := preload("res://src/models/props/salt.gd")
const NEON_COOL := Vector3(0.80, 0.90, 1.10)
## world.gdshader's SALT_TOP, the ceiling on every pixel of salt crust. Mirrored
## here because a shader constant cannot be read from GDScript.
const SALT_TOP := Color(0.6080, 0.5770, 0.5040)
## Room left for what the renderer adds on top of a wash: the paper grain
## (ink.gdshaderinc `paper`, up to 1.065) and this landscape's own glare bleach
## (sky.gdshaderinc, sky_air.y). The model below runs high against the frame —
## it puts the OLD crust wash at 1.008 where the shot measured 224/255 = 0.88,
## because it knows nothing of the shade band or the light's own energy — so
## this is a relationship to hold, and the frame is the proof: with these
## numbers shots/salt-and-scrap/t-flat.png and t-eco.png are both 0.00% pure
## white, against 2.77% and 18.69% before.
const HEADROOM := 0.98


## neon_graded() from sky.gdshaderinc, as GDScript: desaturate, cool, contrast
## as an S around the mids, then the lift. `found` is 0 for the land.
static func graded(c: Color, g: Vector4) -> Color:
	var l := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	var v := Vector3(c.r, c.g, c.b).lerp(Vector3(l, l, l), g.y)
	v = v.lerp(v * NEON_COOL, g.z)
	var sc := Vector3(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0), clampf(v.z, 0.0, 1.0))
	var s := Vector3(sc.x * sc.x * (3.0 - 2.0 * sc.x), sc.y * sc.y * (3.0 - 2.0 * sc.y), sc.z * sc.z * (3.0 - 2.0 * sc.z))
	var curve := Vector3(maxf(s.x, sc.x * 0.8), maxf(s.y, sc.y * 0.8), maxf(s.z, sc.z * 0.8))
	v = v.lerp(curve, g.w)
	v *= 1.0 - g.x
	return Color(v.x, v.y, v.z)


## The grade a frame gets when `a` and `b` are both in view, half each: the day
## row plus the mean of the two landscapes' own offsets (SkyLight.neon_grade_at
## at noon, where night_fall is 0).
static func pair_grade(a: BiomeDef, b: BiomeDef) -> Vector4:
	return SkyLight.NEON_DAY + (a.grade + b.grade) * 0.5


static func worst(c: Color, g: Vector4) -> float:
	var v := graded(c, g)
	return maxf(v.r, maxf(v.g, v.b))


## Every colour the salt flats declares about itself.
static func declared(d: BiomeDef) -> Dictionary:
	var out := {"cliff_wash": d.cliff_wash, "rock_color": d.rock_color}
	for g: Variant in d.grounds:
		out["ground %d" % int(g)] = d.grounds[g]
	for i in d.grass_colors.size():
		out["grass %d" % i] = d.grass_colors[i]
	for k: Variant in d.decor_tints:
		var row: Array = d.decor_tints[k]
		for i in row.size():
			out["decor %s %d" % [k, i]] = row[i]
	for k: Variant in d.tree_tints:
		var row: Array = d.tree_tints[k]
		for i in row.size():
			out["tree %s %d" % [k, i]] = row[i]
	return out


func test_no_salt_wash_clips_under_the_worst_neighbour_it_can_meet() -> void:
	var salt := BiomeRegistry.get_def(&"salt_flats")
	check(salt != null, "the salt flats is registered")
	var by_itself := SkyLight.NEON_DAY + salt.grade
	# The neighbour whose grade, averaged with the flat's, lifts the flat most.
	var enemy: BiomeDef = null
	for d in BiomeRegistry.all():
		if d.sea or d.id == salt.id:
			continue
		if enemy == null or d.grade.x > enemy.grade.x:
			enemy = d
	check(enemy != null, "there is another land to meet")
	var band := pair_grade(salt, enemy)
	for name: String in declared(salt):
		var alone := worst(declared(salt)[name], by_itself)
		var crossed := worst(declared(salt)[name], band)
		lt(alone, 1.0, "%s clips on the flat itself" % name)
		lt(crossed, 1.0, "%s clips where the flat meets the %s" % [name, enemy.id])


func test_the_crust_ceiling_is_kept_in_step_across_the_three_files() -> void:
	# The wash, the shader's ceiling and the props cut from it are one decision
	# in three files; a change to any of them alone brings the white back.
	var salt := BiomeRegistry.get_def(&"salt_flats")
	var wash: Color = salt.grounds[Ground.SALT]
	lt(maxf(wash.r, maxf(wash.g, wash.b)), maxf(SALT_TOP.r, maxf(SALT_TOP.g, SALT_TOP.b)) + 1e-6,
		"the crust wash sits under the ceiling the marks are clamped to")
	# A prop's lit top face has no shade band and no ground mark under it, so it
	# reads brighter than ground of the same value and its ceiling sits lower.
	lt(maxf(SaltProps.CRUST_UP.r, maxf(SaltProps.CRUST_UP.g, SaltProps.CRUST_UP.b)),
		maxf(SALT_TOP.r, maxf(SALT_TOP.g, SALT_TOP.b)), "a lit salt face stops below the ground's own ceiling")
	lt(maxf(SaltProps.CRUST.r, maxf(SaltProps.CRUST.g, SaltProps.CRUST.b)),
		maxf(SaltProps.CRUST_UP.r, maxf(SaltProps.CRUST_UP.g, SaltProps.CRUST_UP.b)), "and nothing cut from the crust goes over it")
	lt(maxf(SaltProps.CRUST_DOWN.r, maxf(SaltProps.CRUST_DOWN.g, SaltProps.CRUST_DOWN.b)),
		SaltProps.CRUST.r, "its shaded face is a step down, not a tint")


func test_the_lit_edge_leaves_room_for_the_paper_and_the_glare() -> void:
	# Even the ceiling is not the page: the grain and this landscape's own bleach
	# are laid on top of it, and a rim at 1.0 is a white line with nothing in it.
	var salt := BiomeRegistry.get_def(&"salt_flats")
	var enemy: BiomeDef = BiomeRegistry.get_def(&"coast")
	for g: Vector4 in [SkyLight.NEON_DAY + salt.grade, pair_grade(salt, enemy)]:
		lt(worst(SALT_TOP, g), HEADROOM, "the brightest salt still has room for the grain over it")


func test_the_flat_is_still_one_of_the_brightest_grounds_in_the_game() -> void:
	# The fix moves the flat's brightness out of its washes and into its own
	# lift; it must not have moved it out of the game. Drawn, its crust stands
	# with the snowfield — ART section 3's "page itself" — and above every other
	# landscape's plainest ground.
	# **NAMED, NOT COUNTED.** This allowed exactly ONE landscape brighter than the
	# flat and meant "the snowfield". The frost sea has been written since, its
	# plain ground is ICE, and frozen water is page-white for the same reason snow
	# is -- so the count said two where the RULE still holds. A count of how many
	# things may be brighter is a number that goes stale the day somebody writes
	# another white landscape; what the claim is really about is that nothing but
	# frozen water outshines the crust.
	const FROZEN: Array[int] = [Ground.SNOW, Ground.ICE]
	var salt := BiomeRegistry.get_def(&"salt_flats")
	var crust := worst(salt.grounds[Ground.SALT], SkyLight.NEON_DAY + salt.grade)
	var over: Array[String] = []
	for d in BiomeRegistry.all():
		if d.sea or d.id == salt.id:
			continue
		var wash := GroundColors.wash(d.plain_ground, d.index)
		if worst(wash, SkyLight.NEON_DAY + d.grade) < crust:
			continue
		if not FROZEN.has(d.plain_ground):
			over.append("%s (%s)" % [d.id, Ground.NAMES[d.plain_ground]])
	check(over.is_empty(), "only frozen water may read brighter than the flat, got %s" % str(over))
	# And the claim is not vacuous the other way: the flat really is up with them,
	# not merely unbeaten by a list that happens to be empty.
	gt(crust, 0.85, "the crust still reads near the top of the page")


func test_the_flat_carries_its_brightness_in_its_lift_and_not_its_washes() -> void:
	# The whole shape of the fix, as a rule: this landscape lifts itself harder
	# than any other, so averaging its grade with ANY neighbour's brings it down.
	# That is the only arrangement under which a near-white land cannot clip
	# across a border, and it is why the washes are taken down by TONE to pay.
	var salt := BiomeRegistry.get_def(&"salt_flats")
	for d in BiomeRegistry.all():
		if d.sea or d.id == salt.id:
			continue
		lt(1.0 - d.grade.x, 1.0 - salt.grade.x + 1e-6,
			"the %s lifts harder than the salt flats, so it would brighten it across a border" % d.id)
