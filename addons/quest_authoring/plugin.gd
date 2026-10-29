@tool
extends EditorPlugin

const LevelAuthoringTaskEditor := preload("res://addons/level_authoring/editor/level_authoring_task_editor.gd")

var _task_editor


func _enter_tree() -> void:
	_task_editor = LevelAuthoringTaskEditor.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _task_editor)


func _exit_tree() -> void:
	if _task_editor != null:
		remove_control_from_docks(_task_editor)
		_task_editor.queue_free()
		_task_editor = null
