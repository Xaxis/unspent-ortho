extends TestCase
## A KEEPER DENS IN ONE PLACE FOR THE WHOLE GAME. A design may station at a
## landmark (the drip warden at a sump pump), and the landmarks' rows go into the
## world's list when 22_landmarks reads them on the crossing; asked before that
## (on the raise, or by 21_doors on the crossing, which comes first), every
## warden denned at its region's heart, and after it at a pump 100-500 tiles off.
## The rows are written on the raise, so every asker gets the one answer.



func test_the_wardens_den_where_they_will_after_the_crossing() -> void:
	var w := WorldGen.generate(Realm.seed_for(7, Realm.UNDERGROUND), 512, &"", Realm.UNDERGROUND)
	RealmWarm.prepare(w)
	var raised := {}
	for st: SentinelState in Sentinels.states(w):
		raised[st.region] = st.lair
	# What 22_landmarks does on the crossing: every site's row, at its cache, once.
	for site: LandmarkSite in Landmarks.sites(w):
		var at := Landmarks.cache_of(site)
		var had := false
		for m: Dictionary in w.landmarks:
			if m.get("kind") == site.kind and (m.get("pos") as Vector2).distance_to(at) < 0.5:
				had = true
		if not had:
			w.landmarks.append({"kind": site.kind, "pos": at, "country": w.country_at(floori(at.x), floori(at.y)), "dir": Vector2.from_angle(site.facing)})
	var wardens := 0
	for st: SentinelState in Sentinels.states(w):
		if st.design == &"drip_warden":
			wardens += 1
		check(raised.has(st.region) and (raised[st.region] as Vector2).is_equal_approx(st.lair),
			"region %d's %s dens at %s after the crossing, and was asked at %s on the raise" % [st.region, st.design, st.lair, raised.get(st.region, Vector2.INF)])
	gt(float(wardens), 0.0, "seed 7's underground at 512 keeps a drip warden (%d)" % wardens)


## The rows a system writes after the raise, at its setup (20_realms' shafts,
## 34_works' depots), come too late for a keeper to station at: one that did would
## den in two places again. Landmarks' own kinds are written on the raise.
func test_no_keeper_stations_at_a_row_written_after_the_raise() -> void:
	for d: SentinelDef in Sentinels.all():
		for k: StringName in d.stations:
			check(k != &"shaft" and k != &"works", "%s stations at %s, a row only setup writes" % [d.id, k])
