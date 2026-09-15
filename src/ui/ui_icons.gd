class_name UiIcons
## Tiny drawn pictures: one 9x9 icon per kind of thing carried, and the HUD's
## need glyphs. Drawn at whole-number scales only (1x in lists, 3x on a page).
##
## Shape rows: '.' clear, 'k' ink rim, '1' '2' '3' the body ramp dark to light,
## '4' '5' '6' the second ramp (a haft, a filling), 'w' the body's brightest
## step (a rivet, a glint), 'l' the machine amber. Items pick a shape and ramps
## by id; an id nobody listed gets a shape from what it does (Items schema).

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
	&"ingot": [".........", ".........", "...kkkkkk", "..k3www3k", ".k333332k", "kkkkkkk2k", "k222221kk", "kkkkkkkk.", "........."],
	&"lump": [".........", ".........", "...kkk...", "..k3w2k..", ".k32211kk", "k3221k21k", "k2111k11k", ".kkkkkkk.", "........."],
	&"sack": ["...kkk...", "....k....", "..kk3kk..", ".k33322k.", "k3332221k", "k3222211k", "k2222111k", ".kkkkkkk.", "........."],
	&"cloth": [".........", ".........", ".kkkkkkk.", "k33w3332k", "kkkkkkkkk", "k2222221k", "k2222211k", ".kkkkkkk.", "........."],
	&"basket": [".........", "..kkkkk..", ".k.....k.", "kkkkkkkkk", "k3232323k", "k2323232k", ".k21212k.", "..kkkkk..", "........."],
	&"pot": [".........", "..kkkkk..", ".k33332k.", "kkkkkkkkk", ".k3w222k.", "k3322221k", ".k22211k.", "..kkkkk..", "........."],
	&"lamp": ["...kkk...", "..k...k..", "..kkkkk..", "..k464k..", ".k36w52k.", ".k25551k.", "..kkkkk..", ".k32221k.", ".kkkkkkk."],
	&"flask": ["...kkk...", "...k3k...", "...k2k...", "..k3552k.", ".k355441k", ".k554441k", ".k444411k", "..kkkkkk.", "........."],
	&"hone": [".........", ".........", "....kkkkk", "..kk3w32k", "kk33322kk", "k22221kk.", "kkkkkk...", ".........", "........."],
	&"kit": [".........", "..kkkkk..", ".k33332k.", "k3w22w21k", "k2222221k", ".k22221k.", "..k2221k.", "...kkkk..", "........."],
	&"dram": [".........", "....k....", "...klk...", "..kl3lk..", "..kl3lk..", "..kl2lk..", "...klk...", "....k....", "........."],
	&"paper": [".........", ".kkkkkk..", ".k3333kk.", ".k3kk33k.", ".k33333k.", ".k3kkk3k.", ".k33333k.", ".kkkkkkk.", "........."],
	&"bundle": [".........", "...kkk...", "..k332k..", ".k3kkk2k.", ".k32221k.", ".k22211k.", "..kkkkk..", ".........", "........."],
}

## id -> [shape, body ramp, second ramp]
const ITEMS := {
	&"knife": [&"knife", &"stone", &"earth"],
	&"knife_shear": [&"knife", &"slate", &"earth"],
	&"axe_hand": [&"axe", &"stone", &"earth"],
	&"axe_felling": [&"axe", &"slate", &"earth"],
	&"axe_works": [&"axe", &"rime", &"ink"],
	&"pick": [&"pick", &"stone", &"earth"],
	&"mattock": [&"mattock", &"stone", &"earth"],
	&"mattock_steel": [&"mattock", &"slate", &"earth"],
	&"billhook": [&"billhook", &"stone", &"earth"],
	&"stave": [&"stave", &"earth", &"earth"],
	&"boathook": [&"boathook", &"stone", &"earth"],
	&"stone": [&"stone", &"stone", &"stone"],
	&"limestone": [&"stone", &"linen", &"linen"],
	&"brimstone": [&"stone", &"copper", &"copper"],
	&"timber": [&"timber", &"sand", &"earth"],
	&"driftwood": [&"driftwood", &"ash", &"ash"],
	&"scrap": [&"scrap", &"plate", &"plate"],
	&"mussels": [&"shell", &"brine", &"brine"],
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
	&"wick": [&"dram", &"lens", &"lens"],
	&"photograph": [&"paper", &"linen", &"linen"],
	&"letter": [&"paper", &"linen", &"linen"],
}

## Stations, drawn larger as sketches on the making page: [rows, body ramp, second ramp].
const STATIONS := {
	&"fire": [[
		".....k.......",
		"....k3k...k..",
		"....k3wk.k3k.",
		"...k3ww3kk3k.",
		"..k32ww23k3k.",
		"..k2w22w2k2k.",
		"..k21221211k.",
		".kk5k111k5kk.",
		"k45kk5k5kk54k",
		"k5456kkk6545k",
		".kkkkkkkkkkk.",
	], &"ember", &"stone"],
	&"bench": [[
		".............",
		"..kk.........",
		".k32k........",
		"kkkkkkkkkkkkk",
		"k66666666666k",
		"k55555555554k",
		"kkkkkkkkkkkkk",
		".k4k.....k4k.",
		".k4kkkkkkk4k.",
		".k4k.....k4k.",
		".kkk.....kkk.",
	], &"stone", &"earth"],
	&"kiln": [[
		"....kkkkk....",
		"...k66665k...",
		"..k6655554k..",
		".k665555544k.",
		".k655kkk544k.",
		"k6555k3k5444k",
		"k6554kwk4444k",
		"k5554k2k4444k",
		"k5544k1k4444k",
		"kkkkkkkkkkkkk",
		".............",
	], &"ember", &"rust"],
}

## HUD need glyphs: one colour ('#') plus an ink rim added when drawn.
const NEEDS := {
	&"hunger": [".........", ".........", ".........", "#.......#", "#.......#", "##.....##", ".#######.", "..#####..", "........."],
	&"wet": ["....#....", "....#....", "...###...", "..#####..", ".#######.", ".#######.", "..#####..", "...###...", "........."],
	&"load": ["...###...", "..#...#..", ".#######.", ".#######.", "####.####", "#########", ".#######.", ".........", "........."],
	&"tired": ["..###....", ".##......", "##.......", "##.......", "##.......", ".##......", "..###....", ".........", "........."],
}


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


## Character -> colour for an item's icon.
static func colours_for(id: StringName) -> Dictionary:
	var st := style_of(id)
	var a := ramp(st[1])
	var b := ramp(st[2])
	var lens := Palette.LENS
	return {
		"k": UiTheme.INK_DEEP,
		"1": _shade(a, 0), "2": _shade(a, 1), "3": _shade(a, 2), "w": a[a.size() - 1],
		"4": _shade(b, 0), "5": _shade(b, 1), "6": _shade(b, 2),
		"l": lens[2],
	}


static func shape_of(id: StringName) -> Array:
	return SHAPES[style_of(id)[0]]


## Draw an item's icon with its top-left at `at`.
static func draw_item(ci: CanvasItem, id: StringName, at: Vector2i, scale: int = 1) -> void:
	UiDraw.sprite(ci, shape_of(id), at, colours_for(id), scale)


## Draw a station sketch (13x11 cells) at a whole-number scale.
static func draw_station(ci: CanvasItem, station: StringName, at: Vector2i, scale: int) -> void:
	if not STATIONS.has(station):
		return
	var st: Array = STATIONS[station]
	var a := ramp(st[1])
	var b := ramp(st[2])
	var cols := {
		"k": UiTheme.INK_DEEP,
		"1": _shade(a, 0), "2": _shade(a, 1), "3": _shade(a, 2), "w": a[a.size() - 1],
		"4": _shade(b, 0), "5": _shade(b, 1), "6": _shade(b, 2),
	}
	UiDraw.sprite(ci, st[0], at, cols, scale)


## Draw a need glyph in `col` with an ink rim (for the HUD over the world).
static func draw_need(ci: CanvasItem, need: StringName, at: Vector2i, col: Color) -> void:
	UiDraw.sprite_rimmed(ci, NEEDS[need], at, {"#": col}, UiTheme.INK_DEEP)


## Dark, mid, light steps of a ramp, chosen so all three read on paper.
static func _shade(r: Array[Color], k: int) -> Color:
	if r.size() >= 6:
		return r[[2, 3, 4][k]]
	if r.size() >= 4:
		return r[[1, 2, 3][k]]
	return r[mini(k, r.size() - 1)]
