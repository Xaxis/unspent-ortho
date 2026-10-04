extends TestCase
## A KEEPER IS A BOSS, NOT A TOUGH WORKER (coordinator's bar, 2026-09-27, moved
## to the human reader 2026-10-02): fought by the shoulder reader (a player who
## sees what is in front of them and hears the rest), with the felling axe.
## A person (the human reader, seeds 17 and 29: reactions of 250-450 ms, one tell
## in ten misread) wins every keeper in the registry at least 18 of 24 bouts, in
## 25 to 45 s, at a real cost (2 health or more lost a bout; the first keeper's
## cost is its own two bars, FIRST_KEEPER). The perfect reader
## (220 ms, never wrong) wins all 24 and has no cost floor: a keeper's tells are
## read in time by a person (test_readable_tells), so mastery may come out
## untouched. test_fight holds the other half: standing in front never wins.
##
## The keeper is put out as 44_sentinels puts one out (its own row, its first
## phase, roused), and its phase follows its body every slice, as the system does.

const F := preload("res://tests/fight/fixture.gd")
const SR := preload("res://tests/fight/shoulder_reader.gd")

const BOUTS := 24
const WINS_AT_LEAST := 18
const SECONDS := Vector2(25.0, 45.0)
const LOST_AT_LEAST := 2.0
## The human reader's hands, as tools/sweep.sh --reader=human:SEED.
const HUMANS: Array[int] = [17, 29]
## The perfect reader.
const PERFECT := -1
## THE FIRST KEEPER'S COST (cb's ruling, 2026-10-03; the owner may overturn it).
## The coast's Reaper teaches the grammar every later keeper uses: the tell, the
## dodge, the opening, the stand, the slew. Its tells all sit at the floor a
## person reads in time, so its promise is that someone who reads it walks away
## whole, and someone who does not is hurt and survives at twelve. It is held to
## these in place of LOST_AT_LEAST:
##   1. a reader who never misreads pays under 2 a bout;
##   2a. a wrong read costs at least 2 health (health lost per tell answered the
##       wrong way, one in WRONG_EVERY of them): errors are never free;
##   2b. no single wrong read downs a person from full health: every blow it
##       throws stays under FightRules.HEALTH, so one mistake never kills;
##   2c. at a newcomer's error rate, one wrong read in NEWCOMER_WRONG_EVERY, it
##       downs a reader in at most NEWCOMER_DOWNS of BOUTS on every reader seed:
##       survivable at realistic error, not only at none.
## A read late by HUMAN_LATE_MS costs nothing at all: its tells are sized so a
## late read still dodges, which is the readability floor doing its job. An
## average of 2 a bout with no downs cannot both hold with bites of 3-4 against
## 12 (one wrong read in 4 to 10: no share gave both).
const FIRST_KEEPER := &"tide_reaper"
const WRONG_EVERY := 4
const NEWCOMER_WRONG_EVERY := 10
const NEWCOMER_DOWNS := 1


static func keeper_bout(land: StringName, start: int, ids: int, human: int = PERFECT, seconds: float = 150.0,
		misread_share: float = SR.MISREAD, misread_as: StringName = &"") -> Dictionary:
	MobState._next_id = ids
	var def := Sentinels.for_land(land)
	# A keeper that bogs (the plough) is fought on the ground it bogs in, its own.
	var bogs: Array = Roster.row(def.kind).get("bogs", [])
	var ground := int(bogs[0]) if not bogs.is_empty() else Ground.GRASS
	var sim := F.make_sim(F.flat_world(96, ground), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"axe_felling")
	sim.hero.inventory.set_held(&"axe_felling")
	sim.hero.kit = FightKit.of([])
	var a := float(start) / 8.0 * TAU
	var m := sim.add_mob(def.kind, sim.hero.pos + Vector2.from_angle(a) * 6.0)
	Sentinels.own_row(m)
	Sentinels.wear_phase(m, def, 0)
	m.facing = (sim.hero.pos - m.pos).angle()
	m.aim = m.facing
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	var reader: Variant = SR.new(sim)
	reader.human = human
	reader.misread_share = misread_share
	reader.misread_as = misread_as
	sim.hero.facing = (m.pos - sim.hero.pos).angle()
	var phase := 0
	var lost := 0
	var t := 0.0
	while t < seconds * 1000.0:
		var want := def.phase_at(m.health_fraction())
		if want != phase and m.alive:
			phase = want
			Sentinels.wear_phase(m, def, want)
		reader.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type == &"hurt":
				lost += int(e.damage)
			if e.type == &"outcome" and e.outcome in [&"downed", &"carried"]:
				return {"won": false, "t": t / 1000.0, "lost": lost, "down": true, "wrong": reader.wrong_reads}
		if not m.alive:
			return {"won": true, "t": t / 1000.0, "lost": lost, "down": false, "wrong": reader.wrong_reads}
	return {"won": false, "t": t / 1000.0, "lost": lost, "down": false, "wrong": reader.wrong_reads}


static func keeper_row(land: StringName, human: int = PERFECT, misread_share: float = SR.MISREAD,
		misread_as: StringName = &"") -> Dictionary:
	var won := 0
	var lost := 0
	var downs := 0
	var wrong := 0
	var t := 0.0
	for i in BOUTS:
		var r := keeper_bout(land, i % 8, 1000 + i / 8, human, 150.0, misread_share, misread_as)
		won += int(r.won)
		lost += int(r.lost)
		downs += int(r.down)
		wrong += int(r.wrong)
		if r.won:
			t += float(r.t)
	return {"won": won, "t": t / maxf(won, 1), "lost": float(lost) / BOUTS, "downs": downs, "lost_all": lost, "wrong": wrong}


## Every keeper's row for every human seed, worked out once for the three bars
## below: each bar is its own test, so a keeper that turns unwinnable fails its
## own line even while another bar stands red (tests/standing.txt).
static var _human_rows: Dictionary = {}


static func human_rows() -> Dictionary:
	if _human_rows.is_empty():
		for land: StringName in Sentinels.lands():
			for h: int in HUMANS:
				var r := keeper_row(land, h)
				print("  info keeper %s, human %d: won %d/%d in %.1f s, losing %.2f a bout" % [land, h, r.won, BOUTS, r.t, r.lost])
				_human_rows["%s %d" % [land, h]] = r
	return _human_rows


func test_a_person_beats_every_keeper() -> void:
	var rows := human_rows()
	for key: String in rows:
		gt(float(rows[key].won), float(WINS_AT_LEAST) - 0.5, "%s: won at least %d of %d" % [key, WINS_AT_LEAST, BOUTS])


func test_a_keeper_fight_lasts_a_boss_fight_for_a_person() -> void:
	var rows := human_rows()
	for key: String in rows:
		var t := float(rows[key].t)
		check(t >= SECONDS.x and t <= SECONDS.y, "%s: a fight of %.0f-%.0f s (%.1f)" % [key, SECONDS.x, SECONDS.y, t])


func test_a_keeper_costs_a_person_something_real() -> void:
	var rows := human_rows()
	for key: String in rows:
		if Sentinels.for_land(StringName(key.split(" ")[0])).id == FIRST_KEEPER:
			continue
		gt(float(rows[key].lost), LOST_AT_LEAST - 0.01, "%s: at a real cost (%.2f lost)" % [key, rows[key].lost])


func test_the_first_keeper_read_without_a_misread_leaves_a_person_whole() -> void:
	var land := _first_keeper_land()
	for h: int in HUMANS:
		var r := keeper_row(land, h, 0.0)
		print("  info first keeper, human %d, no misreads: won %d/%d in %.1f s, losing %.2f a bout, %d downs" % [h, r.won, BOUTS, r.t, r.lost, r.downs])
		lt(float(r.lost), LOST_AT_LEAST, "human %d reading every tell: walks away whole (%.2f lost)" % [h, r.lost])


func test_a_wrong_read_of_the_first_keeper_costs_something_real() -> void:
	var land := _first_keeper_land()
	for h: int in HUMANS:
		var clean := keeper_row(land, h, 0.0)
		var r := keeper_row(land, h, 1.0 / WRONG_EVERY, &"wrong")
		var each := float(int(r.lost_all) - int(clean.lost_all)) / maxf(1.0, float(r.wrong))
		print("  info first keeper, human %d, one in %d read wrong: %d wrong reads, %d health lost (%d reading every tell), %.2f a wrong read" % [h, WRONG_EVERY, r.wrong, r.lost_all, clean.lost_all, each])
		gt(float(r.wrong), 0.5, "human %d: wrong reads were made" % h)
		gt(each, LOST_AT_LEAST - 0.01, "human %d: a wrong read costs something real (%.2f health)" % [h, each])


func test_no_single_blow_of_the_first_keeper_downs_a_person() -> void:
	var def := Sentinels.by_id(FIRST_KEEPER)
	var m := MobState.new(def.kind, Vector2(10, 10))
	for i in def.phases.size():
		Sentinels.wear_phase(m, def, i)
		var id := def.phase(i).id
		lt(float(m.bite.dmg), float(FightRules.HEALTH), "%s: its bite (%d) leaves a person standing" % [id, m.bite.dmg])
		lt(float(m.bite.crush), float(FightRules.HEALTH), "%s: its crush (%d) leaves a person standing" % [id, m.bite.crush])
		if m.come_round != null:
			lt(float(m.come_round.dmg), float(FightRules.HEALTH), "%s: its come-round (%d) leaves a person standing" % [id, m.come_round.dmg])


func test_a_newcomer_survives_the_first_keeper() -> void:
	var land := _first_keeper_land()
	for h: int in HUMANS:
		var r := keeper_row(land, h, 1.0 / NEWCOMER_WRONG_EVERY, &"wrong")
		print("  info first keeper, human %d, one in %d read wrong: won %d/%d in %.1f s, losing %.2f a bout, %d downs" % [h, NEWCOMER_WRONG_EVERY, r.won, BOUTS, r.t, r.lost, r.downs])
		lt(float(r.downs), NEWCOMER_DOWNS + 0.5, "human %d: downed in at most %d of %d bouts (%d)" % [h, NEWCOMER_DOWNS, BOUTS, r.downs])


static func _first_keeper_land() -> StringName:
	for land: StringName in Sentinels.lands():
		if Sentinels.for_land(land).id == FIRST_KEEPER:
			return land
	return &""


func test_a_perfect_reader_beats_every_keeper() -> void:
	for land: StringName in Sentinels.lands():
		var r := keeper_row(land, PERFECT)
		print("  info keeper %s, perfect: won %d/%d in %.1f s, losing %.2f a bout" % [land, r.won, BOUTS, r.t, r.lost])
		eq(int(r.won), BOUTS, "%s: the perfect reader wins every bout" % land)
