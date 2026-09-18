class_name StoryLedger
## The world writing him down (docs/STORY_SYSTEM.md §7): the owner's chosen
## narrator. There is no narrator's voice; there are two records of what he has
## done, and they disagree.
##
##   people    a notebook of hearsay, in a stranger's hand, always a little behind
##   machines  an error log that files everything at once and understands none of it
##
## Only what could have been OBSERVED is here (Story.note). The people's record lags
## by LAG, because it travels as talk; the machines' does not. Pure: it reads the
## ledger and the clock off Story and composes lines, so a fragment's words can be
## worked out anywhere.

## How long an act takes to reach the people who write things down: half a day.
const LAG := 360.0
## How many acts one page holds before the oldest drop off it.
const MOST := 4

## Each act as the people say it, and as the machines file it.
const ACTS := {
	&"works_dark": {"people": "put a works yard dark", "machines": "WORKS LOST"},
	&"keeper_fell": {"people": "brought a keeper down", "machines": "KEEPER LOST"},
	&"went_below": {"people": "went down a shaft", "machines": "UNLOGGED DESCENT"},
	&"filed": {"people": "was read by a clerk", "machines": "DUPLICATE READ"},
}


## The acts the people have heard of by now, oldest first.
static func told(now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in Story.ledger():
		if now - float(e.at) >= LAG and ACTS.has(e.act):
			out.append(e)
	return out


static func lines(voice: StringName) -> PackedStringArray:
	return _machines() if voice == &"machines" else _people()


static func _people() -> PackedStringArray:
	var heard := told(Story.now)
	if heard.is_empty():
		# Before he has done anything worth telling, the notebook is about others.
		return PackedStringArray([
			"Two came up out of the water, years apart.",
			"Neither said where from. Neither stayed.",
		])
	var out := PackedStringArray([
		"One came up out of the water this year.",
		"Since then, they say he",
	])
	for e: Dictionary in heard.slice(maxi(0, heard.size() - MOST)):
		out.append("  %s, in the %s." % [ACTS[e.act].people, _land(e.land)])
	out.append("")
	out.append("Nobody knows his name." if heard.size() < 3 else "I do not think he knows he is written down.")
	return out


static func _machines() -> PackedStringArray:
	var filed: Array[Dictionary] = []
	for e: Dictionary in Story.ledger():
		if ACTS.has(e.act):
			filed.append(e)
	if filed.is_empty():
		return PackedStringArray([
			"ERROR LOG  /  NO ENTRIES",
			"",
			"The log is empty. Whatever it is waiting",
			"to write down has not happened yet.",
		])
	var out := PackedStringArray(["ERROR LOG  /  MARR, E.", "STATUS: DECEASED 14.03.2029", ""])
	for e: Dictionary in filed.slice(maxi(0, filed.size() - MOST)):
		out.append("  %s (%s)" % [ACTS[e.act].machines, _land(e.land).to_upper()])
	out.append("")
	out.append("ALL ATTRIBUTED TO ERROR.")
	return out


## A landscape as a person names it, through the registry's own door.
static func _land(id: StringName) -> String:
	var d := BiomeRegistry.get_def(id)
	return d.display_name if d != null and d.display_name != "" else String(id)
