extends RefCounted
## Individual meshes from verified CC0 Poly Haven collections, not whole sample layouts.
static var cache: Dictionary = {}

static func collect(node: Node, inherited: Basis, meshes: Array) -> void:
	var basis := inherited
	if node is Node3D: basis = inherited * node.transform.basis
	if node is MeshInstance3D: meshes.append({"mesh":node.mesh,"basis":basis})
	for child: Node in node.get_children(): collect(child,basis,meshes)

static func choices(asset: String) -> Array:
	if cache.has(asset): return cache[asset]
	var scene: PackedScene = load("res://assets/environments/scanned/%s/%s.gltf" % [asset,asset])
	var root:=scene.instantiate()
	var meshes:Array=[]
	collect(root,Basis.IDENTITY,meshes)
	root.free()
	cache[asset]=meshes
	return meshes

static func instance(parent: Node3D, asset: String, position: Vector3, height: float, angle: float = 0, variant: int = 0) -> MeshInstance3D:
	var meshes:=choices(asset)
	var entry:Dictionary=meshes[mini(variant,meshes.size()-1)]
	var resource:Mesh=entry.mesh
	var source_basis:Basis=entry.basis
	var bounds:=Transform3D(source_basis,Vector3.ZERO)*resource.get_aabb()
	var scale_value:=height/maxf(bounds.size.y,0.01)
	var pivot:=Node3D.new()
	pivot.position=position
	pivot.rotation.y=angle
	parent.add_child(pivot)
	var node:=MeshInstance3D.new()
	node.mesh=resource
	node.basis=source_basis.scaled(Vector3.ONE*scale_value)
	node.position=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*scale_value
	node.lod_bias=0.25
	if asset=="ceramic_pot":
		var mat:=resource.surface_get_material(0).duplicate() as StandardMaterial3D
		mat.metallic=0.0
		mat.metallic_texture=null
		mat.roughness_texture=null
		mat.roughness=0.87
		node.material_override=mat
	pivot.add_child(node)
	return node

static func grass_mesh() -> Mesh:
	# An 833-triangle dense clump, rather than the full 17-object collection.
	return choices("grass_medium_01")[0].mesh
