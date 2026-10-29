@tool
extends Area2D
class_name LevelAuthoringFlowZone

signal body_entered_flow(flow_id: String, flow_type: String, flow_vector: Vector2, body: Node2D)
signal body_exited_flow(flow_id: String, body: Node2D)

@export var entity_type := "flow_zone"
@export var flow_id := ""
@export_enum("water_current", "wind_tunnel") var flow_type := "water_current":
	set(value):
		flow_type = value
		_update_preview()
@export var flow_vector := Vector2(240.0, 0.0)


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	_update_preview()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		body_entered_flow.emit(flow_id, flow_type, flow_vector, body)


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		body_exited_flow.emit(flow_id, body)


func _update_preview() -> void:
	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = "水流区" if flow_type == "water_current" else "风道"
