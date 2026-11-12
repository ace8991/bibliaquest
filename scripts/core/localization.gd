extends Node
## Locale-independent IDs preserve progress while display language changes.
signal changed
const CODES := ["ht", "fr", "en", "es"]
const NAMES := ["Kreyòl ayisyen", "Français", "English", "Español"]
var locale := "ht"
var strings: Dictionary = {}
var dialogues: Dictionary = {}
var questions: Array = []

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path()) == OK:
		var selected: Variant = cfg.get_value("language", "locale", "ht")
		if selected in CODES: locale = selected
	set_locale(locale, false)

func set_locale(code: String, persist: bool = true) -> void:
	if not code in CODES: return
	locale = code
	strings = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/%s.json" % code))
	dialogues = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/%s.json" % code))
	questions = JSON.parse_string(FileAccess.get_file_as_string("res://data/questions/%s.json" % code))
	if persist:
		var cfg := ConfigFile.new()
		cfg.set_value("language", "locale", code)
		cfg.save(config_path())
	changed.emit()

func text(key: String) -> String:
	return str(strings.get(key, key))

func question(id: String) -> Dictionary:
	for entry: Dictionary in questions:
		if entry.id == id: return entry
	return {}

func config_path() -> String:
	return "user://test_profile_language.cfg" if "--test-profile" in OS.get_cmdline_user_args() else "user://language.cfg"
