extends TestCase
## A GRADE IS ITS SOCKETS (GEAR.md G2, VISION §Gear: a higher grade buys
## modifiers, never a bigger number). Every piece on the GearTree carries
## Rarity.SLOTS of its grade. A tool always takes one binding even at common
## (Gear.sockets says why), and made wear keeps the one socket that is where a
## player's first module lives; both are written here as the named exceptions.


func _allowed(id: StringName, grade: int) -> int:
	var want := Rarity.slots(grade)
	var d := Items.def(id)
	if grade == Rarity.COMMON and (bool(d.get("tool", false)) or StringName(d.get("tier", &"")) == &"made"):
		want = maxi(want, 1)
	return want


func test_every_rung_carries_its_grades_sockets() -> void:
	var wrong := PackedStringArray()
	for id: StringName in GearTree.ids():
		# A module goes IN a socket; its grade is how strange it is, not a count.
		if not Items.DEFS.has(id) or Items.def(id).has("fits"):
			continue
		var grade := GearTree.grade(id)
		var got := Gear.sockets(id)
		var want := _allowed(id, grade)
		if got != want:
			wrong.append("%s (%s): %d, not %d" % [id, Rarity.name_of(grade), got, want])
	eq(wrong.size(), 0, "sockets follow the grade: %s" % ", ".join(wrong))
