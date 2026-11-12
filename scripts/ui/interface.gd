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
	hud = Label.new()
	hud.position = Vector2(32, 25)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(hud)
	hud.custom_minimum_size.x = 950
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	waypoint = Label.new()
	waypoint.position = Vector2(32, 160)
	waypoint.add_theme_font_size_override("font_size", 18)
	waypoint.add_theme_color_override("font_color", Color("ffe0a5"))
	root.add_child(waypoint)
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-300, -116)
	prompt.size = Vector2(600, 40)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)
	footer = Label.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 32
	footer.offset_top = -42
	footer.text = I18n.text("controls")
	footer.add_theme_font_size_override("font_size", 16)
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

func clear(title: String, subtitle: String = "") -> void:
	hud.hide()
	waypoint.hide()
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
	hud.show()
	waypoint.show()
	footer.text = I18n.text("controls")
	footer.show()
	prompt.show()

func update_hud() -> void:
	hud.text = "BIBLIA QUEST / %s\n%s\n%s\n%s" % [I18n.text("valley"), I18n.text("m%d" % Progress.mission()), Progress.objective(), I18n.text("knowledge") % [Progress.completed_questions.size(), Progress.xp]]
