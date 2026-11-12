extends Node
const SaveStore = preload("res://scripts/save/save_store.gd")
const Detector = preload("res://scripts/interactions/detector.gd")
var world: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var mode := "menu"
var active_interactable: Node3D
var dialogue: Dictionary
var dialogue_index := 0
var speaking_id := ""
var dialogue_id := ""
var question_id := ""
var feedback: Label
var answer_buttons: Array[Button] = []
var quiz_continue: Button
var return_mode := "menu"
var save_result := OK

func t(key: String) -> String:
	return I18n.text(key)

func _ready() -> void:
	# This snapshot makes the world visible in the editor; gameplay creates live systems.
	var preview := get_node_or_null("EditorPreview")
	if preview:
		remove_child(preview)
		preview.free()
	setup_input()
	world = preload("res://scripts/world/world.gd").new()
	add_child(world)
	player = preload("res://scripts/player/player.gd").new()
	player.position = Vector3(0, 0.1, 12)
	add_child(player)
	player.collision_mask = 5
	ui = preload("res://scripts/ui/interface.gd").new()
	add_child(ui)
	for npc: Node3D in world.interactables: npc.activated.connect(start_dialogue)
	Progress.changed.connect(ui.update_hud)
	Progress.changed.connect(on_progress_changed)
	get_window().focus_exited.connect(on_focus_lost)
	show_menu()

func setup_input() -> void:
	var keys := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "run": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E, "pause": KEY_ESCAPE}
	for action: String in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)

func set_mode(next: String) -> void:
	mode = next
	player.enabled = mode == "play"
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == "play" else Input.MOUSE_MODE_VISIBLE

func language_picker() -> void:
	var picker := OptionButton.new()
	picker.name = "LanguagePicker"
	for name_text: String in I18n.NAMES: picker.add_item(name_text)
	picker.select(I18n.CODES.find(I18n.locale))
	picker.item_selected.connect(func(index: int):
		I18n.set_locale(I18n.CODES[index])
		if mode == "menu": show_menu()
		else: show_settings(return_mode))
	ui.content.add_child(picker)

func show_menu() -> void:
	set_mode("menu")
	ui.clear("BIBLIA QUEST", t("chapter"))
	ui.label(t("title"), 34)
	ui.label(t("subtitle"), 19)
	language_picker()
	ui.button(t("new"), request_new_game)
	var saved := SaveStore.read_save()
	ui.button(t("continue"), continue_game, saved.is_empty())
	ui.button(t("settings"), func(): show_settings("menu"))
	ui.button(t("exit"), func(): get_tree().quit())
	ui.label(t("disclaimer"), 15)
	if saved.is_empty() and (FileAccess.file_exists(SaveStore.active_path()) or (SaveStore.active_path() == SaveStore.PATH and FileAccess.file_exists(SaveStore.LEGACY_PATH))):
		ui.label(t("bad_save"), 16)

func request_new_game() -> void:
	if not SaveStore.read_save().is_empty():
		ui.clear(t("restart"))
		ui.label(t("replace"))
		ui.button(t("new"), new_game)
		ui.button(t("back"), show_menu)
	else: new_game()

func new_game() -> void:
	set_mode("menu")
	Progress.reset()
	player.position = Vector3(0, 0.1, 12)
	player.safe_position = player.position
	player.yaw = 0
	player.pitch = -0.16
	player.rig.rotation = Vector3(-0.16, 0, 0)
	player.reset_physics_interpolation()
	resume()
	save_game()

func continue_game() -> void:
	var data := SaveStore.read_save()
	if data.is_empty():
		show_menu()
		return
	set_mode("menu")
	Progress.restore(data.progress)
	player.position = Vector3(data.position[0], data.position[1], data.position[2])
	# Project old positions onto the revised terrain, also protects from embedded restores.
	player.position.y = maxf(player.position.y, world.ground_height(player.position.x, player.position.z) + 0.1)
	player.safe_position = player.position
	player.reset_physics_interpolation()
	resume()

func resume() -> void:
	set_mode("play")
	if Progress.stage == "complete": Progress.event("begin_challenge")
	ui.gameplay()
	ui.update_hud()

func _physics_process(_delta: float) -> void:
	if mode != "play": return
	active_interactable = Detector.nearest(player, world.interactables)
	ui.prompt.text = t("talk") % t(active_interactable.dialogue_id) if active_interactable else ""
	var target_id: String = Progress.definition().target
	ui.waypoint.text = ""
	for npc: Node3D in world.interactables:
		if npc.dialogue_id == target_id:
			ui.waypoint.text = t("target") % [t(target_id), int(player.position.distance_to(npc.position))]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if mode == "play": show_pause()
		elif mode == "pause": resume()
		elif mode == "dialogue" or mode == "quiz": save_game(); resume()
		elif mode == "settings": leave_settings()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and mode == "play" and active_interactable != null:
		active_interactable.interact()

func save_notice() -> String:
	return t("saved") if save_result == OK else t("save_failed") % save_result

func show_pause() -> void:
	set_mode("pause")
	save_game()
	ui.clear(t("pause"), t("valley"))
	ui.button(t("resume"), resume)
	ui.button(t("settings"), func(): show_settings("pause"))
	ui.button(t("save_menu"), func(): save_game(); show_menu())
	ui.label(save_notice(), 17)

func start_dialogue(id: String) -> void:
	set_mode("dialogue")
	speaking_id = id
	dialogue_id = id
	if Progress.stage == "chapter_pause": dialogue_id = "after"
	elif id == "soldier_intro":
		if Progress.mission() == 2: dialogue_id = "visit_watchman" if Progress.stage == "challenge" else "visit_veteran"
		else: Progress.event("soldier_met")
	elif Progress.mission() == 1: dialogue_id = "locked"
	elif id == "veteran" and Progress.stage == "challenge": dialogue_id = "visit_watchman"
	elif id == "watchman" and Progress.stage != "challenge": dialogue_id = "visit_veteran"
	dialogue = I18n.dialogues[dialogue_id]
	dialogue_index = 0
	draw_dialogue()

func draw_dialogue() -> void:
	ui.clear(t(speaking_id), t("fiction") % [dialogue_index + 1, dialogue.lines.size()])
	ui.label(dialogue.lines[dialogue_index], 23)
	ui.button(t("continue") + "  →", next_dialogue)
	ui.label(t("close_dialogue"), 16)

func next_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index < dialogue.lines.size(): draw_dialogue(); return
	if dialogue_id == "watchman": Progress.event("watchman_heard")
	if dialogue_id == "veteran": Progress.event("veteran_heard")
	if dialogue_id in ["soldier_intro", "veteran"] and Progress.definition().has("question"): show_quiz()
	else: resume()

func show_quiz() -> void:
	set_mode("quiz")
	question_id = Progress.definition().get("question", "")
	var q := I18n.question(question_id)
	if q.is_empty(): resume(); return
	ui.clear(t("quiz_title"), q.reference + " / " + t("easy"))
	ui.label(q.text, 24)
	answer_buttons.clear()
	for index in range(4):
		answer_buttons.append(ui.button("%s.  %s" % [char(65 + index), q.answers[index]], choose_answer.bind(index)))
	feedback = ui.label(t("choose"), 19)
	quiz_continue = ui.button(t("continue") + "  →", finish_quiz, true)

func choose_answer(index: int) -> void:
	var q := I18n.question(question_id)
	if Progress.answer(q.id, index):
		feedback.text = t("correct") % [int(q.xp), q.explanation]
		for button: Button in answer_buttons: button.disabled = true
		quiz_continue.disabled = false
		save_game()
	else: feedback.text = t("retry") % [q.hint, q.reference]

func finish_quiz() -> void:
	set_mode("complete")
	var mission := "m1" if question_id == "elah_stones_01" else "m2"
	ui.clear(t("complete"), t(mission))
	ui.label(t(mission + "_done"), 24)
	ui.label(t(mission + "_next"), 20)
	ui.button(t("begin2") if mission == "m1" else t("explore"), resume)
	ui.button(t("menu"), show_menu)
	ui.label(save_notice(), 16)

func save_game() -> void:
	save_result = SaveStore.write_save(Progress.snapshot(), player.safe_position)

func on_progress_changed() -> void:
	if mode != "menu": save_game()

func on_focus_lost() -> void:
	if mode == "play": show_pause()

func show_settings(origin: String) -> void:
	return_mode = origin
	set_mode("settings")
	ui.clear(t("settings"), t("settings_note"))
	language_picker()
	for bus: String in Settings.volumes:
		ui.slider(t(bus), Settings.volumes[bus], 0, 1, func(value: float): Settings.volumes[bus] = value; Settings.apply())
	ui.slider(t("sensitivity"), Settings.sensitivity, 0.0005, 0.006, func(value: float): Settings.sensitivity = value)
	var quality := OptionButton.new()
	for item: String in ["low", "medium", "high"]: quality.add_item(t(item))
	quality.select(Settings.quality)
	quality.item_selected.connect(func(index: int): Settings.quality = index; Settings.apply())
	ui.content.add_child(quality)
	var fullscreen := CheckButton.new()
	fullscreen.text = t("fullscreen")
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.toggled.connect(func(value: bool): Settings.fullscreen = value; Settings.apply())
	ui.content.add_child(fullscreen)
	ui.label(t("audio_note"), 15)
	ui.button(t("back"), leave_settings)

func leave_settings() -> void:
	Settings.save_settings()
	if return_mode == "pause": show_pause()
	else: show_menu()
