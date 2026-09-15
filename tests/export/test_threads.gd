extends TestCase
## The web build has 4 pool threads. A pool thread that waits on a nested group
## holds its thread, so world generation must never nest groups: a parallel pass
## started inside another group's element runs inline on that element's thread.
## (Before this rule, a 4-thread pool deadlocked in GenSurface's together() of
## near_steps(), and the threaded web build never drew a world.)


func test_a_pass_inside_a_group_runs_inline() -> void:
	var outer_ids: Array[int] = [-1, -1, -1]
	var inner_ids: Array = [[], [], []]
	var jobs: Array[Callable] = []
	for j in 3:
		jobs.append(func() -> void:
			outer_ids[j] = WorkerThreadPool.get_caller_group_id()
			var seen: Array[int] = []
			GenFields.rows(48, func(_y0: int, _y1: int) -> void:
				seen.append(WorkerThreadPool.get_caller_group_id()), 12)
			inner_ids[j] = seen)
	GenFields.together(jobs)
	for j in 3:
		check(outer_ids[j] >= 0, "job %d ran in a group" % j)
		eq((inner_ids[j] as Array).size(), 4, "every band of job %d ran" % j)
		for id: int in inner_ids[j]:
			eq(id, outer_ids[j], "a band of job %d ran on its element's thread, not a nested group" % j)


func test_a_pass_from_outside_a_group_still_uses_the_pool() -> void:
	var ids: Array[int] = []
	var mutex := Mutex.new()
	GenFields.rows(48, func(_y0: int, _y1: int) -> void:
		mutex.lock()
		ids.append(WorkerThreadPool.get_caller_group_id())
		mutex.unlock(), 12)
	eq(ids.size(), 4)
	for id in ids:
		check(id >= 0, "bands run as a pool group")
