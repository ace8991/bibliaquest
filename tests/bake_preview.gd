extends Node
## Rebuild the editor-only snapshot after changes to procedural world art or character models.
func _ready() -> void:
	var world := preload("res://scripts/world/world.gd").new()
	world.name = "ElahPreview"
	add_child(world)
	await get_tree().process_frame
	var player_visual := preload("res://scripts/world/geometry.gd").person(Color("bfa77a"))
	player_visual.name = "PlayerPreview"
	player_visual.position = world.ground(0, 12)
	world.add_child(player_visual)
	# Let the idle and guard clips pose every skeleton so the snapshot is not in the bind pose.
	for i in range(4): await get_tree().process_frame
	var camera:=Camera3D.new()
	camera.name="PreviewCamera"
	world.add_child(camera)
	camera.position=Vector3(6,5,17)
	camera.look_at(Vector3(0,1,0))
	# The snapshot is static: keep the posed skeletons, drop the animation nodes, and store the
	# character models as plain nodes instead of nested scene instances.
	for modifier: Node in world.find_children("*", "SkeletonModifier3D", true, false):
		modifier.get_parent().remove_child(modifier)
		modifier.free()
	for mixer: Node in world.find_children("*", "AnimationMixer", true, false):
		mixer.get_parent().remove_child(mixer)
		mixer.free()
	var all_nodes:=world.find_children("*", "", true, false)
	for node: Node in all_nodes:
		node.scene_file_path = ""
		node.owner=world
		if node.get_script()!=null: node.set_script(null)
	world.set_script(null)
	var scene:=PackedScene.new()
	var result:=scene.pack(world)
	if result==OK: result=ResourceSaver.save(scene,"res://scenes/world/elah_preview.scn")
	print("EDITOR PREVIEW: ",error_string(result))
	get_tree().quit(0 if result==OK else 1)
