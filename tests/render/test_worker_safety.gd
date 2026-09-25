extends TestCase

## WHAT A WORKER MAY MAKE. A view is set up on a worker (the boot page's `view`
## stage, the title's next coast), and creating a texture from a worker waits on
## the main thread, which is how every test that built a title once hung
## (world_view.gd says so where the far textures moved). The works map's two
## textures were still being made there, in `_bind`. They are bound on the main
## thread now, the first time the view draws or is asked for its material.
func test_a_view_set_up_on_a_worker_makes_its_textures_on_the_main_thread() -> void:
	var w := WorldGen.generate(3, 64)
	var view := WorldView.new()
	var task := WorkerThreadPool.add_task(func() -> void: view.setup(w))
	WorkerThreadPool.wait_for_task_completion(task)
	var mat := view.get("_world_mat") as ShaderMaterial
	check(mat != null, "the view has its material")
	if mat != null:
		eq(mat.get_shader_parameter("works_map"), null, "no works texture was made on the worker")
	var drawn := view.world_material()
	check(drawn.get_shader_parameter("works_map") is Texture2D, "and it is there once the main thread asks")
	view.free()
