extends Node
## Capture the live renderer without changing player progress or preferences.
## Every image is a real frame of the running game scene; nothing is composited.
var game: Node
var review_camera: Camera3D

func frames(count: int, physics: bool = false) -> void:
	for i in range(count):
		if physics: await get_tree().physics_frame
		else: await get_tree().process_frame

func save(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/" + file + ".png")

func shot(file: String, from: Vector3, target: Vector3, fov: float = 40.0, settle: int = 6) -> void:
	review_camera.fov = fov
	review_camera.global_position = from
	review_camera.look_at(target)
	# The project interpolates physics transforms; a teleported camera must not blend from its old place.
	review_camera.reset_physics_interpolation()
	review_camera.current = true
	await frames(settle)
	await save(file)

func measure(label: String) -> void:
	## Real measurement on this machine: uncapped frame rate and renderer counters for the current view.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await frames(30)
	var start := Time.get_ticks_usec()
	await frames(150)
	var seconds := (Time.get_ticks_usec() - start) / 1000000.0
	print("PERF %s: %.1f fps average (%.2f ms/frame), %d draw calls, %d primitives, %.0f MB video memory, quality preset %d, %dx%d, %s" % [label, 150.0 / seconds, seconds / 150.0 * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Settings.quality, get_window().size.x, get_window().size.y, RenderingServer.get_video_adapter_name()])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

func in_front(node: Node3D, distance: float, height: float, side: float = 0.0) -> Vector3:
	## A point in front of a character visual (visuals face their local -Z).
	var basis := node.global_transform.basis
	return node.global_position - basis.z * distance + basis.x * side + Vector3.UP * height

func _ready() -> void:
	I18n.set_locale("fr",false)
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate()
	add_child(game)
	game.set_mode("play")
	game.ui.gameplay()
	game.ui.update_hud()
	game.player.position=Vector3(0,0.1,10)
	game.player.reset_physics_interpolation()
	await frames(50, true)
	game.set_mode("play")
	game.ui.gameplay()
	await save("realism_camp")
	var camera:Camera3D=game.player.camera
	camera.set_as_top_level(true)
	camera.global_position=Vector3(-2,3.1,12)
	camera.look_at(Vector3(-10,1,-5))
	game.player.enabled=false
	game.ui.hide()
	await frames(10)
	await save("realism_detail")
	# --- Dedicated character views, in the real camp lighting.
	review_camera = Camera3D.new()
	review_camera.near = 0.05
	game.add_child(review_camera)
	var player_visual: Node3D = game.player.visual
	# Stand in the open and turn towards the sun so the stills show the lit face.
	game.player.position = game.world.ground(3.0, 16.0) + Vector3.UP * 0.02
	game.player.reset_physics_interpolation()
	player_visual.rotation.y = PI * 0.82
	await frames(20, true)
	var feet: Vector3 = game.player.global_position
	await shot("character_player_body", in_front(player_visual, 3.1, 1.05, 0.7), feet + Vector3.UP * 0.9, 38)
	await shot("character_player_back", in_front(player_visual, -3.0, 1.3, 0.9), feet + Vector3.UP * 0.95, 38)
	await shot("character_player_face", in_front(player_visual, 0.75, 1.63, 0.16), feet + Vector3.UP * 1.60, 26)
	await shot("character_player_hand", in_front(player_visual, 0.55, 0.95, -0.75), feet + Vector3.UP * 0.82 + player_visual.global_transform.basis.x * -0.24, 30)
	await shot("character_player_feet", in_front(player_visual, 0.9, 0.35, 0.5), feet + Vector3.UP * 0.07, 30)
	player_visual.rotation.y = 0.0
	# Each soldier where the game places him.
	for npc: Node3D in game.world.interactables:
		var visual := npc.get_node("Visual") as Node3D
		await shot("character_" + npc.dialogue_id + "_body", in_front(visual, 3.4, 1.2, 0.8), npc.global_position + Vector3.UP * 1.05, 40)
		await shot("character_" + npc.dialogue_id + "_face", in_front(visual, 0.8, 1.68, 0.18), npc.global_position + Vector3.UP * 1.62, 26)
	# Staged line-up: the same three live soldiers moved side by side for one comparison frame.
	var greeting_guard: Node3D = game.world.soldier.get_node("Visual")
	var old_player_position: Vector3 = game.player.position
	game.player.position = greeting_guard.to_global(Vector3(1.2, 0.0, -2.2))
	game.player.reset_physics_interpolation()
	await frames(70, true)
	await shot("character_guard_attention", in_front(greeting_guard, 1.1, 1.65, -0.1), game.world.soldier.global_position + Vector3.UP * 1.63, 30)
	game.player.position = old_player_position
	game.player.reset_physics_interpolation()
	var originals: Array[Transform3D] = []
	var index := 0
	for npc: Node3D in game.world.interactables:
		originals.append(npc.global_transform)
		var visual := npc.get_node("Visual") as Node3D
		npc.global_position = game.world.ground(-1.4 + index * 1.4, 6.0)
		npc.reset_physics_interpolation()
		visual.set_meta("review_rotation", visual.rotation.y)
		visual.rotation.y = PI + (index - 1) * -0.12
		index += 1
	await frames(4, true)
	await shot("character_soldiers_lineup", Vector3(0.5, 1.35, 10.6), Vector3(0, 1.0, 6.0), 36)
	await shot("character_soldiers_faces", Vector3(0.25, 1.62, 8.5), Vector3(0, 1.58, 6.0), 30)
	# Cost of the characters: the same line-up view with and without the four models.
	await shot("character_soldiers_lineup_wide", Vector3(0.5, 1.5, 11.5), Vector3(0, 1.0, 6.0), 50)
	await measure("line-up view, three soldiers visible")
	var visuals: Array[Node3D] = [player_visual]
	for npc: Node3D in game.world.interactables: visuals.append(npc.get_node("Visual") as Node3D)
	for visual: Node3D in visuals: visual.visible = false
	await measure("same view, characters hidden")
	for visual: Node3D in visuals: visual.visible = true
	index = 0
	for npc: Node3D in game.world.interactables:
		npc.global_transform = originals[index]
		npc.reset_physics_interpolation()
		var visual := npc.get_node("Visual") as Node3D
		visual.rotation.y = visual.get_meta("review_rotation")
		index += 1
	# --- Camp residents (ambient extras) where the game places them.
	var population: Node = game.world.get_node("CampPopulation")
	await shot("population_gate", Vector3(0.6, 1.7, 17.2), Vector3(0, 1.1, 12), 58)
	for group: Array in [["supplies", Vector3(-1.2, 1.5, 3.4)], ["tent", Vector3(1.6, 1.5, 3.4)], ["fire", Vector3(2.6, 1.6, 2.6)]]:
		var middle: Vector3 = (population.get_node(group[0] + "_a").global_position + population.get_node(group[0] + "_b").global_position) / 2
		await shot("population_" + group[0], middle + group[1], middle + Vector3.UP * 1.05, 40)
	await shot("population_camp_wide", Vector3(2.5, 4.2, 21.0), Vector3(-1.0, 0.8, 4.0), 58)
	await measure("camp overview with residents")
	for resident: Node3D in population.get_children(): resident.visible = false
	await measure("same overview, residents hidden")
	for resident: Node3D in population.get_children(): resident.visible = true
	var shown := {}
	for resident: Node3D in population.get_children():
		var resident_visual := resident.get_node("Visual") as Node3D
		if shown.has(resident_visual.variant): continue
		shown[resident_visual.variant] = true
		var head_height: float = resident_visual.bone_position("head").y * resident_visual.scale.y + 0.07
		await shot("population_face_" + resident_visual.variant, in_front(resident_visual, 0.85, head_height + 0.03, 0.2), resident.global_position + Vector3.UP * head_height, 26)
	# --- Player in motion through the real controller: walk, run and jump.
	game.player.position = game.world.ground(1.5, 24.0) + Vector3.UP * 0.1
	game.player.yaw = 0.0
	game.player.reset_physics_interpolation()
	game.player.enabled = true
	review_camera.current = true
	Input.action_press("move_forward")
	await frames(34, true)
	var p: Vector3 = game.player.global_position
	await shot("character_player_walk", p + Vector3(-3.4, 1.0, -0.6), p + Vector3(0, 0.9, -0.3), 40, 1)
	await frames(9, true)
	p = game.player.global_position
	await shot("character_player_walk2", p + Vector3(-2.2, 0.6, -3.0), p + Vector3(0, 0.85, -0.4), 40, 1)
	var walker: Node3D = population.get_node("runner_west")
	await shot("population_walker", walker.global_position + Vector3(1.2, 1.1, 3.4), walker.global_position + Vector3.UP * 0.9, 40, 1)
	Input.action_press("run")
	await frames(40, true)
	p = game.player.global_position
	await shot("character_player_run", p + Vector3(-3.6, 1.0, -1.0), p + Vector3(0, 0.9, -0.5), 40, 1)
	await frames(7, true)
	p = game.player.global_position
	await shot("character_player_run2", p + Vector3(-2.4, 0.7, -4.2), p + Vector3(0, 0.9, -0.9), 40, 1)
	Input.action_release("run")
	Input.action_press("jump")
	await frames(9, true)
	Input.action_release("jump")
	p = game.player.global_position
	await shot("character_player_jump", p + Vector3(-3.4, 0.9, -1.0), p + Vector3(0, 1.0, -0.5), 40, 1)
	await frames(50, true)
	# The gameplay camera view while moving, as the player sees it.
	game.player.camera.set_as_top_level(false)
	game.player.camera.transform = Transform3D.IDENTITY
	game.player.camera.current = true
	await frames(30, true)
	await save("character_player_gameplay")
	Input.action_release("move_forward")
	game.player.enabled = false
	print("ART REVIEW: captured live camp, detail and character views")
	get_tree().quit()
