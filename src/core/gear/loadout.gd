class_name Loadout
extends RefCounted
## What is fitted where: one wearable piece per slot and a module in each of its
## sockets. Configured before a journey on the slate's gear page (docs/VISION.md
## §6); saved with the game.
##
## Nothing here consumes anything: a fitted piece is still carried (it still
## weighs on the creel), the loadout only records where it sits. The hand's slot
## mirrors `Inventory.held`, so the loadout stores modules for it and never the
## tool itself.

signal changed


class Slot:
	extends RefCounted
	var item: StringName = &""
	var modules: Array[StringName] = []


## slot id -> Slot
var slots: Dictionary = {}


func _init() -> void:
	for s in Gear.SLOTS:
		slots[s] = Slot.new()


func slot_of(slot: StringName) -> Slot:
	if not slots.has(slot):
		slots[slot] = Slot.new()
	return slots[slot]


func item(slot: StringName) -> StringName:
	return slot_of(slot).item


func modules(slot: StringName) -> Array[StringName]:
	return slot_of(slot).modules


## The piece and its modules, for reading resistances and abilities off a slot.
func ids_in(slot: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var r := slot_of(slot)
	if r.item != &"":
		out.append(r.item)
	out.append_array(r.modules)
	return out


## Everything fitted anywhere, in slot order.
func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s in Gear.SLOTS:
		out.append_array(ids_in(s))
	return out


## How many copies of `id` are fitted (a second copy needs a second carried).
func fitted_count(id: StringName) -> int:
	var n := 0
	for other in all_ids():
		if other == id:
			n += 1
	return n


func free_sockets(slot: StringName) -> int:
	var r := slot_of(slot)
	# Nothing in hand: nothing to socket onto.
	if slot == Gear.HAND_SLOT and r.item == &"":
		return 0
	return maxi(0, Gear.sockets(r.item) - r.modules.size())


## Put a wearable piece in its slot. &"" empties it (its modules come out too).
func fit(slot: StringName, id: StringName) -> bool:
	if not slots.has(slot):
		return false
	if id != &"" and not Gear.fits(id, slot):
		return false
	var r := slot_of(slot)
	r.item = id
	r.modules = _keep_fitting(r.modules, id)
	changed.emit()
	return true


## The thing in hand is the inventory's; the loadout follows it so the page shows
## it and its sockets stay honest when it changes.
func hold(id: StringName) -> void:
	var r := slot_of(Gear.HAND_SLOT)
	if r.item == id:
		return
	r.item = id
	r.modules = _keep_fitting(r.modules, id)
	changed.emit()


func socket(slot: StringName, module_id: StringName) -> bool:
	if not Gear.is_module(module_id) or not Gear.fits(module_id, slot):
		return false
	if free_sockets(slot) <= 0:
		return false
	slot_of(slot).modules.append(module_id)
	changed.emit()
	return true


func unsocket(slot: StringName, module_id: StringName) -> bool:
	var r := slot_of(slot)
	var i := r.modules.find(module_id)
	if i < 0:
		return false
	r.modules.remove_at(i)
	changed.emit()
	return true


## Take out everything in a slot (the piece and its modules). The hand keeps its
## tool, which belongs to the inventory.
func clear_slot(slot: StringName) -> void:
	var r := slot_of(slot)
	if r.item == &"" and r.modules.is_empty():
		return
	if slot != Gear.HAND_SLOT:
		r.item = &""
	r.modules = [] as Array[StringName]
	changed.emit()


## Drop anything fitted that is no longer carried (a piece traded, spent or lost).
## `carried.call(id, n)` answers whether at least n of id are in the creel.
func keep_only(carried: Callable) -> void:
	var dirty := false
	for s in Gear.SLOTS:
		var r := slot_of(s)
		if r.item != &"" and s != Gear.HAND_SLOT and not bool(carried.call(r.item, 1)):
			r.item = &""
			r.modules = [] as Array[StringName]
			dirty = true
		var keep: Array[StringName] = []
		var used: Dictionary = {}
		for m: StringName in r.modules:
			used[m] = int(used.get(m, 0)) + 1
			if bool(carried.call(m, int(used[m]))):
				keep.append(m)
			else:
				dirty = true
		r.modules = keep
	if dirty:
		changed.emit()


## Modules that still have a socket to sit in once `holder` is the piece.
static func _keep_fitting(mods: Array[StringName], holder: StringName) -> Array[StringName]:
	var keep: Array[StringName] = []
	for m: StringName in mods:
		if keep.size() < Gear.sockets(holder):
			keep.append(m)
	return keep


## JSON-safe (SaveGame contract).
func save() -> Dictionary:
	var out: Dictionary = {}
	for s in Gear.SLOTS:
		var r := slot_of(s)
		var mods := PackedStringArray()
		for m: StringName in r.modules:
			mods.append(String(m))
		out[String(s)] = {"item": String(r.item), "modules": mods}
	return out


## Numbers come back as floats and keys as Strings; ids are plain strings here.
func load_from(v: Variant) -> void:
	if not (v is Dictionary):
		return
	for s in Gear.SLOTS:
		var raw: Variant = (v as Dictionary).get(String(s), null)
		if not (raw is Dictionary):
			continue
		var row := raw as Dictionary
		var r := slot_of(s)
		if s != Gear.HAND_SLOT:
			r.item = StringName(row.get("item", ""))
		var mods: Array[StringName] = []
		for m: Variant in (row.get("modules", []) as Array):
			mods.append(StringName(m))
		r.modules = mods
	changed.emit()
