class_name StoryPacing
## Revelations one at a time (docs/STORY.md): "the next waits until the last
## has been felt."
##
## A beat marked `reveal` in StoryContent.BEATS is a revelation: something about
## who Elias was, or what the world is, that changes how everything after it reads.
## After one lands, the story offers no other for SETTLE world minutes. What that
## holds back is what the story OFFERS, never what the player already did:
##
##   a REPLY that would land a new revelation is not offered while one is settling
##     (StoryTalk.replies), so a conversation stops short and is there to be finished
##     later, with the same person, in a quiet that is its own;
##   a PERSON who waits on a revelation (`appears_when`) is not there until it has
##     settled, so June does not stand in the square the minute her name is said.
##
## A thing READ is never held. A page cannot be unread, and a stranger's notebook
## that says too much too soon is the world being what it is. A beat the player's
## own state lands (WITNESSED) is not held either, because it has already happened
## to him — but both count as the revelation that everything else then waits on.
##
## Pure: it reads `Story` and the clock `Story.now`, and a test sets both by hand.

## World minutes a revelation takes to settle. Four real minutes at
## Tuning.MINUTES_PER_SECOND, and a slept night settles anything.
const SETTLE := 240.0


static func is_reveal(beat: StringName) -> bool:
	return bool(StoryContent.BEATS.get(beat, {}).get("reveal", false))


## The revelation that landed last, or &"".
static func last_reveal() -> StringName:
	var best := &""
	var best_at := -INF
	for b: StringName in Story.landed_beats():
		if not is_reveal(b):
			continue
		var at := Story.landed_at(b)
		if at > best_at:
			best_at = at
			best = b
	return best


## Whether a revelation is still being felt.
static func settling() -> bool:
	var b := last_reveal()
	return b != &"" and Story.now - Story.landed_at(b) < SETTLE


## World minutes until the last revelation has settled, 0 when none is settling.
static func settles_in() -> float:
	var b := last_reveal()
	if b == &"":
		return 0.0
	return maxf(0.0, SETTLE - (Story.now - Story.landed_at(b)))


## Whether this beat has landed and, if it is a revelation, been felt.
static func felt(beat: StringName) -> bool:
	if not Story.landed(beat):
		return false
	return not is_reveal(beat) or Story.now - Story.landed_at(beat) >= SETTLE


## Whether a reply is held back: it would land a revelation not yet landed, by
## itself or by the node it leads to, while another is still settling.
static func withheld(talk_id: StringName, reply: Dictionary) -> bool:
	if not settling():
		return false
	for b: StringName in _lands(talk_id, reply):
		if is_reveal(b) and not Story.landed(b):
			return true
	return false


static func _lands(talk_id: StringName, reply: Dictionary) -> Array:
	var out: Array = reply.get("beats", []).duplicate()
	var to := StringName(str(reply.get("to", &"")))
	var node: Dictionary = StoryContent.TALKS.get(talk_id, {}).get("nodes", {}).get(to, {})
	out.append_array(node.get("beats", []))
	return out
