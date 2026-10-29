@tool
extends Area2D
class_name LevelAuthoringTraversal

signal traversal_activated(traversal_id: String, traversal_type: String, force_vector: Vector2, body: Node2D)

@export var entity_type := "traversal"
@export var traversal_id := ""
@export_enum("grapple_point", "bounce_pad") var traversal_type := "grapple_point":
	set(value):
		traversal_type = value
		_update_preview()
@export var force_vector := Vector2(0.0, -520.0)
@export var activate_on_enter := false
@export var one_shot := false
var _activated := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
	_update_preview()


func _on_body_entered(body: Node2D) -> void:
	if activate_on_enter and (body.name == "Player" or body.is_in_group("player")):
		activate(body)


func activate(body: Node2D = null) -> void:
	if one_shot and _activated:
		return
	_activated = true
	traversal_activated.emit(traversal_id, traversal_type, force_vector, body)


func _update_preview() -> void:
	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = "抓钩点" if traversal_type == "grapple_point" else "弹跳点"
