@tool
extends Area2D
class_name LevelAuthoringPortal

@export var entity_id := ""
@export var entity_type := "portal"
@export var portal_id := "portal"
@export_file("*.tscn") var target_scene_path := ""
@export var target_spawn_point_id := "entry"
@export var enabled := true

var _transition_started := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _transition_started or not enabled:
		return
	if not body is CharacterBody2D:
		return
	if target_scene_path.is_empty():
		push_warning("Portal '%s' has no target scene." % portal_id)
		return
	var world_manager := get_node_or_null("/root/LevelWorldManager")
	if world_manager == null:
		push_warning("LevelWorldManager autoload is not available.")
		return
	_transition_started = true
	world_manager.transition_to_map(target_scene_path, target_spawn_point_id)
