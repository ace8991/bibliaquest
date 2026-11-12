extends RefCounted

static func nearest(player: CharacterBody3D, objects: Array) -> Node3D:
	var best: Node3D = null
	var distance := INF
	for object: Node3D in objects:
		var d := player.global_position.distance_to(object.global_position)
		if d > object.reach or d >= distance: continue
		var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, object.global_position + Vector3.UP, 1)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			best = object
			distance = d
	return best
