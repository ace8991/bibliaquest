extends Control
## Circular mini-map: rotates with the camera, the player stays in the centre.
## Presentation only. It reads positions from the world and the current target from Progress.
const Terrain = preload("res://scripts/world/terrain.gd")
const FIELD := 46.0          # half size of the playable field in metres
const MAP_PIXELS := 192
const RADIUS := 92.0         # on-screen radius in canvas pixels
const GOLD := Color("e9c97f")
const SHADER := """
shader_type canvas_item;
uniform sampler2D map : filter_linear, repeat_disable;
uniform vec2 player = vec2(0.0);
uniform float yaw = 0.0;
uniform float view_range = 26.0;
uniform float field = 46.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float d = length(p);
	vec2 right = vec2(cos(yaw), -sin(yaw));
	vec2 forward = vec2(-sin(yaw), -cos(yaw));
	vec2 world = player + right * p.x * view_range - forward * p.y * view_range;
	vec2 uv = (world + vec2(field)) / (2.0 * field);
	vec3 colour = vec3(0.10, 0.12, 0.12);
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) colour = texture(map, uv).rgb;
	colour *= mix(1.0, 0.62, smoothstep(0.55, 1.0, d));
	COLOR = vec4(colour, (1.0 - smoothstep(0.985, 1.0, d)) * 0.94);
}
"""
var world: Node3D
var player: Node3D
var view_range := 26.0
var surface: ColorRect
var overlay: Control
var caption: Label
var target_text := ""

func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2, RADIUS * 2 + 30)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface = ColorRect.new()
	surface.size = Vector2(RADIUS * 2, RADIUS * 2)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	material.shader = shader
	surface.material = material
	add_child(surface)
	overlay = Control.new()
	overlay.size = surface.size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(draw_overlay)
	add_child(overlay)
	caption = Label.new()
	# Right-aligned on the map edge so long names in any language stay on screen.
	caption.position = Vector2(RADIUS * 2 - 420, RADIUS * 2 + 6)
	caption.size = Vector2(420, 24)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color("ffe0a5"))
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 1)
	add_child(caption)

func setup(world_node: Node3D, player_node: Node3D) -> void:
	world = world_node
	player = player_node
	(surface.material as ShaderMaterial).set_shader_parameter("map", bake_map())
	(surface.material as ShaderMaterial).set_shader_parameter("field", FIELD)

func bake_map() -> ImageTexture:
	## Top-down drawing of the valley from the same height function as the terrain.
	var image := Image.create(MAP_PIXELS, MAP_PIXELS, false, Image.FORMAT_RGB8)
	var low := Color("6f6044")
	var high := Color("a8946a")
	var path_colour := Color("c9b78d")
	var river_colour := Color("7d8478")
	for py in range(MAP_PIXELS):
		for px in range(MAP_PIXELS):
			var x := (float(px) + 0.5) / MAP_PIXELS * 2.0 * FIELD - FIELD
			var z := (float(py) + 0.5) / MAP_PIXELS * 2.0 * FIELD - FIELD
			var height := Terrain.height(x, z)
			var colour := low.lerp(high, clampf(height * 0.22 + 0.5, 0.0, 1.0))
			# Light from the north-west gives the relief some shape.
			var slope := Terrain.height(x + 1.0, z + 1.0) - height
			colour = colour.lightened(clampf(-slope * 0.22, 0.0, 0.2)) if slope < 0.0 else colour.darkened(clampf(slope * 0.22, 0.0, 0.25))
			var river := absf(x - Terrain.river_x(z))
			colour = colour.lerp(river_colour, 1.0 - smoothstep(2.0, 4.5, river))
			var point := Vector2(x, z)
			var path := minf(Terrain.path_distance(point, Vector2(0, 44), Vector2(0, -4)), minf(Terrain.path_distance(point, Vector2(0, -4), Vector2(8, -13)), Terrain.path_distance(point, Vector2(0, -4), Vector2(-12, -9))))
			colour = colour.lerp(path_colour, (1.0 - smoothstep(0.9, 2.2, path)) * 0.8)
			image.set_pixel(px, py, colour)
	if world != null and "tent_sites" in world:
		for site: Vector2 in world.tent_sites:
			var centre := (site + Vector2(FIELD, FIELD)) / (2.0 * FIELD) * MAP_PIXELS
			image.fill_rect(Rect2i(int(centre.x - 4), int(centre.y - 5), 8, 10), Color("3a342b"))
			image.fill_rect(Rect2i(int(centre.x), int(centre.y - 5), 1, 10), Color("8b7c62"))
	return ImageTexture.create_from_image(image)

func to_map(position: Vector3) -> Vector2:
	## World position to overlay pixels (player in the centre, camera forward is up).
	var yaw: float = player.yaw
	var offset := Vector2(position.x - player.position.x, position.z - player.position.z)
	var right := Vector2(cos(yaw), -sin(yaw))
	var forward := Vector2(-sin(yaw), -cos(yaw))
	return Vector2(RADIUS, RADIUS) + Vector2(offset.dot(right), -offset.dot(forward)) / view_range * RADIUS

func _process(_delta: float) -> void:
	if world == null or player == null or not is_visible_in_tree(): return
	var material := surface.material as ShaderMaterial
	material.set_shader_parameter("player", Vector2(player.position.x, player.position.z))
	material.set_shader_parameter("yaw", player.yaw)
	material.set_shader_parameter("view_range", view_range)
	caption.text = target_text
	overlay.queue_redraw()

func draw_overlay() -> void:
	if world == null or player == null: return
	var centre := Vector2(RADIUS, RADIUS)
	var edge := RADIUS - 7.0
	# Ambient residents: small quiet dots.
	for resident: Node in get_tree().get_nodes_in_group("camp_residents"):
		var point := to_map((resident as Node3D).position)
		if point.distance_to(centre) < edge: overlay.draw_circle(point, 2.4, Color(0.92, 0.9, 0.84, 0.75))
	# Mission people: white dots, the current target is a gold diamond kept on the rim when far away.
	var target_id: String = Progress.definition().target
	for npc: Node3D in world.interactables:
		var point := to_map(npc.position)
		var outside := point.distance_to(centre) > edge
		if npc.dialogue_id == target_id:
			if outside: point = centre + (point - centre).normalized() * edge
			var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
			diamond(point, 7.5 * pulse, GOLD, Color(0.1, 0.08, 0.03))
			if outside: overlay.draw_line(point, point + (point - centre).normalized() * 6.0, GOLD, 2.0)
		elif not outside:
			overlay.draw_circle(point, 4.2, Color(0.08, 0.1, 0.1))
			overlay.draw_circle(point, 3.0, Color("f3efe4"))
	# Player arrow: points where the character faces, relative to the camera.
	var facing: float = player.visual.rotation.y - player.yaw
	var tip := Vector2(-sin(facing), -cos(facing))
	var side := Vector2(tip.y, -tip.x)
	var arrow := PackedVector2Array([centre + tip * 10.0, centre - tip * 6.0 + side * 6.5, centre - tip * 2.5, centre - tip * 6.0 - side * 6.5])
	overlay.draw_colored_polygon(PackedVector2Array([centre + tip * 12.5, centre - tip * 8.0 + side * 9.0, centre - tip * 3.0, centre - tip * 8.0 - side * 9.0]), Color(0.05, 0.07, 0.08))
	overlay.draw_colored_polygon(arrow, Color("fff6dd"))
	# Rim and the north mark, which turns with the map.
	overlay.draw_arc(centre, RADIUS - 1.5, 0, TAU, 96, Color(0.04, 0.06, 0.07, 0.95), 5.0, true)
	overlay.draw_arc(centre, RADIUS - 1.5, 0, TAU, 96, GOLD, 1.6, true)
	var north := centre + Vector2(-sin(-player.yaw), -cos(-player.yaw)) * (RADIUS - 2.0)
	overlay.draw_circle(north, 10.0, Color(0.05, 0.07, 0.08))
	overlay.draw_arc(north, 10.0, 0, TAU, 32, GOLD, 1.4, true)
	var font := get_theme_default_font()
	overlay.draw_string(font, north + Vector2(-5.0, 5.5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)

func diamond(at: Vector2, extent: float, fill: Color, outline: Color) -> void:
	var shape := PackedVector2Array([at + Vector2(0, -extent), at + Vector2(extent * 0.8, 0), at + Vector2(0, extent), at + Vector2(-extent * 0.8, 0)])
	var border := PackedVector2Array()
	for corner: Vector2 in shape: border.append(at + (corner - at) * 1.3)
	overlay.draw_colored_polygon(border, outline)
	overlay.draw_colored_polygon(shape, fill)
