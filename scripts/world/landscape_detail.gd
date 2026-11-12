extends RefCounted
const Geo = preload("res://scripts/world/geometry.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const Surfaces = preload("res://scripts/world/surface_materials.gd")

static func ridge_height(x: float, z: float, noise: FastNoiseLite) -> float:
	var edge := maxf(absf(x),absf(z))
	var rise := smoothstep(48.0,155.0,edge)
	var detail := noise.get_noise_2d(x,z)
	var ridge := 10.0 + detail*12.0 + sin(x*0.012+z*0.008)*5.0
	return Terrain.raw_height(x,z) + smoothstep(44.0,48.0,edge)*2.8 + rise*ridge

static func ridges(parent: Node3D) -> void:
	var noise := FastNoiseLite.new()
	noise.seed=1747
	noise.frequency=0.007
	noise.fractal_octaves=4
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in range(160):
		for xi in range(160):
			var x:float=-320.0+xi*4
			var z:float=-320.0+zi*4
			if x>=-44 and x<44 and z>=-44 and z<44: continue
			for corner: Vector2 in [Vector2(0,0),Vector2(4,0),Vector2(0,4),Vector2(4,0),Vector2(4,4),Vector2(0,4)]:
				var px:=x+corner.x
				var pz:=z+corner.y
				surface.set_color(Color("777d62").lerp(Color("a79c7e"),(noise.get_noise_2d(px*3,pz*3)+1)*0.5))
				surface.add_vertex(Vector3(px,ridge_height(px,pz,noise),pz))
	surface.generate_normals()
	var mat:=Surfaces.scanned("rocky_terrain_02",0.18).duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo=true
	Geo.mesh(parent,surface.commit(),Vector3.ZERO,mat)

static func rock(parent: Node3D, position: Vector3, scale_value: Vector3, seed_value: int) -> void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise:=FastNoiseLite.new()
	noise.seed=seed_value
	noise.frequency=1.8
	for ring in range(8):
		for segment in range(14):
			for corner: Vector2i in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var a:=float(segment+corner.x)/14*TAU
				var b:=float(ring+corner.y)/8*PI
				var point:=Vector3(sin(b)*cos(a),cos(b),sin(b)*sin(a))
				point*=1.0+noise.get_noise_3dv(point)*0.3
				surface.add_vertex(point*scale_value)
	surface.generate_normals()
	Geo.mesh(parent,surface.commit(),position,Surfaces.scanned("rocky_terrain_02",0.8))

static func olive(parent: Node3D, position: Vector3, seed_value: int) -> void:
	var root:=Node3D.new()
	root.position=position
	parent.add_child(root)
	var wood:=Surfaces.scanned("weathered_planks",0.35)
	Geo.beam(root,Vector3.ZERO,Vector3(0.15,1.8,0),0.17,wood)
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var centers:Array[Vector3]=[]
	for i in range(7):
		var angle:=i*TAU/7+rng.randf_range(-0.3,0.3)
		var center:=Vector3(cos(angle)*1.35,2.25+rng.randf_range(-0.25,1.1),sin(angle)*1.35)
		Geo.beam(root,Vector3(0.15,1.4,0),center,0.065,wood)
		centers.append(center)
	var leaf:=SurfaceTool.new()
	leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector3 in [Vector3(-0.035,0,0),Vector3(0,0.02,-0.12),Vector3(0.035,0,0),Vector3(-0.035,0,0),Vector3(0.035,0,0),Vector3(0,-0.01,0.12)]: leaf.add_vertex(point)
	leaf.generate_normals()
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=leaf.commit()
	multi.instance_count=2000
	for i in range(2000):
		var center:Vector3=centers[i%centers.size()]
		var offset:=Vector3(rng.randf_range(-1,1),rng.randf_range(-0.65,0.65),rng.randf_range(-1,1))
		var transform:=Transform3D(Basis.from_euler(Vector3(rng.randf_range(-1,1),rng.randf_range(0,TAU),rng.randf_range(-1,1))),center+offset)
		multi.set_instance_transform(i,transform)
		multi.set_instance_color(i,Color("303b23").lerp(Color("68754b"),rng.randf()))
	var node:=MultiMeshInstance3D.new()
	node.multimesh=multi
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.roughness=0.95
	node.material_override=mat
	root.add_child(node)
