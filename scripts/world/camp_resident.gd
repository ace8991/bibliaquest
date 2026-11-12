extends CharacterBody3D
## Ambient resident, deliberately separate from mission interactables and save data.
var visual: Node3D
var route: Array[Vector3] = []
var waypoint := 1
var wait_left := 0.0
var speed := 1.0
var observer: Node3D
var meshes: Array[Node] = []
var lod_timer := 0.0

func configure(info: Dictionary, world: Node3D) -> void:
	name = info.id
	position = world.ground(float(info.at[0]), float(info.at[1])) + Vector3.UP * 0.04
	var armed: bool = info.get("armed", false)
	var geo = preload("res://scripts/world/geometry.gd")
	visual = geo.soldier(Color(info.color), info.model) if armed else geo.person(Color(info.color), info.model, info.get("activity", "idle"))
	visual.name = "Visual"
	visual.scale = Vector3.ONE * float(info.get("scale", 1.0))
	visual.rotation.y = float(info.get("facing", 0.0))
	if info.has("faces"):
		# Turn towards a point of interest: a companion, the fire, the road.
		var toward: Vector3 = world.ground(float(info.faces[0]), float(info.faces[1])) - position
		visual.rotation.y = atan2(-toward.x, -toward.z)
	add_child(visual)
	meshes = visual.find_children("*", "MeshInstance3D", true, false)
	if not armed:
		for mesh: Node3D in meshes:
			if "gear" in mesh.name or "helmet" in mesh.name: mesh.hide()
	for point: Array in info.get("route", []):
		route.append(world.ground(float(point[0]), float(point[1])))
	speed = float(info.get("speed", 1.0))
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	collider.shape = capsule
	collider.position.y = 0.85
	add_child(collider)
	collision_layer = 4
	collision_mask = 7
	floor_snap_length = 0.4
	add_to_group("camp_residents")

func _ready() -> void:
	# All model nodes have entered the tree before advancing their idle phase.
	if visual.animation_tree != null:
		visual.animation_tree.advance(float(absi(name.hash()) % 100) * 0.037)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(observer):
		observer = get_tree().get_first_node_in_group("observer_player") as Node3D
	var moving := false
	# Pause travel in menus/dialogues and give the player personal space.
	if is_instance_valid(observer) and observer.enabled and route.size() > 1:
		wait_left = maxf(0.0, wait_left - delta)
		var offset := route[waypoint] - position
		offset.y = 0
		if offset.length() < 0.18:
			waypoint = (waypoint + 1) % route.size()
			wait_left = 2.5
		elif wait_left == 0.0 and position.distance_to(observer.position) > 1.25:
			var direction := offset.normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-4.0 * delta))
			moving = true
	if not moving:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = -0.2 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	visual.pose(Vector2(get_real_velocity().x, get_real_velocity().z).length(), false, delta)
	lod_timer -= delta
	if lod_timer <= 0.0 and is_instance_valid(observer):
		lod_timer = 0.5
		var distance := position.distance_to(observer.position)
		var reach := 32.0 if Settings.quality == 0 else 48.0
		visual.visible = distance < reach
		# Re-skinning every mesh each frame is the main cost of a character in the Compatibility
		# renderer. A resident standing far away holds his pose; walkers always keep animating.
		var still_far := route.size() < 2 and distance > (14.0 if Settings.quality == 0 else 24.0)
		visual.process_mode = Node.PROCESS_MODE_INHERIT if visual.visible and not still_far else Node.PROCESS_MODE_DISABLED
		for mesh: GeometryInstance3D in meshes:
			var small := false
			for part: String in visual.NO_SHADOW: small = small or String(mesh.name).ends_with(part)
			# On the Low preset only nearby residents cast shadows, and brows/lashes/eyes/beard shells
			# (invisible beyond a few metres) are skipped at a distance to save draw calls.
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if not small and (distance < 11.0 or Settings.quality > 0) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if small and not String(mesh.name).ends_with("beard"): mesh.visible = distance < (12.0 if Settings.quality == 0 else 20.0)
