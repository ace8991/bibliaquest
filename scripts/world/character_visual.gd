extends Node3D
## Adapter between gameplay code and an imported, skinned character model.
## The model is a glTF scene (mesh + Skeleton3D + AnimationPlayer) built by
## art_source/characters/build_characters.py. Feet are at local y=0 and the
## character faces local -Z, like the previous procedural visual.
##
## Interface kept from the old visual: pose(speed, airborne, delta).
const MODELS := {
	"observer": "res://assets/characters/observer.glb",
	"soldier_intro": "res://assets/characters/soldier_intro.glb",
	"watchman": "res://assets/characters/watchman.glb",
	"veteran": "res://assets/characters/veteran.glb",
	# Camp residents (ambient extras, see data/camp_population.json).
	"porter": "res://assets/characters/porter.glb",
	"cook": "res://assets/characters/cook.glb",
	"elder": "res://assets/characters/elder.glb",
	"spearman": "res://assets/characters/spearman.glb",
	"sentry": "res://assets/characters/sentry.glb",
	"youth": "res://assets/characters/youth.glb",
	"herdsman": "res://assets/characters/herdsman.glb",
	"armorer": "res://assets/characters/armorer.glb",
}
const MANIFEST_PATH := "res://assets/characters/characters.json"
const LOOPS := ["idle", "walk", "run", "guard", "talk"]
## Small meshes whose shadows are invisible in play; skipping them saves draw calls per character.
const NO_SHADOW := ["brows", "lashes", "eyes", "beard"]
static var manifest: Dictionary = {}

var variant := "observer"
var tunic := Color(0, 0, 0, 0)
var locomotion := true
var idle_clip := "idle"
var model: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var walk_speed := 1.45
var walk_stride := 1.45
var run_speed := 6.0
var run_stride := 3.84
var state := "idle"
var _move := 0.0
var _run := 0.0
var _air := 0.0
var _airborne := false
var _last_pose_frame := -100

static func load_manifest() -> Dictionary:
	if manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary: manifest = parsed
	return manifest

## Call before the node enters the tree. locomotion=false gives a standing guard.
## resting_clip replaces the idle clip when the model has it (for example "talk").
func setup(variant_name: String, tunic_color: Color = Color(0, 0, 0, 0), with_locomotion: bool = true, resting_clip: String = "idle") -> void:
	variant = variant_name if MODELS.has(variant_name) else "observer"
	idle_clip = resting_clip
	tunic = tunic_color
	locomotion = with_locomotion
	build()

func build() -> void:
	if model != null: return
	var path: String = MODELS[variant]
	if not ResourceLoader.exists(path):
		push_warning("Character model missing, using the observer model: " + path)
		path = MODELS.observer
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Character model missing: " + path)
		return
	model = scene.instantiate() as Node3D
	model.name = "Model"
	# glTF characters face +Z; gameplay expects -Z as forward.
	model.rotation.y = PI
	add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty(): skeleton = skeletons[0] as Skeleton3D
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty(): animation_player = players[0] as AnimationPlayer
	var info: Dictionary = load_manifest().get(variant, {})
	var gaits: Dictionary = info.get("gaits", {})
	if gaits.has("walk"):
		walk_speed = gaits.walk.speed
		walk_stride = gaits.walk.stride
	if gaits.has("run"):
		run_speed = gaits.run.speed
		run_stride = gaits.run.stride
	apply_materials()
	if animation_player == null: return
	for clip: String in LOOPS:
		if has_clip(clip): animation_player.get_animation(clip_name(clip)).loop_mode = Animation.LOOP_LINEAR
	if locomotion: build_tree()

func _ready() -> void:
	if animation_player == null: return
	if locomotion:
		apply(0.0, false, 0.0)
		animation_tree.advance(0.0)
	else:
		if skeleton != null:
			var attention := preload("res://scripts/world/guard_attention.gd").new()
			attention.name = "GuardAttention"
			skeleton.add_child(attention)
		animation_player.play(clip_name("guard") if has_clip("guard") else clip_name("idle"))
		# Offset each guard so the three soldiers do not breathe in unison.
		animation_player.seek(fmod(float(absi(variant.hash()) % 1000) * 0.013, animation_player.current_animation_length), true)

func relative_path(from: Node, to: Node) -> NodePath:
	## Path between two nodes of the model, usable before the model enters the scene tree.
	var up: Array[Node] = []
	var node := from
	while node != null:
		up.append(node)
		node = node.get_parent()
	var down: Array[String] = []
	node = to
	while node != null and not up.has(node):
		down.push_front(String(node.name))
		node = node.get_parent()
	var steps: Array[String] = []
	for i in range(up.find(node)): steps.append("..")
	return NodePath("/".join(steps + down))

func build_tree() -> void:
	var root := AnimationNodeBlendTree.new()
	for clip: String in ["idle", "walk", "run", "jump"]:
		var node := AnimationNodeAnimation.new()
		node.animation = clip_name(idle_clip if clip == "idle" and has_clip(idle_clip) else clip)
		root.add_node(clip, node)
	var gait := AnimationNodeBlend2.new()
	gait.sync = true  # walk and run are both one-second cycles and must stay in phase
	root.add_node("gait", gait)
	root.connect_node("gait", 0, "walk")
	root.connect_node("gait", 1, "run")
	root.add_node("cadence", AnimationNodeTimeScale.new())
	root.connect_node("cadence", 0, "gait")
	var move := AnimationNodeBlend2.new()
	move.sync = true
	root.add_node("move", move)
	root.connect_node("move", 0, "idle")
	root.connect_node("move", 1, "cadence")
	root.add_node("jump_seek", AnimationNodeTimeSeek.new())
	root.connect_node("jump_seek", 0, "jump")
	root.add_node("air", AnimationNodeBlend2.new())
	root.connect_node("air", 0, "move")
	root.connect_node("air", 1, "jump_seek")
	root.connect_node("output", 0, "air")
	animation_tree = AnimationTree.new()
	animation_tree.name = "AnimationTree"
	animation_tree.tree_root = root
	model.add_child(animation_tree)
	animation_tree.anim_player = relative_path(animation_tree, animation_player)
	animation_tree.active = true

func apply_materials() -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for part: String in NO_SHADOW:
			if String(instance.name).ends_with(part): instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(instance.mesh.get_surface_count()):
			var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null: continue
			var name_text := String(source.resource_name)
			if name_text == "cloth" and tunic.a > 0.0:
				var cloth := source.duplicate() as BaseMaterial3D
				cloth.albedo_color = Color(tunic.r, tunic.g, tunic.b, 1.0)
				instance.set_surface_override_material(surface, cloth)

## speed is the measured horizontal speed in m/s.
func pose(speed: float, airborne: bool, delta: float) -> void:
	_last_pose_frame = Engine.get_physics_frames()
	apply(speed, airborne, delta)

func apply(speed: float, airborne: bool, delta: float) -> void:
	if animation_tree == null: return
	var quick := 1.0 - exp(-12.0 * delta) if delta > 0.0 else 1.0
	_move = lerpf(_move, smoothstep(0.12, 1.0, speed), quick)
	_run = lerpf(_run, clampf((speed - walk_speed) / maxf(run_speed - walk_speed, 0.1), 0.0, 1.0), 1.0 - exp(-7.0 * delta) if delta > 0.0 else 1.0)
	_air = lerpf(_air, 1.0 if airborne else 0.0, 1.0 - exp(-(20.0 if airborne else 13.0) * delta) if delta > 0.0 else 1.0)
	if airborne and not _airborne: animation_tree.set("parameters/jump_seek/seek_request", 0.0)
	_airborne = airborne
	# Play the one-second cycles at the cadence whose stride matches the real speed.
	var stride := lerpf(walk_stride, run_stride, _run)
	var cadence := clampf(speed / maxf(stride, 0.1), 0.55, 1.9)
	animation_tree.set("parameters/gait/blend_amount", _run)
	animation_tree.set("parameters/cadence/scale", cadence)
	animation_tree.set("parameters/move/blend_amount", _move)
	animation_tree.set("parameters/air/blend_amount", _air)
	state = "jump" if airborne else ("idle" if speed < 0.12 else ("run" if _run > 0.5 else "walk"))

func _physics_process(delta: float) -> void:
	# When the controller stops calling pose() (pause, dialogue, menu) settle into the idle clip.
	if animation_tree != null and Engine.get_physics_frames() - _last_pose_frame > 2:
		apply(0.0, false, delta)

func clip_name(clip: String) -> StringName:
	## The exporter names looping clips "<name>-loop"; Godot's importer strips that hint.
	if animation_player != null and not animation_player.has_animation(clip) and animation_player.has_animation(clip + "-loop"):
		return StringName(clip + "-loop")
	return StringName(clip)

func has_clip(clip: String) -> bool:
	return animation_player != null and animation_player.has_animation(clip_name(clip))

func clip(clip_base: String) -> Animation:
	return animation_player.get_animation(clip_name(clip_base)) if has_clip(clip_base) else null

func bone_position(bone: String) -> Vector3:
	## Bone origin in this node's local space (feet at y=0, forward -Z).
	if skeleton == null: return Vector3.ZERO
	var index := skeleton.find_bone(bone)
	if index < 0: return Vector3.ZERO
	return global_transform.affine_inverse() * (skeleton.global_transform * skeleton.get_bone_global_pose(index).origin)
