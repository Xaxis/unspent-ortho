class_name Taken
extends RefCounted
## THE CARRIED-OFF (docs/VISION.md §9.5, and the thread §2's rescue and escort
## goals have been waiting on).
##
## **The game already takes people and then forgets them.** A raid's snatcher
## stands in a yard unanswered, somebody goes off the holding's books
## (`48_raids._take_person` -> `46_settlements.lose_person`), a line is said on
## the glass, and that is the end of it: the person does not exist anywhere
## afterwards. Nothing could be written about rescuing them because there was
## nobody to rescue.
##
## WHERE THEY ARE IS DERIVED AND NEVER PLACED. They are at the plan's depot in
## the region whose network took them — `Works.sites(world)` already answers one
## depot per region, purely, from the island itself. So a rescue needs no new
## site, no new prop and no marker: the yard the player could already walk to and
## break is where their neighbour is, and it was always the most important place
## in a region without anybody being able to say why.
##
## WHICH CLOSES THE LOOP THE CHAPTER OPENED. Breaking a depot is one half of a
## chapter's DEFENDED, it quiets the region for good, and now it is also what
## frees whoever the plan is holding there. One act, three meanings, no new
## verb — and the reason to walk into the most dangerous place in a landscape
## stops being a number on a slate and becomes a person you knew.
##
## What this file is: the record and the rules. Who writes it is the raids
## package, who frees them is the works package's own signal, and what anybody
## SAYS about it is the story's.

## One person the plan has taken.
##
##   who       the folk row's id, so the settlement package can put them back
##   name      what they are called, when anybody knows — a named person of the
##             cast has one and a villager does not, because 35_folk's rows are
##             streamed and nameless. Empty is expected and is not a hole.
##   home_name the settlement they were taken FROM, by name, and this is the field
##             that does the work: a record that cannot say who it is about is a
##             number and nobody rescues a number, but "somebody out of Oyster
##             Row" is a person. It is kept here because the holding may be razed
##             by the time anybody asks.
##   home      the settlement they were taken from
##   region    the region whose network holds them, which is where the depot is
##   minutes   the world minute it happened, so "three days ago" can be said
##   freed     they are out, and the record stays so the story can remember it
class TakenPerson extends RefCounted:
	var who := -1
	var name := ""
	var home_name := ""
	var home := -1
	var region := -1
	var minutes := 0.0
	var freed := false

	func save() -> Dictionary:
		return {"who": who, "name": name, "home_name": home_name, "home": home,
			"region": region, "minutes": SaveCodec.num(minutes), "freed": freed}

	static func load_from(d: Dictionary) -> TakenPerson:
		var t := TakenPerson.new()
		t.who = SaveCodec.to_int(d.get("who", -1))
		t.name = str(d.get("name", ""))
		t.home_name = str(d.get("home_name", ""))
		t.home = SaveCodec.to_int(d.get("home", -1))
		t.region = SaveCodec.to_int(d.get("region", -1))
		t.minutes = float(d.get("minutes", 0.0))
		t.freed = bool(d.get("freed", false))
		return t


## Everybody the plan has taken this game, in the order it happened. Saved under
## key `taken` and deliberately OUTSIDE `WorldStamp`: a person being held is
## never a reason to refuse somebody's save.
var people: Array[TakenPerson] = []


## Somebody has been carried off. Returns the record, so the caller can say it.
func take(who: int, person_name: String, home: int, home_name: String, region: int, minutes: float) -> TakenPerson:
	var t := TakenPerson.new()
	t.who = who
	t.name = person_name
	t.home_name = home_name
	t.home = home
	t.region = region
	t.minutes = minutes
	people.append(t)
	return t


## Who is still being held in that region. The list a rescue is about, and the
## reason a depot is worth walking into.
func held_in(region: int) -> Array[TakenPerson]:
	var out: Array[TakenPerson] = []
	for t in people:
		if not t.freed and t.region == region:
			out.append(t)
	return out


## Everyone still held, anywhere.
func held() -> Array[TakenPerson]:
	var out: Array[TakenPerson] = []
	for t in people:
		if not t.freed:
			out.append(t)
	return out


## The yard in that region has gone dark, so whoever was in it walks out. Returns
## the ones freed by this, so somebody can say their names.
##
## A record is never deleted. The story remembers that it happened, and a person
## who was taken and came back is a different person to one who never was.
func free_region(region: int) -> Array[TakenPerson]:
	var out: Array[TakenPerson] = []
	for t in people:
		if not t.freed and t.region == region:
			t.freed = true
			out.append(t)
	return out


## Whether this region is holding anybody. The cheap question, because the
## chapter and the story both ask it of every region they look at.
func holds_anyone(region: int) -> bool:
	for t in people:
		if not t.freed and t.region == region:
			return true
	return false


func save() -> Dictionary:
	var rows: Array = []
	for t in people:
		rows.append(t.save())
	return {"people": rows}


func load_from(d: Dictionary) -> void:
	people.clear()
	for row: Variant in d.get("people", []):
		if row is Dictionary:
			people.append(TakenPerson.load_from(row))


## What to call one of them out loud. A name when anybody knows it, and where
## they came from when nobody does — never "person 41", which is what a record
## that only keeps an id forces every caller to invent a way around.
static func say(t: TakenPerson) -> String:
	if t == null:
		return "somebody"
	if t.name != "":
		return t.name
	return "somebody" if t.home_name == "" else "somebody out of %s" % t.home_name
