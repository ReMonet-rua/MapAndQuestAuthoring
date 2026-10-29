@tool
extends Area2D
class_name LevelAuthoringCheckpoint

signal activated(checkpoint_id: String, scene_path: String, respawn_position: Vector2)

@export var entity_type := "checkpoint"
@export var checkpoint_id := ""
@export var save_automatically := false
@export var one_shot := true

var _has_activated := false


func _ready() -> void:
	_update_visual_state()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		activate()


func activate() -> void:
	if one_shot and _has_activated:
		return
	_has_activated = true
	_update_visual_state()
	var manager := get_node_or_null("/root/LevelWorldManager")
	if manager != null and manager.has_method("activate_checkpoint"):
		manager.call("activate_checkpoint", checkpoint_id, _get_scene_path(), get_respawn_position())
	if save_automatically:
		var save_manager := get_node_or_null("/root/SaveManager")
		if save_manager != null and save_manager.has_method("save_auto"):
			save_manager.call("save_auto")
	activated.emit(checkpoint_id, _get_scene_path(), get_respawn_position())


func _update_visual_state() -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null and _has_activated:
		visual.color = Color(0.35, 1.0, 0.72, 0.88)
	var label := get_node_or_null("Label") as Label
	if label != null and _has_activated:
		label.text = "已激活检查点"


func get_respawn_position() -> Vector2:
	var marker := get_node_or_null("RespawnPoint") as Node2D
	return marker.global_position if marker != null else global_position


func _get_scene_path() -> String:
	var current_scene := get_tree().current_scene
	return current_scene.scene_file_path if current_scene != null else ""
