## Oksana Ril, the last colonist, on the dead ring. Her voice is found on the ground
## early (the `ring_calling` radio); she is met in orbit, late. Until the orbital
## realm is grown her place casts nowhere, and she waits.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"oksana", "name": "Oksana", "title": "a woman on the ring",
		"at": &"the_ring", "talk": &"oksana", "trade": &"gatherer",
		"look": {"build": &"woman", "hair": &"white", "hair_style": &"long", "beard": &"none"},
		"may_join": true,
		"wants": "To be heard.",
		"fears": "That the calling was for nobody.",
		"hides": "Priya Nand's last notebook, and four years of the Guest's signal, written out by hand.",
	})
