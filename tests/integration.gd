extends Node
## Runs real scene + physics + UI callbacks. Backs up and restores the user's save.
const Store = preload("res://scripts/save/save_store.gd")
var failures := 0
var game: Node
var original_save := ""
var had_save := false
var language_backup := ""
var had_language := false
var initial_locale := "ht"

func check(condition: bool, description: String) -> void:
	if condition: print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for i in range(count): await get_tree().physics_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/" + name + ".png")

func walk_to(target: Vector2) -> void:
	for i in range(900):
		var offset := target - Vector2(game.player.position.x, game.player.position.z)
		if offset.length() < 0.3: break
		var direction := offset.normalized()
		Input.action_press("move_right", maxf(direction.x, 0))
		Input.action_press("move_left", maxf(-direction.x, 0))
		Input.action_press("move_back", maxf(direction.y, 0))
		Input.action_press("move_forward", maxf(-direction.y, 0))
		await frames(1)
	for action: String in ["move_right","move_left","move_back","move_forward"]: Input.action_release(action)
	await frames(12)
	check(Vector2(game.player.position.x,game.player.position.z).distance_to(target) < 0.65, "Walkable route to %s" % target)

func finish_dialogue() -> void:
	for i in range(5):
		if game.mode != "dialogue": break
		game.next_dialogue()

func _ready() -> void:
	initial_locale = I18n.locale
	had_language = FileAccess.file_exists(I18n.config_path())
	if had_language: language_backup = FileAccess.get_file_as_string(I18n.config_path())
	had_save = FileAccess.file_exists(Store.active_path())
	if had_save: original_save = FileAccess.get_file_as_string(Store.active_path())
	game = load("res://scenes/main/main.tscn").instantiate()
	add_child(game)
	await frames(5)
	check(game.mode == "menu", "Main menu starts")
	await capture("menu")
	var keys: Array = I18n.strings.keys()
	for locale: String in I18n.CODES:
		I18n.set_locale(locale, false)
		check(I18n.strings.size() == keys.size(), "Complete UI keys: " + locale)
		var complete_keys := true
		for key: String in keys: complete_keys = complete_keys and I18n.strings.has(key) and not I18n.text(key).is_empty()
		check(complete_keys, "All UI strings populated: " + locale)
		check(I18n.question("elah_challenge_02").answers.size() == 4 and I18n.question("elah_challenge_02").correct == 2, "Mission 02 question contract: " + locale)
		game.show_menu()
		await frames(2)
		await capture("menu_" + locale)
		check(game.ui.card.size.y <= 700, "Menu fits 720px layout: " + locale)
		game.show_settings("menu")
		await frames(2)
		check(game.ui.card.size.y <= 700, "Settings fit 720px layout: " + locale)
		await capture("settings_" + locale)
	I18n.set_locale("en", false)
	game.show_menu()
	game.new_game()
	await frames(30)
	check(game.player.is_on_floor(), "Player settles on terrain")
	var start: Vector3 = game.player.position
	Input.action_press("move_forward")
	await frames(40)
	Input.action_release("move_forward")
	await frames(15)
	check(game.player.position.z < start.z - 1, "W moves forward with camera-relative physics")
	check(absf(game.player.velocity.z) < 0.01, "Movement decelerates to rest")
	Input.action_press("run")
	Input.action_press("move_right")
	await frames(30)
	check(game.player.velocity.x > 5.5, "Shift reaches running speed")
	Input.action_release("run")
	Input.action_release("move_right")
	await frames(20)
	Input.action_press("jump")
	await frames(8)
	Input.action_release("jump")
	check(game.player.position.y > 0.4, "Space jumps")
	await frames(60)
	check(game.player.is_on_floor(), "Gravity returns player to ground")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(40, -20)
	game.player._unhandled_input(mouse)
	if DisplayServer.get_name() != "headless":
		check(game.player.yaw < -0.01 and game.player.pitch > -0.16, "Mouse rotates camera rig")
	else: print("SKIP: Mouse capture requires graphical renderer")
	game.player.yaw = 0
	game.player.pitch = -0.16
	game.player.rig.rotation = Vector3(-0.16, 0, 0)
	game.show_pause()
	start = game.player.position
	Input.action_press("move_forward")
	await frames(20)
	Input.action_release("move_forward")
	check(game.player.position.is_equal_approx(start), "Pause freezes movement")
	game.resume()
	game.player.position = Vector3(0, 0.05, 4.3)
	game.player.reset_physics_interpolation()
	await frames(20)
	check(game.active_interactable == game.world.soldier, "Approach detects soldier")
	await capture("camp")
	check(game.world.sun.shadow_enabled, "Low preset includes contact shadows")
	await check_characters()
	await check_population()
	await check_hud()
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	game._unhandled_input(interact)
	check(game.mode == "dialogue" and Progress.stage == "learn", "Interaction opens dialogue and advances quest")
	game.next_dialogue()
	game.next_dialogue()
	game.next_dialogue()
	check(game.mode == "quiz", "Dialogue opens quiz")
	game.answer_buttons[0].pressed.emit()
	check(Progress.xp == 0 and Progress.stage == "learn" and game.quiz_continue.disabled, "Wrong answer allows retry without reward")
	await capture("quiz")
	game.answer_buttons[1].pressed.emit()
	check(Progress.stage == "complete" and Progress.xp == 25, "Correct answer completes mission and awards XP")
	check(not Progress.answer("elah_stones_01", 1) and Progress.xp == 25, "Repeated answer cannot farm XP")
	check(not Progress.chapter_complete, "Phase 1 does not complete biblical chapter")
	game.quiz_continue.pressed.emit()
	check(game.mode == "complete", "Completion screen opens")
	await capture("completion")
	game.save_game()
	var data: Dictionary = Store.read_save()
	check(not data.is_empty() and data.progress.xp == 25, "Save round trip preserves reward")
	game.show_menu()
	Progress.reset()
	game.continue_game()
	check(Progress.stage == "challenge" and Progress.xp == 25, "Continue restores mission and unlocks Mission 02")
	var legacy := data.duplicate(true)
	legacy.version = 1
	var migrated := Store.migrate(legacy)
	check(not migrated.is_empty() and migrated.version == 2 and migrated.progress.xp == 25, "Schema 1 migration preserves completed Mission 01")
	legacy.progress.xp = 999
	check(Store.migrate(legacy).is_empty(), "Invalid legacy save cannot migrate")
	var before: Dictionary = Progress.snapshot()
	game.start_dialogue("veteran")
	finish_dialogue()
	check(Progress.snapshot() == before and game.mode == "play", "Veteran cannot skip lookout prerequisite")
	await walk_to(Vector2(3,4.3))
	await walk_to(Vector2(3,-4))
	await walk_to(Vector2(8,-10.8))
	check(game.active_interactable != null and game.active_interactable.dialogue_id == "watchman", "Lookout reachable through terrain")
	await capture("lookout")
	game._unhandled_input(interact)
	check(game.dialogue_id == "watchman", "E opens lookout dialogue")
	game.resume()
	check(Progress.stage == "challenge", "Abandoned conversation does not satisfy objective")
	game.start_dialogue("watchman")
	finish_dialogue()
	check(Progress.stage == "witness", "Finished lookout dialogue unlocks veteran")
	game.show_menu()
	game.continue_game()
	check(Progress.stage == "witness", "Mid-mission checkpoint survives reload")
	game.show_settings("pause")
	var selector := game.ui.content.get_node("LanguagePicker") as OptionButton
	selector.item_selected.emit(1)
	check(I18n.locale == "fr" and game.ui.heading.text == "Paramètres", "Settings selector redraws language immediately")
	var cfg := ConfigFile.new()
	cfg.load(I18n.config_path())
	check(cfg.get_value("language","locale") == "fr", "Language choice persists")
	game.leave_settings()
	game.resume()
	check(Progress.stage == "witness" and Progress.xp == 25, "Language change preserves mission state")
	await walk_to(Vector2(3,-4))
	await walk_to(Vector2(-12,-6.7))
	check(game.active_interactable != null and game.active_interactable.dialogue_id == "veteran", "Veteran reachable through camp")
	await capture("veteran")
	game._unhandled_input(interact)
	finish_dialogue()
	check(game.mode == "quiz" and Progress.stage == "challenge_quiz", "Veteran unlocks Mission 02 quiz")
	for locale: String in I18n.CODES:
		I18n.set_locale(locale, false)
		game.show_quiz()
		await frames(2)
		await capture("mission02_" + locale)
		check(game.ui.card.size.y <= 700, "Mission 02 quiz fits: " + locale)
	game.choose_answer(0)
	check(Progress.xp == 25 and Progress.stage == "challenge_quiz", "Mission 02 wrong answer has no reward")
	game.choose_answer(2)
	check(Progress.xp == 60 and Progress.stage == "chapter_pause" and Progress.completed_questions.size() == 2, "Mission 02 complete with 60 total XP")
	check(not Progress.answer("elah_challenge_02", 2) and Progress.xp == 60, "Mission 02 cannot award duplicate XP")
	game.finish_quiz()
	await capture("mission02_complete")
	game.show_menu()
	game.continue_game()
	check(Progress.stage == "chapter_pause" and not Progress.chapter_complete, "Completed missions reload without finishing biblical chapter")
	# Collision sampling on sloped ground and in the recessed riverbed.
	for location: Vector2 in [Vector2(28,12),Vector2(20,12),Vector2(-30,-20)]:
		var ground_y: float = game.world.ground_height(location.x,location.y)
		game.player.position = Vector3(location.x,ground_y+1,location.y)
		game.player.reset_physics_interpolation()
		await frames(65)
		check(game.player.is_on_floor() and absf(game.player.position.y-ground_y)<0.18, "Terrain collider matches visible surface at %s" % location)
	I18n.set_locale("en", false)
	var bad := data.duplicate(true)
	bad.position = [999, 0, 0]
	check(not Store.valid(bad), "Reject out-of-bounds save")
	bad = data.duplicate(true)
	bad.progress.xp = 999
	check(not Store.valid(bad), "Reject inconsistent XP")
	bad = data.duplicate(true)
	bad.version = 99
	check(not Store.valid(bad), "Reject unsupported schema")
	check(not Store.valid({}) and not Store.valid(null), "Reject missing fields and malformed data")
	var file := FileAccess.open("user://test_corrupt.json", FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(Store.read_save("user://test_corrupt.json").is_empty(), "Corrupt JSON handled gracefully")
	DirAccess.remove_absolute("user://test_corrupt.json")
	game.show_settings("pause")
	await capture("settings")
	game.leave_settings()
	check(game.mode == "pause", "Settings returns to pause")
	# Camera obstruction: place a wall behind the player and check the spring arm.
	game.resume()
	# A wall on world +Z only tests obstruction if the camera faces that wall.
	# Stop physical mouse motion from changing this deterministic test setup.
	game.player.set_process_unhandled_input(false)
	game.player.yaw = 0.0
	game.player.pitch = -0.16
	game.player.rig.rotation = Vector3(-0.16, 0, 0)
	game.player.velocity = Vector3.ZERO
	game.player.position = Vector3(0, 0.05, 0)
	game.player.reset_physics_interpolation()
	preload("res://scripts/world/geometry.gd").box(game.world, Vector3(0, 2, 2), Vector3(5, 4, 0.3), preload("res://scripts/world/geometry.gd").material(Color.GRAY), true)
	await frames(20)
	check(game.player.arm.get_hit_length() < 3, "Spring arm retracts against scenery")
	game.player.position = Vector3(0, 0.05, 43)
	game.player.reset_physics_interpolation()
	Input.action_press("move_back")
	await frames(60)
	Input.action_release("move_back")
	check(game.player.position.z < 44.3, "Playable boundary blocks movement")
	# Restore original save and language even after failed checks.
	I18n.set_locale(initial_locale, false)
	if had_language:
		file = FileAccess.open(I18n.config_path(), FileAccess.WRITE)
		file.store_string(language_backup)
		file.close()
	else: DirAccess.remove_absolute(I18n.config_path())
	if had_save:
		file = FileAccess.open(Store.active_path(), FileAccess.WRITE)
		file.store_string(original_save)
		file.close()
	else: DirAccess.remove_absolute(Store.active_path())
	print("INTEGRATION RESULT: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func check_hud() -> void:
	## Mission tracker and mini-map: present in play, hidden in menus, positions make sense.
	var map = game.ui.minimap
	var centre := Vector2(map.RADIUS, map.RADIUS)
	check(map.is_visible_in_tree() and game.ui.mission_panel.is_visible_in_tree(), "Mini-map and mission tracker are shown during play")
	check(map.to_map(game.player.position).distance_to(centre) < 0.01, "Mini-map keeps the player in its centre")
	var soldier_point: Vector2 = map.to_map(game.world.soldier.position)
	check(soldier_point.distance_to(centre) < map.RADIUS and soldier_point.y < centre.y, "Objective ahead of the camera is drawn above the player on the mini-map")
	game.player.yaw = PI
	check(map.to_map(game.world.soldier.position).y > centre.y, "Mini-map rotates with the camera")
	game.player.yaw = 0.0
	check(game.ui.mission_title.text == I18n.text("m1") and game.ui.hud.text.contains(Progress.objective()) and game.ui.xp_bar.max_value == 60, "Mission tracker shows mission, objective and the 60 XP total")
	check(game.ui.prompt_panel.visible and not game.ui.prompt.text.is_empty() and map.target_text.contains(I18n.text("soldier_intro")), "Interaction prompt and objective distance are displayed")
	game.show_pause()
	await frames(2)
	check(not map.is_visible_in_tree() and not game.ui.mission_panel.is_visible_in_tree() and not game.ui.prompt_panel.visible, "HUD is hidden behind menus")
	game.resume()
	await frames(2)

func check_population() -> void:
	var population: Node = game.world.get_node("CampPopulation")
	check(population.get_child_count() == 10 and game.world.interactables.size() == 3, "Ten ambient residents leave exactly three mission interactables")
	var walker = population.get_node("runner_west")
	var start: Vector3 = walker.position
	# He may be resting at a waypoint (2.5 s), so allow one full pause before he sets off again.
	for i in range(300):
		await frames(1)
		if walker.position.distance_to(start) > 0.5: break
	check(walker.position.distance_to(start) > 0.5, "Ambient walker travels along his camp route")
	check(walker.visual.state == "walk", "Ambient walker plays the walk cycle while travelling")
	var faces := {}
	var talkers := 0
	for resident: Node in population.get_children():
		faces[resident.visual.variant] = true
		if resident.visual.idle_clip == "talk" and resident.visual.has_clip("talk"): talkers += 1
	check(faces.size() == 8 and not faces.has("observer") and not faces.has("soldier_intro"), "Residents use eight models of their own, none shared with the player or mission soldiers")
	check(talkers >= 5, "Conversation groups play the talk clip")
	game.show_pause()
	await frames(3)
	start = walker.position
	await frames(20)
	check(Vector2(walker.position.x, walker.position.z).distance_to(Vector2(start.x, start.z)) < 0.01, "Ambient travel pauses with the game")
	game.resume()
	var saved_position: Vector3 = game.player.position
	game.player.enabled = false
	game.player.position = walker.position + Vector3(0.7, 0.0, 0.0)
	game.player.enabled = true
	await frames(3)
	start = walker.position
	await frames(20)
	check(Vector2(walker.position.x, walker.position.z).distance_to(Vector2(start.x, start.z)) < 0.05, "Ambient walker yields near the player")
	game.player.position = saved_position
	game.player.reset_physics_interpolation()
	await frames(5)

func check_characters() -> void:
	## Rigged character models: skeleton, clips, grounded feet, in-place animation, live playback.
	var visual = game.player.visual
	var skeleton: Skeleton3D = visual.skeleton
	check(skeleton != null and skeleton.get_bone_count() >= 50, "Player model has a skinned skeleton")
	var bones_ok := skeleton != null
	for bone: String in ["Root","pelvis","spine_03","head","upperarm_l","lowerarm_r","hand_r","index_02_l","thigh_l","calf_r","foot_l","ball_r"]:
		bones_ok = bones_ok and skeleton.find_bone(bone) >= 0
	check(bones_ok, "Skeleton has the expected body, hand and foot bones")
	var skinned := 0
	for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).skin != null: skinned += 1
	check(skinned >= 6, "Body, hair and clothing meshes are skinned to the skeleton")
	var clips_ok := true
	for clip: String in ["idle","walk","run","jump"]: clips_ok = clips_ok and visual.has_clip(clip) and visual.clip(clip).length > 0.3
	check(clips_ok, "Idle, walk, run and jump clips are imported")
	check(clips_ok and visual.clip("walk").loop_mode == Animation.LOOP_LINEAR and visual.clip("jump").loop_mode == Animation.LOOP_NONE, "Locomotion clips loop and the jump does not")
	check(visual.animation_tree != null and visual.animation_tree.active, "AnimationTree drives the player model")
	var head_height: float = visual.bone_position("head").y
	check(head_height > 1.45 and head_height < 1.72, "Standing head bone height matches a ~1.75 m human")
	var lowest_foot: float = minf(visual.bone_position("ball_l").y, visual.bone_position("ball_r").y)
	check(lowest_foot > -0.02 and lowest_foot < 0.07, "Idle feet rest on the ground plane")
	# Run and sample the pose: limbs must move, the model must not drift from its controller.
	var samples: Array[float] = []
	var drift := 0.0
	var lowest := 1.0
	Input.action_press("run")
	Input.action_press("move_back")
	for i in range(45):
		await frames(1)
		samples.append(visual.bone_position("foot_l").z)
		drift = maxf(drift, Vector2(visual.bone_position("Root").x, visual.bone_position("Root").z).length())
		lowest = minf(lowest, minf(visual.bone_position("ball_l").y, visual.bone_position("ball_r").y))
	check(visual.state == "run", "Adapter reports the run state at running speed")
	Input.action_release("run")
	Input.action_release("move_back")
	check(samples.max() - samples.min() > 0.35, "Running animation swings the legs")
	check(drift < 0.01, "Animations are in place: no doubled root motion")
	check(lowest > -0.06, "Running feet stay above the ground plane")
	await frames(40)
	check(visual.state == "idle", "Adapter returns to idle at rest")
	Input.action_press("jump")
	await frames(6)
	Input.action_release("jump")
	check(visual.state == "jump" and visual.bone_position("foot_l").y > 0.15, "Jump clip lifts the feet while airborne")
	await frames(60)
	# The three soldiers use their own models with a guard clip, shield and spear.
	var soldiers_ok := true
	var distinct := {}
	for npc: Node3D in game.world.interactables:
		var npc_visual = npc.get_node_or_null("Visual")
		soldiers_ok = soldiers_ok and npc_visual != null and npc_visual.skeleton != null and npc_visual.animation_player != null
		if not soldiers_ok: break
		soldiers_ok = soldiers_ok and npc_visual.animation_player.is_playing() and npc_visual.animation_player.current_animation == npc_visual.clip_name("guard")
		soldiers_ok = soldiers_ok and npc_visual.find_children("*gear*", "MeshInstance3D", true, false).size() == 1
		distinct[npc_visual.variant] = true
	check(soldiers_ok, "Each soldier has a rigged model playing the guard clip with equipment")
	check(distinct.size() == 3, "The three soldiers use three distinct models")
	var guard = game.world.soldier.get_node("Visual")
	var attention = guard.skeleton.get_node("GuardAttention")
	var observed_head: Array[Basis] = [Basis.IDENTITY]
	var sample_head := func() -> void:
		observed_head[0] = guard.skeleton.get_bone_global_pose(guard.skeleton.find_bone("head")).basis
	attention.modification_processed.connect(sample_head)
	game.player.enabled = false
	game.player.position = guard.to_global(Vector3(0.9, 0.0, -2.0))
	game.player.reset_physics_interpolation()
	await frames(70)
	check(attention.attending and absf(attention.yaw) > 0.1 and absf(attention.yaw) <= 0.55, "Guard acknowledges a nearby observer with a limited head turn")
	var turned_head := observed_head[0]
	game.player.position = guard.to_global(Vector3(0, 0, 2.0))
	game.player.reset_physics_interpolation()
	await frames(70)
	check(not attention.attending and absf(attention.yaw) < 0.03, "Guard returns to neutral when the observer goes behind him")
	check(turned_head.get_rotation_quaternion().angle_to(observed_head[0].get_rotation_quaternion()) > 0.1, "Attention changes the rendered head bone pose")
	attention.modification_processed.disconnect(sample_head)
	game.player.enabled = true
	game.player.position = Vector3(0, 0.05, 4.3)
	game.player.reset_physics_interpolation()
	await frames(20)
