class_name UiIcons
## Tiny pictures on the slate's glass: one 9x9 icon per kind of thing carried,
## and the HUD's pressure glyphs. Drawn at whole-number scales only.
##
## Shape rows: '.' clear, 'k' the outline (dim), '1' '2' '3' the
## body dark to light, '4' '5' '6' the second part (a haft, a filling), 'w' the
## body's brightest step (a rivet, a glint), 'l' a working part. Items pick a
## shape and ramps by id (the ramps name the sketches' world colours); an id
## nobody listed gets a shape from what it does (Items schema). On the glass
## every icon is phosphor, or the module's violet for found things.

const SIZE := 9

const SHAPES := {
	&"knife": [".......kk", "......k3k", ".....k32k", "....k32k.", "...k21k..", "..kkkk...", ".k54k....", "k54k.....", "kkk......"],
	&"axe": ["..kkkk...", ".k3332k..", "k33221kk.", "k3221k5k.", ".kkkkk5k.", ".....k5k.", ".....k5k.", ".....k4k.", ".....kkk."],
	&"pick": [".kkkkkkk.", "k3322221k", "kk.k5k.kk", "...k5k...", "...k5k...", "...k5k...", "...k5k...", "...k4k...", "...kkk..."],
	&"mattock": ["kkkk.....", "k332kkkk.", "k3221221k", "k21kk5kk.", "kkk.k5k..", "....k5k..", "....k5k..", "....k4k..", "....kkk.."],
	&"billhook": ["..kkk....", ".k332k...", "k3k.k2k..", "kk..k2k..", "....k21k.", "....kkkk.", ".....k5k.", ".....k4k.", ".....kkk."],
	&"stave": [".......kk", "......k6k", ".....k5k.", "....k5k..", "...k5k...", "..k5k....", ".k5k.....", "k4k......", "kk......."],
	&"boathook": ["....kkk..", "...k3.3k.", "....kk3k.", "....k5k..", "...k5k...", "..k5k....", ".k5k.....", "k4k......", "kk......."],
	&"glim": ["....kkk..", "...k3l3k.", "...k2l2k.", "...k232k.", "....k2k..", "....k2k..", "...k121k.", "...kk1kk.", "....kkk.."],
	&"stone": [".........", "..kkkk...", ".k3332k..", "k332222k.", "k322221k.", "k222211k.", ".k2111k..", "..kkkk...", "........."],
	&"timber": [".........", ".........", "..kkkkkk.", ".k3k5555k", "k323k544k", "k232k444k", ".k3k4444k", "..kkkkkk.", "........."],
	&"driftwood": [".........", ".....kk..", "....k3k..", ".kkkk32k.", "k33333kkk", "k2222222k", ".k111k11k", "..kkk.kk.", "........."],
	&"scrap": [".........", ".kkkkk...", ".k3332kk.", ".k3w222k.", ".k22222k.", "..k2w21k.", "..k2111k.", "..kkkkkk.", "........."],
	&"shell": [".........", "......kk.", "....kkwk.", "...k332k.", "..k3321k.", ".k3221k..", "k3211k...", "k211k....", ".kkk....."],
	&"greens": ["....k....", "...k3k...", "..k32k.k.", "..k2k.k3k", ".k2k.k32k", ".k2kk21k.", "..k21k1k.", "...kkkk..", "........."],
	&"bread": [".........", ".........", "..kkkkk..", ".k3w332k.", "k3232322k", "k2222221k", ".kkkkkkk.", ".........", "........."],
	&"bowl": [".........", "...k.k...", "..k.k....", "kkkkkkkkk", "k6554444k", ".k32221k.", ".k22211k.", "..kkkkk..", "........."],
	&"ore": [".........", "..kkkkk..", ".k33w26k.", "k3522225k", "k2262215k", "k2521161k", ".k21111k.", "..kkkkk..", "........."],
	&"ingot": [".........", ".........", "...kkkk..", "..k3ww2k.", ".kk2222kk", ".k222211k", "k2222111k", "kkkkkkkkk", "........."],
	&"lump": [".........", ".........", "...kkk...", "..k3w2k..", ".k32211kk", "k3221k21k", "k2111k11k", ".kkkkkkk.", "........."],
	&"sack": ["...kkk...", "....k....", "..kk3kk..", ".k33322k.", "k3332221k", "k3222211k", "k2222111k", ".kkkkkkk.", "........."],
	&"cloth": [".........", ".........", ".kkkkkkk.", "k33w3332k", "kkkkkkkkk", "k2222221k", "k2222211k", ".kkkkkkk.", "........."],
	&"basket": [".........", "..kkkkk..", ".k.....k.", "kkkkkkkkk", "k3232323k", "k2323232k", ".k21212k.", "..kkkkk..", "........."],
	&"pot": [".........", "..kkkkk..", ".k33332k.", "kkkkkkkkk", ".k3w222k.", "k3322221k", ".k22211k.", "..kkkkk..", "........."],
	&"lamp": ["...kkk...", "..k...k..", "..kkkkk..", "..k464k..", ".k36w52k.", ".k25551k.", "..kkkkk..", ".k32221k.", ".kkkkkkk."],
	&"flask": ["...kkk...", "...k3k...", "...k2k...", "..k3552k.", ".k355441k", ".k554441k", ".k444411k", "..kkkkkk.", "........."],
	&"hone": [".........", ".........", "....kkkkk", "..kk3w32k", "kk33322kk", "k22221kk.", "kkkkkk...", ".........", "........."],
	&"kit": [".........", "..kkkkk..", ".k33332k.", "k3w22w21k", "k2222221k", ".k22221k.", "..k2221k.", "...kkkk..", "........."],
	&"dram": [".......k.", "......k2k", ".....k33k", "....k3l2k", "...k3l2k.", "..k3l2k..", ".k322k...", "k1kkk....", "kk......."],
	&"paper": [".........", ".kkkkkk..", ".k3333kk.", ".k3kk33k.", ".k33333k.", ".k3kkk3k.", ".k33333k.", ".kkkkkkk.", "........."],
	&"berries": [".....kk..", "....k5k..", "..kkkkkk.", ".k3wk3wk.", ".k21k21k.", "..kk3wkk.", "...k21k..", "....kk...", "........."],
	&"beam": [".......kk", "......kll", ".....k3kk", "....k32k.", "...k32k..", "..k32k...", ".kk2k....", "k21k.....", "kkk......"],
	&"broad": [".kkkkkkk.", "kl33333lk", ".kkkkkkk.", "...k2k...", "...k2k...", "..kk2kk..", "..k121k..", "..k121k..", "..kkkkk.."],
	&"blade": [".......k.", "......klk", ".....k3k.", "....k3k..", "...k3k...", "..kkk....", ".k2k.....", "k21k.....", "kkk......"],
	&"hammer": ["kkkkkkk..", "k33l33k..", "k22222k..", "kkkkkkk..", "...k2k...", "...k2k...", "...k2k...", "...k1k...", "...kkk..."],
	&"torch": ["......kkk", ".....k3lk", "....k32k.", "...k32k..", "..kk2k...", ".k21kk...", "k211k....", "k11k.....", "kkk......"],
	&"brace": [".........", "..kkkkk..", ".k3w3w3k.", ".kkkkkkk.", ".k22222k.", ".kkkkkkk.", ".k3w3w3k.", "..kkkkk..", "........."],
	&"rig": ["kk.....kk", "k3k...k3k", ".k3kkk3k.", ".k2k.k2k.", ".k2kkk2k.", ".k2k.k2k.", ".k1kkk1k.", ".kk...kk.", "........."],
	&"lens": [".........", "..kkkkk..", ".k32223k.", "k32klk23k", "k2klllk2k", "k32klk23k", ".k32223k.", "..kkkkk..", "........."],
	&"aerial": ["....k....", "...klk...", "....k....", "....k....", "...k3k...", "..k3w3k..", ".k32223k.", "kkkkkkkkk", "........."],
	&"bundle": [".........", "...kkk...", "..k332k..", ".k3kkk2k.", ".k32221k.", ".k22211k.", "..kkkkk..", ".........", "........."],
	# Gear against a place's pressures (the hazards package).
	&"mask": [".kkkkkkk.", "k3333333k", "k32kkk23k", "k3k454k3k", "k3k555k3k", "k32k4k23k", ".k22221k.", "..kkkkk..", "........."],
	&"hat": [".........", "...kkk...", "..k333k..", "..k332k..", ".kkkkkkk.", "k3333332k", "k2222221k", ".kkkkkkk.", "........."],
	&"vest": [".kk...kk.", "k33kkk33k", "k3355533k", "k3355533k", "k3345433k", "k3355533k", "k2245422k", ".kkkkkkk.", "........."],
	&"boot": ["..kkkk...", "..k33wk..", "..k332k..", "..k332k..", "..k3321kk", "..k32221k", ".kk5555kk", ".k44444k.", ".kkkkkk.."],
	&"wing": ["kk.......", "k4kk.....", "k34wkk...", "k3344wkk.", "k333444wk", ".kkk333k.", "...kkkk..", ".........", "........."],
	&"coil": [".........", "..kkkkk..", ".k33333k.", ".k2kkk2k.", ".k23332k.", ".k2kkk2k.", ".k23332k.", "..kkkkk..", "........."],
	&"signet": [".........", ".kkkkkkk.", ".k33333k.", ".k3lll3k.", ".k33333k.", ".k2kkk2k.", ".k2k.k2k.", ".kkk.kkk.", "........."],
	&"shield": [".kkkkkkk.", "k3333333k", "k33lll33k", "k3322233k", ".k22222k.", ".k22221k.", "..k111k..", "...kkk...", "........."],
}

## id -> [shape, body ramp, second ramp]
const ITEMS := {
	&"knife": [&"knife", &"stone", &"earth"],
	&"knife_shear": [&"knife", &"slate", &"earth"],
	&"axe_hand": [&"axe", &"stone", &"earth"],
	&"axe_felling": [&"axe", &"slate", &"earth"],
	&"axe_works": [&"axe", &"rime", &"ink"],
	&"pick": [&"pick", &"stone", &"earth"],
	&"pick_steel": [&"pick", &"slate", &"earth"],
	&"mattock": [&"mattock", &"stone", &"earth"],
	&"mattock_steel": [&"mattock", &"slate", &"earth"],
	&"billhook": [&"billhook", &"stone", &"earth"],
	&"stave": [&"stave", &"earth", &"earth"],
	&"boathook": [&"boathook", &"stone", &"earth"],
	&"haft": [&"stave", &"sand", &"sand"],
	&"las_hand": [&"beam", &"found", &"lens"],
	&"las_long": [&"beam", &"found", &"lens"],
	&"beam_lance": [&"beam", &"plate", &"lens"],
	&"rep_light": [&"beam", &"plate", &"lens"],
	&"las_broad": [&"broad", &"found", &"lens"],
	&"sonic_wave": [&"broad", &"plate", &"lens"],
	&"flash_burst": [&"broad", &"plate", &"lens"],
	&"arc_cut": [&"blade", &"found", &"lens"],
	&"mono_blade": [&"blade", &"plate", &"lens"],
	&"pulse_hammer": [&"hammer", &"found", &"lens"],
	&"stun_hand": [&"hammer", &"plate", &"lens"],
	&"plasma_torch": [&"torch", &"found", &"lens"],
	&"kit_plate": [&"kit", &"plate", &"plate"],
	&"kit_brace": [&"brace", &"plate", &"plate"],
	&"kit_rig": [&"rig", &"plate", &"plate"],
	&"kit_lens": [&"lens", &"plate", &"lens"],
	&"kit_aerial": [&"aerial", &"plate", &"lens"],
	&"stone": [&"stone", &"stone", &"stone"],
	&"limestone": [&"stone", &"linen", &"linen"],
	&"brimstone": [&"stone", &"copper", &"copper"],
	&"timber": [&"timber", &"sand", &"earth"],
	&"driftwood": [&"driftwood", &"ash", &"ash"],
	&"scrap": [&"scrap", &"plate", &"plate"],
	&"mussels": [&"shell", &"slate", &"brine"],
	&"whelks": [&"shell", &"sand", &"sand"],
	&"samphire": [&"greens", &"moss", &"moss"],
	&"wrack": [&"greens", &"earth", &"earth"],
	&"reeds": [&"greens", &"sand", &"sand"],
	&"gorse_cut": [&"greens", &"spruce", &"copper"],
	&"peat": [&"lump", &"earth", &"earth"],
	&"crottle": [&"greens", &"ash", &"ash"],
	&"bread": [&"bread", &"earth", &"earth"],
	&"soup": [&"bowl", &"earth", &"moss"],
	&"stew": [&"bowl", &"earth", &"rust"],
	&"smoked": [&"bowl", &"earth", &"copper"],
	&"iron_ore": [&"ore", &"slate", &"rust"],
	&"copper_ore": [&"ore", &"slate", &"copper"],
	&"copper": [&"ingot", &"copper", &"copper"],
	&"berries": [&"berries", &"bloom", &"moss"],
	&"tin_ore": [&"ore", &"slate", &"stone"],
	&"coal": [&"lump", &"ink", &"ink"],
	&"charcoal": [&"lump", &"ink", &"ink"],
	&"iron": [&"ingot", &"slate", &"slate"],
	&"tin": [&"ingot", &"stone", &"stone"],
	&"wool": [&"sack", &"linen", &"linen"],
	&"yarn": [&"sack", &"linen", &"linen"],
	&"salt": [&"sack", &"linen", &"linen"],
	&"lime": [&"sack", &"linen", &"linen"],
	&"kelp_ash": [&"sack", &"ash", &"ash"],
	&"blanket": [&"cloth", &"rust", &"rust"],
	&"oilcloth": [&"cloth", &"spruce", &"spruce"],
	&"basket": [&"basket", &"sand", &"sand"],
	&"pot": [&"pot", &"stone", &"stone"],
	&"lamp": [&"lamp", &"copper", &"ember"],
	&"oil": [&"flask", &"ash", &"copper"],
	&"resin": [&"flask", &"ash", &"copper"],
	&"pitch": [&"flask", &"ash", &"ink"],
	&"dye": [&"flask", &"ash", &"bloom"],
	&"hone": [&"hone", &"slate", &"slate"],
	&"wick": [&"dram", &"found", &"lens"],
	&"photograph": [&"paper", &"linen", &"linen"],
	&"letter": [&"paper", &"linen", &"linen"],
	&"rag": [&"cloth", &"linen", &"linen"],
	&"wrap_warm": [&"cloth", &"rust", &"rust"],
	&"oilskin": [&"cloth", &"spruce", &"spruce"],
	&"scarf_mask": [&"mask", &"linen", &"ash"],
	&"hat_brim": [&"hat", &"sand", &"earth"],
	&"vest_heatsink": [&"vest", &"plate", &"copper"],
	&"rebreather": [&"mask", &"plate", &"linen"],
	&"boots_magnet": [&"boot", &"plate", &"earth"],
	&"glide_wing": [&"wing", &"plate", &"sand"],
	&"scanner_lens": [&"lens", &"plate", &"lens"],
	&"shield_plate": [&"shield", &"found", &"lens"],
	&"mod_wadding": [&"sack", &"linen", &"linen"],
	&"mod_filter": [&"flask", &"ink", &"ash"],
	&"mod_foil": [&"cloth", &"plate", &"plate"],
	&"mod_spring": [&"coil", &"plate", &"earth"],
	&"mod_signet": [&"signet", &"found", &"lens"],
}

## Stations at list size, same rules as SHAPES.
const STATION_MARKS := {
	&"fire": ["....k....", "...k6k...", "..k656k..", "..k565k..", ".k56665k.", "kk45554kk", "k3kkkkk3k", "k21k.k21k", ".kk...kk."],
	&"bench": [".........", ".........", "kkkkkkkkk", "k5555554k", "kkkkkkkkk", ".k4k.k4k.", ".k4kkk4k.", ".k4k.k4k.", ".kkk.kkk."],
	&"kiln": ["...kkk...", "..k656k..", ".k65554k.", "k6554544k", "k55kkk44k", "k54k6k44k", "k54k5k44k", "kkkkkkkkk", "........."],
}

## Felt pressures as 9x9 glyphs, one colour ('#'): the body's needs and every
## hazard id the landscape registry names (BiomeDef.hazards). An id with no
## glyph of its own shows PRESSURE_ANY.
const NEEDS := {
	&"hunger": ["....#....", "...#.....", "....#....", ".........", "#########", ".#######.", "..#####..", "...###...", "........."],
	&"wet": ["....#....", "....#....", "...###...", "..#####..", ".#######.", ".#######.", "..#####..", "...###...", "........."],
	&"load": ["...###...", "..#...#..", ".#######.", ".#######.", "####.####", "#########", ".#######.", ".........", "........."],
	&"tired": ["..###....", ".##......", "##.......", "##.......", "##.......", ".##......", "..###....", ".........", "........."],
	&"cold": ["....#....", ".#..#..#.", "..#.#.#..", "...###...", "#########", "...###...", "..#.#.#..", ".#..#..#.", "....#...."],
	&"heat": ["...#.....", "..##..#..", "..###.##.", ".#####.#.", ".###.###.", "###...###", "##..#..##", ".#.###.#.", "..#####.."],
	&"fumes": [".........", "..##.....", ".#..#.##.", ".#...#..#", "..###...#", "....#.##.", ".##..#...", "#..#.....", ".##......"],
	&"toxins": ["....#....", "...###...", "..#####..", ".##.#.##.", ".###.###.", ".##.#.##.", "..#####..", "...###...", "........."],
	&"radiation": [".........", ".##...##.", "###...###", "###.#.###", "...###...", "....#....", "...###...", "..#####..", "..#####.."],
	&"dark": ["..####...", ".##......", "##.......", "##.......", "##.......", "##.......", ".##......", "..####...", "........."],
	&"vacuum": ["..#####..", ".#.....#.", "#..#.#..#", "#.......#", "#...#...#", "#.......#", "#..#.#..#", ".#.....#.", "..#####.."],
	&"pressure": ["#...#...#", ".#..#..#.", "..#.#.#..", ".........", "###...###", ".........", "..#.#.#..", ".#..#..#.", "#...#...#"],
	&"em": ["....##...", "...##....", "..##.....", ".######..", "....##...", "...##....", "..##.....", ".##......", "#........"],
	&"resonance": ["#.......#", "#..#.#..#", "#.#...#.#", "#.#.#.#.#", "#.#...#.#", "#..#.#..#", "#.......#", ".........", "........."],
	&"time_shear": ["#########", ".#.....#.", "..#...#..", "...#.#...", "....#....", "...#.#...", "..#.#.#..", ".#.###.#.", "#########"],
}
const PRESSURE_ANY := ["...###...", "..#...#..", ".#..#..#.", "#...#...#", "#...#...#", "#.......#", ".#..#..#.", "..#...#..", "...###..."]


## Shape name and ramps for an item id.
static func style_of(id: StringName) -> Array:
	if ITEMS.has(id):
		return ITEMS[id]
	var d := Items.def(id)
	if d.get("stuff", &"") == &"found":
		return [&"glim", &"found", &"lens"]
	if d.has("kit"):
		return [&"kit", &"plate", &"plate"]
	if d.get("feeds", 0.0) > 0.0:
		return [&"bowl", &"earth", &"rust"]
	match d.get("verb", &""):
		&"cut": return [&"knife", &"stone", &"earth"]
		&"fell": return [&"axe", &"stone", &"earth"]
		&"break": return [&"pick", &"stone", &"earth"]
		&"dig": return [&"mattock", &"stone", &"earth"]
	if d.get("tool", false):
		return [&"stave", &"earth", &"earth"]
	return [&"bundle", &"sand", &"earth"]


## A thing taken whole from the machines (found tech, a charge, salvage kit): the
## slate reads it in the stolen module's violet.
static func is_found(id: StringName) -> bool:
	if id == &"":
		return false
	var d := Items.def(id)
	if d.get("stuff", &"") == &"found" or d.get("group", &"") == &"found" or d.has("kit"):
		return true
	return UiSketch.FOUND_SHAPES.has(style_of(id)[0])


## The world's colour ramps by name, for the sketches' intermediate drawing (the
## slate shows them as phosphor tones: UiSketch.to_phosphor).
static func ramp(name: StringName) -> Array[Color]:
	match name:
		&"stone": return Palette.STONE
		&"brine": return Palette.BRINE
		&"slate": return Palette.SLATE
		&"earth": return Palette.EARTH
		&"rust": return Palette.RUST
		&"moss": return Palette.MOSS
		&"spruce": return Palette.SPRUCE
		&"sand": return Palette.SAND
		&"linen": return Palette.LINEN
		&"flesh": return Palette.FLESH
		&"copper": return Palette.COPPER
		&"ash": return Palette.ASH
		&"ember": return Palette.EMBER
		&"rime": return Palette.RIME
		&"bloom": return Palette.BLOOM
		&"found": return Palette.FOUND
		&"lens": return Palette.LENS
		&"plate": return Palette.PLATE
		&"ink": return Palette.INK
	return Palette.STONE


## The tones an icon is shown in: phosphor for what people made, the module's
## violet for what was taken from the machines.
static func tones_for(id: StringName) -> Array[Color]:
	return UiTheme.MACHINE if is_found(id) else UiTheme.PHOSPHOR


## Character -> colour for an item's icon on the glass: its outline in the
## dimmest tone that still reads, the body stepping up to bright, the second
## part (a haft, a filling) a step under it, and a working part the hottest.
static func colours_for(id: StringName) -> Dictionary:
	# A mended thing is FOUND parts bound with MADE cord, and the slate draws both
	# idioms at once (docs/ART.md §10): the body in the stolen module's violet,
	# the binding, haft and cord in phosphor.
	if Gear.is_mended(id):
		var m := UiTheme.MACHINE
		var p := UiTheme.PHOSPHOR
		return {"k": m[1], "1": m[2], "2": m[3], "3": m[3], "w": m[4], "4": p[2], "5": p[2], "6": p[3], "l": m[4]}
	var t := tones_for(id)
	return {"k": t[1], "1": t[2], "2": t[3], "3": t[3], "w": t[4], "4": t[2], "5": t[2], "6": t[3], "l": t[4]}


static func shape_of(id: StringName) -> Array:
	return SHAPES[style_of(id)[0]]


## Draw an item's icon with its top-left at `at`.
static func draw_item(ci: CanvasItem, id: StringName, at: Vector2i, scale: int = 1) -> void:
	UiDraw.sprite(ci, shape_of(id), at, colours_for(id), scale)


## A station's small mark, for list rows (building one, making at one).
static func draw_station_mark(ci: CanvasItem, station: StringName, at: Vector2i) -> void:
	var rows: Array = STATION_MARKS.get(station, STATION_MARKS[&"bench"])
	var t := UiTheme.PHOSPHOR
	UiDraw.sprite(ci, rows, at, {"k": t[1], "1": t[2], "2": t[3], "3": t[3], "4": t[2], "5": t[3], "6": t[4]})


static func pressure_rows(id: StringName) -> Array:
	return NEEDS.get(id, PRESSURE_ANY)


## Draw a pressure glyph in `col` held by a rim of dead glass (over the world).
static func draw_need(ci: CanvasItem, need: StringName, at: Vector2i, col: Color) -> void:
	UiDraw.sprite_rimmed(ci, pressure_rows(need), at, {"#": col}, UiTheme.RIM)
