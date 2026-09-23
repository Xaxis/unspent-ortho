extends TestCase
## A PLACE `SiteKinds` DESCRIBES IS LAID WHERE A LANDSCAPE CLAIMS IT. The rows were
## read by nothing for their whole life, so a landscape that named a den or a
## quarry got a word in its file and nothing in its world. `GenScatter._site_kinds`
## reads a claim by the row's own name as a rate per 1,000 tiles of each region,
## at least one per region, and `_landmarks` furnishes it from the row's props.
##
## No shipped landscape claims one yet (the L2 builders will), so this claims a
## den for the moss on the shared definition, grows a world, and puts the claim
## back whatever happens.

func test_a_claimed_place_is_laid_in_every_region_and_furnished() -> void:
	var moss := BiomeRegistry.get_def(&"moss")
	var had: Variant = moss.sites.get("den", null)
	moss.sites["den"] = 1.0
	var w := WorldGen.generate(4, 512)
	if had == null:
		moss.sites.erase("den")
	else:
		moss.sites["den"] = had
	var regions := 0
	var dens := {}
	for r: Dictionary in w.regions:
		if int(r.get("index", -1)) == moss.index:
			regions += 1
			dens[int(r.id)] = 0
	gt(regions, 0, "the moss grows a region on this world")
	var furnished := 0
	for m: Dictionary in w.landmarks:
		if m.kind != &"den":
			continue
		check(bool(m.get("site", false)), "a laid den says it is a claimed place")
		eq(int(m.country), moss.index, "a den stands in the landscape that claimed it")
		check(dens.has(int(m.region)), "and in one of its regions, said on the row")
		dens[int(m.region)] = int(dens.get(int(m.region), 0)) + 1
		for p in w.props:
			if p.kind == PropKind.BONES and p.pos.distance_to(m.pos) <= 4.0:
				furnished += 1
				break
	for id: int in dens:
		gt(dens[id], 0, "region %d holds at least one den" % id)
	gt(furnished, 0, "a den is furnished with its bones")
	check(not moss.sites.has("den") or had != null, "the claim was put back")


## A landscape that claims nothing is given nothing: the reader adds no place
## the shipped content did not ask for, which is why it moves no world today.
func test_no_claim_no_place() -> void:
	var w := WorldGen.generate(4, 512)
	var own := 0
	for m: Dictionary in w.landmarks:
		# The four with placers of their own are claimed under their own keys and
		# carry the flag too; what must not appear is one the READER laid.
		if bool(m.get("site", false)) and not GenScatter.SITES_LAID_ELSEWHERE.has(m.kind):
			own += 1
	eq(own, 0, "no SiteKinds place stands where no landscape claims one")
