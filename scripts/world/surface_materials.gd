extends RefCounted
## Offline, CC0 Poly Haven material maps; see assets/materials/SOURCES.json.
static var cache: Dictionary = {}

static func scanned(asset: String, scale_value: float = 1.0) -> StandardMaterial3D:
	var key := asset + str(scale_value)
	if cache.has(key): return cache[key]
	var mat := StandardMaterial3D.new()
	var base := "res://assets/materials/%s/%s" % [asset, asset]
	mat.albedo_texture = load(base + "_diff_1k.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load(base + "_nor_gl_1k.jpg")
	mat.normal_scale = 0.4
	if asset == "rocky_terrain_02": mat.albedo_color = Color(1.0, 0.83, 0.7)
	mat.roughness_texture = load(base + "_rough_1k.jpg")
	mat.roughness = 0.95
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale_value
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	cache[key] = mat
	return mat

static func cloth(color: Color) -> ShaderMaterial:
	var key := "cloth" + color.to_html()
	if cache.has(key): return cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/materials/woven_cloth.gdshader")
	mat.set_shader_parameter("cloth_color", color)
	cache[key] = mat
	return mat
