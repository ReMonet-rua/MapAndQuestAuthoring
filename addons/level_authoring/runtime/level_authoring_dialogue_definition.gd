@tool
extends Resource
class_name LevelAuthoringDialogueDefinition

@export var dialogue_id := ""
@export var start_node_id := "start"
@export var nodes: Array[Dictionary] = []


static func from_csv(csv_path: String) -> LevelAuthoringDialogueDefinition:
	var definition := LevelAuthoringDialogueDefinition.new()
	if not FileAccess.file_exists(csv_path):
		return definition
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return definition
	var headers := file.get_csv_line()
	if headers.is_empty():
		return definition
	if str(headers[0]).begins_with("\uFEFF"):
		headers[0] = str(headers[0]).trim_prefix("\uFEFF")
	var header_indexes: Dictionary = {}
	for index in headers.size():
		header_indexes[str(headers[index]).strip_edges()] = index
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty():
			continue
		var node_id := _csv_value(row, header_indexes, "node_id")
		if node_id.is_empty():
			continue
		var node_definition := {
			"node_id": node_id,
			"speaker": _csv_value(row, header_indexes, "speaker"),
			"text": _csv_value(row, header_indexes, "text"),
			"next_node_id": _csv_value(row, header_indexes, "next_node_id"),
			"portrait": _csv_value(row, header_indexes, "portrait"),
		}
		definition.nodes.append(node_definition)
		if definition.dialogue_id.is_empty():
			definition.dialogue_id = _csv_value(row, header_indexes, "dialogue_id")
		var start_value := _csv_value(row, header_indexes, "start_node_id")
		if not start_value.is_empty():
			definition.start_node_id = start_value
	return definition


static func _csv_value(row: PackedStringArray, header_indexes: Dictionary, column_name: String) -> String:
	if not header_indexes.has(column_name):
		return ""
	var index := int(header_indexes[column_name])
	if index < 0 or index >= row.size():
		return ""
	return str(row[index]).strip_edges()


func get_node_definition(node_id: String) -> Dictionary:
	for node_definition in nodes:
		if str(node_definition.get("node_id", "")) == node_id:
			return node_definition
	return {}
