extends SkeletonModifier3D
## Add a restrained head turn after the guard animation, without changing the body or gear.
var target: Node3D
var yaw := 0.0
var pitch := 0.0
var attending := false

func _process_modification_with_delta(delta: float) -> void:
	var rig := get_skeleton()
	if rig == null or not is_inside_tree(): return
	var head := rig.find_bone("head")
	if head < 0: return
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("observer_player") as Node3D
	var desired_yaw := 0.0
	var desired_pitch := 0.0
	attending = false
	var pose := rig.get_bone_global_pose(head)
	if is_instance_valid(target):
		var direction := rig.to_local(target.global_position + Vector3.UP * 1.6) - pose.origin
		var horizontal := Vector2(direction.x, direction.z).length()
		# glTF faces +Z. Do not swivel backwards or stare at distant people.
		var angle := atan2(direction.x, direction.z)
		attending = horizontal > 0.35 and horizontal < 4.0 and absf(angle) < deg_to_rad(75.0)
		if attending:
			desired_yaw = clampf(angle, -0.55, 0.55)
			desired_pitch = clampf(-atan2(direction.y, horizontal), -0.18, 0.18)
	var blend := 1.0 - exp(-4.0 * delta)
	yaw = lerpf(yaw, desired_yaw, blend)
	pitch = lerpf(pitch, desired_pitch, blend)
	pose.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * pose.basis
	rig.set_bone_global_pose(head, pose)
