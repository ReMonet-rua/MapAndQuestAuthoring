@tool
extends Area2D
class_name LevelAuthoringHazard

signal hazard_entered(hazard_id: String, hazard_type: String, damage: int, body: Node2D)

@export var entity_type := "hazard"
@export var hazard_id := ""
@export_enum("spikes", "moving_blade", "acid", "lava", "other") var hazard_type := "spikes"
@export_range(0, 999, 1) var damage := 1
@export var one_shot := false
@export var active := true:
	set(value):
		active = value
		_update_active_state()

var _has_triggered := false


func _ready() -> void:
	_update_active_state()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not active or (one_shot and _has_triggered):
		return
	hazard_entered.emit(hazard_id, hazard_type, damage, body)
	if one_shot:
		_has_triggered = true
		active = false


func _update_active_state() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		if is_inside_tree() and not Engine.is_editor_hint():
			collision.set_deferred("disabled", not active)
		else:
			collision.disabled = not active
	var visual := get_node_or_null("EditorPreview") as Polygon2D
	if visual != null:
		visual.modulate.a = 1.0 if active else 0.25
