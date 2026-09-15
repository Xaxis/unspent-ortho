class_name Items
## Every item, as data. The survival work package fills this in from
## docs/research/design-extract.md §9 (names are placeholders until the story
## rewrite; mechanics numbers are the source's).
##
## Schema (all optional except name, bulk):
##   name: String          what the player sees
##   bulk: float           weight toward load
##   tool: bool            has an edge; can be held
##   verb: StringName      work verb it enables: break dig fell cut
##   stuff: StringName     hardness: wood iron steel crucible found
##   speed: int            work speed 10000 = bare-hand baseline (lower is faster)
##   bite: int             uses per full edge (0 = never dulls)
##   swing: Array[int]     [windup, active, recovery, cooldown] ms
##   reach: float, width: float, dmg: int, knock: float, knock_ms: int
##   feeds: float          hours of food
##   kit: StringName       wearable salvage slot

const DEFS := {
	&"knife": {"name": "knife", "bulk": 1.0, "tool": true, "verb": &"cut", "stuff": &"iron", "speed": 8200, "bite": 90,
		"swing": [60, 100, 120, 140], "reach": 0.9, "width": 1.0, "dmg": 2, "knock": 4.0, "knock_ms": 150},
	&"stone": {"name": "stone", "bulk": 5.0},
	&"timber": {"name": "timber", "bulk": 6.0},
	&"driftwood": {"name": "driftwood", "bulk": 3.0},
	&"scrap": {"name": "a piece of plate", "bulk": 2.0},
	&"mussels": {"name": "mussels", "bulk": 1.0, "feeds": 4.0},
}


static func def(id: StringName) -> Dictionary:
	return DEFS.get(id, {})


static func display_name(id: StringName) -> String:
	return def(id).get("name", String(id))


static func has_edge(id: StringName) -> bool:
	return def(id).get("tool", false)


static func bulk(id: StringName) -> float:
	return def(id).get("bulk", 1.0)
