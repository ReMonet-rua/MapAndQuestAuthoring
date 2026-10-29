extends Node

const SpawnPoint := preload("res://addons/level_authoring/runtime/level_authoring_spawn_point.gd")
const Checkpoint := preload("res://addons/level_authoring/runtime/level_authoring_checkpoint.gd")

signal map_loaded(scene_path: String, spawn_point_id: String)
signal checkpoint_activated(checkpoint_id: String, scene_path: String)

var _pending_spawn_point_id := ""
var _pending_checkpoint_id := ""
var _pending_scene_path := ""
var _waiting_for_spawn := false
var _saved_location_applied := false
var active_checkpoint_id := ""
var active_checkpoint_scene_path := ""
var active_checkpoint_position := Vector2.ZERO


func transition_to_map(scene_path: String, spawn_point_id: String = "") -> void:
	if scene_path.is_empty():
		push_error("Cannot transition to an empty scene path.")
		return
	if not ResourceLoader.exists(scene_path):
		push_error("Target map does not exist: %s" % scene_path)
		return
	_pending_scene_path = scene_path
	_pending_spawn_point_id = spawn_point_id
	_pending_checkpoint_id = ""
	_waiting_for_spawn = true
	_saved_location_applied = false
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		_waiting_for_spawn = false
		push_error("Failed to load map '%s' with error %s" % [scene_path, error])
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("set_current_location"):
		game_state.call("set_current_location", scene_path, spawn_point_id)


func activate_checkpoint(checkpoint_id: String, scene_path: String, respawn_position: Vector2) -> bool:
	if checkpoint_id.is_empty() or scene_path.is_empty():
		return false
	active_checkpoint_id = checkpoint_id
	active_checkpoint_scene_path = scene_path
	active_checkpoint_position = respawn_position
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("set_current_location"):
		game_state.call("set_current_location", scene_path, checkpoint_id)
	checkpoint_activated.emit(checkpoint_id, scene_path)
	return true


func respawn_at_checkpoint() -> bool:
	if active_checkpoint_id.is_empty() or active_checkpoint_scene_path.is_empty():
		return false
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path == active_checkpoint_scene_path:
		var player := current_scene.find_child("Player", true, false)
		if player is Node2D:
			player.global_position = active_checkpoint_position
			return true
	_pending_scene_path = active_checkpoint_scene_path
	_pending_spawn_point_id = ""
	_pending_checkpoint_id = active_checkpoint_id
	_waiting_for_spawn = true
	_saved_location_applied = true
	var error := get_tree().change_scene_to_file(active_checkpoint_scene_path)
	if error != OK:
		_waiting_for_spawn = false
		push_error("Failed to respawn at checkpoint '%s' with error %s" % [active_checkpoint_id, error])
		return false
	return true


func _process(_delta: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if not _waiting_for_spawn:
		_apply_saved_location(current_scene)
		return
	var player := current_scene.find_child("Player", true, false)
	if player == null:
		return
	var destination := Vector2.ZERO
	if not _pending_checkpoint_id.is_empty():
		var checkpoint := _find_checkpoint(current_scene, _pending_checkpoint_id)
		if checkpoint == null:
			return
		destination = checkpoint.get_respawn_position()
	else:
		var spawn_point := _find_spawn_point(current_scene, _pending_spawn_point_id)
		if spawn_point == null:
			return
		destination = spawn_point.global_position
	if player is Node2D:
		player.global_position = destination
	_waiting_for_spawn = false
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("set_current_location"):
		var saved_id := _pending_checkpoint_id if not _pending_checkpoint_id.is_empty() else _pending_spawn_point_id
		game_state.call("set_current_location", _pending_scene_path, saved_id)
	map_loaded.emit(_pending_scene_path, _pending_spawn_point_id)
	_pending_checkpoint_id = ""
	_saved_location_applied = true


func _apply_saved_location(current_scene: Node) -> void:
	if _saved_location_applied:
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("get"):
		return
	var saved_scene_path := str(game_state.get("current_scene_path"))
	if saved_scene_path.is_empty() or saved_scene_path != current_scene.scene_file_path:
		return
	var saved_spawn_id := str(game_state.get("current_spawn_id"))
	var player := current_scene.find_child("Player", true, false)
	if player is not Node2D:
		return
	var checkpoint := _find_checkpoint(current_scene, saved_spawn_id)
	if checkpoint != null:
		active_checkpoint_id = checkpoint.checkpoint_id
		active_checkpoint_scene_path = current_scene.scene_file_path
		active_checkpoint_position = checkpoint.get_respawn_position()
		player.global_position = active_checkpoint_position
	else:
		var spawn_point := _find_spawn_point(current_scene, saved_spawn_id)
		if spawn_point != null:
			player.global_position = spawn_point.global_position
	_saved_location_applied = true


func _find_spawn_point(root: Node, spawn_point_id: String) -> Node:
	for child in root.get_children():
		if child is SpawnPoint and child.spawn_point_id == spawn_point_id:
			return child
		var nested := _find_spawn_point(child, spawn_point_id)
		if nested != null:
			return nested
	return null


func _find_checkpoint(root: Node, checkpoint_id: String) -> Checkpoint:
	for child in root.get_children():
		if child is Checkpoint and child.checkpoint_id == checkpoint_id:
			return child
		var nested := _find_checkpoint(child, checkpoint_id)
		if nested != null:
			return nested
	return null
