extends CharacterBody3D
## Replace Visual with a rig; consume animation_state_changed in an AnimationTree adapter.
signal animation_state_changed(state: String)
var enabled := false
var animation_state := "idle"
var yaw := 0.0
var pitch := -0.16
var rig: Node3D
var arm: SpringArm3D
var camera: Camera3D
var visual: Node3D
var safe_position := Vector3(0, 0.05, 12)

func _ready() -> void:
	add_to_group("observer_player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	visual = preload("res://scripts/world/geometry.gd").person(Color("bfa77a"))
	visual.name = "Visual"
	add_child(visual)
	rig = Node3D.new()
	rig.position.y = 1.5
	rig.position.x = 0.4
	add_child(rig)
	arm = SpringArm3D.new()
	arm.spring_length = 4.5
	arm.margin = 0.2
	arm.collision_mask = 1
	var probe := SphereShape3D.new()
	probe.radius = 0.22
	arm.shape = probe
	arm.add_excluded_object(get_rid())
	rig.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 60
	camera.near = 0.1
	arm.add_child(camera)
	camera.current = true
	rig.rotation.x = pitch

func _unhandled_input(event: InputEvent) -> void:
	if enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		yaw -= event.relative.x * Settings.sensitivity
		pitch = clampf(pitch - event.relative.y * Settings.sensitivity, -0.85, 0.45)
		rig.rotation = Vector3(pitch, yaw, 0)

func _physics_process(delta: float) -> void:
	if not enabled: return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	# 1.8 m/s is a brisk human walk and matches the authored walk cycle; Shift runs at 6 m/s.
	var speed := 6.0 if Input.is_action_pressed("run") else 1.8
	velocity.x = move_toward(velocity.x, direction.x * speed, 22 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 22 * delta)
	if not is_on_floor(): velocity.y -= 20.0 * delta
	elif Input.is_action_just_pressed("jump"): velocity.y = 6.2
	move_and_slide()
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 1 - exp(-14 * delta))
	var next_state := "jump" if not is_on_floor() else ("run" if speed > 4 and input.length() > 0.1 else ("walk" if input.length() > 0.1 else "idle"))
	if next_state != animation_state:
		animation_state = next_state
		animation_state_changed.emit(animation_state)
	visual.pose(Vector2(velocity.x, velocity.z).length(), not is_on_floor(), delta)
	if is_on_floor(): safe_position = position
	if position.y < -10:
		position = Vector3(0, 0.05, 12)
		velocity = Vector3.ZERO
		reset_physics_interpolation()
