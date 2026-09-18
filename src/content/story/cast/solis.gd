## Adrian Solis keeps the Covenant's peace. Not wholly human, and not the villain:
## he believes the peace is the only thing keeping anyone alive, and he may be right.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"solis", "name": "Solis", "title": "the Covenant's warden",
		"at": &"the_covenant", "talk": &"solis", "trade": &"keeper",
		"look": {"build": &"stark", "hair": &"grey", "hair_style": &"crop", "beard": &"none", "coat": &"long"},
		"wants": "Order.",
		"fears": "Being the last human thing about himself.",
		"hides": "He is not wholly human. The machines made what the war left of him.",
	})
