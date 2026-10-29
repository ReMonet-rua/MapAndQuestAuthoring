@tool
extends Node2D
class_name LevelAuthoringNpcService

signal service_requested(service_id: String, service_type: String, body: Node2D)

@export var entity_type := "npc"
@export var service_id := ""
@export_enum("merchant", "ability_trainer", "map_seller", "quest_board") var service_type := "merchant"
@export_file("*.csv") var dialogue_file := ""
@export var condition_id := ""
@export var display_name := "服务 NPC":
	set(value):
		display_name = value
		_update_preview()


func _ready() -> void:
	_update_preview()


func request_service(body: Node2D = null, available_condition_id: String = "") -> bool:
	if not condition_id.is_empty() and available_condition_id != condition_id:
		return false
	service_requested.emit(service_id, service_type, body)
	return true


func _update_preview() -> void:
	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = display_name
