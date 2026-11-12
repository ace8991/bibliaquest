extends Node3D
## Shared component; content and quest event IDs are supplied by each instance.
signal activated(dialogue_id: String)
@export var prompt := "[E] Pale ak sòlda a"
@export var dialogue_id := "soldier_intro"
@export var reach := 2.7

func interact() -> void:
	activated.emit(dialogue_id)
