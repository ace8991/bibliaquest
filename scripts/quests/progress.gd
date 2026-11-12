extends Node
signal changed
var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters/elah.json"))
var stage := "arrive"
var completed_objectives: Array = []
var completed_questions: Array = []
var xp := 0
var chapter_complete := false

func definition() -> Dictionary:
	for item: Dictionary in chapter.stages:
		if item.id == stage: return item
	return chapter.stages[0]

func mission() -> int:
	return int(definition().mission)

func reset() -> void:
	stage = "arrive"
	completed_objectives.clear()
	completed_questions.clear()
	xp = 0
	chapter_complete = false
	changed.emit()

func event(event_id: String) -> void:
	var stages: Array = chapter.stages
	for index in range(stages.size() - 1):
		if stages[index].id == stage and stages[index].event == event_id:
			# Quiz transitions can only happen after their unique answer was awarded.
			if event_id == "quiz_passed" and not completed_questions.has(stages[index].question): return
			completed_objectives.append(stage)
			stage = stages[index + 1].id
			changed.emit()
			return

func answer(question_id: String, choice: int) -> bool:
	if definition().get("question", "") != question_id: return false
	var question := I18n.question(question_id)
	if question.is_empty() or choice != int(question.correct) or completed_questions.has(question_id): return false
	completed_questions.append(question_id)
	xp += int(question.xp)
	event("quiz_passed")
	return true

func objective() -> String:
	return I18n.text(definition().objective)

func snapshot() -> Dictionary:
	return {"chapter": "elah", "mission": mission(), "stage": stage,
		"completed_objectives": completed_objectives.duplicate(),
		"completed_questions": completed_questions.duplicate(), "xp": xp,
		"chapter_complete": false}

func restore(data: Dictionary) -> void:
	stage = data.stage
	completed_objectives = data.completed_objectives.duplicate()
	completed_questions = data.completed_questions.duplicate()
	xp = int(data.xp)
	chapter_complete = false
	changed.emit()
