extends TestCase
## No two gate shards may reach one `user://` directory.
##
## `tools/check.sh` starts three godot processes with `--shard=I/3` and Godot's
## `user://` is one path per PROJECT, not per process, so every root a test wrote
## was a directory all three wrote together. It cost a full gate cycle: an md5 of
## "" is a file another shard deleted mid-test, and "Nothing is saved there" is a
## slot another shard cleared.
##
## This file exists because of HOW it came back rather than how bad it was.
## `--shard=I/N` splits test FILES round-robin, so which tests collide changes
## every time a file is added or renamed -- the failure moves, and the diff that
## brings it back never mentions saves. And the honest response to a red gate is
## to run it again, which makes it green, so the bug trains people to re-run
## instead of read. Two tests had already worked around it by hand with
## timestamped roots (test_bank, test_score_system) without the cause being named.
##
## So: a name that does not carry its shard fails here, not in a fortnight.


## Every family a test writes into, as {what: the function that names it}. A new
## `user://` root added to the game belongs in this list on the same commit.
func roots_for(shard: int) -> Dictionary:
	return {
		"saves": SaveSlots.shard_root(shard),
		"settings": PlayerSettings.shard_file(shard),
		"dev": DevMode.shard_root(shard),
	}


func test_no_two_shards_share_a_root() -> void:
	for a in 4:
		for b in 4:
			if a == b:
				continue
			var ra := roots_for(a)
			var rb := roots_for(b)
			for what: String in ra:
				check(ra[what] != rb[what],
					"shard %d and shard %d must not share a %s root (both %s)" % [a, b, what, ra[what]])


## The shard's root still has to ANSWER to the base, or `SaveSlots.testing()` and
## every `begins_with(TEST_ROOT)` check stops recognising a test run -- which is
## how a suffix quietly turns the runner into something that writes a player's
## own saves.
func test_a_shards_root_is_still_a_test_root() -> void:
	for i in 4:
		check(SaveSlots.shard_root(i).begins_with(SaveSlots.TEST_ROOT),
			"saves shard %d answers to TEST_ROOT (%s)" % [i, SaveSlots.shard_root(i)])
		check(DevMode.shard_root(i).begins_with(DevMode.TEST_ROOT),
			"dev shard %d answers to TEST_ROOT (%s)" % [i, DevMode.shard_root(i)])
		check(PlayerSettings.shard_file(i).begins_with("user://test-settings"),
			"settings shard %d is still a test file (%s)" % [i, PlayerSettings.shard_file(i)])


## And none of them may be the player's own, whatever the shard.
func test_no_shard_can_reach_the_players_own() -> void:
	for i in 4:
		check(not SaveSlots.shard_root(i).begins_with(SaveSlots.PLAYER_ROOT),
			"shard %d keeps clear of the player's saves" % i)
		check(PlayerSettings.shard_file(i) != PlayerSettings.FILE,
			"shard %d keeps clear of the player's settings" % i)


## The runner really did hand this process its own, rather than leaving the
## shared default in place: a test that passes the three above and never has
## them APPLIED proves nothing about the gate.
func test_this_process_took_the_root_it_was_given() -> void:
	check(SaveSlots.root.begins_with(SaveSlots.TEST_ROOT),
		"saves are in the test runner's own place (%s)" % SaveSlots.root)
	eq(SaveSlots.test_root, SaveSlots.root, "and `root` is the shard's, not the base")
	check(PlayerSettings.test_file.begins_with("user://test-settings"),
		"settings are the test runner's own (%s)" % PlayerSettings.test_file)
