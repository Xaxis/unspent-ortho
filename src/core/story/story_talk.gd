class_name StoryTalk
extends RefCounted
## One conversation in progress: where it is, what is being said, and what the
## player may say back (owner, 2026-09-17). Pure — it holds no node, draws
## nothing and reads no keys, so a test can have a whole conversation in a loop.
##
##   var t := StoryTalk.start(&"tide_keeper")
##   t.says()            what is on the screen now
##   t.replies()         what the player may say, already filtered by what they know
##   t.pick(i)           say the i'th; false when that ends it
##
## A reply's `pick` is remembered against the node it was given at, so the record
## is "asked about the tide at the fire" rather than "said thing 2".

var id: StringName = &""
var node: StringName = &""
var over := false


static func start(talk_id: StringName) -> StoryTalk:
	var t := StoryTalk.new()
	var def: Dictionary = StoryContent.TALKS.get(talk_id, {})
	if def.is_empty():
		t.over = true
		return t
	t.id = talk_id
	t.node = StringName(str(def.get("start", &"")))
	t._land(t._node())
	return t


func title() -> String:
	return String(StoryContent.TALKS.get(id, {}).get("title", ""))


func says() -> PackedStringArray:
	var out := PackedStringArray()
	for l: String in _node().get("says", []):
		out.append(l)
	return out


## What the player may say, in order. A reply with `when` is hidden until the
## player knows that fragment or has landed that beat: a conversation should not
## offer a question the player has no reason to ask. A reply that would land a
## revelation is hidden while another is still being felt (StoryPacing), and is
## there to be asked the next time.
func replies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in _node().get("replies", []):
		var when := StringName(str(r.get("when", &"")))
		if when != &"" and not (Story.knows(when) or Story.landed(when)):
			continue
		if StoryPacing.withheld(id, r):
			continue
		out.append(r)
	return out


## Say the i'th reply. Returns false when the conversation is over.
func pick(i: int) -> bool:
	var rs := replies()
	if over or i < 0 or i >= rs.size():
		return not over
	var r: Dictionary = rs[i]
	var said := StringName(str(r.get("pick", &"")))
	if said != &"":
		Story.choose(StringName("%s.%s" % [id, node]), said)
	for b: StringName in r.get("beats", []):
		Story.beat(b)
	var to := StringName(str(r.get("to", &"")))
	if to == &"" or not _nodes().has(to):
		over = true
		return false
	node = to
	_land(_node())
	return true


## Beats a node lands simply by being reached: what somebody tells you is knowing
## it, with no reply needed.
func _land(n: Dictionary) -> void:
	for b: StringName in n.get("beats", []):
		Story.beat(b)


func _nodes() -> Dictionary:
	return StoryContent.TALKS.get(id, {}).get("nodes", {})


func _node() -> Dictionary:
	return _nodes().get(node, {})
