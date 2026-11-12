extends RefCounted
## Original modular geometry with licensed offline PBR surfaces.
const Surfaces = preload("res://scripts/world/surface_materials.gd")
static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	return mat

static func mesh(parent: Node3D, resource: Mesh, position: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = resource
	node.material_override = mat
	node.position = position
	parent.add_child(node)
	return node

static func box(parent: Node3D, position: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var resource := BoxMesh.new()
	resource.size = size
	var node := mesh(parent, resource, position, mat)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

static func ellipsoid(parent: Node3D, position: Vector3, radii: Vector3, mat: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 20
	sphere.rings = 12
	var node := mesh(parent, sphere, position, mat)
	node.scale = radii
	return node

## Characters are imported, rigged models (see character_visual.gd and ASSET_REGISTER.md).
## The tunic colour tints the woven cloth; variant selects the model.
static func person(tunic: Color, variant: String = "observer", resting_clip: String = "idle") -> Node3D:
	var root := preload("res://scripts/world/character_visual.gd").new()
	root.setup(variant, tunic, true, resting_clip)
	return root
static func tent(parent: Node3D, position: Vector3, mat: Material) -> void:
	var root := Node3D.new()
	root.position=position
	parent.add_child(root)
	var base_color := Color("9c8868")
	if mat is StandardMaterial3D: base_color=mat.albedo_color
	var fabric := Surfaces.cloth(base_color)
	# Sagging cloth panels retain the prior roof collision envelope.
	for side: float in [-1.0,1.0]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for iz in range(12):
			for ix in range(10):
				for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
					var u := (ix+corner.x)/10.0
					var v := (iz+corner.y)/12.0
					var sag := sin(u*PI)*0.16 + sin(v*PI)*sin(u*PI)*0.10
					surface.add_vertex(Vector3(side*u*1.84,2.4*(1-u)-sag+sin(v*PI*8)*sin(u*PI)*0.025,-2.1+v*4.2))
		surface.generate_normals()
		mesh(root,surface.commit(),Vector3.ZERO,fabric).create_trimesh_collision()
	var timber := Surfaces.scanned("weathered_planks",0.5)
	for z: float in [-2.0,2.0]:
		beam(root,Vector3(0,0,z),Vector3(0,2.43,z),0.065,timber)
	beam(root,Vector3(0,2.43,-2.2),Vector3(0,2.43,2.2),0.055,timber)
	var end := SurfaceTool.new()
	end.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [Vector3(-1.84,0,-2),Vector3(0,2.4,-2),Vector3(1.84,0,-2)]: end.add_vertex(v)
	end.generate_normals()
	mesh(root,end.commit(),Vector3.ZERO,fabric)
	var rope:=material(Color("9f8a65"))
	for side: float in [-1.0,1.0]:
		for z: float in [-1.8,1.8]:
			beam(root,Vector3(side*2.6,0,z),Vector3(side*2.6,0.34,z),0.035,timber)
			beam(root,Vector3(side,1.05,z),Vector3(side*2.6,0.25,z),0.012,rope)

static func beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 6
	var instance := mesh(parent, cylinder, (a + b) / 2, mat)
	instance.quaternion = Quaternion(Vector3.UP, (b-a).normalized())

static func crate(parent: Node3D, position: Vector3) -> void:
	var wood := Surfaces.scanned("weathered_planks", 0.8)
	box(parent, position + Vector3(0,0.4,0), Vector3(1,0.8,0.85), wood, true)
	var bands := material(Color("413b2d"))
	for side: float in [-0.32,0.32]:
		box(parent, position + Vector3(side,0.4,0), Vector3(0.065,0.83,0.88), bands)
	for z: float in [-0.44,0.44]:
		for y: float in [0.2,0.4,0.6]:
			box(parent, position + Vector3(0,y,z), Vector3(0.98,0.015,0.012), bands)

static func jar(parent: Node3D, position: Vector3) -> void:
	var clay := material(Color("9b6545"))
	var body := SphereMesh.new()
	body.radius = 0.28
	body.height = 0.7
	body.radial_segments = 12
	body.rings = 6
	mesh(parent, body, position + Vector3(0,0.34,0), clay)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.13
	lip.outer_radius = 0.20
	lip.rings = 12
	lip.ring_segments = 8
	mesh(parent, lip, position + Vector3(0,0.65,0), clay)
	var opening := CylinderMesh.new()
	opening.top_radius = 0.14
	opening.bottom_radius = 0.14
	opening.height = 0.01
	mesh(parent, opening, position + Vector3(0,0.64,0), material(Color("3a3027")))

## Standing guard. Helmet, shield and spear are part of the soldier models and are skinned to
## the head, left forearm and right hand bones, so no separate equipment is added here.
static func soldier(tunic: Color, variant: String = "soldier_intro") -> Node3D:
	var root := preload("res://scripts/world/character_visual.gd").new()
	root.setup(variant, tunic, false)
	return root