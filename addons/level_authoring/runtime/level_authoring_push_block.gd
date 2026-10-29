@tool
extends RigidBody2D
class_name LevelAuthoringPushBlock

signal pushed(block_id: String, body: Node2D)

@export var entity_type := "pushable"
@export var block_id := ""


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Node2D and (body.name == "Player" or body.is_in_group("player")):
		pushed.emit(block_id, body)
