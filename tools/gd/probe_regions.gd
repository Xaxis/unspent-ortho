extends SceneTree
## HOW BIG EACH LANDSCAPE'S PLACE IS, measured, per landscape and seed.
##
##   godot --headless --path . -s tools/gd/probe_regions.gd -- --seeds=1,42,90210 [--size=N]
##
## Written for the owner's "the immensity each region should present vs the
## current 'walk a few paces and youre in a different landscape'". Each number is
## a question a player's eyes or legs ask, not a property of the generator:
##
##   frames   the main region's tiles over one top-down play frame (26.7 x 17.9)
##   core_s   seconds at a run (5.4 tiles/s) across the widest disc of the main
##            region that is all its own landscape: the core, not the bounds
##   eco      how deep the ecotone reaches into this landscape from its border,
##            in tiles (tiles with any `blend` over the border tiles): the width
##            of a slow blend, never a line
##   own      from the shoulder (eye ~2 units up, the frame's floor PITCH + FOV/2
##            down) at the core, all the way round out to SkyLight.SEE: the share
##            of the LAND in view, weighted by the screen it takes, that is this
##            landscape. Near ground dominates it; read `mid` and `far`.
##   mid      the same past MID_BAND tiles: the land beyond your own surroundings
##   far      the same past FAR_BAND tiles: what reads on the horizon, the
##            owner's complaint
##   lands    how many landscapes hold at least 5% of that horizon band
##   poi      things worth walking to inside the main region: landmarks, sites,
##            villages, the depot, the keeper's lair
##   reach    share of the main region within POI_REACH tiles of one of them
##   gap_s    the longest run from anywhere in the main region to the nearest
##            one, in seconds: an empty walk
##   road     share of the main region's tiles a road crosses
##   read     how far off a landmark of the main region READS at eye level, in
##            tiles, median over its landmarks and 36 bearings: the farthest a
##            standing eye (EYE_STAND up) still sees its top over the land
##            between, and no farther than its height holds READ_DEG of the
##            frame (a shape, not a speck)
##
## THE REGION-SCALE FORM: what a world is laid out as at the scale of a
## continent and of a region, not of a walk.
##
##   ring     over the continents (`GenBodies.CONTINENT_SHARE` of the biggest):
##            rad_cv the spread of centre distance from the square's middle over
##            its mean, share_cv the same of their tiles. 0 and 0 is a ring of
##            equal bodies. `dice`: `GenBodies.dice` of the continents' centres,
##            the RMS offset from a quincunx on the square (0 is dice-five)
##   lochs    per continent, inlets whose head lies LOCH_DEPTH or more tiles up
##            narrow water from open sea (sea LOCH_OPEN from land): how many,
##            the deepest in tiles, and that depth over the body's equivalent
##            radius sqrt(tiles / pi) (`reach`)
##   hole     the widest disc of open water (a diameter, in tiles) that lies
##            inside the hull of the continents' centres (in brackets, the same
##            without keeping inside the hull), and `straits` each continent's gap to
##            its nearest neighbour: a hole much wider than the widest strait
##            is a ring round an empty sea
##   rivers   per continent: how many, and per 10k of its tiles (a river is on
##            the body its mouth is on)
##   macro    per main region: the spread (m) of height smoothed over a box of
##            2 MACRO_R + 1 blocks of MACRO_BLOCK tiles (about 200 tiles);
##            `fine` the spread of what that smoothing removes. Relief with a
##            backbone has macro; a repeated swell has only fine
##   trunk    per main region: the share of its tiles within TRUNK_REACH of a
##            laid road (any road: no trunk is laid yet)
##   seams    per world: road crossings of a landscape border (joined within
##            SEAM_REACH), and how many have a place within SEAM_REACH
##   mottle   per main region: `run` the mean run, in tiles along a row of
##            MOTTLE_BLOCK blocks, of one dominant ground; `ent` the mean and
##            `ent_sd` the spread of ground entropy (bits) over MOTTLE_WINDOW
##            windows. A short run with a flat entropy is camouflage; long runs
##            and a spread entropy are structure
##
## Headless, deterministic, no rendering: a world grown by BootWorld and read.

const FRAME_TILES := 26.7 * 17.9
const RUN := 5.4
const FAR_BAND := 250.0
const POI_REACH := 40.0
const SEE := 900.0
const EYE_UP := 1.98
const PITCH := 10.0
const FOV := 60.0
const ASPECT := 16.0 / 9.0
const AZIMUTHS := 720
const EYE_STAND := 1.7
## The least angle a landmark has to stand to read as a shape: 12 pixels of the
## 1080 a 60-degree frame is drawn in.
const READ_DEG := 0.67
const MID_BAND := 30.0
const LOCH_OPEN := 12.0
const LOCH_DEPTH := 40.0
const MACRO_BLOCK := 8
const MACRO_R := 12
const TRUNK_REACH := 12
const SEAM_REACH := 10.0
const MOTTLE_BLOCK := 16
const MOTTLE_WINDOW := 64
const SEA_STEP := 4

var _road := 0
## A directory to write one landscape map per seed into (`regions_<seed>.png`).
var _map := ""


func _init() -> void:
	var seeds: Array[int] = [1, 42, 90210]
	var size := Tuning.WORLD_SIZE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds.clear()
			for s in a.trim_prefix("--seeds=").split(","):
				seeds.append(s.to_int())
		elif a.begins_with("--map="):
			_map = a.trim_prefix("--map=")
		elif a.begins_with("--size="):
			size = a.trim_prefix("--size=").to_int()
	GearEconomy.declare(true)
	print("regions size %d seeds %s GEN %d" % [size, seeds, WorldStamp.GEN])
	print("regions %-18s %6s %4s %6s %6s %5s %5s %5s %4s %4s %5s %6s %5s %6s %5s %5s" % [
		"land", "seed", "runs", "tiles", "frames", "core_s", "eco", "own", "mid", "far", "lands", "poi", "reach", "gap_s", "road", "read"])
	for s in seeds:
		var t0 := Time.get_ticks_msec()
		var w := BootWorld.world(s, size)
		print("regions grew seed %d in %d ms, %d continents, %d regions" % [s, Time.get_ticks_msec() - t0, w.continents.size(), w.regions.size()])
		_seed(w)
		if _map != "":
			_draw(w)
	quit()


## Every landscape in its own colour, the blend shaded toward black, each
## region's edge drawn dark: the patchwork (or the lack of it) at a glance.
func _draw(w: WorldData) -> void:
	var n := w.size
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var sea := Color(0.06, 0.1, 0.18)
	for y in n:
		for x in n:
			var i := y * n + x
			if w.level[i] <= 0:
				img.set_pixel(x, y, sea)
				continue
			var c := int(w.country[i])
			var col := Color.from_hsv(fposmod(float(c) * 0.618034, 1.0), 0.55, 0.85)
			col = col.lerp(Color.BLACK, w.blend[i] * 0.6)
			if x > 0 and y > 0 and (w.region[i] != w.region[i - 1] or w.region[i] != w.region[i - n]):
				col = Color(0.05, 0.05, 0.05)
			img.set_pixel(x, y, col)
	var path := _map.path_join("regions_%d.png" % w.seed_value)
	var abs_path := path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	img.save_png(abs_path)
	print("regions map ", abs_path)


func _seed(w: WorldData) -> void:
	for row: Dictionary in w.continents:
		if not row.has("types"):
			continue
		var names: PackedStringArray = []
		for cc: int in (row.types as PackedInt32Array):
			names.append(str(BiomeRegistry.by_index(cc).id))
		var home := " home" if w.continent_at(floori(w.spawn.x), floori(w.spawn.y)) == int(row.id) else ""
		print("regions body %d%s at %s: %s" % [int(row.id), home, (row.centre as Vector2).round(), ", ".join(names)])
	var lm := Landmarks.sites(w)
	var ws := Works.sites(w)
	var ks := Sentinels.states(w)
	var sites := 0
	for m: Dictionary in w.landmarks:
		if bool(m.get("site", false)):
			sites += 1
	var missing: PackedStringArray = []
	var held := {}
	for i in w.country.size():
		if w.level[i] > 0:
			held[int(w.country[i])] = true
	for d: BiomeDef in BiomeRegistry.land_in(w.realm):
		if not held.has(d.index):
			missing.append(str(d.id))
	print("regions world %d: %d regions (chapters, asks), %d keepers, %d depots, %d landmarks, %d sites, %d villages, missing [%s]" % [
		w.seed_value, w.regions.size(), ks.size(), ws.size(), lm.size(), sites, w.villages.size(), ", ".join(missing)])
	var mains: Array[Dictionary] = []
	for d: BiomeDef in BiomeRegistry.land_in(w.realm):
		var main := {}
		var runs := 0
		for r: Dictionary in w.regions:
			if StringName(str(r.get("type", &""))) != d.id:
				continue
			runs += 1
			if main.is_empty() or int(r.tiles) > int(main.tiles):
				main = r
		if main.is_empty():
			print("regions %-18s %6d %4d  NO REGION" % [d.id, w.seed_value, 0])
			continue
		var id := int(main.id)
		mains.append({"land": d.id, "id": id})
		var bounds: Rect2 = main.bounds
		var core := _core(w, id, bounds)
		var eco := _ecotone(w, d.index)
		var view := _view(w, d.index, Vector2(core.x, core.y))
		var poi: Array[Vector2] = []
		var reads: Array[float] = []
		for s: LandmarkSite in lm:
			if s.region == id:
				poi.append(s.pos)
				reads.append(_reads(w, s))
		reads.sort()
		var read := reads[reads.size() / 2] if not reads.is_empty() else 0.0
		for m: Dictionary in w.landmarks:
			var p: Vector2 = m.get("pos", Vector2.ZERO)
			if bool(m.get("site", false)) and w.region_at(floori(p.x), floori(p.y)) == id:
				poi.append(p)
		for v: Dictionary in w.villages:
			var p: Vector2 = v.pos
			if w.region_at(floori(p.x), floori(p.y)) == id:
				poi.append(p)
		for s: WorksSite in ws:
			if s.region == id:
				poi.append(s.pos)
		for s: SentinelState in ks:
			if s.region == id:
				poi.append(s.lair)
		_road = 0
		var walk := _walk(w, id, bounds, poi)
		print("regions %-18s %6d %4d %6d %6.1f %5.0f %5.1f %5.2f %4.2f %4.2f %5d %6d %5.2f %6.0f %5.3f %5.0f" % [
			d.id, w.seed_value, runs, int(main.tiles), float(main.tiles) / FRAME_TILES,
			2.0 * core.z / RUN, eco, view.x, view.y, view.z, int(view.w), poi.size(), walk.x, walk.y / RUN, float(_road) / maxf(1.0, float(main.tiles)), read])
	_bodies(w)
	_sea(w)
	for m: Dictionary in w.landmarks:
		if StringName(str(m.get("kind", &""))) == &"tread":
			var tp: Vector2 = m.get("pos", Vector2.ZERO)
			print("regions tread %d at %s on body %d, %s" % [w.seed_value, tp.round(), w.continent_at(floori(tp.x), floori(tp.y)), BiomeRegistry.name_of(int(m.get("country", 0)))])
	var places: Array[Vector2] = []
	for s: LandmarkSite in lm:
		places.append(s.pos)
	for m: Dictionary in w.landmarks:
		places.append(m.get("pos", Vector2.ZERO) as Vector2)
	for v: Dictionary in w.villages:
		places.append(v.pos as Vector2)
	for s: WorksSite in ws:
		places.append(s.pos)
	_seams(w, places)
	_form(w, mains)


## The widest disc of the main region: x, y its centre, z its radius in tiles.
## A two-pass chamfer distance to the nearest tile NOT in the region (sea and
## other landscapes alike), inside the region's bounds grown by one.
func _core(w: WorldData, id: int, b: Rect2) -> Vector3:
	var x0 := maxi(0, int(b.position.x) - 1)
	var y0 := maxi(0, int(b.position.y) - 1)
	var x1 := mini(w.size, int(b.end.x) + 2)
	var y1 := mini(w.size, int(b.end.y) + 2)
	var bw := x1 - x0
	var bh := y1 - y0
	var d := PackedFloat32Array()
	d.resize(bw * bh)
	for y in bh:
		for x in bw:
			d[y * bw + x] = 1e9 if w.region[(y + y0) * w.size + x + x0] - 1 == id else 0.0
	const A := 1.0
	const B := 1.41421
	for y in bh:
		for x in bw:
			var i := y * bw + x
			if d[i] == 0.0:
				continue
			var v := d[i]
			if x > 0: v = minf(v, d[i - 1] + A)
			else: v = minf(v, A)
			if y > 0:
				v = minf(v, d[i - bw] + A)
				if x > 0: v = minf(v, d[i - bw - 1] + B)
				if x < bw - 1: v = minf(v, d[i - bw + 1] + B)
			else: v = minf(v, A)
			d[i] = v
	var best := Vector3(0, 0, 0)
	for y in range(bh - 1, -1, -1):
		for x in range(bw - 1, -1, -1):
			var i := y * bw + x
			if d[i] == 0.0:
				continue
			var v := d[i]
			if x < bw - 1: v = minf(v, d[i + 1] + A)
			else: v = minf(v, A)
			if y < bh - 1:
				v = minf(v, d[i + bw] + A)
				if x < bw - 1: v = minf(v, d[i + bw + 1] + B)
				if x > 0: v = minf(v, d[i + bw - 1] + B)
			else: v = minf(v, A)
			d[i] = v
			if v > best.z:
				best = Vector3(x + x0 + 0.5, y + y0 + 0.5, v)
	return best


## How deep a landscape's ecotone reaches in from its borders, in tiles: its land
## tiles with any blend toward a neighbour, over its land tiles on a border.
func _ecotone(w: WorldData, cc: int) -> float:
	var border := 0
	var band := 0
	var n := w.size
	for y in range(1, n - 1):
		for x in range(1, n - 1):
			var i := y * n + x
			if w.country[i] != cc or w.level[i] <= 0:
				continue
			if w.blend[i] > 0.01:
				band += 1
			for j: int in [i - 1, i + 1, i - n, i + n]:
				if w.level[j] > 0 and w.country[j] != cc:
					border += 1
					break
	return float(band) / maxf(1.0, float(border))


## What the eye sees from the core, all the way round: a viewshed per bearing
## (AZIMUTHS of them), each visible tile weighted by the angle it adds above what
## is already hidden behind -- the share of the SCREEN it takes -- from the bottom
## of the shoulder's frame (PITCH + FOV/2 down) out to SEE. Returns x the share of
## land in view that is `cc`, y the same past MID_BAND tiles (the land beyond the
## player's own surroundings), z the same past FAR_BAND (the horizon), w how many
## landscapes hold 5% of that horizon.
func _view(w: WorldData, cc: int, at: Vector2) -> Vector4:
	var n := w.size
	var eye_h := float(w.level_at(floori(at.x), floori(at.y))) * WorldData.STEP + EYE_UP
	var floor_ang := -deg_to_rad(PITCH + FOV * 0.5)
	var sums := PackedFloat32Array()
	sums.resize(6)
	var far_by := {}
	for a in AZIMUTHS:
		var yaw := TAU * float(a) / AZIMUTHS
		var dx := cos(yaw)
		var dy := sin(yaw)
		var top := floor_ang
		var t := 1.0
		while t < SEE:
			var ix := floori(at.x + dx * t)
			var iy := floori(at.y + dy * t)
			if ix < 0 or iy < 0 or ix >= n or iy >= n:
				break
			var i := iy * n + ix
			var lv := w.level[i]
			var gh := maxf(float(lv) * WorldData.STEP, Swim.WATER_Y)
			var ang := atan2(gh - eye_h, t)
			if ang > top:
				var wgt := ang - top
				top = ang
				if lv > 0:
					var mine := int(w.country[i]) == cc
					sums[0] += wgt
					if mine: sums[1] += wgt
					if t > MID_BAND:
						sums[2] += wgt
						if mine: sums[3] += wgt
					if t > FAR_BAND:
						sums[4] += wgt
						if mine: sums[5] += wgt
						far_by[int(w.country[i])] = float(far_by.get(int(w.country[i]), 0.0)) + wgt
			t += maxf(0.5, t * 0.01)
	var lands := 0
	for c: int in far_by:
		if float(far_by[c]) >= 0.05 * sums[4]:
			lands += 1
	return Vector4(sums[1] / maxf(1e-6, sums[0]), sums[3] / maxf(1e-6, sums[2]),
		sums[5] / maxf(1e-6, sums[4]), lands)


## How far off one landmark reads, in tiles: see the header's `read`.
func _reads(w: WorldData, s: LandmarkSite) -> float:
	var high := LandmarkModels.high_of(s.kind)
	var top := float(w.level_at(floori(s.pos.x), floori(s.pos.y))) * WorldData.STEP + high
	var most := minf(SEE, high / tan(deg_to_rad(READ_DEG)))
	var n := w.size
	var got: Array[float] = []
	for b in 36:
		var a := TAU * float(b) / 36.0
		var dx := cos(a)
		var dy := sin(a)
		var worst := -INF
		var seen := 0.0
		var t := 1.0
		while t < most:
			var ix := floori(s.pos.x + dx * t)
			var iy := floori(s.pos.y + dy * t)
			if ix < 0 or iy < 0 or ix >= n or iy >= n:
				break
			var gh := maxf(float(w.level[iy * n + ix]) * WorldData.STEP, Swim.WATER_Y)
			# The eye standing here sees the top if the line down to it clears
			# everything nearer the landmark.
			if (gh + EYE_STAND - top) / t >= worst:
				seen = t
			worst = maxf(worst, (gh - top) / t)
			t += maxf(1.0, t * 0.02)
		got.append(seen)
	got.sort()
	return got[got.size() / 2]


## Over the main region: x the share of its tiles within POI_REACH of a point
## worth walking to, y the longest distance any tile is from one (a BFS through
## the region's own tiles, so a point across a bay is not "near").
func _walk(w: WorldData, id: int, b: Rect2, poi: Array[Vector2]) -> Vector2:
	var x0 := maxi(0, int(b.position.x))
	var y0 := maxi(0, int(b.position.y))
	var x1 := mini(w.size, int(b.end.x) + 1)
	var y1 := mini(w.size, int(b.end.y) + 1)
	var bw := x1 - x0
	var bh := y1 - y0
	var dist := PackedInt32Array()
	dist.resize(bw * bh)
	dist.fill(-1)
	var q := PackedInt32Array()
	var total := 0
	for y in bh:
		for x in bw:
			var ti := (y + y0) * w.size + x + x0
			if w.region[ti] - 1 == id:
				total += 1
				if not w.road.is_empty() and w.road[ti] != 0:
					_road += 1
	for p in poi:
		var ix := floori(p.x) - x0
		var iy := floori(p.y) - y0
		if ix < 0 or iy < 0 or ix >= bw or iy >= bh:
			continue
		var k := iy * bw + ix
		if dist[k] < 0:
			dist[k] = 0
			q.append(k)
	if q.is_empty():
		return Vector2(0.0, INF)
	var head := 0
	var near := 0
	var worst := 0
	while head < q.size():
		var k := q[head]
		head += 1
		var dk := dist[k]
		var x := k % bw
		var y := k / bw
		if w.region[(y + y0) * w.size + x + x0] - 1 == id:
			worst = maxi(worst, dk)
			if dk <= POI_REACH:
				near += 1
		for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + dd.x
			var ny := y + dd.y
			if nx < 0 or ny < 0 or nx >= bw or ny >= bh:
				continue
			var j := ny * bw + nx
			if dist[j] >= 0:
				continue
			if w.region[(ny + y0) * w.size + nx + x0] - 1 != id:
				continue
			dist[j] = dk + 1
			q.append(j)
	return Vector2(float(near) / maxf(1.0, float(total)), float(worst))



static func _cv(v: Array[float]) -> float:
	if v.is_empty():
		return 0.0
	return _sd(v) / maxf(1e-6, _mean(v))


static func _mean(v: Array[float]) -> float:
	var m := 0.0
	for x in v:
		m += x
	return m / maxf(1.0, float(v.size()))


static func _sd(v: Array[float]) -> float:
	if v.is_empty():
		return 0.0
	var m := _mean(v)
	var q := 0.0
	for x in v:
		q += (x - m) * (x - m)
	return sqrt(q / v.size())


## ring, lochs and rivers, per continent: see the header.
func _bodies(w: WorldData) -> void:
	var n := w.size
	var most := 0
	for row: Dictionary in w.continents:
		most = maxi(most, int(row.tiles))
	var big: Array[Dictionary] = []
	for row: Dictionary in w.continents:
		if float(row.tiles) >= GenBodies.CONTINENT_SHARE * float(most):
			big.append(row)
	var rad: Array[float] = []
	var tiles: Array[float] = []
	var mid := Vector2(n, n) * 0.5
	var rad_s: PackedStringArray = []
	var til_s: PackedStringArray = []
	for row: Dictionary in big:
		rad.append((row.centre as Vector2).distance_to(mid) / n)
		tiles.append(float(row.tiles))
		rad_s.append("%.3f" % rad[-1])
		til_s.append("%dk" % roundi(float(row.tiles) / 1000.0))
	var centres := PackedVector2Array()
	for row: Dictionary in big:
		centres.append((row.centre as Vector2) / float(n))
	print("regions ring %d: %d continents  rad_cv %.3f  share_cv %.3f  dice %.3f  rad [%s]  tiles [%s]" % [
		w.seed_value, big.size(), _cv(rad), _cv(tiles), GenBodies.dice(centres), " ".join(rad_s), " ".join(til_s)])
	# Lochs, on a grid of every second tile: a loch is at least six tiles wide.
	const ST := 2
	var cw := n / ST
	var sea := PackedByteArray()
	sea.resize(cw * cw)
	var land := PackedByteArray()
	land.resize(cw * cw)
	for cy in cw:
		for cx in cw:
			var i := cy * ST * n + cx * ST
			var g := int(w.ground[i])
			if w.level[i] <= 0 and g != Ground.RIVER and g != Ground.BLACKWATER:
				sea[cy * cw + cx] = 1
			elif w.level[i] > 0:
				land[cy * cw + cx] = 1
	var dl := GenFields.distance8(land, cw, 1e6)
	var dist := PackedInt32Array()
	dist.resize(cw * cw)
	dist.fill(-1)
	var q := PackedInt32Array()
	for i in cw * cw:
		if sea[i] != 0 and dl[i] * ST > LOCH_OPEN:
			dist[i] = 0
			q.append(i)
	var head := 0
	while head < q.size():
		var i := q[head]
		head += 1
		var x := i % cw
		var y := i / cw
		for d: Vector2i in GenBodies.NEIGHBOURS:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= cw or ny >= cw:
				continue
			var j := ny * cw + nx
			if sea[j] == 0 or dist[j] >= 0:
				continue
			dist[j] = dist[i] + 1
			q.append(j)
	var inlet := PackedByteArray()
	inlet.resize(cw * cw)
	for i in cw * cw:
		if dist[i] >= 0 and float(dist[i] * ST) >= LOCH_DEPTH:
			inlet[i] = 1
	var sizes := PackedInt32Array()
	var label := GenFields.components(inlet, cw, sizes)
	var deepest := {}
	for i in cw * cw:
		var lab := label[i]
		if lab < 0:
			continue
		if not deepest.has(lab) or dist[i] > dist[int(deepest[lab])]:
			deepest[lab] = i
	var lochs := {}
	for lab: int in deepest:
		var i: int = deepest[lab]
		var body := _body_near(w, land, cw, ST, i % cw, i / cw)
		if body == 0:
			continue
		var got: Array = lochs.get(body, [])
		got.append(float(dist[i] * ST))
		lochs[body] = got
	var rivers := {}
	for r: PackedVector2Array in w.rivers:
		if r.is_empty():
			continue
		var m := r[r.size() - 1]
		var b := w.continent_at(floori(m.x), floori(m.y))
		if b == 0:
			m = r[0]
			b = w.continent_at(floori(m.x), floori(m.y))
		rivers[b] = int(rivers.get(b, 0)) + 1
	print("regions %-6s %6s %4s %7s %5s %6s %5s %6s %6s" % ["body", "seed", "id", "tiles", "lochs", "deep", "reach", "rivers", "per10k"])
	for row: Dictionary in big:
		var id := int(row.id)
		var ds: Array = lochs.get(id, [])
		var deep := 0.0
		for v: float in ds:
			deep = maxf(deep, v)
		var eq_r := sqrt(float(row.tiles) / PI)
		var rv := int(rivers.get(id, 0))
		print("regions %-6s %6d %4d %7d %5d %6.0f %5.2f %6d %6.2f" % ["body", w.seed_value, id, int(row.tiles), ds.size(), deep, deep / eq_r, rv, float(rv) * 10000.0 / float(row.tiles)])


## The body whose land stands nearest a coarse cell, within 12 cells, or 0.
static func _body_near(w: WorldData, land: PackedByteArray, cw: int, st: int, x: int, y: int) -> int:
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var nx := x + dx
				var ny := y + dy
				if nx >= 0 and ny >= 0 and nx < cw and ny < cw and land[ny * cw + nx] != 0:
					return w.continent_at(nx * st, ny * st)
	return 0


## seams: see the header.
func _seams(w: WorldData, places: Array[Vector2]) -> void:
	var n := w.size
	if w.road.is_empty():
		return
	var at: Array[Vector2] = []
	for y in range(1, n - 1):
		for x in range(1, n - 1):
			var i := y * n + x
			if w.road[i] == 0 or w.level[i] <= 0:
				continue
			for j: int in [i + 1, i + n]:
				if w.road[j] != 0 and w.level[j] > 0 and w.country[j] != w.country[i]:
					var p := Vector2(x + 0.5, y + 0.5)
					var dup := false
					for a in at:
						if a.distance_to(p) <= SEAM_REACH:
							dup = true
							break
					if not dup:
						at.append(p)
					break
	var placed := 0
	for p in at:
		for s in places:
			if s.distance_to(p) <= SEAM_REACH:
				placed += 1
				break
	print("regions seams %d: %d road crossings of a border, %d with a place within %d tiles (%.2f)" % [
		w.seed_value, at.size(), placed, int(SEAM_REACH), float(placed) / maxf(1.0, float(at.size()))])


## macro, trunk and mottle per main region: see the header.
func _form(w: WorldData, mains: Array[Dictionary]) -> void:
	var n := w.size
	# Height in blocks, sea at 0.
	var bw := ceili(float(n) / MACRO_BLOCK)
	var hsum := PackedFloat32Array()
	hsum.resize(bw * bw)
	var hcnt := PackedInt32Array()
	hcnt.resize(bw * bw)
	for y in n:
		var brow := (y / MACRO_BLOCK) * bw
		for x in n:
			var b := brow + x / MACRO_BLOCK
			hsum[b] += maxf(0.0, float(w.level[y * n + x])) * WorldData.STEP
			hcnt[b] += 1
	var raw := PackedFloat32Array()
	raw.resize(bw * bw)
	for b in bw * bw:
		raw[b] = hsum[b] / maxf(1.0, float(hcnt[b]))
	var smooth := _box(_box(raw, bw, MACRO_R, true), bw, MACRO_R, false)
	var near := GenFields.near_steps(w.road, n, TRUNK_REACH) if not w.road.is_empty() else PackedByteArray()
	# Mottle blocks and windows: the owner is the region at the centre, kept
	# where it holds half the block.
	var mb := ceili(float(n) / MOTTLE_BLOCK)
	var mw := ceili(float(n) / MOTTLE_WINDOW)
	var own_b := PackedInt32Array()
	own_b.resize(mb * mb)
	var own_w := PackedInt32Array()
	own_w.resize(mw * mw)
	for by in mb:
		for bx in mb:
			own_b[by * mb + bx] = w.region[mini(n - 1, by * MOTTLE_BLOCK + MOTTLE_BLOCK / 2) * n + mini(n - 1, bx * MOTTLE_BLOCK + MOTTLE_BLOCK / 2)]
	for by in mw:
		for bx in mw:
			own_w[by * mw + bx] = w.region[mini(n - 1, by * MOTTLE_WINDOW + MOTTLE_WINDOW / 2) * n + mini(n - 1, bx * MOTTLE_WINDOW + MOTTLE_WINDOW / 2)]
	const G := 64
	var hist_b := PackedInt32Array()
	hist_b.resize(mb * mb * G)
	var cnt_b := PackedInt32Array()
	cnt_b.resize(mb * mb)
	var hist_w := PackedInt32Array()
	hist_w.resize(mw * mw * G)
	var cnt_w := PackedInt32Array()
	cnt_w.resize(mw * mw)
	var tiles := {}
	var trunk := {}
	for y in n:
		for x in n:
			var i := y * n + x
			var r := w.region[i]
			if r <= 0:
				continue
			tiles[r] = int(tiles.get(r, 0)) + 1
			if not near.is_empty() and near[i] <= TRUNK_REACH:
				trunk[r] = int(trunk.get(r, 0)) + 1
			var g := int(w.ground[i]) & (G - 1)
			var b := (y / MOTTLE_BLOCK) * mb + x / MOTTLE_BLOCK
			if own_b[b] == r:
				hist_b[b * G + g] += 1
				cnt_b[b] += 1
			var k := (y / MOTTLE_WINDOW) * mw + x / MOTTLE_WINDOW
			if own_w[k] == r:
				hist_w[k * G + g] += 1
				cnt_w[k] += 1
	var dom := PackedInt32Array()
	dom.resize(mb * mb)
	for b in mb * mb:
		dom[b] = -1
		if cnt_b[b] * 2 < MOTTLE_BLOCK * MOTTLE_BLOCK:
			continue
		var best := 0
		for g in G:
			if hist_b[b * G + g] > hist_b[b * G + best]:
				best = g
		dom[b] = best
	print("regions %-24s %6s %6s %6s %5s %5s %5s %6s" % ["form", "seed", "macro", "fine", "trunk", "run", "ent", "ent_sd"])
	for m: Dictionary in mains:
		var r := int(m.id) + 1
		var sm: Array[float] = []
		var fi: Array[float] = []
		for by in bw:
			for bx in bw:
				var cy := mini(n - 1, by * MACRO_BLOCK + MACRO_BLOCK / 2)
				var cx := mini(n - 1, bx * MACRO_BLOCK + MACRO_BLOCK / 2)
				if w.region[cy * n + cx] != r:
					continue
				sm.append(smooth[by * bw + bx])
				fi.append(raw[by * bw + bx] - smooth[by * bw + bx])
		var runs := 0
		var run_blocks := 0
		for by in mb:
			var cur := -2
			for bx in mb:
				var b := by * mb + bx
				var d := dom[b] if own_b[b] == r else -1
				if d < 0:
					cur = -2
					continue
				run_blocks += 1
				if d != cur:
					runs += 1
					cur = d
		var ents: Array[float] = []
		for k in mw * mw:
			if own_w[k] != r or cnt_w[k] * 2 < MOTTLE_WINDOW * MOTTLE_WINDOW:
				continue
			var e := 0.0
			for g in G:
				var c := hist_w[k * G + g]
				if c > 0:
					var p := float(c) / float(cnt_w[k])
					e -= p * log(p) / log(2.0)
			ents.append(e)
		print("regions %-24s %6d %6.2f %6.2f %5.2f %5.0f %5.2f %6.2f" % [
			"form " + str(m.land), w.seed_value, _sd(sm), _sd(fi),
			float(trunk.get(r, 0)) / maxf(1.0, float(tiles.get(r, 0))),
			float(run_blocks) / maxf(1.0, float(runs)) * MOTTLE_BLOCK, _mean(ents), _sd(ents)])


## A box mean of radius `r` along rows (`along_x`) or columns, edges clamped.
static func _box(v: PackedFloat32Array, bw: int, r: int, along_x: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(v.size())
	for a in bw:
		for b in bw:
			var s := 0.0
			for k in range(-r, r + 1):
				var c := clampi(b + k, 0, bw - 1)
				s += v[a * bw + c] if along_x else v[c * bw + a]
			if along_x:
				out[a * bw + b] = s / float(2 * r + 1)
			else:
				out[b * bw + a] = s / float(2 * r + 1)
	return out


## hole and straits: see the header. On a grid of every SEA_STEP-th tile.
func _sea(w: WorldData) -> void:
	var n := w.size
	var most := 0
	for row: Dictionary in w.continents:
		most = maxi(most, int(row.tiles))
	var big := {}
	var centres := PackedVector2Array()
	for row: Dictionary in w.continents:
		if float(row.tiles) >= GenBodies.CONTINENT_SHARE * float(most):
			big[int(row.id)] = true
			centres.append((row.centre as Vector2) / SEA_STEP)
	var cw := n / SEA_STEP
	var any := PackedFloat32Array()
	any.resize(cw * cw)
	var d := PackedFloat32Array()
	d.resize(cw * cw)
	var lab := PackedInt32Array()
	lab.resize(cw * cw)
	for cy in cw:
		for cx in cw:
			var i := cy * cw + cx
			var x := cx * SEA_STEP
			var y := cy * SEA_STEP
			var land := w.level[y * n + x] > 0
			any[i] = 0.0 if land else 1e9
			var b := w.continent_at(x, y) if land else 0
			d[i] = 0.0 if big.has(b) else 1e9
			lab[i] = b if big.has(b) else 0
	GenFields.propagate_min(any, cw, 1.0)
	# Nearest continent through two chamfer sweeps, carrying its id.
	const R2 := 1.41421
	for sweep in 2:
		var ys := range(cw) if sweep == 0 else range(cw - 1, -1, -1)
		var xs := range(cw) if sweep == 0 else range(cw - 1, -1, -1)
		var sgn := -1 if sweep == 0 else 1
		for cy: int in ys:
			for cx: int in xs:
				var i := cy * cw + cx
				for o: Vector3 in [Vector3(sgn, 0, 1.0), Vector3(0, sgn, 1.0), Vector3(sgn, sgn, R2), Vector3(-sgn, sgn, R2)]:
					var nx := cx + int(o.x)
					var ny := cy + int(o.y)
					if nx < 0 or ny < 0 or nx >= cw or ny >= cw:
						continue
					var j := ny * cw + nx
					if d[j] + o.z < d[i]:
						d[i] = d[j] + o.z
						lab[i] = lab[j]
	var pair := {}
	for cy in cw - 1:
		for cx in cw - 1:
			var i := cy * cw + cx
			for j: int in [i + 1, i + cw]:
				if lab[i] > 0 and lab[j] > 0 and lab[i] != lab[j]:
					var key := mini(lab[i], lab[j]) * 256 + maxi(lab[i], lab[j])
					var g := (d[i] + d[j] + 1.0) * SEA_STEP
					pair[key] = minf(float(pair.get(key, 1e9)), g)
	# Each continent's strait is its gap to its nearest neighbour.
	var nearest := {}
	for key: int in pair:
		for b: int in [key / 256, key % 256]:
			nearest[b] = minf(float(nearest.get(b, 1e9)), float(pair[key]))
	var widest := 0.0
	var gaps: PackedStringArray = []
	for b: int in nearest:
		widest = maxf(widest, float(nearest[b]))
		gaps.append("%d:%d" % [b, roundi(float(nearest[b]))])
	var hull := Geometry2D.convex_hull(centres)
	var hole := 0.0
	var edge := 0.0
	var hole_at := Vector2.ZERO
	for cy in cw:
		for cx in cw:
			var p := Vector2(cx, cy)
			var open := any[cy * cw + cx] * SEA_STEP
			if open <= hole or not Geometry2D.is_point_in_polygon(p, hull):
				continue
			edge = maxf(edge, open)
			# The disc may not run out of the hull: open water that opens onto
			# the outer sea is the world's edge, not a hole in its middle.
			var rim := INF
			for k in hull.size() - 1:
				rim = minf(rim, p.distance_to(Geometry2D.get_closest_point_to_segment(p, hull[k], hull[k + 1])) * SEA_STEP)
			var r := minf(open, rim)
			if r > hole:
				hole = r
				hole_at = p * SEA_STEP
	print("regions sea %d: hole %d tiles across at %s (%d to the hull's edge), straits [%s], widest %d, hole/widest %.2f" % [
		w.seed_value, roundi(2.0 * hole), hole_at, roundi(2.0 * edge), " ".join(gaps), roundi(widest), 2.0 * hole / maxf(1.0, widest)])
