class_name StorySecret
## Where he hid it (docs/STORY.md): in the ORDER of three ordinary memories,
## the kitchen at night, a song in the car, June's play. A living brain reliving
## them in order turns the key. His own hand scratched the order on a wall
## (`three_words`): kitchen. car. the hall. in that order.
##
## The keepers hold two of them and the Seeker's 2029 gives the third back, in
## whatever order he meets them, and that order commits nothing (ruled
## 2026-09-28). With all three back he holds it (`HELD`). The version is decided
## at the channel, by the order he relives them in there (`the_channel.relive`),
## which lands `secret_whole` or `secret_misremembered`. Pure: reads Story.

const KEY: Array[StringName] = [&"mem_kitchen", &"mem_car", &"mem_hall"]
## Landed once all three are back, in any order: what opens the channel's choice.
const HELD := &"secret_held"


## The memories back so far, in the order they came back. Colour only: the dev
## page shows it; nothing decides on it.
static func order() -> Array[StringName]:
	var got: Array[StringName] = []
	for m: StringName in KEY:
		if Story.landed(m):
			got.append(m)
	got.sort_custom(func(a: StringName, b: StringName) -> bool: return Story.landed_at(a) < Story.landed_at(b))
	return got


static func complete() -> bool:
	return order().size() == KEY.size()


## Whether he relived them at the channel in the order he hid them in.
static func whole() -> bool:
	return Story.landed(&"secret_whole")
