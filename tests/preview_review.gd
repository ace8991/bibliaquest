extends Node
## Renders the baked EditorPreview snapshot on its own, exactly as the editor shows it
## before F5 (no gameplay scripts run), to prove the character models are part of it.
func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var preview := (load("res://scenes/world/elah_preview.scn") as PackedScene).instantiate()
	add_child(preview)
	var skeletons := preview.find_children("*", "Skeleton3D", true, false)
	var meshes := 0
	for node: Node in preview.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).skin != null: meshes += 1
	var camera := preview.get_node("PreviewCamera") as Camera3D
	camera.current = true
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/editor_preview.png")
	camera.global_position = Vector3(1.4, 1.5, 9.4)
	camera.look_at(Vector3(0, 1.1, 12))
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/editor_preview_character.png")
	print("PREVIEW REVIEW: %d skeletons, %d skinned meshes in the baked editor snapshot" % [skeletons.size(), meshes])
	get_tree().quit(0 if skeletons.size() == 14 and meshes > 80 else 1)
