class_name DevRegions
extends Control
## EVERY REGION PICKED OUT AND NAMED, over the flyover (owner, 2026-09-18: "build
## in fly over view a system that highlights each region so when active I can
## look at view and give feedback on per region and name").
##
## A region is the unit this whole game keys on — a keeper, a depot, a chapter, a
## sub-arc, an interference file all belong to one — and until now it was the one
## thing a player or an owner could not SEE. The landscape under your feet has a
## name on the glass; which run of it you are standing in, how far it goes and
## where it gives way to the next has only ever existed in `WorldData.regions`.
##
## HOW IT DRAWS THE REAL SHAPE AND NOT A BOX. A region is an irregular blob and
## its `bounds` is a rectangle that lies about it — two regions of one landscape
## can have bounds that overlap almost completely. So this samples: a coarse grid
## over the screen, each point unprojected onto the ground plane and asked
## `WorldData.region_at`. That is exact by construction, costs one lookup per
## sample, and needs no shader, no mesh and no bake — which matters because the
## alternative was tinting the terrain, and the terrain is the one thing in this
## project that is expensive to rebuild.
##
## The camera is orthographic, so a screen point unprojects to a RAY and the
## ground is met by walking that ray down to the world's own height. One step is
## enough for the flat majority and a short refinement fixes the terraces, which
## is the whole of `_ground_under`.
##
## A SAMPLE IS A SQUARE OF ITS OWN COLOUR, not a per-pixel fill: at STEP the grid
## is coarse enough to be cheap and fine enough that a region's edge reads as an
## edge. It is deliberately a dev instrument and looks like one.

## Base pixels between samples. 14 is about half the width of a capital, so a
## border lands within half a letter of where it really is.
const STEP := 14
## How far down the ray to look for the ground, in world units, and how many
## halvings to settle a terrace with.
const RAY := 400.0
const REFINE := 7

## How much of the region's colour is laid over the world. LOW on purpose: this
## is on while he is judging how a place LOOKS, so it has to say which region a
## thing is in without becoming the thing he sees. At 0.30 the coast read as a
## pink sheet and the art under it could not be judged at all.
const WASH := 0.17
## The one under the middle of the screen is the one being talked about.
const UNDER_WASH := 0.30

var game: Node
var showing := false

var _labels: Array[Dictionary] = []
var _under := -1


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A colour per region id. Spread round the wheel by INDEX rather than hashed, so
## neighbouring regions never come out near-identical — the one thing that would
## make the picture useless.
static func colour_of(i: int, n: int) -> Color:
	var h := fposmod(float(i) * 0.61803398875 + float(i % 3) * 0.11, 1.0)
	return Color.from_hsv(h, 0.72, 1.0)


## Which region the middle of the screen is over, or -1. What the owner is
## looking at IS what the readout should be about.
func under() -> int:
	return _under


func step() -> void:
	if showing:
		queue_redraw()


func _draw() -> void:
	_labels.clear()
	_under = -1
	if not showing or game == null:
		return
	var world: WorldData = game.get("world")
	var cam: Camera3D = game.get("camera")
	if world == null or cam == null or world.regions.is_empty():
		return
	var screen := UiBase.screen().size
	var n := world.regions.size()
	# Where each region's samples land, so a name can be put in the middle of the
	# part that is ON SCREEN rather than at a centre that may be off it.
	var sums: Dictionary = {}
	var mid := Vector2i(screen.x / 2, screen.y / 2)
	for y in range(0, screen.y, STEP):
		for x in range(0, screen.x, STEP):
			var p := ground_under(cam, Vector2(x, y), world)
			if not p.is_finite():
				continue
			var r := world.region_at(floori(p.x), floori(p.y))
			if r < 0:
				continue
			if absi(x - mid.x) <= STEP and absi(y - mid.y) <= STEP:
				_under = r
			var c := colour_of(r, n)
			c.a = WASH
			draw_rect(Rect2(x, y, STEP, STEP), c)
			var s: Array = sums.get(r, [0.0, 0.0, 0])
			s[0] += float(x)
			s[1] += float(y)
			s[2] += 1
			sums[r] = s
	# A second pass over the one being looked at, so it stands out of the rest.
	if _under >= 0:
		for y in range(0, screen.y, STEP):
			for x in range(0, screen.x, STEP):
				var p := ground_under(cam, Vector2(x, y), world)
				if not p.is_finite():
					continue
				if world.region_at(floori(p.x), floori(p.y)) != _under:
					continue
				var c := colour_of(_under, n)
				c.a = UNDER_WASH - WASH
				draw_rect(Rect2(x, y, STEP, STEP), c)
	_name_them(world, sums, n)


## A name over the middle of each region's visible part. Skipped for a region with
## only a corner on screen: a label with nothing under it is worse than none.
func _name_them(world: WorldData, sums: Dictionary, n: int) -> void:
	for key: Variant in sums:
		var r := int(key)
		var s: Array = sums[key]
		if int(s[2]) < 6:
			continue
		var at := Vector2i(int(s[0] / float(s[2])), int(s[1] / float(s[2])))
		var row: Dictionary = world.regions[r] if r < world.regions.size() else {}
		var d := BiomeRegistry.by_index(int(row.get("index", 0)))
		var name := "%s  #%d" % [d.display_name if d != null else "?", r]
		var note := "%d tiles" % int(row.get("tiles", 0))
		var col := colour_of(r, n)
		col.a = 1.0
		var back := Color(0.04, 0.04, 0.06, 0.72)
		var w := maxi(UiFont.width(name), UiFont.width(note)) + 10
		var h := UiFont.SIZE * 2 + 8
		# Held inside the glass: a region whose visible middle is at the edge had its
		# name cut in half, which is the one thing a naming tool may not do.
		var sc := UiBase.screen().size
		at.x = clampi(at.x, w / 2 + 4, sc.x - w / 2 - 4)
		at.y = clampi(at.y, h / 2 + 4, sc.y - h / 2 - 4)
		draw_rect(Rect2(at.x - w / 2, at.y - h / 2, w, h), back)
		UiDraw.text_centred(self, at.x, at.y - h / 2 + 4, name, col)
		UiDraw.text_centred(self, at.x, at.y - h / 2 + 4 + UiFont.SIZE, note, Color(0.72, 0.76, 0.80))
		_labels.append({"region": r, "at": at})


## Where a screen point meets the ground, in tiles, or INF off the world. PUBLIC
## because the flyover's mouse asks the same question — drag and zoom both need
## to know what is under the pointer — and one answer to it is the point.
##
## The ray is walked rather than solved because the ground is terraced: a plane
## solve answers for a flat world and puts a border half a region away on a
## hillside, which is exactly the error this tool exists to make visible.
func ground_under(cam: Camera3D, at: Vector2, world: WorldData) -> Vector2:
	var from := cam.project_ray_origin(at)
	var dir := cam.project_ray_normal(at)
	if absf(dir.y) < 1e-5:
		return Vector2.INF
	var lo := 0.0
	var hi := RAY
	# Under the ground or above it, at the far end: if the ray never gets under
	# the surface there is nothing here to name.
	var far := from + dir * hi
	if far.y > world.height_at(Vector2(far.x, far.z)):
		return Vector2.INF
	for i in REFINE:
		var midt := (lo + hi) * 0.5
		var p := from + dir * midt
		if p.y > world.height_at(Vector2(p.x, p.z)):
			lo = midt
		else:
			hi = midt
	var hit := from + dir * hi
	if hit.x < 0.0 or hit.z < 0.0 or hit.x >= float(world.size) or hit.z >= float(world.size):
		return Vector2.INF
	return Vector2(hit.x, hit.z)
