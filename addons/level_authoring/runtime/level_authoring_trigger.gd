@tool
extends Area2D
class_name LevelAuthoringTrigger

signal triggered(trigger_id: String, trigger_type: String, event_key: String, body: Node2D)

@export var entity_type := "trigger"
@export var trigger_id := "trigger"
@export_enum("enter", "interact", "item_acquired", "quest_changed") var trigger_type := "enter"
@export var event_key := ""
@export var one_shot := false

var _has_triggered := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if trigger_type != "enter":
		return
	activate(body)


func activate(body: Node2D = null) -> void:
	if _has_triggered:
		return
	triggered.emit(trigger_id, trigger_type, event_key, body)
	if one_shot:
		_has_triggered = true
		set_deferred("monitoring", false)
