@tool
extends Resource
class_name LevelAuthoringQuestDefinition

@export var quest_id := ""
@export var title := ""
@export_multiline var description := ""
@export var steps: Array[Dictionary] = []
@export var rewards: Array[String] = []


func get_step(step_id: String) -> Dictionary:
	for step in steps:
		if str(step.get("step_id", "")) == step_id:
			return step
	return {}
