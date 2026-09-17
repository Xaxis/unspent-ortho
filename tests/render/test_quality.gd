extends TestCase
## The floor five builders stand on (docs/LOOK.md): the two screen sizes, and the
## quality tiers whose rows the lighting, lights and degrade packages read.
##
## These are cheap assertions about a data table, and they are here because the
## table is a contract rather than an implementation: a row that loses a key, or a
## base that stops being a whole multiple of the slate's design size, breaks
## somebody else's package silently and a long way from here.

## Every key a row must carry, and what it must be.
const KEYS := {
	"id": TYPE_STRING_NAME, "label": TYPE_STRING, "note": TYPE_STRING,
	"render_scale": TYPE_FLOAT, "upscale": TYPE_INT, "msaa": TYPE_INT,
	"shadow_size": TYPE_INT, "shadow_filter": TYPE_INT, "shadow_lights": TYPE_INT,
	"near_stand_in": TYPE_BOOL, "volumetric": TYPE_BOOL, "air_stand_in": TYPE_FLOAT, "ssao": TYPE_BOOL, "ssil": TYPE_BOOL,
	"forward_only": TYPE_BOOL,
}


func test_the_base_is_a_whole_multiple_of_the_slate_it_still_draws() -> void:
	# The slate is drawn in the base's own pixels now, so the doors answer in those.
	eq(UiBase.screen(), Rect2i(Vector2i.ZERO, UiBase.SIZE), "the full-screen rect is the frame")
	eq(UiBase.mid_x(), UiBase.SIZE.x / 2, "and the middle is the frame's middle")
	# The module's own pixel is whole, or nothing on the glass lands on a pixel.
	eq(UiBase.SIZE.x % UiBase.PITCH, 0, "the frame is a whole number of module pixels across")
	eq(UiBase.SIZE.y % UiBase.PITCH, 0, "and down")
	eq(UiFont.PITCH, UiBase.PITCH, "and the face is cut to that same pixel")
	# The LEGACY space survives for the loading page, its HTML twin and the gallery.
	# A fractional SCALE would put their pixel font between pixels, so the two sizes
	# are still not independently editable.
	eq(UiBase.DESIGN * UiBase.SCALE, UiBase.SIZE, "SIZE is DESIGN times SCALE")
	eq(UiBase.SIZE.x * UiBase.DESIGN.y, UiBase.SIZE.y * UiBase.DESIGN.x, "and the same shape")
	eq(UiBase.legacy_screen(), Rect2i(Vector2i.ZERO, UiBase.DESIGN), "the legacy rect is in the old units")


func test_a_world_position_is_brought_into_the_slates_units() -> void:
	# The trap the base change laid, and why it is gone: unproject_position answers
	# in the base's pixels, which is what every UI layer is drawn in now. Only a
	# layer still on `fit` — the loading page, the gallery, the bolts — converts.
	eq(UiBase.to_design(Vector2(UiBase.SIZE)), Vector2(UiBase.DESIGN), "a corner maps to the corner")
	eq(UiBase.to_design(Vector2.ZERO), Vector2.ZERO, "and the origin stays put")


func test_every_tier_is_a_whole_row() -> void:
	var seen := {}
	for r: Dictionary in Quality.ROWS:
		for key: String in KEYS:
			check(r.has(key), "%s has %s" % [r.get("id", "?"), key])
			if r.has(key):
				eq(typeof(r[key]), KEYS[key], "%s's %s is the right kind" % [r.get("id", "?"), key])
		check(not seen.has(r.id), "%s is named once" % r.id)
		seen[r.id] = true
		check(str(r.note) != "", "%s says what it is" % r.id)
		var s := float(r.render_scale)
		check(s > 0.0 and s <= 1.0, "%s renders at a fraction of the base (%f)" % [r.id, s])
		check(int(r.shadow_lights) >= 0, "%s allows a countable number of casting lights" % r.id)
	eq(seen.size(), Quality.ROWS.size(), "no tier is declared twice")


func test_the_tiers_the_brief_names_all_exist() -> void:
	for id: StringName in [&"ultra", &"high", &"medium", &"low", &"web"]:
		check(Quality.has(id), "there is a %s tier" % id)
		eq(Quality.row(id).id, id, "and row() finds it")
	check(not Quality.has(&"nonesuch"), "and nothing else")
	check(Quality.row(&"nonesuch").is_empty(), "an unknown tier is an empty row, not a crash")


## The web is the degradation path, not a different game (docs/LOOK.md): whatever
## it asks for has to be something Compatibility can actually do.
func test_the_web_tier_never_asks_for_what_compatibility_cannot_do() -> void:
	var web := Quality.row(&"web")
	check(not bool(web.forward_only), "the web tier does not need Forward+")
	check(not bool(web.volumetric), "no true volumetrics on the web path")
	check(not bool(web.ssao) and not bool(web.ssil), "and no screen-space lighting")
	for id: StringName in [&"ultra", &"high"]:
		check(bool(Quality.row(id).forward_only), "%s is a Forward+ tier" % id)
	for id: StringName in [&"medium", &"low"]:
		check(not bool(Quality.row(id).forward_only), "%s runs on either renderer" % id)


func test_what_a_tier_is_rendered_at_is_the_base_times_its_scale() -> void:
	for r: Dictionary in Quality.ROWS:
		var want := Vector2i(Vector2(UiBase.SIZE) * float(r.render_scale))
		eq(Quality.render_pixels(r.id), want, "%s renders %dx%d" % [r.id, want.x, want.y])
	check(Quality.render_pixels(&"ultra") == UiBase.SIZE, "ultra is native")
	# The point of the whole arrangement: a tier costs the WORLD's sharpness and
	# never the slate's, so the UI is the same size on the cheapest tier and the
	# dearest and nothing a player reads moves.
	check(Quality.render_pixels(&"web") != Quality.render_pixels(&"ultra"), "and the web is not")


func test_a_machine_is_given_a_tier_it_can_run() -> void:
	var picked := Quality.detect()
	check(Quality.has(picked), "detect names a real tier (%s)" % picked)
	if not Quality.forward_plus():
		check(not bool(Quality.row(picked).forward_only), "a Compatibility machine is never given a Forward+ tier")


## Both settings doors offer the tiers by NAME and copy none of the rows, so a
## tier added to Quality.ROWS is offered in both without touching either table.
func test_both_settings_doors_offer_every_tier_and_invent_none() -> void:
	var want: Array = ["auto"]
	for id: StringName in Quality.ids():
		want.append(String(id))

	var owner_side: Array = []
	for v: Variant in ConfigChoices.options("build.quality"):
		owner_side.append(String(v))
	eq(owner_side, want, "the owner's configuration offers auto and every tier")
	eq(ConfigChoices.check("build.quality", "auto"), "", "and auto is allowed")
	check(ConfigChoices.check("build.quality", "sparkling") != "", "and a tier nobody declared is not")

	var player_side: Array = []
	for v: Variant in PlayerSettings.options_of(PlayerSettings.row(&"picture.quality")):
		player_side.append(String(v))
	eq(player_side, want, "the player's picture settings offer the same list")
	eq(PlayerSettings.default_of(&"picture.quality"), &"auto", "and start on auto")
