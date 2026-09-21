extends RefCounted
## The city's buildings: what people live in where the people before them built
## UPWARD. `Houses` draws one storey and a hearth; this draws the other stock a
## landscape may name (`BiomeForms.RAISED`) — storeys stacked, a frontage at the
## foot, plant and tanks on a flat roof, and somebody's sign still burning.
##
## Everything here is the same vocabulary as a house and none of it is a new
## idiom: a storey is `Houses.walls` raised off the ground, its faces are worn by
## `Houses.weathered`, its ground floor takes `Houses.door` and `Houses.salvage`,
## the machines' enamel is `Houses.struck_plate`. What makes it a city is that
## the storeys STACK and that the thing which reads at fifty tiles is not a roof
## but a FRONTAGE: bands of glazing between floor slabs that stand proud.
##
## Under LANTERN the relief is the drawing (docs/LOOK.md). A floor slab standing
## a hand proud of the storey under it rules a line of light along its top and
## drops a bar of shade under it at every hour the sun is up; a painted band
## would read as a sticker at noon and vanish at dusk. So every horizontal on
## these buildings is a piece of geometry and nothing about a storey is painted
## on. What that costs is about 700 triangles a tower, against a coastal house's
## 1400: a tower is cheaper than a house, because a patched roof is expensive
## and a parapet is not.
##
## A building faces +X (its door), like every model.

const Kit := preload("res://src/models/props/kit.gd")
const Houses := preload("res://src/models/props/houses.gd")
const P := preload("res://src/render/palette.gd")

## The one door: build the named form of `BiomeForms.RAISED`. `Houses.build`
## sends anything it does not itself draw here, so a landscape's stock may mix
## a croft and a tower without either file knowing about the other.
static func build(k: Kit, form: StringName, c: int) -> void:
	match form:
		&"tower": tower(k, c)
		&"stack": stack(k, c)
		&"block": block(k, c)
		&"shell": shell(k, c)
		&"arcade": arcade(k, c)
		&"spire": spire(k, c)


## How tall one storey stands. Everything here is a multiple of it, so a city's
## floor lines run level across the buildings that share a street — which is the
## one thing that makes a row of them read as a city and not as a shelf of boxes.
const STOREY := 1.25
## How many floors up a building is drawn in full. Above this it keeps its
## silhouette and its floor lines and drops the wear, the growth and half the
## glazing — see `shaft`, which explains why that is a readability argument and
## not only a budget one.
const DETAIL_FLOORS := 4
## How far a floor slab stands proud of the wall under it, and how deep it is.
## Three screen pixels at the play camera: enough for the sun to rule a line
## along and to drop a bar of shade under, and not so much that the building
## reads as a stack of trays.
const LEDGE := 0.085
const SLAB := 0.11
## How much of a storey's height the glazing band takes. Under a half it reads
## as punched windows; over two thirds the building has no wall left.
const GLASS := 0.52
## How far proud of the storeys a hung FRAME stands, so a door, a plate or a sign
## is clear of the wall behind it rather than fighting with it.
const FRAME := 0.07

## WHAT A CITY'S WINDOWS ARE MADE OF, and it is NOT the landscape's timber.
##
## These were `BiomeDressing.timber`, which is the right answer for a house: a
## cottage's window is a wooden frame in a wooden wall. It is the wrong answer
## for a cast-concrete tower, and it was the single thing making one read as a
## shanty — every storey of every face is outlined by its mullions, its sill and
## its head, so a brown frame paints eleven brown bands up a grey building and
## the eye calls the whole thing timber. The owner's word for it was "shitty
## wooden shanties", and he was describing this and not the massing.
##
## A mullion is dark anodised metal, near black, because that is what a curtain
## wall is and because a DARK frame is what makes a lit pane read as a lit pane
## rather than as a painted rectangle. The boarding over a broken light is plate
## and ply — what somebody nailed up, which is the one place a city admits it is
## patched.
const MULLION := Color(0.208, 0.220, 0.239)
const BOARDING := Color(0.478, 0.451, 0.416)

## Stolen light, as the city runs it: a sign nobody has turned off in twenty
## years. Wider than a house's tube (`Houses.NEON_TUBES`) because a billboard is
## a FIELD of colour and not a line of it.
##
## WHY THESE AND NOT THE OBVIOUS ONES. This list read pink, cyan, VIOLET. The
## violet sat at hue 261, inside the 240-336 band `palette.gd` reserves for the
## machines, and that reservation is load-bearing rather than decorative: it is
## the whole reason a patched roof never reads as a live machine. The city is
## about to be the most crowded frame in the game, which is exactly where that
## one cue does the most work, so a violet sign spends the thing that makes the
## frame legible. The cyan went with it -- a purple-to-teal gradient is the most
## copied palette in this genre and says nothing about this place.
##
## Two builders found this independently and reached the same verdict from
## opposite directions, which is why the list is ordered as well as recoloured.
##
## What a real city at night is actually lit by: SODIUM vapour first, as the
## ground note, and the MERCURY green of whatever the municipality stopped
## maintaining -- a stairwell, an underpass, a sign nobody replaced. Then one
## dirty warm white. The magenta is LAST on purpose and is a COMMERCIAL ACCENT:
## one shop's sign, never the street's ground note, because advertising is the
## one thing here that still has money in it. Order matters because a stock of
## six deals these out, and a list led by the accent puts a burning pink sign on
## half the buildings, which is the neon-filter mistake in miniature.
##
## The sodium is `15_lights.NEON_SODIUM` written out a second time on purpose: a
## model may not depend on a system. `tests/render/test_signage.gd` fails if the
## two ever drift, and fails if any colour here re-enters the machines' band --
## which is the assert that matters, because the violet had never drawn a single
## pixel and so nothing anywhere would ever have said a word about it.
## THE RESERVATION IS ABOUT MASS, NOT HUE, and the measurement says so. Every
## machine body fill spans 240.0 to 336.0 EXACTLY -- clerk at one end, runner at
## the other, no headroom -- and every one of them is dark and low-chroma: value
## at most 0.43, saturation at most 0.37. That is the cue. A machine is a cold
## heavy MASS, and nothing bright and small is ever going to be mistaken for one.
##
## So the accent below sits at hue 316, inside the band, ON PURPOSE. It is the
## coast's own stolen neon (`Houses.NEON_TUBES[1]`, `15_lights.NEON_MAGENTA`),
## shipped since M1 and named in a canon frame, at value 1.00 against a machine's
## 0.43 -- and it is written as that same number rather than a near-match, for
## the same reason the sodium is: a light and the sign it comes off must be one
## value and not two that drifted.
##
## What was actually wrong with the violet this list used to end on was never its
## hue of 258. It was that it was offered as the GROUND NOTE -- a field of it up
## four storeys, which is area, which is mass, which is the one thing the
## reservation protects. Index 0 is the only entry that covers a building, so
## index 0 is the only entry the gate can meaningfully hold.
const SIGN_SODIUM := Color(1.0, 0.52, 0.16)
const SIGN_MAGENTA := Color(1.0, 0.25, 0.8)
const SIGN_COLOURS: Array[Color] = [SIGN_SODIUM, Color(0.522, 0.878, 0.549), Color(1.0, 0.88, 0.72), SIGN_MAGENTA]


## A ground wash used as a MATERIAL. `BiomeDressing.drift` (and anything else
## derived from `GroundColors.wash`) carries that ground's MARK CODE in its
## alpha, and a lit shader given one on a model draws the landscape's ground
## stipple across it — measured, as a dithered field over a whole roof deck.
## The colour is what was wanted; the code belongs to the ground.
static func solid(col: Color) -> Color:
	return Color(col.r, col.g, col.b, 1.0)


# --- the shared body ------------------------------------------------------------

## The eight corners of a storey, in the layout `Houses.walls` returns ([b00,
## b10, b11, b01, t00, t10, t11, t01]) so every routine written for a house works
## on it unchanged. `inset` pulls the storey in from the plan below it, which is
## how a stack steps back as it rises; a storey with no inset and no lean is a
## box, and a box is the one thing this game may not put on screen, so the lean
## is dealt from the seed and never zero.
##
## Drawing nothing is the point.
##
## Split out because every form wanted a FRAME to hang things on — a door, the
## machines' enamel, a sign four storeys tall — and the only way to get one was
## to call `storey` again at full height. That drew a blank wall over the entire
## shaft: five storeys of glazing, sills, boards and worn faces, built and then
## painted out, on every building in the stock. The frame is proud of the walls
## by `FRAME` so that anything hung on it stands clear of the storey behind it.
static func corners(w: float, d: float, y0: float, h: float, s: int, inset := 0.0) -> Array[Vector3]:
	var c: Array[Vector3] = []
	var sx: Array[float] = [-1.0, 1.0, 1.0, -1.0]
	var sz: Array[float] = [-1.0, -1.0, 1.0, 1.0]
	var bw := (w - inset) * 0.5
	var bd := (d - inset) * 0.5
	for i in 4:
		c.append(Vector3(sx[i] * bw + Kit.j(s, i, 0.05), y0, sz[i] * bd + Kit.j(s, i + 4, 0.05)))
	for i in 4:
		# A concrete frame does not lean the way a rubble wall does — it was cast
		# true and then the ground moved under it. So the lean is a tenth of a
		# house's and it is the same sign on both corners of a face: the building
		# is OUT OF PLUMB, not shivering.
		var b := c[i]
		var tilt := Vector3(Kit.j(s, 12, 0.03), 0.0, Kit.j(s, 13, 0.03))
		c.append(Vector3(b.x, y0 + h + Kit.j(s, i + 8, 0.03), b.z) + tilt * h)
	return c


## One storey standing between y0 and y0 + h, drawn.
static func storey(k: Kit, w: float, d: float, y0: float, h: float, s: int, front: Color, side: Color, inset := 0.0) -> Array[Vector3]:
	var c := corners(w, d, y0, h, s, inset)
	k.made.quad(c[2], c[1], c[5], c[6], front)
	k.made.quad(c[3], c[2], c[6], c[7], side)
	k.made.quad(c[0], c[3], c[7], c[4], GroundColors.down(side, 0.2))
	k.made.quad(c[1], c[0], c[4], c[5], GroundColors.down(front, 0.15))
	return c


## The floor slab between two storeys, standing proud all round: the horizontal
## that rules a line of light across the whole frontage. Drawn as a `slab`, so
## its top face is wound by the kit and can never come out culled.
static func ledge(k: Kit, w: float, d: float, y: float, s: int, col: Color, out: float = LEDGE) -> void:
	k.slab(0.0, y, 0.0, w + out * 2.0, SLAB, d + out * 2.0, s, col, GroundColors.up(col, 0.22), 0.02)


## A band of glazing across one face, with the mullions between its lights and
## the sill it sits on. `state`:
##   0  glass that still holds: a dark hole with the sky in it by day
##   1  boarded from inside with whatever was to hand
##   2  gone — the floor behind it open to the weather, which is the darkest
##      thing on the building and what makes the rest read as inhabited
##   3  somebody is behind it: the one in five that is lamp-coded, so it holds its
##      value into the night while the rest of the frontage goes with the hour
##
## The sill and the head stand PROUD and the glass sits back against them. A
## recess cut into the wall would be the honest thing and is not drawable here:
## the wall is one opaque quad, so anything behind it is not dim, it is invisible.
## What a sill actually does at this camera is throw a bar of shade down the
## glass, and that is what is built.
static func band(k: Kit, f: Array, v0: float, v1: float, lights: int, s: int, state: int, glass: Color, frame: Color, board: Color) -> void:
	var bl: Vector3 = f[0]
	var br: Vector3 = f[1]
	var tr: Vector3 = f[2]
	var tl: Vector3 = f[3]
	var face := 0.012
	match state:
		1:
			# Boarded: boards run across at slightly different angles, and the dark
			# of the room shows between two of them.
			Houses.wall_rect(k.made, bl, br, tr, tl, 0.06, v0, 0.94, v1, face, P.INK[1])
			var n := 4
			for i in n:
				var vv := lerpf(v0, v1, (i + 0.5) / n)
				var tilt := Kit.j(s, i, 0.012)
				k.made.quad(Houses.on_wall(bl, br, tr, tl, 0.04, vv - 0.024 + tilt, 0.03),
					Houses.on_wall(bl, br, tr, tl, 0.96, vv - 0.024 - tilt, 0.03),
					Houses.on_wall(bl, br, tr, tl, 0.96, vv + 0.022 - tilt, 0.03),
					Houses.on_wall(bl, br, tr, tl, 0.04, vv + 0.022 + tilt, 0.03),
					board if i != 2 else GroundColors.down(board, 0.3))
		2:
			# Open to the weather. Nothing but the dark, and the stumps of the
			# mullions that were in it.
			Houses.wall_rect(k.made, bl, br, tr, tl, 0.05, v0, 0.95, v1, face, P.INK[0])
			for i in lights - 1:
				var u := 0.05 + (i + 1) * 0.9 / lights
				Houses.wall_rect(k.made, bl, br, tr, tl, u - 0.008, v0, u + 0.008, lerpf(v0, v1, 0.35), 0.03, GroundColors.down(frame, 0.4))
		_:
			var pane := GroundColors.lamp(P.COPPER[4], 0.85) if state == 3 else glass
			Houses.wall_rect(k.made, bl, br, tr, tl, 0.05, v0, 0.95, v1, face, pane)
			for i in lights - 1:
				var u := 0.05 + (i + 1) * 0.9 / lights
				Houses.wall_rect(k.made, bl, br, tr, tl, u - 0.011, v0, u + 0.011, v1, 0.028, frame)
			if state == 3:
				# One light of it is curtained: a room somebody arranged, not a
				# floor left on. Drawn over the pane, so it reads at any hour.
				var u0 := 0.05 + 0.9 / lights * float(1 + int(Rng.hash01(s, 0, 66) * (lights - 1)))
				Houses.wall_rect(k.made, bl, br, tr, tl, u0 - 0.9 / lights + 0.014, v0 + 0.01, u0 - 0.014, v1 - 0.01, 0.034, GroundColors.down(frame, 0.2))
	# The sill, and the head over it: both stand clear of the glass, so the sun
	# rules a line along the sill's top and drops a bar of shade down the light.
	Houses.wall_rect(k.made, bl, br, tr, tl, 0.02, v0 - 0.035, 0.98, v0 + 0.008, 0.05, GroundColors.up(frame, 0.2))
	Houses.wall_rect(k.made, bl, br, tr, tl, 0.02, v1 - 0.008, 0.98, v1 + 0.028, 0.045, GroundColors.down(frame, 0.25))


## The parapet round a flat roof: the deck, a wall standing on its edge with one
## length of it gone, and the gravel and puddles that gather on it. The deck is
## the only thing on a tower the play camera looks straight down at, so it is
## where the building is either furnished or a lid.
static func parapet(k: Kit, w: float, d: float, y: float, s: int, c: int) -> Array[float]:
	var dress := BiomeDressing.of(c)
	# The deck is what BANKS on a flat roof here (`BiomeDressing.drift`): gravel
	# on the coast, ash in the Burning, needles in the pinewood. It was the
	# landscape's bleached bone, which made every roof in frame the brightest
	# thing in it.
	# A concrete deck, and the gravel that has blown onto it laid as real clumps.
	# It was `BiomeDressing.drift` flat across the whole deck, and `drift` is
	# derived from `GroundColors.wash()`, whose ALPHA carries that ground's MARK
	# CODE — so the lit shader drew a landscape's ground stipple over every roof
	# in the settlement. A ground wash is not a material; only a palette colour is.
	# **AND IT IS CONCRETE, SO IT IS LIT AS CONCRETE.** `matter_of` has carried a
	# row for it (85) since the made band was written, and until now nothing in
	# the game tagged anything with one — twelve tuned rows and a single call
	# site across sixty-four model files, so every cast deck and parapet in the
	# world returned the one default every made surface shares. The mark rides in
	# the ALPHA, which is why it goes on here and not on `dress.concrete` itself:
	# a dressing colour reaches FOUND geometry too, and `found.gdshader` reads
	# alpha under 0.5 as a beacon that BLINKS. `GroundColors.down` preserves
	# alpha, so every shade taken off these two keeps the mark; a `lerp` would
	# lose it and fall back to the default, which is where it was anyway.
	var deck := GroundColors.made(GroundColors.down(dress.concrete, 0.2), GroundColors.CONCRETE)
	var wall := GroundColors.made(GroundColors.down(dress.concrete, 0.34), GroundColors.CONCRETE)
	k.slab(0.0, y, 0.0, w + 0.1, 0.1, d + 0.1, s, GroundColors.down(deck, 0.15), deck, 0.02)
	# Gravel drifted into the corners, standing CLEAR of the deck. A clump wide
	# and flat enough to read as a drift sits almost exactly in the deck's own
	# plane, and two coplanar surfaces come out as a dithered field — which was
	# read as shadow acne, then as SSAO, and is neither: it survives every hour
	# and every quality tier, because it is geometry.
	for i in 4:
		var gx := (Rng.hash01(s, i, 31) - 0.5) * w * 0.8
		var gz := (Rng.hash01(s, i, 32) - 0.5) * d * 0.8
		k.clump(gx, y + 0.12, gz, 0.18 + Kit.j(s, i, 0.06), 0.09, s + 300 + i, solid(dress.drift[i % 2]), 6)
	var top := y + 0.1
	var hw := w * 0.5
	var hd := d * 0.5
	var ph := 0.28
	# Four lengths of parapet, each its own height, and one of them down to a
	# stub: a level roofline all the way round is the silhouette of a box.
	var gone := int(Rng.hash01(s, 0, 11) * 4.0)
	for i in 4:
		var h := ph * (0.75 + Rng.hash01(s, i, 12) * 0.5)
		if i == gone:
			h *= 0.3
		match i:
			0: k.slab(hw + 0.02, top, 0.0, 0.16, h, d + 0.12, s + i * 7, wall, GroundColors.up(wall, 0.25), 0.015)
			1: k.slab(-hw - 0.02, top, 0.0, 0.16, h, d + 0.12, s + i * 7, GroundColors.down(wall, 0.2), GroundColors.up(wall, 0.15), 0.015)
			2: k.slab(0.0, top, hd + 0.02, w + 0.12, h, 0.16, s + i * 7, wall, GroundColors.up(wall, 0.25), 0.015)
			_: k.slab(0.0, top, -hd - 0.02, w + 0.12, h, 0.16, s + i * 7, GroundColors.down(wall, 0.15), GroundColors.up(wall, 0.15), 0.015)
	return [top, ph]


## What lives on a city roof: tanks on legs, a stair head, ducts, a bundle of
## aerials somebody added long after. All FOUND but the stair head, which people
## built. This is the half of a tower the camera sees most of, so it carries most
## of the silhouette break.
static func plant(k: Kit, w: float, d: float, y: float, s: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var hw := w * 0.5
	var hd := d * 0.5
	# A water tank up on four legs, which is the one shape that says "people".
	var tx := hw * (-0.4 + Rng.hash01(s, 0, 21) * 0.5)
	var tz := hd * (0.35 - Rng.hash01(s, 1, 22) * 0.8)
	for i in 4:
		var lx := tx + (0.22 if (i & 1) == 0 else -0.22)
		var lz := tz + (0.22 if (i & 2) == 0 else -0.22)
		k.rod(Vector3(lx, y, lz), Vector3(lx, y + 0.42, lz), 0.026, 4, P.PLATE[2])
	k.found.prism(tx, y + 0.42, tz, 0.34, y + 0.92, 0.3, 10, P.RUST[2], P.PLATE[4])
	k.found.prism(tx, y + 0.9, tz, 0.3, y + 0.98, 0.16, 10, P.PLATE[3], P.PLATE[4])
	# The stair head: the way out onto the roof, built by hand out of whatever the
	# people who use it had, with a door in it.
	var sx := -hw * 0.45
	var sz := -hd * 0.3
	# CUTSTONE (row 91) rather than the default, and the name overstates it: this
	# is `BiomeDressing.walling`, "a ruin, a lean-to, a dry-stone gable", and the
	# row is written for DRESSED block. But the default it would otherwise take is
	# the timber/thatch/cloth/mud-render row, which is wrong about stone in every
	# term — harder, glassier and more relieved is right for a built wall, and a
	# rough gable reading slightly too dressed beats a stone gable lit as canvas.
	# If dry stone ever gets a row of its own this moves to it.
	k.slab(sx, y, sz, 0.58, 0.72, 0.5, s + 40,
		GroundColors.made(dress.walling[1], GroundColors.CUTSTONE),
		GroundColors.made(dress.walling[2], GroundColors.CUTSTONE), 0.025, 0.06, Kit.j(s, 2, 0.05))
	k.plate(Vector3(sx + 0.3, y + 0.74, sz + 0.3), Vector3(sx + 0.3, y + 0.74, sz - 0.3),
		Vector3(sx - 0.34, y + 0.86, sz - 0.3), Vector3(sx - 0.34, y + 0.86, sz + 0.3), P.PLATE[2], P.PLATE[1], P.PLATE[4])
	# Ducting run across the deck and over the parapet, and a bundle of aerials.
	var a := Vector3(tx - 0.1, y + 0.24, tz + 0.4)
	var b := Vector3(hw * 0.7, y + 0.34, -hd * 0.5)
	k.rod(a, a.lerp(b, 0.55) + Vector3(0, 0.1, 0), 0.07, 6, P.PLATE[2])
	k.rod(a.lerp(b, 0.55) + Vector3(0, 0.1, 0), b, 0.07, 6, P.PLATE[3])
	var mast := Vector3(hw * 0.55, y, hd * 0.55)
	k.rod(mast, mast + Vector3(0.04, 1.35, -0.03), 0.028, 5, P.PLATE[2])
	for i in 4:
		var up := 0.6 + i * 0.22
		var lean := Vector3(Kit.j(s, i + 30, 0.26), 0.12 + Kit.j(s, i + 34, 0.06), Kit.j(s, i + 38, 0.26))
		k.rod(mast + Vector3(0, up, 0), mast + Vector3(0, up, 0) + lean, 0.012, 3, P.PLATE[4])
	if dress.cold():
		# Snow lies on the deck and caps the tank, and the parapet keeps it.
		k.clump(tx, y + 0.96, tz, 0.3, 0.12, s + 51, dress.snow[0], 7)
		k.clump(w * 0.1, y + 0.1, -d * 0.2, w * 0.3, 0.1, s + 52, dress.snow[0], 7)
		k.clump(-w * 0.2, y + 0.1, d * 0.22, w * 0.22, 0.09, s + 53, dress.snow[1], 7)


## The immense sign the city is remembered for: a FOUND frame of gantry and
## bracing bolted off one flank, and inside it a face of light that has been
## burning since before anybody now alive was born (docs/VISION.md: mended high
## tech). The face is NEON-coded, so `PropModels.neon_point` reads its middle and
## its colour off the geometry and the light it throws can never part company
## with the thing casting it.
##
## It hangs on a WALL and not on the roof, unlike a house's stolen tube. A house
## puts its tube where this camera always looks because a tube is thin; a sign
## four storeys tall is read from anywhere, and a city's signs face its streets.
static func billboard(k: Kit, f: Array, v0: float, v1: float, col: Color, s: int) -> void:
	var bl: Vector3 = f[0]
	var br: Vector3 = f[1]
	var tr: Vector3 = f[2]
	var tl: Vector3 = f[3]
	var out := Houses.wall_out(bl, br, tr, tl)
	var u0 := 0.14
	var u1 := 0.80
	# The gantry it is hung on: four brackets off the wall and a frame across them.
	for uu: float in [u0, u1]:
		for vv: float in [v0, v1]:
			var at := Houses.on_wall(bl, br, tr, tl, uu, vv, 0.0)
			k.rod(at, at + out * 0.22, 0.022, 4, P.PLATE[2])
	var a := Houses.on_wall(bl, br, tr, tl, u0, v0, 0.0) + out * 0.22
	var b := Houses.on_wall(bl, br, tr, tl, u1, v0, 0.0) + out * 0.22
	var cc := Houses.on_wall(bl, br, tr, tl, u1, v1, 0.0) + out * 0.22
	var dd := Houses.on_wall(bl, br, tr, tl, u0, v1, 0.0) + out * 0.22
	k.rod(a, b, 0.026, 4, P.PLATE[1])
	k.rod(dd, cc, 0.026, 4, P.PLATE[1])
	k.rod(a, dd, 0.026, 4, P.PLATE[1])
	k.rod(b, cc, 0.026, 4, P.PLATE[1])
	# The face. MADE, because what it is now is a sheet somebody keeps alive, and
	# because NEON is a MADE mark: the lights read the made surface for it.
	#
	# It is drawn as a SIGN and not as a panel of colour. A single lit rectangle
	# this size reads as a sticker laid on the building — the first frames of it
	# were a pink oblong four storeys tall with nothing in it — so the light is
	# broken into three registers with dead gaps between them, the middle one
	# carrying blocks that read as type at the distance a player sees this from,
	# and the whole thing is set in a dark surround that is what the gantry holds.
	var g := out * 0.015
	var lit := GroundColors.neon(col)
	var dim := GroundColors.neon(col.darkened(0.45))
	k.made.quad(a + g, b + g, cc + g, dd + g, P.INK[0])
	var rows: Array[Vector2] = [Vector2(0.06, 0.3), Vector2(0.37, 0.72), Vector2(0.79, 0.95)]
	for r in rows.size():
		var lo: float = rows[r].x
		var hi: float = rows[r].y
		var face := lit if r == 1 else dim
		var q := out * 0.03
		k.made.quad(a.lerp(dd, lo) + q, b.lerp(cc, lo) + q, b.lerp(cc, hi) + q, a.lerp(dd, hi) + q, face)
		if r != 1:
			continue
		# Type across the middle register: five blocks, each its own width, with
		# the third one dead. A sign that has lost a character is the whole of
		# what says nobody has maintained this in twenty years.
		for i in 5:
			var t0 := 0.07 + i * 0.18
			var t1 := t0 + 0.09 + Rng.hash01(s, i, 43) * 0.04
			var ga := a.lerp(b, t0)
			var gb := a.lerp(b, t1)
			var ca := dd.lerp(cc, t0)
			var cb := dd.lerp(cc, t1)
			var p := out * 0.045
			k.made.quad(ga.lerp(ca, lo + 0.08) + p, gb.lerp(cb, lo + 0.08) + p,
				gb.lerp(cb, hi - 0.08) + p, ga.lerp(ca, hi - 0.08) + p,
				P.INK[0] if i == 2 else GroundColors.neon(Color(1, 1, 1)))
	# And the conduit somebody ran down the wall to feed it.
	var foot := Houses.on_wall(bl, br, tr, tl, u0 + 0.05, 0.0, 0.0)
	k.rod(Houses.on_wall(bl, br, tr, tl, u0 + 0.05, v0, 0.0) + out * 0.04, foot + out * 0.04, 0.018, 4, P.PLATE[1])


## The ground floor as a street frontage: shutters rolled down over what were
## shops, one of them up with the dark behind it, a stall built into the opening
## next to it. This is the storey a player walks past, so it carries the detail.
static func frontage(k: Kit, f: Array, s: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var bl: Vector3 = f[0]
	var br: Vector3 = f[1]
	var tr: Vector3 = f[2]
	var tl: Vector3 = f[3]
	var out := Houses.wall_out(bl, br, tr, tl)
	var bays := 3
	for i in bays:
		var u0 := 0.07 + i * 0.3
		var u1 := u0 + 0.22
		var open := i == int(Rng.hash01(s, 0, 61) * bays)
		# The opening itself, and the lintel over it standing proud.
		Houses.wall_rect(k.made, bl, br, tr, tl, u0, 0.03, u1, 0.62, 0.01, P.INK[1] if open else GroundColors.down(dress.concrete, 0.3))
		Houses.wall_rect(k.made, bl, br, tr, tl, u0 - 0.02, 0.62, u1 + 0.02, 0.7, 0.05, GroundColors.up(dress.concrete, 0.2))
		if open:
			# The shutter rolled up in its box, and a counter across the opening.
			Houses.wall_rect(k.made, bl, br, tr, tl, u0, 0.5, u1, 0.6, 0.06, P.PLATE[2])
			var ca := Houses.on_wall(bl, br, tr, tl, u0, 0.0, 0.0) + out * 0.02
			var cb := Houses.on_wall(bl, br, tr, tl, u1, 0.0, 0.0) + out * 0.02
			k.slab((ca.x + cb.x) * 0.5, ca.y + 0.32, (ca.z + cb.z) * 0.5, maxf(0.1, (cb - ca).length()) * 0.9, 0.09, 0.26, s + i, P.EARTH[2], P.EARTH[3], 0.02)
			continue
		# Corrugation: the shutter's own ribs, which are what reads at this camera.
		for r in 7:
			var vv := 0.06 + r * 0.075
			Houses.wall_rect(k.made, bl, br, tr, tl, u0 + 0.008, vv, u1 - 0.008, vv + 0.042, 0.022 + 0.004 * (r % 2), P.PLATE[3] if r % 2 == 0 else P.PLATE[2])
	# What the street leaves against a frontage: a bank of it along the foot.
	var drift := dress.drift
	for i in 5:
		var p := Houses.on_wall(bl, br, tr, tl, 0.08 + i * 0.2, 0.0, 0.0) + out * (0.16 + Kit.j(s, i + 12, 0.1))
		k.clump(p.x, -0.06, p.z, 0.26 + Kit.j(s, i, 0.08), 0.13 + Kit.j(s, i + 6, 0.05), s + 70 + i, solid(drift[i % 2]), 6)


## A shared skeleton: `n` storeys of (w, d), each stepped in by `step`, the floor
## slab between each pair, and a glazing band on the two faces the camera reads.
## Returns the height the top slab stands at.
static func shaft(k: Kit, w: float, d: float, n: int, step: float, s: int, c: int) -> float:
	var dress := BiomeDressing.of(c)
	# A building that has stood sixty years is STAINED, and its mass has to sit
	# BELOW the ground it stands on in value or a settlement of these reads as a
	# row of white boxes on a pale plain — which is what the first frames of them
	# were. `BiomeDressing.concrete` is what the machine age cast HERE; what a city
	# does to it is take it down, and let the HORIZONTALS be the light thing, so
	# the floor lines are the drawing and the wall is what they are drawn on.
	var body := GroundColors.down(dress.concrete, 0.34)
	# Glass at noon is a dark hole with the sky in it, not a lit pane. It was
	# lamp-coded — the mark that says "draw me at full value whatever the hour" —
	# and it turned every band on every building into a stripe of daylight blue at
	# eleven in the morning. Lamp code belongs on the few floors still lived behind,
	# which `band` deals one in five of; this is what the rest are.
	var glass := P.SLATE[1].lerp(P.RIME[1], 0.3)
	var y := 0.0
	for i in n:
		var inset := step * i
		var shade := GroundColors.down(body, 0.18 + 0.05 * (i % 2))
		var t := storey(k, w, d, y, STOREY, s + i * 17, GroundColors.down(body, 0.04 * i), shade, inset)
		var faces := Houses.faces(t)
		# ABOVE THE FOURTH FLOOR, LESS OF IT — and this is a readability argument
		# before it is a budget one. The camera shows fifteen world units and a
		# thing of height h takes h * cos(57) = 0.545 of them up the screen, so
		# from the fifth floor of an eleven-storey tower up you are in the top
		# third of the frame or out of it altogether. Wear, growth and the
		# per-face glazing states are all read at arm's length and none of them
		# survives being drawn there; what carries at that height is the
		# SILHOUETTE and the floor lines, which are `storey` and `ledge`, and
		# every floor keeps both. It is also what makes a tower three times its
		# old height cost about what it did.
		var near_ground := i < DETAIL_FLOORS
		# Every face is worn, as every face of a house is: a building worn only
		# where the camera happens to look is what made a village read tidy.
		if near_ground:
			for fi in faces.size():
				var wf: Array = faces[fi]
				Houses.weathered(k, wf[0], wf[1], wf[2], wf[3], s + i * 31 + fi * 7, GroundColors.down(body, 0.35), dress.growth)
		var v0 := (1.0 - GLASS) * 0.55
		var v1 := v0 + GLASS
		for fi in 4:
			var wf: Array = faces[fi]
			# Which storeys still have glass, which are boarded and which stand
			# open is dealt per FACE, so the two sides of one building are never
			# the same building drawn twice.
			var h := Rng.hash01(s, i * 4 + fi, 63)
			var state := 0
			if h < 0.24:
				state = 1
			elif h < 0.36:
				state = 2
			elif h < 0.46:
				state = 3
			if i == 0:
				# The ground floor is a frontage, not a band of glazing.
				frontage(k, wf, s + fi * 13, c)
				continue
			# High up, the two long faces carry the glazing and the two short ones
			# are blank wall: half the bands, and at that height in frame the eye
			# is reading the column of lit floors, not which side of it they are on.
			if not near_ground and fi % 2 == 1:
				continue
			band(k, wf, v0, v1, 4 if fi % 2 == 0 else 5, s + i * 41 + fi, state, glass, MULLION, BOARDING)
		y += STOREY
		ledge(k, w - step * i, d - step * i, y - SLAB * 0.5, s + i * 23, GroundColors.up(body, 0.12))
	return y


# --- the forms ------------------------------------------------------------------

## "tower": five storeys of cast frame with a sign four of them tall bolted off
## its flank. The tallest thing a person lives in.
static func tower(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 3100
	var w := 2.5
	var d := 2.9
	var top := shaft(k, w, d, 11, 0.0, s, c)
	var t := corners(w + FRAME, d + FRAME, 0.0, top, s)
	var faces := Houses.faces(t)
	var fb: Array = faces[0]
	Houses.door(k, fb[0], fb[1], fb[2], fb[3], 0.62, 0.11, 0.16)
	Houses.struck_plate(k, fb[0], fb[1], fb[2], fb[3], 0.28, 0.1)
	# The sign on the +z flank, where a street would run past it.
	billboard(k, faces[1], 0.40, 0.74, SIGN_COLOURS[0], s + 5)
	Houses.salvage(k, faces[3][0], faces[3][1], faces[3][2], faces[3][3], 0.3, s + 9)
	var r := parapet(k, w, d, top, s + 60, c)
	plant(k, w, d, r[0] + 0.05, s + 70, c)


## "stack": four storeys stepping back as they rise, each setback a terrace with
## something standing on it. Where a tower is one mass, this is a staircase.
static func stack(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 3200
	var w := 2.8
	var d := 2.6
	var step := 0.16
	var top := shaft(k, w, d, 8, step, s, c)
	# The ground storey's frame, not the whole shaft's: everything hung on this
	# one is at street level, and the storeys above it step back out of its plan.
	var t := corners(w + FRAME, d + FRAME, 0.0, STOREY, s)
	var faces := Houses.faces(t)
	Houses.door(k, faces[0][0], faces[0][1], faces[0][2], faces[0][3], 0.34, 0.11, 0.72)
	Houses.struck_plate(k, faces[0][0], faces[0][1], faces[0][2], faces[0][3], 0.76, 0.42)
	# A SIGN ON THE FLANK. A city where only the tower and the block burn is a
	# city with two lit buildings in it; what the owner asked for is technology
	# everywhere, and a stack of let storeys is exactly the wall a sign is hung
	# on. Mercury green here, so the street is not one colour: SIGN_COLOURS is
	# read across the stock rather than each form reaching for the sodium.
	billboard(k, faces[1], 0.30, 0.86, SIGN_COLOURS[1], s + 5)
	# What people put on a terrace they can get out onto: a rail, a tank, washing.
	for i in range(1, 8):
		var y := STOREY * i
		var hw := (w - step * i) * 0.5
		var hd := (d - step * i) * 0.5
		for j in 4:
			var u := -0.8 + j * 0.53
			k.rod(Vector3(hw + step * 0.4, y, u * hd), Vector3(hw + step * 0.4, y + 0.3, u * hd), 0.016, 4, P.PLATE[2])
		k.rod(Vector3(hw + step * 0.4, y + 0.3, -hd * 0.8), Vector3(hw + step * 0.4, y + 0.3, hd * 0.8), 0.016, 4, P.PLATE[3])
		if i == 2:
			k.found.prism(hw + step * 0.2, y + 0.04, -hd * 0.4, 0.2, y + 0.5, 0.17, 9, P.RUST[2], P.PLATE[3])
		else:
			k.sag(Vector3(hw + step * 0.35, y + 0.28, -hd * 0.7), Vector3(hw + step * 0.35, y + 0.28, hd * 0.7), 0.07, 4, 0.008, dress.pale[0])
	var r := parapet(k, w - step * 3.0, d - step * 3.0, top, s + 60, c)
	plant(k, w - step * 3.0, d - step * 3.0, r[0] + 0.05, s + 70, c)


## "block": three storeys, wide and low, its whole ground floor a street
## frontage and its roof a field of plant. The building a city is mostly made of.
static func block(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 3300
	var w := 3.4
	var d := 2.4
	var top := shaft(k, w, d, 3, 0.0, s, c)
	var t := corners(w + FRAME, d + FRAME, 0.0, top, s)
	var faces := Houses.faces(t)
	Houses.struck_plate(k, faces[0][0], faces[0][1], faces[0][2], faces[0][3], 0.9, 0.24)
	# An awning over the frontage, on poles: the one thing that breaks a wide
	# building's silhouette at the height a player walks at.
	var fb: Array = faces[0]
	var out := Houses.wall_out(fb[0], fb[1], fb[2], fb[3])
	var wa := Houses.on_wall(fb[0], fb[1], fb[2], fb[3], 0.06, 0.34, 0.0)
	var wb := Houses.on_wall(fb[0], fb[1], fb[2], fb[3], 0.72, 0.34, 0.0)
	var fa := wa + out * 0.62 + Vector3(0, -0.16, 0)
	var fbb := wb + out * 0.58 + Vector3(0, -0.2, 0)
	k.plate(fa, fbb, wb, wa, P.PLATE[3], P.PLATE[1], P.PLATE[4])
	for p: Vector3 in [fa, fbb]:
		k.rod(Vector3(p.x, 0.0, p.z), p, 0.026, 4, P.PLATE[2])
	# The sign runs along the top of the frontage, where the awning does not
	# reach: a shop's own, not the city's, so it is the smaller colour.
	billboard(k, faces[2], 0.56, 0.84, SIGN_COLOURS[1], s + 5)
	Houses.salvage(k, faces[1][0], faces[1][1], faces[1][2], faces[1][3], 0.7, s + 9)
	var r := parapet(k, w, d, top, s + 60, c)
	plant(k, w, d, r[0] + 0.05, s + 70, c)
	# A second tank at the other end: a wide roof with one tank on it reads empty.
	k.found.prism(-w * 0.3, r[0] + 0.05, d * 0.22, 0.26, r[0] + 0.6, 0.23, 9, P.RUST[3], P.PLATE[4])


## "shell": a tower whose top storeys came down. What is left is lived in — the
## break closed with plate and board, the floors above it gone to sky, and the
## spill of its own concrete lying where it fell with the reinforcement standing
## out of it. The silhouette nothing else in a city can be mistaken for.
static func shell(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 3400
	var w := 2.3
	var d := 2.5
	var top := shaft(k, w, d, 3, 0.0, s, c)
	var t := corners(w + FRAME, d + FRAME, 0.0, top, s)
	var faces := Houses.faces(t)
	Houses.door(k, faces[0][0], faces[0][1], faces[0][2], faces[0][3], 0.5, 0.11, 0.17)
	Houses.struck_plate(k, faces[0][0], faces[0][1], faces[0][2], faces[0][3], 0.2, 0.12)
	var hw := w * 0.5
	var hd := d * 0.5
	# HALF A STOREY MORE, AND ONLY HALF OF IT. What says a building came down is
	# what is missing from its OUTLINE, and a flat lid with planks on it says
	# nothing at all at the distance this is read from: two walls of the floor
	# above still stand, to their own broken heights, and the other two are sky.
	var body := GroundColors.down(dress.concrete, 0.34)
	for i in 5:
		var z := -hd + (i + 0.5) * d / 5.0
		var h := 0.9 - i * 0.14 + Kit.j(s, i + 60, 0.16)
		k.slab(hw - 0.09, top, z, 0.2, maxf(0.2, h), d / 5.0 + 0.02, s + i * 5, body, GroundColors.up(body, 0.2), 0.02)
	for i in 4:
		var x := -hw + (i + 0.5) * w / 4.0
		var h := 0.35 + i * 0.17 + Kit.j(s, i + 70, 0.14)
		k.slab(x, top, -hd + 0.09, w / 4.0 + 0.02, maxf(0.18, h), 0.2, s + i * 7 + 3, GroundColors.down(body, 0.12), GroundColors.up(body, 0.15), 0.02)
	# The floor that is left, closed off with plate laid across it and boards
	# where the plate ran out, and it leans, because it was never square.
	k.plate(Vector3(hw * 0.9, top + 0.1, hd), Vector3(hw * 0.9, top + 0.1, -hd),
		Vector3(-hw, top + 0.34, -hd * 0.9), Vector3(-hw, top + 0.34, hd * 0.9), P.PLATE[2], P.PLATE[1], P.PLATE[4])
	for i in 4:
		var z := -hd * 0.7 + i * hd * 0.47
		# TIMBER (row 80), and this one is exact: `BiomeDressing.timber` is
		# "timber that has stood out in this weather for years", which is the row.
		k.slab(Kit.j(s, i, 0.2), top + 0.3 + Kit.j(s, i + 4, 0.05), z, w * 0.7, 0.08, 0.3, s + i * 3,
			GroundColors.made(dress.timber[0], GroundColors.TIMBER),
			GroundColors.made(dress.timber[1], GroundColors.TIMBER), 0.02, 0.0, Kit.j(s, i + 8, 0.1))
	# Reinforcement standing out of the broken edge, bent where it tore.
	for i in 6:
		var at := Vector3(-hw + Rng.hash01(s, i, 71) * w, top + 0.3, -hd + Rng.hash01(s, i, 72) * d)
		k.rod(at, at + Vector3(Kit.j(s, i + 20, 0.18), 0.3 + Rng.hash01(s, i, 73) * 0.28, Kit.j(s, i + 26, 0.18)), 0.014, 3, P.RUST[2])
	# What came down, lying at the foot with grass through it.
	var gs := k.made.vertex_count()
	for i in 9:
		# Inside the form's own `reach` (BiomeForms: a shell stands on 2.0 tiles),
		# or the spill is geometry a player can walk through.
		var p := Vector2(-1.25 - Rng.hash01(s, i, 75) * 0.6, Kit.j(s, i + 50, 1.6))
		var big := Rng.hash01(s, i, 74) < 0.45
		k.slab(p.x, -0.06, p.y, (0.78 if big else 0.42) + Kit.j(s, i + 60, 0.16), 0.26, 0.5, s + 80 + i,
			GroundColors.down(dress.concrete, 0.24) if i % 2 else GroundColors.down(dress.pale[1], 0.3),
			GroundColors.down(dress.pale[0], 0.18), 0.04, 0.12, Kit.j(s, i + 70, 0.4))
	for i in 4:
		k.clump(-1.7 + Kit.j(s, i + 90, 0.6), -0.04, Kit.j(s, i + 94, 0.9), 0.17, 0.2, s + 100 + i, dress.growth, 6)
	k.sway_by_height(gs, 0.0, 0.2, 0.2)
	Houses.salvage(k, faces[3][0], faces[3][1], faces[3][2], faces[3][3], 0.5, s + 9)


## "arcade": three storeys with a walkway bridging out of the upper one on
## struts, which ends in the air — the building it crossed to is not there any
## more. The one form that puts something BETWEEN the camera and the street.
static func arcade(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 3500
	var w := 2.6
	var d := 3.0
	var top := shaft(k, w, d, 3, 0.0, s, c)
	var t := corners(w + FRAME, d + FRAME, 0.0, top, s)
	var faces := Houses.faces(t)
	Houses.door(k, faces[0][0], faces[0][1], faces[0][2], faces[0][3], 0.7, 0.11, 0.17)
	Houses.struck_plate(k, faces[0][0], faces[0][1], faces[0][2], faces[0][3], 0.34, 0.12)
	# AN ARCADE IS SHOPS, so it is the one form whose sign belongs LOW, at the
	# height somebody walking under it reads rather than four storeys up. Warm
	# white: the light a frontage spills onto a wet pavement, which is what the
	# landscape's reflections are made of.
	billboard(k, faces[1], 0.14, 0.52, SIGN_COLOURS[2], s + 5)
	# The walkway: a deck out of the second storey, a rail along both sides, the
	# struts under it, and the torn end where it stopped.
	var y := STOREY * 2.0 + 0.2
	var hd := d * 0.5
	var reach := 2.1
	k.slab(w * 0.5 + reach * 0.5, y, 0.0, reach, 0.12, 0.72, s + 20, dress.concrete, GroundColors.up(dress.concrete, 0.18), 0.02)
	for side: float in [-1.0, 1.0]:
		for i in 5:
			var x := w * 0.5 + 0.2 + i * (reach - 0.4) / 4.0
			k.rod(Vector3(x, y + 0.12, side * 0.34), Vector3(x, y + 0.42, side * 0.34), 0.014, 4, P.PLATE[2])
		k.rod(Vector3(w * 0.5 + 0.2, y + 0.42, side * 0.34), Vector3(w * 0.5 + reach - 0.2, y + 0.42, side * 0.34), 0.016, 4, P.PLATE[3])
	for i in 2:
		var x := w * 0.5 + 0.5 + i * 1.1
		k.rod(Vector3(x, y, 0.0), Vector3(w * 0.5 - 0.05, y - 0.85 - i * 0.2, 0.0), 0.028, 4, P.PLATE[2])
	# The torn end: the deck's reinforcement standing out of the break.
	for i in 4:
		var z := -0.3 + i * 0.2
		k.rod(Vector3(w * 0.5 + reach * 0.5 - 0.02, y + 0.06, z), Vector3(w * 0.5 + reach * 0.5 + 0.22 + Rng.hash01(s, i, 81) * 0.2, y + 0.1 + Kit.j(s, i, 0.12), z + Kit.j(s, i + 4, 0.1)), 0.013, 3, P.RUST[2])
	Houses.salvage(k, faces[1][0], faces[1][1], faces[1][2], faces[1][3], 0.24, s + 9)
	var r := parapet(k, w, d, top, s + 60, c)
	plant(k, w, d, r[0] + 0.05, s + 70, c)
	if dress.cold():
		k.clump(w * 0.5 + reach * 0.5, y + 0.12, 0.0, reach * 0.4, 0.09, s + 91, dress.snow[0], 7)


## "spire": narrow, six storeys, a mast on its head with the machines' beacon
## still turning. Nobody lives above the third floor. The vertical a street needs
## one of, and never two.
static func spire(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 3600
	var w := 1.8
	var d := 1.9
	var top := shaft(k, w, d, 11, 0.04, s, c)
	var t := corners(w + FRAME, d + FRAME, 0.0, STOREY, s)
	var faces := Houses.faces(t)
	Houses.door(k, faces[0][0], faces[0][1], faces[0][2], faces[0][3], 0.5, 0.1, 0.74)
	Houses.struck_plate(k, faces[0][0], faces[0][1], faces[0][2], faces[0][3], 0.82, 0.4)
	# THE SIGN GOES HIGH ON THIS ONE, on its own band of frame four storeys up
	# rather than on the ground storey every other form hangs from. A spire is
	# the vertical a street gets one of, so its sign is the thing read from the
	# far end of the street and over the roofs of everything between — which is
	# the whole reason a city has a skyline rather than a row of shopfronts.
	# SODIUM, and NOT the magenta this first reached for. `SIGN_MAGENTA` is in
	# SIGN_COLOURS and was unused by every form on purpose: slums.gd's own header
	# says the machine ramps own the violet band and the amber LENS is the one
	# saturated thing on a machine, "so in the most crowded frame in the game the
	# ONE violet thing is a machine and the player reads it instantly -- that is
	# the payoff, and nothing in this file may spend it". Hanging magenta on the
	# tallest sign in the city spends exactly that, and the frame showed it: a
	# four-storey pink slab that owned the picture and would have made every
	# machine in the street harder to find. Sodium is what a real city at night
	# is anyway, and it is the surest way not to look like every cyberpunk frame
	# ever made.
	var high := Houses.faces(corners(w + FRAME, d + FRAME, STOREY * 3.6, STOREY * 5.4, s + 11))
	billboard(k, high[1], 0.24, 0.78, SIGN_COLOURS[0], s + 12)
	var r := parapet(k, w - 0.3, d - 0.3, top, s + 60, c)
	var head := r[0] + 0.05
	# The mast, guyed to three corners of the deck.
	var tip := Vector3(0.03, head + 1.9, -0.02)
	k.rod(Vector3(0, head, 0), tip, 0.038, 6, P.PLATE[2])
	for i in 3:
		var a := Vector2.from_angle(i * TAU / 3.0 + 0.4) * (w * 0.5 - 0.22)
		k.cable(Vector3(a.x, head + 0.1, a.y), tip.lerp(Vector3(0, head, 0), 0.25), 0.08, 3, 0.008, P.PLATE[1])
	k.found.prism(tip.x, tip.y - 0.12, tip.z, 0.09, tip.y + 0.06, 0.07, 8, P.PLATE[1], P.RUST[2])
	# The stair somebody bolted up the outside once the inside one went.
	for i in 19:
		var y := 0.4 + i * 0.7
		var side := 1.0 if i % 2 == 0 else -1.0
		k.rod(Vector3(-w * 0.5 - 0.03, y, -0.3 * side), Vector3(-w * 0.5 - 0.03, y, 0.3 * side), 0.014, 3, P.PLATE[3])
		k.rod(Vector3(-w * 0.5 - 0.03, y, 0.3 * side), Vector3(-w * 0.5 - 0.03, y + 0.7, -0.3 * side), 0.011, 3, P.PLATE[2])
	Houses.salvage(k, faces[3][0], faces[3][1], faces[3][2], faces[3][3], 0.5, s + 9)
	if dress.cold():
		k.clump(0.2, head + 0.06, 0.15, w * 0.3, 0.1, s + 92, dress.snow[0], 7)
