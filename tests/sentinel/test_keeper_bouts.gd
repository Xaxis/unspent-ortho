extends TestCase
## A KEEPER IS A BOSS, NOT A TOUGH WORKER (coordinator's bar, 2026-09-27): fought
## by the shoulder reader (a player who sees what is in front of them and hears
## the rest), with the felling axe, every keeper in the registry is won at least
## 18 of 24 bouts, in 25 to 45 s, at a real cost (2 health or more lost on
## average). test_fight holds the other half: standing in front never wins.
##
## The keeper is put out as 44_sentinels puts one out (its own row, its first
## phase, roused), and its phase follows its body every slice, as the system does.

const F := preload("res://tests/fight/fixture.gd")
const SR := preload("res://tests/fight/shoulder_reader.gd")

const BOUTS := 24
const WINS_AT_LEAST := 18
const SECONDS := Vector2(25.0, 45.0)
const LOST_AT_LEAST := 2.0


static func keeper_bout(land: StringName, start: int, ids: int, seconds: float = 150.0) -> Dictionary:
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
				return {"won": false, "t": t / 1000.0, "lost": lost}
		if not m.alive:
			return {"won": true, "t": t / 1000.0, "lost": lost}
	return {"won": false, "t": t / 1000.0, "lost": lost}


static func keeper_row(land: StringName) -> Dictionary:
	var won := 0
	var lost := 0
	var t := 0.0
	for i in BOUTS:
		var r := keeper_bout(land, i % 8, 1000 + i / 8)
		won += int(r.won)
		lost += int(r.lost)
		if r.won:
			t += float(r.t)
	return {"won": won, "t": t / maxf(won, 1), "lost": float(lost) / BOUTS}


func test_every_keeper_is_a_boss_to_a_player_over_the_shoulder() -> void:
	for land: StringName in Sentinels.lands():
		var r := keeper_row(land)
		print("  info keeper %s: won %d/%d in %.1f s, losing %.2f a bout" % [land, r.won, BOUTS, r.t, r.lost])
		gt(float(r.won), float(WINS_AT_LEAST) - 0.5, "%s: won at least %d of %d" % [land, WINS_AT_LEAST, BOUTS])
		check(r.t >= SECONDS.x and r.t <= SECONDS.y, "%s: a fight of %.0f-%.0f s (%.1f)" % [land, SECONDS.x, SECONDS.y, r.t])
		gt(r.lost, LOST_AT_LEAST - 0.01, "%s: at a real cost (%.2f lost)" % [land, r.lost])
