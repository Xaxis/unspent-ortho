class_name WorldGen
## seed -> WorldData. Deterministic, no side effects, no nodes.
##
## Stages (src/core/worldgen/), each reading only what earlier ones wrote:
##   1. shape      GenShape      one island, bays and headlands, sea on every edge
##   2. layout     GenCountries  countries as a journey north from the south coast, balanced shares
##   3. relief     GenRelief     float elevation per country; beaches, sea cliffs, shingle ledges
##   4. tiles      GenCountries  country, country2 and blend per tile (ecotones)
##   5. rivers     GenWater      drainage from high ground to the sea, beds and valleys
##   6. terrace    GenRelief     integer levels
##   7. still      GenWater      blackwater pools, frozen tarns
##   8. settle     GenSettle     villages (levelled), roads (graded, bridged), spawn
##   9. access     GenAccess     scree breaches so every region can be walked to
##  10. sites      GenScatter    tips, circles, wrecks, ruins, summits
##  11. surface    GenSurface    grounds from world-position fields
##  12. props      GenScatter    villages, landmarks, the machines' grid, scatter

const DEFAULT_SIZE := Tuning.WORLD_SIZE
const MAX_LEVEL := GenRelief.MAX_LEVEL

## Milliseconds per stage of the most recent generate() (for tools and tests).
static var last_timings: Dictionary = {}


## `until` = &"tiles" stops once every tile has its country (the layout is
## final by then): for tests that only need shares and borders.
static func generate(seed_value: int, size: int = DEFAULT_SIZE, until: StringName = &"") -> WorldData:
	var w := WorldData.new(seed_value, size)
	var c := GenContext.new(w)
	var t := Time.get_ticks_usec()
	var marks := {}
	c.mark(&"start")
	GenShape.run(c)
	t = _mark(c, marks, &"shape", t)
	GenCountries.coarse(c)
	t = _mark(c, marks, &"layout", t)
	GenRelief.run(c)
	t = _mark(c, marks, &"relief", t)
	GenCountries.fine(c)
	t = _mark(c, marks, &"tiles", t)
	if until == &"tiles":
		for i in c.n:
			w.level[i] = 1 if c.land[i] != 0 else -1
		last_timings = marks
		return w
	GenWater.rivers(c)
	t = _mark(c, marks, &"rivers", t)
	GenRelief.terrace(c)
	t = _mark(c, marks, &"terrace", t)
	GenWater.still(c)
	t = _mark(c, marks, &"still", t)
	GenSettle.villages(c)
	c.mark(&"settle.villages")
	GenSettle.roads(c)
	c.mark(&"settle.roads")
	GenSettle.spawn(c)
	t = _mark(c, marks, &"settle", t)
	GenAccess.run(c)
	t = _mark(c, marks, &"access", t)
	GenScatter.sites(c)
	c.mark(&"surface.sites")
	GenSurface.run(c)
	t = _mark(c, marks, &"surface", t)
	GenScatter.props(c)
	t = _mark(c, marks, &"props", t)
	w.rivers = c.rivers
	var total := 0.0
	for k: StringName in marks:
		total += marks[k]
	marks[&"total"] = total
	last_timings = marks
	last_detail = c.timings
	return w


## Finer marks inside stages (GenContext.mark) from the most recent generate().
static var last_detail: Dictionary = {}


static func _mark(c: GenContext, marks: Dictionary, name: StringName, t0: int) -> int:
	c.mark(StringName(String(name) + ".rest"))
	var t := Time.get_ticks_usec()
	marks[name] = (t - t0) / 1000.0
	return t


## Chamfer distance in tiles from each tile to the nearest tile at level <= 0.
static func distance_to_sea(w: WorldData) -> PackedFloat32Array:
	var solid := PackedByteArray()
	solid.resize(w.size * w.size)
	for i in solid.size():
		solid[i] = 1 if w.level[i] <= 0 else 0
	return distance_field(solid, w.size)


## 4-neighbour chamfer distance to the nearest cell where mask == 1.
static func distance_field(mask: PackedByteArray, size: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(size * size)
	for i in d.size():
		d[i] = 0.0 if mask[i] == 1 else 1e9
	for y in size:
		for x in size:
			var i := y * size + x
			var v := d[i]
			if x > 0:
				v = minf(v, d[i - 1] + 1.0)
			if y > 0:
				v = minf(v, d[i - size] + 1.0)
			d[i] = v
	for y in range(size - 1, -1, -1):
		for x in range(size - 1, -1, -1):
			var i := y * size + x
			var v := d[i]
			if x < size - 1:
				v = minf(v, d[i + 1] + 1.0)
			if y < size - 1:
				v = minf(v, d[i + size] + 1.0)
			d[i] = v
	return d
