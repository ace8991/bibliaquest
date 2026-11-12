extends Node3D
const Geo = preload("res://scripts/world/geometry.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const Detail = preload("res://scripts/world/landscape_detail.gd")
const Surfaces = preload("res://scripts/world/surface_materials.gd")
const Scans = preload("res://scripts/world/scanned_props.gd")
var soldier: Node3D
var interactables: Array[Node3D] = []
var sun: DirectionalLight3D
var foliage: MultiMeshInstance3D
var tent_sites: Array[Vector2] = []  # read by the mini-map

func ground_height(x: float, z: float) -> float:
	return Terrain.height(x,z)

func ground(x: float, z: float) -> Vector3:
	return Vector3(x, ground_height(x,z), z)

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat:=PanoramaSkyMaterial.new()
	sky_mat.panorama=load("res://assets/environments/sky/kloofendal_48d_partly_cloudy_puresky_2k.hdr")
	sky_mat.energy_multiplier=0.95
	sky.sky_material=sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("c2cbd3")
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color("a8b6bf")
	env.fog_light_energy = 0.65
	env.fog_density = 0.0017
	env.fog_sky_affect = 0.15
	env.tonemap_exposure = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -48, 0)
	sun.light_color = Color("fff1d8")
	sun.light_energy = 0.95
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.6
	sun.directional_shadow_max_distance = 70
	add_child(sun)
	Terrain.build(self)
	var earth := Geo.material(Color("998a6e"))
	var stone := Surfaces.scanned("rocky_terrain_02",0.5)
	var cloth := Geo.material(Color("a18b66"))
	for location: Vector2 in [Vector2(-10,3),Vector2(-19,3),Vector2(10,3),Vector2(-24,-10),Vector2(10,-24)]:
		Geo.tent(self, ground(location.x,location.y), cloth)
		tent_sites.append(location)
	Geo.tent(self, ground(-16,-10), Geo.material(Color("526b75")))
	tent_sites.append(Vector2(-16,-10))
	for x: float in [29.0,36.0,41.0]:
		Geo.tent(self, ground(x,-33), Geo.material(Color("796451")))
		tent_sites.append(Vector2(x,-33))
	for location: Vector2 in [Vector2(-5,3),Vector2(5,3),Vector2(-22,-10),Vector2(-18,-5)]:
		Geo.crate(self, ground(location.x,location.y))
		Scans.instance(self,"ceramic_pot",ground(location.x+0.9,location.y),0.40)
		Geo.jar(self, ground(location.x+1.3,location.y+0.7))
	# Unlit stone fire ring and logs: no costly particles or extra lights.
	for i in range(10):
		var angle := i * TAU / 10
		Geo.box(self, ground(-7+cos(angle),-4+sin(angle)) + Vector3(0,0.14,0), Vector3(0.38,0.28,0.35), stone)
	for z: float in [-4.2,-3.8]:
		Geo.beam(self, ground(-7.7,z)+Vector3.UP*0.12,ground(-6.3,z)+Vector3.UP*0.12,0.12,Geo.material(Color("473b2c")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1740
	for i in range(125):
		var x := rng.randf_range(-42,42)
		var z := rng.randf_range(-42,42)
		if absf(x)<4 or Vector2(x,z).distance_to(Vector2(8,-13))<4 or Vector2(x,z).distance_to(Vector2(-12,-9))<4: continue
		Detail.rock(self,ground(x,z),Vector3(rng.randf_range(0.25,1.2),rng.randf_range(0.2,0.65),rng.randf_range(0.35,1)),i+1740)
	for location: Vector2 in [Vector2(-8,9),Vector2(13,-5),Vector2(23,8),Vector2(-24,-19)]:
		Scans.instance(self,"namaqualand_boulder_02",ground(location.x,location.y)-Vector3.UP*0.12,0.8,location.x*0.7)
	for location: Vector2 in [Vector2(-6,8),Vector2(7,9),Vector2(-22,7),Vector2(15,-9),Vector2(-26,-15),Vector2(24,12),Vector2(18,-27),Vector2(-17,20),Vector2(28,-17),Vector2(-8,-25)]:
		Scans.instance(self,"shrub_02",ground(location.x,location.y),0.65+absf(location.x)*0.012,location.y*0.9,1)
	Detail.ridges(self)
	for location: Vector2 in [Vector2(-28,-18),Vector2(-30,10),Vector2(-24,25),Vector2(32,18),Vector2(37,-12),Vector2(-10,-30)]:
		Detail.olive(self,ground(location.x,location.y),int(location.x*10+location.y))
	# Follow terrain along each boundary; 2.5m wall cannot be jumped.
	for side: float in [-45.0,45.0]:
		for i in range(23):
			var coordinate := -44.0+i*4
			Geo.box(self,ground(coordinate,side)+Vector3(0,1.0,0),Vector3(4.1,3.0,1),stone,true).hide()
			Geo.box(self,ground(side,coordinate)+Vector3(0,1.0,0),Vector3(1,3.0,4.1),stone,true).hide()
	# Each guard faces a sensible direction: the camp entrance, the valley, the fire ring.
	soldier = add_soldier("soldier_intro",Vector2(0,2),Color("82724e"),Vector2(0.15,1))
	add_soldier("watchman",Vector2(8,-13),Color("925d4c"),Vector2(0.55,0.83))
	add_soldier("veteran",Vector2(-12,-9),Color("526b75"),Vector2(0.45,0.9))
	flag(Vector2(1.5,2),Color("465f78"))
	flag(Vector2(9.5,-13),Color("985447"))
	flag(Vector2(-14,-8),Color("465f78"))
	var population := Node3D.new()
	population.name = "CampPopulation"
	add_child(population)
	var residents: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/camp_population.json"))
	for info: Dictionary in residents:
		var resident := preload("res://scripts/world/camp_resident.gd").new()
		resident.configure(info, self)
		population.add_child(resident)
	build_grass(rng)
	I18n.changed.connect(refresh_names)
	Progress.changed.connect(refresh_names)
	Settings.changed.connect(apply_quality)
	refresh_names()
	apply_quality()

func add_soldier(id: String, location: Vector2, color: Color, facing: Vector2 = Vector2(0,-1)) -> Node3D:
	var npc := preload("res://scripts/interactions/interactable.gd").new()
	npc.dialogue_id = id
	npc.name = id
	npc.position = ground(location.x,location.y)
	add_child(npc)
	var visual := Geo.soldier(color, id)
	visual.name = "Visual"
	visual.rotation.y = atan2(-facing.x, -facing.y)
	npc.add_child(visual)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height=1.8
	capsule.radius=0.3
	shape.shape=capsule
	shape.position.y=0.9
	body.add_child(shape)
	body.collision_layer=4
	npc.add_child(body)
	var marker := Label3D.new()
	marker.name="Nameplate"
	marker.position.y=2.65
	marker.font_size=30
	marker.visibility_range_end=22.0
	marker.visibility_range_end_margin=3.0
	marker.pixel_size=0.007
	marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	marker.modulate=Color("ffe1a0")
	npc.add_child(marker)
	interactables.append(npc)
	return npc

func refresh_names() -> void:
	for npc: Node3D in interactables:
		var marker := npc.get_node("Nameplate") as Label3D
		marker.text = ("◇ " if Progress.definition().target == npc.dialogue_id else "") + I18n.text(npc.dialogue_id)

func flag(location: Vector2, color: Color) -> void:
	var position := ground(location.x,location.y)
	Geo.box(self,position+Vector3(0,2,0),Vector3(0.09,4,0.09),Surfaces.scanned("weathered_planks",0.5))
	Geo.box(self,position+Vector3(0.6,3.4,0),Vector3(1.2,0.8,0.04),Surfaces.cloth(color))

func build_grass(rng: RandomNumberGenerator) -> void:
	foliage=MultiMeshInstance3D.new()
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=Scans.grass_mesh()
	multi.instance_count=850
	var bounds:=multi.mesh.get_aabb()
	for i in range(850):
		var x:=rng.randf_range(-43,43)
		var z:=rng.randf_range(-43,43)
		var point:=Vector2(x,z)
		var path:=minf(absf(x),minf(Terrain.path_distance(point,Vector2(0,-4),Vector2(8,-13)),Terrain.path_distance(point,Vector2(0,-4),Vector2(-12,-9))))
		if path<2.3: x+=4.5
		var scale_value:=rng.randf_range(0.25,0.48)/maxf(bounds.size.y,0.01)
		var basis:=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale_value)
		var offset:=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)
		multi.set_instance_transform(i,Transform3D(basis,ground(x,z)+basis*offset))
	foliage.multimesh=multi
	foliage.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foliage)

func apply_quality() -> void:
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=[38.0,60.0,85.0][Settings.quality]
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL if Settings.quality==0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	get_viewport().msaa_3d=Viewport.MSAA_4X if Settings.quality==2 else (Viewport.MSAA_2X if Settings.quality==1 else Viewport.MSAA_DISABLED)
	if foliage: foliage.multimesh.visible_instance_count=[300,550,850][Settings.quality]
