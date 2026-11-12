extends Node
signal changed
var sensitivity := 0.0025
var quality := 0
var fullscreen := false
var volumes := {"Master": 0.8, "Music": 0.6, "SFX": 0.8}

func _ready() -> void:
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var cfg := ConfigFile.new()
	if cfg.load(config_path()) == OK:
		sensitivity = clampf(float(cfg.get_value("input", "sensitivity", sensitivity)), 0.0005, 0.006)
		quality = clampi(int(cfg.get_value("video", "quality", 0)), 0, 2)
		fullscreen = bool(cfg.get_value("video", "fullscreen", false))
		for bus: String in volumes:
			volumes[bus] = clampf(float(cfg.get_value("audio", bus, volumes[bus])), 0, 1)
	apply()

func apply() -> void:
	for bus: String in volumes:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(volumes[bus], 0.0001)))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()

func save_settings() -> void:
	apply()
	var cfg := ConfigFile.new()
	cfg.set_value("input", "sensitivity", sensitivity)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	for bus: String in volumes: cfg.set_value("audio", bus, volumes[bus])
	cfg.save(config_path())

func config_path() -> String:
	return "user://test_profile_settings.cfg" if "--test-profile" in OS.get_cmdline_user_args() else "user://settings.cfg"
