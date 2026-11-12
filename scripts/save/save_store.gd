extends RefCounted
## Schema 2 has its own file; legacy schema 1 remains untouched as a backup.
const PATH := "user://save_v2.json"
const LEGACY_PATH := "user://save_v1.json"
const VERSION := 2
const STAGES := ["arrive", "learn", "complete", "challenge", "witness", "challenge_quiz", "chapter_pause"]

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != VERSION or not data.get("progress") is Dictionary: return false
	var p: Dictionary = data.progress
	if p.get("chapter") != "elah" or p.get("chapter_complete") != false: return false
	var rank := STAGES.find(p.get("stage"))
	if rank < 0 or p.get("mission") != (1 if rank < 3 else 2): return false
	if p.get("completed_objectives") != STAGES.slice(0, rank): return false
	var questions: Array = []
	if rank >= 2: questions.append("elah_stones_01")
	if rank == 6: questions.append("elah_challenge_02")
	if p.get("completed_questions") != questions: return false
	if p.get("xp") != (60 if rank == 6 else (25 if rank >= 2 else 0)): return false
	var pos: Variant = data.get("position")
	if not pos is Array or pos.size() != 3: return false
	for value: Variant in pos:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	return absf(float(pos[0])) <= 44.3 and absf(float(pos[2])) <= 44.3 and float(pos[1]) >= -4 and float(pos[1]) <= 12

static func migrate(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("version") != 1 or not data.get("progress") is Dictionary: return {}
	if not data.progress.get("stage") in ["arrive", "learn", "complete"]: return {}
	var result: Dictionary = data.duplicate(true)
	result.version = VERSION
	if not valid(result): return {}
	# The terrain has changed. Preserve all progress, restore at a known safe camp entry.
	result.position = [0, 0.1, 12]
	return result

static func active_path() -> String:
	return "user://test_profile_save_v2.json" if "--test-profile" in OS.get_cmdline_user_args() else PATH

static func read_save(path: String = "") -> Dictionary:
	var target := active_path() if path.is_empty() else path
	if not FileAccess.file_exists(target):
		if target == PATH and FileAccess.file_exists(LEGACY_PATH): target = LEGACY_PATH
		else: return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(target)) != OK: return {}
	var data: Variant = parser.data
	if valid(data): return data
	return migrate(data) if target == LEGACY_PATH else {}

static func write_save(progress: Dictionary, position: Vector3, path: String = "") -> Error:
	if path.is_empty(): path = active_path()
	var data := {"version": VERSION, "progress": progress, "position": [position.x, position.y, position.z]}
	if not valid(data): return ERR_INVALID_DATA
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)
