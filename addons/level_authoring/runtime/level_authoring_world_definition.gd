@tool
extends Resource
class_name LevelAuthoringWorldDefinition

@export var world_id := ""
@export var display_name := ""
@export var start_map_id := ""
@export var maps: Array[Dictionary] = []


func find_map(map_id: String) -> Dictionary:
	for map_entry in maps:
		if str(map_entry.get("map_id", "")) == map_id:
			return map_entry
	return {}
