extends TestCase
## A landscape's works are sited one region at a time (streamed worldgen S4j1):
## each region throws its own darts, takes its own share of the landscape's
## counts, and sees no other region's works. So a region laid again ALONE, after
## every other region is laid, sites and composes exactly what it laid in the
## world -- which is what lets a streamed world lay a region's works once its own
## ground is there, whatever else has been laid.

const SIZE := 1024
const SEEDS: Array[int] = [1, 90210]


func test_every_region_laid_alone_lays_what_it_laid_in_the_world() -> void:
	for s in SEEDS:
		GenWorks.checking = true
		GenWorks.checked = []
		WorldGen.generate(s, SIZE)
		GenWorks.checking = false
		var rows := GenWorks.checked
		GenWorks.checked = []
		var works := 0
		var shared := {}
		var moved: Array = []
		for r: Dictionary in rows:
			works += (r.world as Array).size()
			if (r.world as Array).size() > 0:
				shared[r.land] = int(shared.get(r.land, 0)) + 1
			if var_to_str(r.world) != var_to_str(r.alone):
				moved.append("%s region %d: %d marks in the world, %d alone" % [r.land, r.region, (r.world as Array).size(), (r.alone as Array).size()])
		gt(float(works), 40.0, "seed %d: works to lay" % s)
		var split := 0
		for land: StringName in shared:
			if int(shared[land]) > 1:
				split += 1
		gt(float(split), 0.0, "seed %d: some landscape lays works in more than one region" % s)
		eq(moved, [], "seed %d: every region alone lays what it laid in the world" % s)
