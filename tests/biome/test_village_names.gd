extends TestCase
## EVERY VILLAGE HAS ITS OWN NAME (GenSettle._name). The survey, the map and the
## story's lines name places by it, so two villages called the same send him to
## the wrong one. A landscape's list runs out on a big island (the slums'
## blocks); past it the names are numbered, each number once. Seed 1 had eight
## slum villages all "Ninth Shift 24": the overflow was numbered by a count of
## names taken that it never added to. At the shipped size, four seeds.

const SEEDS: Array[int] = [1, 7, 42, 90210]


func test_no_two_villages_on_one_world_share_a_name() -> void:
	for s: int in SEEDS:
		var w := WorldGen.generate(s, Tuning.WORLD_SIZE)
		var seen := {}
		var repeats: Array[String] = []
		for v: Dictionary in w.villages:
			var nm := str(v.get("name", ""))
			if seen.has(nm):
				repeats.append("%s (villages %d and %d)" % [nm, int(seen[nm]), int(v.id)])
			else:
				seen[nm] = int(v.id)
		check(repeats.is_empty(), "seed %d: each of %d villages has a name of its own; shared: %s" % [s, w.villages.size(), ", ".join(repeats)])
