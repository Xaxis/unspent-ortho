extends Node3D
## Every model in the game on one lit plinth, under the game's own camera,
## lights and outline. The review surface for anything drawn:
##   tools/shot.sh shots/gallery.png --scene=gallery [--filter=pine] [--hour=21]
##
## Discovery is by convention so parallel work never edits a shared list: any
## script under res://src/models/ or res://src/systems/ (recursively) that defines
##   static func gallery() -> Array   # of {"name": String, "node": Node3D}
## contributes its items. Nodes that need the world material get it via
## `material` meta; see _material_for().
##
## THE GALLERY'S OWN OPTIONS, read straight off the command line because they are
## the review surface's and not the game's (boot_options.gd lists them beside
## --silhouette):
##
##   --wear=LAND,LAND  stand each model once per landscape and lay THAT LAND'S
##                     WEAR on it: the same hull rusted in the bog, bloomed on
##                     the salt, sooted in the Burning, iced on the snowfield,
##                     side by side under one sky. LANTERN law 1 is "wear
##                     accumulates by world position" and until this flag existed
##                     no model review had ever shown it — not in one state, in
##                     NONE, because `matter_wear()` returns zero while
##                     `sky_view.z <= 0` and the gallery never set it. So the law
##                     could not be shown or refuted by any frame anybody looked
##                     at. Names are `SkyWear.OF`'s: an unknown one is refused
##                     rather than quietly worn like the coast.
##   --filter=NAME     only items whose name contains NAME
##   --bearing=DEG     turn the camera DEG round the models. 0 is the play
##                     camera's own 45 degrees; 180 is the half of every model
##                     that this one fixed projection has never shown anybody.
##                     The sun does not turn with it, so a face brought round
##                     may be in shade: pass --hour as well.
##   --piece=N|list    one model: `list` prints its FOUND pieces numbered, each
##                     with its size, where it is, the bearing that shows it and
##                     the colour the palette gave it; N then aims the camera at
##                     piece N, filling the frame with it from that bearing, with
##                     --bearing or --zoom overriding either half. `all` or
##                     `all:N` takes the model's own timber and thatch in as well
##                     (a strike scored across a plate is MADE, not FOUND).
##                     Numbers are largest-first and hold for a model until its
##                     geometry changes, so say the number WITH the model.
##
## WHY --piece EXISTS. tests/render/test_found_drawn.gd rasterises every model at
## eight bearings and fails when a FOUND piece is drawn from none of them. It
## found 87 such pieces -- including every rust run in the game -- and once they
## were mended nothing in this repository could photograph one: they are 0.03 to
## 0.10 units wide on models up to eight units tall, so at any framing that held
## the whole model they were three screen pixels, and three of them were on faces
## this bearing turns away. A guarantee that a piece is drawn from SOME bearing,
## with no instrument that can show a person that bearing, is half a guarantee.
## So the aim is measured the same way the test measures: triangles joined at
## their corners are one piece, and a piece's bearing is the one that turns the
## most of its front faces to the camera. The test says a piece is not hidden;
## this says what it looks like.

## Screen pixels a grid cell must be wide before the names are worth drawing.
const TAG_PITCH := 58.0
## Bearings the aim tries, 15 degrees apart: fine enough to bring a flat face
## square to the camera, coarse enough to be a number worth saying out loud.
const AIM_STEPS := 24
## How much wider than the piece itself an aimed frame is. A rust run filling the
## frame edge to edge is a coloured rectangle; the question being asked is
## whether it reads as rust ON something, so the thing it is on has to be in the
## picture with it. --zoom overrides this when a tighter look is wanted.
const PIECE_AIR := 2.5
## Air round a frame fitted to whole models.
const FIT_AIR := 1.08
## Pieces printed by `--piece=list` before the list is cut off. A coast house is
## 58, which is the longest anybody has had to read down so far.
const PIECES_LISTED := 64
## Pieces smaller than this share of the largest are left out of the list: a
## model is mostly rivets and bolt heads, and none of them is what a review is
## looking for.
const PIECE_FLOOR := 0.004
const FOUND_SHADER := preload("res://src/render/found.gdshader")
## Frames the gallery sweeps for captions a model hung deferred. Three is two
## more than any of them takes, and after that the walk stops: two hundred
## models' subtrees, every frame, is the whole reason this was a per-frame job.
const CAPTION_SWEEPS := 3

var options: BootOptions
var _mat: ShaderMaterial
var _cam: CameraRig
## [{name, at: Vector3}] — where each item's label is hung in the world.
var _labels: Array[Dictionary] = []
var _tags: Control
var _sweeps := CAPTION_SWEEPS


func setup(o: BootOptions) -> void:
	options = o
	name = "gallery"
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/render/world.gdshader")
	var sky := SkyLight.new()
	add_child(sky)
	sky.set_hour(o.hour)

	var items: Array = []
	var paths := _find("res://src/models")
	paths.append_array(_find("res://src/systems"))
	for path in paths:
		var s: GDScript = load(path)
		if s == null:
			continue
		for m in s.get_script_method_list():
			if m.name == "gallery":
				items.append_array(s.call("gallery"))
				break
	var filter := ""
	var bearing := 0.0
	var turned := false
	var piece := ""
	var wear: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.trim_prefix("--filter=")
		elif a.begins_with("--bearing="):
			bearing = float(a.trim_prefix("--bearing="))
			turned = true
		elif a.begins_with("--piece="):
			piece = a.trim_prefix("--piece=")
		elif a.begins_with("--wear="):
			wear = a.trim_prefix("--wear=").split(",", false)
	var all_names := items
	if filter != "":
		# **THE FILTER AND THE NAMES HAVE TO AGREE ABOUT WHAT A NAME IS.** An item
		# is named "scrap tree 0" while everything a caller reads it from -- a
		# `PropKind`, a file, a `--put` token -- spells it `scrap_tree`, so the
		# obvious filter matched NOTHING and the run drew an empty plinth and said
		# ok. A shot of nothing that reports success is worse than an error,
		# because the next person compares two empty frames and concludes the
		# change did nothing.
		var want := filter.to_lower().replace("_", " ")
		items = items.filter(func(it: Dictionary) -> bool:
			return String(it.name).to_lower().replace("_", " ").contains(want))
		if items.is_empty():
			printerr("gallery --filter=%s matched no item of %d. Names carry spaces (\"scrap tree 0\"); underscores and case are folded, so this really is not here." % [filter, all_names.size()])
			get_tree().quit(1)
			return

	var spacing := 3.2
	var cols := maxi(1, ceili(sqrt(items.size() * 1.8)))
	if not wear.is_empty():
		for land in wear:
			if not SkyWear.OF.has(StringName(land)):
				push_error("--wear=%s: no such landscape in SkyWear.OF (%s)" % [land, ", ".join(SkyWear.OF.keys())])
				get_tree().quit(1)
				return
		# One COLUMN per landscape and one ROW per model, so a row reads as the
		# same thing in four places and a column as four things in one place.
		items = _per_wear(items, wear)
		cols = wear.size()
		_wear_swatch(sky, wear, spacing)
	var rows := ceili(float(items.size()) / cols)
	var plinth := MeshKit.new()
	plinth.box(Vector3(-1.5, -0.5, -1.5), Vector3(cols * spacing + 0.3, 0.0, rows * spacing + 0.3), Palette.STONE[2], Palette.MOSS[3])
	var ground := MeshInstance3D.new()
	ground.mesh = plinth.build()
	ground.material_override = _mat
	add_child(ground)
	var shown: Array[Node3D] = []
	for i in items.size():
		var it: Dictionary = items[i]
		var node: Node3D = it.node
		# Half a cell across WHEN THE WEAR BANDS ARE ON, so a model sits at the
		# centre of its own texel and not on the seam between two of them (see
		# `_wear_swatch`). Off, the grid is where it always was, so every frame
		# this instrument has already taken stays comparable with the next.
		var mid := 0.5 if not wear.is_empty() else 0.0
		node.position = Vector3(((i % cols) + mid) * spacing, 0.0, (i / cols) * spacing)
		_apply_material(node)
		add_child(node)
		shown.append(node)
		_labels.append({"name": String(it.name), "at": node.position + Vector3(0, -0.2, 1.1)})
	var cam := CameraRig.new()
	# The play camera's own bearing, so --bearing and the log both read as an
	# offset from the one view every other picture in this repository was taken at.
	var square := cam.yaw_deg
	cam.yaw_deg += bearing
	add_child(cam)
	_cam = cam
	# THE FRAME IS THE MODELS' OWN, not a box worked out from the grid. The old
	# one measured the plinth, so the top two units of an eight-unit tower were
	# outside every picture ever taken of it -- and the shot came back green,
	# because a frame that cuts a model off is a perfectly good PNG.
	var aimed := ""
	if piece != "" and not shown.is_empty():
		aimed = _aim(shown[0], String(items[0].name), piece, cam, bearing if turned else INF, o.zoom)
		if items.size() > 1:
			print("gallery --piece took \"%s\"; %d more matched --filter" % [items[0].name, items.size() - 1])
	if aimed == "":
		var box := _extent(shown)
		_frame(cam, box, FIT_AIR, o.zoom, Vector3(box.get_center().x, 0.0, box.get_center().z))
	# A name is only worth drawing where it does not cover the model beside it.
	# The whole gallery is a contact sheet of two hundred silhouettes at forty
	# pixels a cell; a review that needs the names uses --filter and gets them.
	# In the slate's units, because that is what the names are drawn in and what
	# TAG_PITCH counts. Off the raw viewport it would be three times larger and
	# every contact sheet would come back covered in names.
	var pitch := UiBase.to_design(cam.unproject_position(Vector3.ZERO)).distance_to(
		UiBase.to_design(cam.unproject_position(Vector3(spacing, 0.0, 0.0))))
	# An aimed frame is a close look at one piece, and a name drawn over it at
	# that magnification is a hoarding across the thing being judged. The log
	# says what the picture is of instead.
	var named := pitch >= TAG_PITCH and aimed == ""
	if named:
		_add_tags()
	print("gallery %d items, %s (cell %d px, %.1f units tall, bearing %d)%s" % [items.size(),
		"named" if named else "a contact sheet: --filter for names", roundi(pitch),
		cam.view_height, roundi(cam.yaw_deg - square), aimed])


## The names, drawn in the game's own pixel font on a scrap of the slate's
## glass, at whole pixels of the 640x360 base.
##
## They were Label3D with a 12 px outline around a 24 px face: the outline
## swallowed the fill and every name read as a near-black smear over the models
## it was naming — 1.11:1 against the plinth. This is the surface every model
## review happens on, so the labels have to be readable at native size.
func _add_tags() -> void:
	var layer := CanvasLayer.new()
	layer.name = "tags"
	layer.layer = 10
	UiBase.fit(layer)
	add_child(layer)
	_tags = Control.new()
	_tags.name = "canvas"
	_tags.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tags.theme = UiTheme.theme()
	_tags.draw.connect(_draw_tags)
	layer.add_child(_tags)


func _process(_delta: float) -> void:
	# The sweep for captions is not a per-frame job: a model's own script hangs
	# them deferred, so they are all there within a few frames of the first, and
	# walking two hundred models' whole subtree every frame is the gallery's own
	# budget spent on nothing.
	if _sweeps > 0:
		_sweeps -= 1
		_take_over_labels(self)
	if _tags != null:
		_tags.queue_redraw()


## A model's own script may hang Label3D captions on a row (machine_gallery's
## poses do, deferred, so they land after the first frame). They are the same
## dark smear over the plinth, so the gallery takes them over: the node is
## hidden and its text is drawn as a tag at the place it hung.
##
## On the contact sheet (`pitch < TAG_PITCH`, no `_tags` canvas) there is nothing
## to draw them on, so this hides them and they are gone: two hundred names at
## forty pixels a cell is a smear, and `--filter` is how a review gets them.
func _take_over_labels(n: Node) -> void:
	if n is Label3D and n.visible:
		var l := n as Label3D
		l.visible = false
		_labels.append({"name": l.text, "node": l})
		return
	for c in n.get_children():
		_take_over_labels(c)


func _draw_tags() -> void:
	if _cam == null:
		return
	# Near first, so the tag nearest the eye keeps its place and the ones behind
	# it step down out of its way — and a row's own caption is dropped when the
	# name above it already says the same word.
	var rows := _labels.duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _tag_at(a).z > _tag_at(b).z)
	var placed: Array[Dictionary] = []
	for l: Dictionary in rows:
		# A caption whose node has been freed has no place left: it is dropped,
		# never hung at the world's origin.
		if l.has("node") and not is_instance_valid(l.get("node")):
			continue
		var at := _tag_at(l)
		if _cam.is_position_behind(at):
			continue
		var p := UiBase.to_design(_cam.unproject_position(at))
		var text: String = l.name
		var w := UiFont.legacy_width(text)
		var box := Rect2i(roundi(p.x) - w / 2 - 3, roundi(p.y) - 5, w + 6, 11)
		var said := false
		for k in 5:
			var clash := {}
			for o: Dictionary in placed:
				if (o.box as Rect2i).intersects(box):
					clash = o
					break
			if clash.is_empty():
				break
			if String(clash.text).ends_with(text):
				said = true
				break
			box.position.y += 12
			said = k == 4
		if said:
			continue
		placed.append({"box": box, "text": text})
		UiDraw.rect(_tags, box, Color(UiTheme.GLASS, 0.82))
		UiDraw.frame(_tags, box, UiTheme.GHOST)
		UiDraw.text_legacy(_tags, Vector2i(box.position.x + 3, box.position.y), text, UiTheme.TEXT)


func _tag_at(l: Dictionary) -> Vector3:
	var n: Node3D = l.get("node")
	# A taken-over caption carries a node and no `at`: once it is freed there is
	# no place left to hang it, and asking for `at` was an error, not a fallback.
	return n.global_position if n != null and is_instance_valid(n) else (l.get("at", Vector3.ZERO) as Vector3)


# --- Framing ------------------------------------------------------------------

## Put the frame round `box`, at whatever bearing the camera is already at, with
## the camera standing its own `distance` back from `stand`.
##
## Orthographic, so the framing is exact: the eight corners projected onto the
## screen's own two axes give the rectangle the picture has to hold, and the
## camera's focus is the middle of it -- not the middle of the plinth, and not
## the ground.
##
## DEPTH IS A SEPARATE QUESTION, and getting it wrong is not a framing error but
## a LIGHTING one: the air is depth fog with a begin and an end, so a camera that
## simply backs off to see a tall model hazes everything it came to look at
## (measured: 2.7 units further back than the old gallery stood, and the plinth's
## far half went grey). So the frame moves in the screen plane only, and `stand`
## says what the camera keeps its distance from -- the GROUND the models stand on
## for a whole gallery, which is the depth the play camera keeps and so the only
## one at which a review frame is fogged the way the game fogs it, and the PIECE
## itself for an aim, where a ground six units below would put the subject inside
## the near blur (`CameraRig.near_plane`) and soften the one thing in the picture.
func _frame(cam: CameraRig, box: AABB, air: float, zoom: float, stand: Vector3) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(-cam.pitch_deg), deg_to_rad(cam.yaw_deg), 0.0))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var p := box.get_endpoint(i)
		var s := Vector2(p.dot(b.x), p.dot(b.y))
		lo = lo.min(s)
		hi = hi.max(s)
	# The base's aspect, never a spelled screen size: the frame a shot captures
	# is UiBase.SIZE whatever window a tool run opens off the side of the desk.
	var aspect := float(UiBase.SIZE.x) / float(UiBase.SIZE.y)
	cam.view_height = zoom if zoom > 0.0 else maxf(hi.y - lo.y, (hi.x - lo.x) / aspect) * air
	var mid := (lo + hi) * 0.5
	cam.snap_to(b * Vector3(mid.x, mid.y, stand.dot(b.z)))


## The extent of what is actually on the plinth. Every VisualInstance3D in every
## item, which is how the leaves get counted: a crown is as much of a tree's
## silhouette as its trunk, and anything measuring a model that reads only the
## MADE mesh frames half of it.
func _extent(nodes: Array[Node3D]) -> AABB:
	var pts := PackedVector3Array()
	for n in nodes:
		_corners(n, Transform3D.IDENTITY, pts)
	if pts.is_empty():
		return AABB(Vector3.ZERO, Vector3.ONE)
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return AABB(lo, hi - lo)


func _corners(n: Node, at: Transform3D, out: PackedVector3Array) -> void:
	var here := at * (n as Node3D).transform if n is Node3D else at
	if n is VisualInstance3D:
		var box := (n as VisualInstance3D).get_aabb()
		if box.size.length_squared() > 0.0:
			for i in 8:
				out.append(here * box.get_endpoint(i))
	for c in n.get_children():
		_corners(c, here, out)


# --- Aiming at one piece ------------------------------------------------------

## Fill the frame with one FOUND piece of `node`, from the bearing that turns the
## most of it toward the camera. Returns what it aimed at, for the log, or ""
## when it could not (which leaves the whole-model fit to do its job).
func _aim(node: Node3D, who: String, want: String, cam: CameraRig, bearing: float, zoom: float) -> String:
	# FOUND alone is the default because that is the half a missing piece hides
	# in and the half the visibility test holds: a model's own timber is one
	# vast connected piece that would head every list. `all` is for the rest of
	# it -- a strike scored across a plate is MADE, and so is a thatch.
	var whole := want.begins_with("all")
	want = want.trim_prefix("all").trim_prefix(":")
	var tris := PackedVector3Array()
	var tint := PackedColorArray()
	_tris(node, Transform3D.IDENTITY, true, tris, tint)
	var of := "FOUND"
	if whole or tris.is_empty():
		# Nothing of the machines in it: a thatched roof, a boulder, a person.
		# Its own geometry is then what there is to look at.
		_tris(node, Transform3D.IDENTITY, false, tris, tint)
		of = "whole" if whole else "MADE"
	if tris.is_empty():
		print("gallery --piece: \"%s\" has no geometry to aim at" % who)
		return ""
	var pieces := _pieces(tris, tint, cam.yaw_deg, cam.pitch_deg)
	if pieces.is_empty():
		return ""
	print("gallery %d %s pieces of \"%s\", largest first:" % [pieces.size(), of, who])
	for i in mini(pieces.size(), PIECES_LISTED):
		var p: Dictionary = pieces[i]
		var s: Vector3 = (p.box as AABB).size
		print("gallery   piece %-3d %5.2f x %5.2f x %5.2f  at %-22s bearing %4d  face %.3f  #%s"
			% [i, s.x, s.y, s.z, str((p.box as AABB).get_center().snappedf(0.01)), int(p.bearing), p.face,
			(p.tint as Color).to_html(false)])
	if pieces.size() > PIECES_LISTED:
		print("gallery   ... and %d smaller" % (pieces.size() - PIECES_LISTED))
	if not want.is_valid_int():
		return ""
	var n := want.to_int()
	if n < 0 or n >= pieces.size():
		print("gallery --piece=%d: \"%s\" has %d" % [n, who, pieces.size()])
		return ""
	var chosen: Dictionary = pieces[n]
	if is_inf(bearing):
		cam.yaw_deg = cam.yaw_deg + float(chosen.bearing)
	var at: AABB = (chosen.box as AABB)
	_frame(cam, at, PIECE_AIR, zoom, at.get_center())
	return ", aimed at piece %d of \"%s\" (%.2f x %.2f x %.2f)" % [n, who, at.size.x, at.size.y, at.size.z]


## Triangles joined at a shared corner are one piece, as the visibility test
## joins them (tests/render/test_found_drawn.gd), so a number printed here names
## the same thing that test holds to being drawn. Each piece carries the bearing
## that turns the most of its FRONT faces to the camera -- front as the shaders
## cull, since a face wound away is not there to be judged.
##
## Occlusion is deliberately NOT modelled: the test's job is to say whether a
## piece is buried, and this one's is to point the camera. If a piece turns out
## to be behind its own housing, the picture says so, which is the whole point.
func _pieces(tris: PackedVector3Array, tint: PackedColorArray, yaw: float, pitch: float) -> Array[Dictionary]:
	var of := _join(tris)
	var count := 0
	for pid in of:
		count = maxi(count, pid + 1)
	if count == 0:
		return []
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	# A piece's own colour, as the palette wrote it. This is what turns a thing a
	# reviewer can SEE into a number they can type: a coast house has 58 pieces
	# and no names, and "the blue plaque with the orange score" is findable in
	# that list by its #2b3a6b and by nothing else.
	var wash: Array[Color] = []
	var many := PackedInt32Array()
	many.resize(count)
	for i in count:
		lo.append(Vector3.INF)
		hi.append(-Vector3.INF)
		wash.append(Color(0, 0, 0, 0))
	var face := PackedFloat32Array()
	face.resize(count * AIM_STEPS)
	# The camera's own view axis at each bearing, at the play camera's pitch: a
	# piece is judged by what it turns toward the eye from where the eye can be,
	# never from straight on, because this projection has no straight on.
	var axes: Array[Vector3] = []
	for s in AIM_STEPS:
		axes.append(Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw + s * (360.0 / AIM_STEPS)), 0.0)).z)
	for t in range(0, tris.size() - 2, 3):
		var pid := of[t / 3]
		for j in 3:
			lo[pid] = lo[pid].min(tris[t + j])
			hi[pid] = hi[pid].max(tris[t + j])
			if t + j < tint.size():
				wash[pid] += tint[t + j]
				many[pid] += 1
		# Twice the signed area facing each bearing. MeshKit emits a, c, b for an
		# authored a, b, c, so this is the same winding test the raster uses.
		var n := (tris[t + 2] - tris[t]).cross(tris[t + 1] - tris[t])
		for s in AIM_STEPS:
			face[pid * AIM_STEPS + s] += maxf(0.0, n.dot(axes[s])) * 0.5
	var out: Array[Dictionary] = []
	for pid in count:
		var best := 0
		for s in AIM_STEPS:
			if face[pid * AIM_STEPS + s] > face[pid * AIM_STEPS + best]:
				best = s
		var n := maxf(many[pid], 1.0)
		out.append({"box": AABB(lo[pid], hi[pid] - lo[pid]), "bearing": best * (360.0 / AIM_STEPS),
			"face": face[pid * AIM_STEPS + best],
			"tint": Color(wash[pid].r / n, wash[pid].g / n, wash[pid].b / n)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.face) > float(b.face))
	var most: float = float(out[0].face)
	return out.filter(func(p: Dictionary) -> bool: return float(p.face) >= most * PIECE_FLOOR)


static func _join(verts: PackedVector3Array) -> PackedInt32Array:
	var n := verts.size() / 3
	var parent := PackedInt32Array()
	parent.resize(n)
	for i in n:
		parent[i] = i
	var first := {}
	for i in n:
		for j in 3:
			var q := verts[i * 3 + j].snappedf(0.0005)
			if first.has(q):
				_union(parent, i, first[q])
			else:
				first[q] = i
	var ids := {}
	var out := PackedInt32Array()
	out.resize(n)
	for i in n:
		var r := _root(parent, i)
		if not ids.has(r):
			ids[r] = ids.size()
		out[i] = ids[r]
	return out


static func _root(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _root(parent, a)
	var rb := _root(parent, b)
	if ra != rb:
		parent[maxi(ra, rb)] = mini(ra, rb)


## Every triangle of an item in the gallery's own space. `found` picks the halves
## drawn with found.gdshader -- which is what the machines' pieces are made of,
## and what the visibility test measures -- and leaves the timber and thatch out.
func _tris(n: Node, at: Transform3D, found: bool, out: PackedVector3Array, tint: PackedColorArray) -> void:
	var here := at * (n as Node3D).transform if n is Node3D else at
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		for s in mi.mesh.get_surface_count():
			if _is_found(mi, s) != found:
				continue
			var arrays := mi.mesh.surface_get_arrays(s)
			if arrays.is_empty():
				continue
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if index.is_empty():
				for i in v.size():
					out.append(here * v[i])
					tint.append(col[i] if i < col.size() else Color.WHITE)
			else:
				for i in index:
					out.append(here * v[i])
					tint.append(col[i] if i < col.size() else Color.WHITE)
	for c in n.get_children():
		_tris(c, here, found, out, tint)


func _is_found(mi: MeshInstance3D, surface: int) -> bool:
	var mat := mi.material_override
	if mat == null:
		mat = mi.get_surface_override_material(surface)
	if mat == null:
		mat = mi.mesh.surface_get_material(surface)
	return mat is ShaderMaterial and (mat as ShaderMaterial).shader == FOUND_SHADER


## Each item once per landscape, in the order the landscapes were named, so the
## grid comes out a row per model and a column per land.
static func _per_wear(items: Array, wear: PackedStringArray) -> Array:
	var out: Array = []
	for it: Dictionary in items:
		for i in wear.size():
			var node: Node3D = it.node if i == 0 else (it.node as Node3D).duplicate()
			out.append({"name": "%s %s" % [it.name, wear[i]], "node": node})
	return out


## Bind a wear texture the gallery's own grid samples, and the scale that makes
## it line up. Built HERE and not in `SkyWear`, which is under the frozen
## `src/render/` (CLAUDE.md): this reads that file's public table and nothing
## else, so the review surface can show the law without the law's own package
## being touched.
##
## The shaders sample `sky_wear` at `world.xz * sky_view.z`, so a column of the
## grid maps to a band of the image. Each landscape gets BLOCK texels rather than
## one: the sampler filters linearly, and a model two units wide centred in a
## 3.2-unit cell would otherwise blend a third of its neighbour's rust into its
## own bloom. At 32 texels a cell, a model of that width spans twenty of them,
## centred, and never reaches the seam.
##
## `sky_ground` is bound to zeroes at the same time. It is sampled WITHOUT the
## `sky_view.z` guard `matter_wear` has, so switching the scale on would
## otherwise start every snow, ash, wet and fog lookup reading whatever texture
## was last left in the global.
func _wear_swatch(sky: SkyLight, wear: PackedStringArray, spacing: float) -> void:
	const BLOCK := 32
	var n := wear.size()
	var w := n * BLOCK
	var wear_img := Image.create(w, 1, false, Image.FORMAT_RGBA8)
	var zero_img := Image.create(w, 1, false, Image.FORMAT_RGBA8)
	for i in w:
		wear_img.set_pixel(i, 0, SkyWear.of(StringName(wear[i / BLOCK])))
		zero_img.set_pixel(i, 0, Color(0, 0, 0, 0))
	sky.set_wear(ImageTexture.create_from_image(wear_img))
	# THROUGH SkyLight, never round it. It is the one writer of every sky_* global
	# (CLAUDE.md's sky row), and `tests/render/test_one_writer.gd` holds that —
	# it caught this file writing `sky_ground` directly, which is the rule doing
	# its job. The size handed over is overwritten a line down; only the texture
	# matters here.
	sky.set_ground(ImageTexture.create_from_image(zero_img), 1)
	# One cell of the grid is one landscape's block: u = x / (n * spacing).
	sky.ground_scale = 1.0 / (spacing * float(n))
	# AND WRITE THE GLOBALS AGAIN. `SkyLight.compose()` is what puts `ground_scale`
	# into `sky_view.z`, and it runs once from `set_hour` — which the gallery calls
	# before this, when the scale was still 0. Without this line the scale never
	# reaches the shader, `matter_wear` takes its `sky_view.z <= 0` exit, and the
	# frame comes out exactly as it did before the flag existed: no wear at all,
	# at any strength. Measured by forcing the swatch to (1,1,1,1) and seeing
	# nothing change.
	sky.compose()


func _apply_material(n: Node) -> void:
	if n is GeometryInstance3D and (n as GeometryInstance3D).material_override == null:
		(n as GeometryInstance3D).material_override = _mat
	for c in n.get_children():
		_apply_material(c)


func _find(root: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root.path_join(f))
	for d in dir.get_directories():
		out.append_array(_find(root.path_join(d)))
	return out
