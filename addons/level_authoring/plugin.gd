@tool
extends EditorPlugin

const LevelAuthoringDock := preload("res://addons/level_authoring/editor/level_authoring_dock.gd")
const LevelAuthoringMapGraph := preload("res://addons/level_authoring/editor/level_authoring_map_graph.gd")

var _dock
var _map_graph
var _map_graph_button: Button


func _enter_tree() -> void:
	_dock = LevelAuthoringDock.new()
	_dock.plugin = self
	add_control_to_dock(DOCK_SLOT_LEFT_BL, _dock)
	_map_graph = LevelAuthoringMapGraph.new()
	_map_graph.plugin = self
	_map_graph_button = add_control_to_bottom_panel(_map_graph, "地图连接图")
	_map_graph_button.tooltip_text = "查看各地图的传送关系、可达性和单向出口"


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	if _map_graph != null:
		remove_control_from_bottom_panel(_map_graph)
		_map_graph.queue_free()
		_map_graph = null
		_map_graph_button = null


func _handles(object: Object) -> bool:
	return object is Node2D


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _dock == null:
		return false
	return _dock.handle_canvas_input(event)


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if _dock != null:
		_dock.draw_canvas_overlay(overlay)
