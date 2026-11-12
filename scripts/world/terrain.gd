extends RefCounted
## A deterministic height field: visible mesh and collider share the exact triangles.
const SIZE := 46
const STEP := 2.0
const PADS := [Vector2(-10, 3), Vector2(-19, 3), Vector2(10, 3), Vector2(-16, -10), Vector2(-24, -10), Vector2(10, -24), Vector2(8, -13), Vector2(-12, -9)]

static func river_x(z: float) -> float:
	return 20.0 + sin(z * 0.07) * 2.5

static func raw_height(x: float, z: float) -> float:
	var relief := (sin(x * 0.075) * cos(z * 0.095) * 1.8 + sin(z * 0.055) * 0.65) * smoothstep(4.0, 15.0, absf(x))
	var river := -1.65 * exp(-pow((x - river_x(z)) / 3.1, 2))
	return relief + river

static func height(x: float, z: float) -> float:
	var value := raw_height(x, z)
	for pad: Vector2 in PADS:
		var distance := Vector2(x, z).distance_to(pad)
		value = lerpf(raw_height(pad.x, pad.y), value, smoothstep(3.2, 5.5, distance))
	return value

static func path_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var fraction := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0, 1)
	return p.distance_to(a + (b - a) * fraction)

static func build(parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 1740
	noise.frequency = 0.32
	for z_index in range(SIZE):
		for x_index in range(SIZE):
			var x := -46.0 + x_index * STEP
			var z := -46.0 + z_index * STEP
			for point: Vector2 in [Vector2(x,z), Vector2(x+STEP,z), Vector2(x,z+STEP), Vector2(x+STEP,z), Vector2(x+STEP,z+STEP), Vector2(x,z+STEP)]:
				var path := minf(absf(point.x), minf(path_distance(point, Vector2(0,-4), Vector2(8,-13)), path_distance(point, Vector2(0,-4), Vector2(-12,-9))))
				var path_weight := 1.0-smoothstep(0.65,2.4,path)
				var river_weight := 1.0-smoothstep(1.2,3.8,absf(point.x-river_x(point.y)))
				surface.set_color(Color(path_weight,river_weight,0,1))
				surface.add_vertex(Vector3(point.x, height(point.x, point.y), point.y))
	surface.generate_normals()
	var resource := surface.commit()
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = resource
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://assets/materials/valley_ground.gdshader")
	mat.set_shader_parameter("soil_color",load("res://assets/materials/brown_mud_dry/brown_mud_dry_diff_1k.jpg"))
	mat.set_shader_parameter("soil_normal",load("res://assets/materials/brown_mud_dry/brown_mud_dry_nor_gl_1k.jpg"))
	mat.set_shader_parameter("stone_color",load("res://assets/materials/rocky_terrain_02/rocky_terrain_02_diff_1k.jpg"))
	terrain.material_override = mat
	parent.add_child(terrain)
	terrain.create_trimesh_collision()
