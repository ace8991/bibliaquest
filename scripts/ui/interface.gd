extends CanvasLayer
## Presentation helpers only; quest decisions live in Progress.
var root: Control
var card: PanelContainer
var content: VBoxContainer
var hud: Label
var prompt: Label
var footer: Label
var heading: Label
var waypoint: Label
var minimap: Control
var mission_panel: PanelContainer
var mission_title: Label
var chapter_line: Label
var xp_bar: ProgressBar
var xp_label: Label
var prompt_panel: PanelContainer
var toast: PanelContainer
var toast_label: Label
var toast_tween: Tween
var last_objective := ""
const GOLD := Color("e9c97f")

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 21
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182329")
	style.border_color = Color("9c8759")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	theme.set_stylebox("normal", "Button", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("384b50")
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	root.theme = theme
	# Mission tracker, top left: chapter line, mission title, current objective, XP bar.
	mission_panel = PanelContainer.new()
	mission_panel.position = Vector2(24, 20)
	mission_panel.custom_minimum_size.x = 430
	mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_panel.add_theme_stylebox_override("panel", plate(Color(0.035, 0.055, 0.065, 0.80), 16, 12))
	root.add_child(mission_panel)
	var tracker := VBoxContainer.new()
	tracker.add_theme_constant_override("separation", 5)
	mission_panel.add_child(tracker)
	chapter_line = small_label("", 13, Color("9fb0b0"))
	tracker.add_child(chapter_line)
	mission_title = small_label("", 23, GOLD)
	tracker.add_child(mission_title)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.55)
	rule.custom_minimum_size = Vector2(0, 1)
	tracker.add_child(rule)
	hud = small_label("", 17, Color("f1ecdf"))
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.custom_minimum_size.x = 398
	tracker.add_child(hud)
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 10)
	tracker.add_child(xp_row)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(170, 8)
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	track.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("background", track)
	xp_bar.add_theme_stylebox_override("fill", fill)
	xp_row.add_child(xp_bar)
	xp_label = small_label("", 14, Color("cfd6d3"))
	xp_row.add_child(xp_label)
	# Mini-map, top right; the distance to the objective is written under it.
	minimap = preload("res://scripts/ui/minimap.gd").new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Offsets from the top-right corner, so the map follows the screen edge at any size.
	minimap.offset_left = -208
	minimap.offset_top = 20
	minimap.offset_right = -24
	minimap.offset_bottom = 234
	root.add_child(minimap)
	waypoint = Label.new()  # kept for gameplay code; shown as the caption of the mini-map
	waypoint.hide()
	root.add_child(waypoint)
	# Interaction prompt: a key cap and the action, only visible when there is something to do.
	prompt_panel = PanelContainer.new()
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.offset_top = -134
	prompt_panel.offset_bottom = -92
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := plate(Color(0.035, 0.055, 0.065, 0.88), 22, 9)
	pill.set_corner_radius_all(20)
	pill.border_color = Color(GOLD, 0.8)
	pill.set_border_width_all(1)
	prompt_panel.add_theme_stylebox_override("panel", pill)
	root.add_child(prompt_panel)
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", Color("fff3d6"))
	prompt_panel.add_child(prompt)
	# Short announcement when the objective changes.
	toast = PanelContainer.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.position.y = 118
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner := plate(Color(0.035, 0.055, 0.065, 0.90), 26, 12)
	banner.border_color = GOLD
	banner.border_width_top = 2
	banner.border_width_bottom = 2
	toast.add_theme_stylebox_override("panel", banner)
	toast.modulate.a = 0.0
	root.add_child(toast)
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 19)
	toast.add_child(toast_label)
	footer = Label.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 32
	footer.offset_top = -38
	footer.text = I18n.text("controls")
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	footer.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	footer.add_theme_constant_override("shadow_offset_x", 1)
	footer.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(footer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	card = PanelContainer.new()
	card.custom_minimum_size.x = 690
	var panel := style.duplicate() as StyleBoxFlat
	panel.bg_color = Color(0.045, 0.075, 0.085, 0.96)
	panel.content_margin_left = 32
	panel.content_margin_right = 32
	panel.content_margin_top = 25
	panel.content_margin_bottom = 25
	card.add_theme_stylebox_override("panel", panel)
	center.add_child(card)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)

func plate(colour: Color, margin_x: int, margin_y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(6)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box

func small_label(text: String, font_size: int, colour: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", colour)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 1)
	return node

func _process(_delta: float) -> void:
	# Gameplay code only sets texts; the HUD decides what is worth showing.
	prompt_panel.visible = prompt.visible and not prompt.text.is_empty() and not card.visible
	minimap.target_text = waypoint.text

func announce(title: String, text: String) -> void:
	toast_label.text = title + "\n" + text
	if toast_tween != null: toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_property(toast, "modulate:a", 1.0, 0.35)
	toast_tween.tween_interval(3.2)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.8)

func clear(title: String, subtitle: String = "") -> void:
	mission_panel.hide()
	minimap.hide()
	toast.hide()
	footer.hide()
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	card.show()
	prompt.hide()
	heading = label(title, 29, Color("efd19a"))
	if not subtitle.is_empty(): label(subtitle, 17, Color("a7b7b7"))

func label(text: String, font_size: int = 21, color: Color = Color("eee8da")) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = 626
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	content.add_child(node)
	return node

func button(text: String, action: Callable, disabled: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.disabled = disabled
	node.custom_minimum_size.y = 44
	node.pressed.connect(action)
	content.add_child(node)
	return node

func slider(text: String, value: float, minimum: float, maximum: float, action: Callable) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = text
	name_label.custom_minimum_size.x = 270
	row.add_child(name_label)
	var control := HSlider.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = (maximum - minimum) / 100
	control.value = value
	control.custom_minimum_size.x = 320
	control.value_changed.connect(action)
	row.add_child(control)
	content.add_child(row)

func gameplay() -> void:
	card.hide()
	mission_panel.show()
	minimap.show()
	toast.show()
	footer.text = I18n.text("controls")
	footer.show()
	prompt.show()

func update_hud() -> void:
	chapter_line.text = "BIBLIA QUEST  •  %s" % I18n.text("valley")
	mission_title.text = I18n.text("m%d" % Progress.mission())
	var objective := Progress.objective()
	hud.text = "◆  " + objective
	var total := 0
	for stage: Dictionary in Progress.chapter.stages:
		if stage.has("question"): total += int(I18n.question(stage.question).get("xp", 0))
	xp_bar.max_value = maxi(total, 1)
	xp_bar.value = Progress.xp
	xp_label.text = I18n.text("knowledge") % [Progress.completed_questions.size(), Progress.xp]
	if objective != last_objective and not last_objective.is_empty() and mission_panel.visible:
		announce(I18n.text("new_objective"), objective)
	last_objective = objective
