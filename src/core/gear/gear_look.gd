class_name GearLook
## What a body is seen wearing: the loadout turned into the people model's look
## (owner, 2026-09-17: the gear page draws "the fully rendered character ... wearing
## real gear"). One answer for the page and for the figure walking the coast, so
## what the slate shows is what the world shows.
##
## Pure data in the model's own words (`PersonLook`), read off each fitted piece's
## `wears` row in Items.DEFS: `hat` and `coat` name the one worn, `extras`,
## `salvage` and `gear` add to what the body already has, `wing` hangs the glide
## wing on the back. The result carries `kit: true`, which is how a look says it
## is somebody's chosen kit and not a crowd's dealt one: a crowd keeps a cap on
## salvage so no villager wears the full set, and a player wears what they fitted.
##
##   GearLook.compose(bare, loadout) -> look spec      bare: the body before any gear
##   GearLook.wing(loadout) -> bool                     the wing is worn
##   GearLook.pieces(id) -> Array[String]              "hat:brim", "salvage:lens": what one piece puts on

## Keys whose value replaces the body's own.
const NAMED: Array[String] = ["hat", "coat"]
## Keys whose values are added to the body's own list.
const LISTED: Array[String] = ["extras", "salvage", "gear"]


static func compose(bare: Dictionary, loadout: Loadout) -> Dictionary:
	var out := bare.duplicate(true)
	out["kit"] = true
	if loadout == null:
		return out
	for slot in Gear.SLOTS:
		for id in loadout.ids_in(slot):
			var wears: Dictionary = Items.def(id).get("wears", {})
			for k: String in NAMED:
				if wears.has(k):
					out[k] = StringName(str(wears[k]))
			for k: String in LISTED:
				if not wears.has(k):
					continue
				var have: Array = (out.get(k, []) as Array).duplicate()
				for v: Variant in wears[k]:
					var name := StringName(str(v))
					if not have.has(name):
						have.append(name)
				out[k] = have
	return out


static func wing(loadout: Loadout) -> bool:
	if loadout == null:
		return false
	for slot in Gear.SLOTS:
		for id in loadout.ids_in(slot):
			if bool((Items.def(id).get("wears", {}) as Dictionary).get("wing", false)):
				return true
	return false


## Every mark one piece puts on a body, as "key:name", for a test to find again in
## the look the model actually keeps.
static func pieces(id: StringName) -> Array[String]:
	var out: Array[String] = []
	var wears: Dictionary = Items.def(id).get("wears", {})
	for k: String in NAMED:
		if wears.has(k):
			out.append("%s:%s" % [k, wears[k]])
	for k: String in LISTED:
		for v: Variant in wears.get(k, []):
			out.append("%s:%s" % [k, v])
	if bool(wears.get("wing", false)):
		out.append("wing:true")
	return out
