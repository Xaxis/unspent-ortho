extends TestCase
## WHAT IS DRAWN IS WHAT HITS (#76): a keeper's strike carries its biting part,
## or the drawn part of the blow that lands (a spray, a thrown weight, a bolt),
## to its bite box's front as the box goes live, in every phase. A strike drawn
## short of the box is a bite landing out of thin air; one drawn past it claims
## ground the bite never reaches.

## How far the drawn front may sit from the box's front, tiles.
const NEAR := 0.3
## The band a person stands in, world units: what the front is read at.
const LOW := 0.12
const HIGH := 1.8


## The farthest drawn point ahead of the body's centre within a person's height,
## in world tiles (the model's own scale applied). Each triangle is clipped to
## the band, so a long member crossing it counts where it crosses.
static func drawn_front(m: MachineModel) -> float:
	var k := m.scale.x
	var front := -INF
	for s: StringName in m.surfaces:
		var tris := m.posed_triangles(m.surfaces[s])
		for t in range(0, tris.size(), 3):
			for e in 3:
				var a := tris[t + e] * k
				var b := tris[t + (e + 1) % 3] * k
				if a.y >= LOW and a.y <= HIGH:
					front = maxf(front, a.x)
				for y0: float in [LOW, HIGH]:
					if (a.y - y0) * (b.y - y0) < 0.0:
						front = maxf(front, lerpf(a.x, b.x, (y0 - a.y) / (b.y - a.y)))
	return front


func test_every_keeper_strike_lands_at_its_box_front() -> void:
	var off: Array[String] = []
	var seen := 0
	for def: SentinelDef in Sentinels.all():
		var row := Roster.row(def.kind)
		var m := FigureModel.create(row.get("model", &"")) as MachineModel
		check(m != null, "%s draws a machine" % def.id)
		if m == null:
			continue
		var radius := float(row.get("radius", 0.5))
		for i in def.phases.size():
			var p := def.phase(i)
			var box := radius + float(p.bite.get("reach", 0.6))
			m.set_pose(&"windup")
			m.settle()
			m.strike_front = box
			m.blow_live = true
			m.set_pose(&"strike")
			m.settle()
			var front := drawn_front(m)
			seen += 1
			print("  info %s %s: box front %.2f, drawn %.2f" % [def.id, p.id, box, front])
			if absf(front - box) > NEAR:
				off.append("%s %s (box %.2f, drawn %.2f)" % [def.id, p.id, box, front])
		m.free()
	gt(seen, 19, "every keeper's phases were measured")
	check(off.is_empty(), "every strike lands within %.1f of its box front: %s" % [NEAR, ", ".join(off)])

