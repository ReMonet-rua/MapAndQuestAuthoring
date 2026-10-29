@tool
extends VBoxContainer

const MapValidator := preload("res://addons/level_authoring/editor/level_authoring_map_validator.gd")
const MAPS_DIRECTORY := "res://scenes/maps"
const PORT_TYPE := 1
const REACHABLE_COLOR := Color(0.38, 0.82, 0.58, 1.0)
const BROKEN_COLOR := Color(0.94, 0.38, 0.32, 1.0)
const HORIZONTAL_GAP := 380.0
const VERTICAL_GAP := 250.0

var plugin: EditorPlugin
var _start_map_selector: OptionButton
var _graph: GraphEdit
var _summary_label: Label
var _status_label: Label
var _validator
var _map_paths: Array[String] = []
var _map_data_by_path: Dictionary = {}
var _graph_name_by_path: Dictionary = {}
var _spawn_slot_by_path: Dictionary = {}
var _portal_slot_by_path: Dictionary = {}
var _edges: Array[Dictionary] = []
var _reachable_paths: Dictionary = {}
var _start_path := ""


func _ready() -> void:
	name = "地图连接图"
	_build_ui()
	refresh_graph()


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	var start_label := Label.new()
	start_label.text = "可达性起点"
	toolbar.add_child(start_label)
	_start_map_selector = OptionButton.new()
	_start_map_selector.custom_minimum_size = Vector2(220.0, 0.0)
	_start_map_selector.item_selected.connect(_on_start_map_selected)
	toolbar.add_child(_start_map_selector)
	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(refresh_graph)
	toolbar.add_child(refresh_button)
	var layout_button := Button.new()
	layout_button.text = "自动排列"
	layout_button.pressed.connect(_apply_layout)
	toolbar.add_child(layout_button)
	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toolbar.add_child(_summary_label)
	add_child(toolbar)

	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.custom_minimum_size = Vector2(720.0, 420.0)
	_graph.show_grid = true
	_graph.show_minimap_button = true
	_graph.minimap_enabled = true
	_graph.add_valid_connection_type(PORT_TYPE, PORT_TYPE)
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	add_child(_graph)

	_status_label = Label.new()
	_status_label.text = "连接图只读；请在地图素材属性中更改传送目标。"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)
	_validator = MapValidator.new()


func refresh_graph() -> void:
	if _graph == null:
		return
	_map_paths.clear()
	_map_data_by_path.clear()
	_scan_maps(MAPS_DIRECTORY)
	_map_paths.sort()
	_load_maps_and_linked_targets()
	_map_paths.sort()
	_populate_start_map_selector()
	_build_graph()
	_status_label.text = "连接图只读。点击地图卡片中的“打开地图”或传送点行中的“定位”可跳转到场景。"


func _scan_maps(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not file_name.begins_with("."):
			var child_path := directory_path.path_join(file_name)
			if directory.current_is_dir():
				_scan_maps(child_path)
			elif file_name.ends_with(".tscn") and not _map_paths.has(child_path):
				_map_paths.append(child_path)
		file_name = directory.get_next()
	directory.list_dir_end()


func _load_maps_and_linked_targets() -> void:
	var checked_paths: Dictionary = {}
	var next_index := 0
	while next_index < _map_paths.size():
		var scene_path := _map_paths[next_index]
		next_index += 1
		if checked_paths.has(scene_path):
			continue
		checked_paths[scene_path] = true
		var map_data: Dictionary = _validator.read_map_data(scene_path)
		_map_data_by_path[scene_path] = map_data
		if map_data.has("error"):
			continue
		for portal in map_data.get("portals", []):
			if not bool(portal.get("enabled", true)):
				continue
			var target_path := str(portal.get("target_scene_path", "")).strip_edges()
			if target_path.is_empty() or not FileAccess.file_exists(target_path):
				continue
			if not _map_paths.has(target_path):
				_map_paths.append(target_path)


func _populate_start_map_selector() -> void:
	_start_map_selector.clear()
	_start_map_selector.disabled = _map_paths.is_empty()
	for scene_path in _map_paths:
		var map_data: Dictionary = _map_data_by_path.get(scene_path, {})
		_start_map_selector.add_item(_get_map_title(scene_path, map_data))
		_start_map_selector.set_item_tooltip(_start_map_selector.get_item_count() - 1, scene_path)
	if _map_paths.is_empty():
		_start_path = ""
		return
	var preferred_path := _get_current_scene_path()
	if not _map_paths.has(preferred_path):
		preferred_path = _map_paths[0]
	_start_path = preferred_path
	_start_map_selector.select(_map_paths.find(_start_path))


func _get_current_scene_path() -> String:
	var edited_root := EditorInterface.get_edited_scene_root()
	if edited_root == null:
		return ""
	return edited_root.scene_file_path


func _on_start_map_selected(index: int) -> void:
	if index < 0 or index >= _map_paths.size():
		return
	_start_path = _map_paths[index]
	_build_graph()
	_status_label.text = "已将“%s”设为起点；不可达地图以警示标题标出。" % _get_map_title(_start_path, _map_data_by_path.get(_start_path, {}))


func _build_graph() -> void:
	_graph.clear_connections()
	for child in _graph.get_children():
		if child is GraphNode:
			child.free()
	_graph_name_by_path.clear()
	_spawn_slot_by_path.clear()
	_portal_slot_by_path.clear()
	_edges = _collect_valid_edges()
	var adjacency := _build_adjacency()
	var incoming := _build_incoming_edges()
	_reachable_paths = _find_reachable_paths(adjacency)
	var depths := _find_depths(adjacency)
	var max_depth := 0
	for depth_value in depths.values():
		max_depth = maxi(max_depth, int(depth_value))
	var rows_by_depth: Dictionary = {}

	for map_index in range(_map_paths.size()):
		var scene_path := _map_paths[map_index]
		var map_data: Dictionary = _map_data_by_path.get(scene_path, {})
		var graph_node_name := "Map_%03d" % map_index
		_graph_name_by_path[scene_path] = graph_node_name
		var depth := int(depths.get(scene_path, max_depth + 1))
		if not _reachable_paths.has(scene_path):
			depth = max_depth + 1
		var row := int(rows_by_depth.get(depth, 0))
		rows_by_depth[depth] = row + 1
		var graph_node := _build_map_node(scene_path, graph_node_name, map_data)
		_graph.add_child(graph_node)
		graph_node.position_offset = Vector2(100.0 + depth * HORIZONTAL_GAP, 80.0 + row * VERTICAL_GAP)

	var visible_edge_count := 0
	for edge in _edges:
		var from_path := str(edge.get("from_path", ""))
		var to_path := str(edge.get("to_path", ""))
		if from_path == to_path:
			continue
		var from_slots: Dictionary = _portal_slot_by_path.get(from_path, {})
		var to_slots: Dictionary = _spawn_slot_by_path.get(to_path, {})
		var from_port := int(from_slots.get(int(edge.get("portal_index", -1)), -1))
		var to_port := int(to_slots.get(str(edge.get("target_spawn_point_id", "")), -1))
		if from_port < 0 or to_port < 0:
			continue
		_graph.connect_node(
			str(_graph_name_by_path[from_path]),
			from_port,
			str(_graph_name_by_path[to_path]),
			to_port,
			true
		)
		visible_edge_count += 1

	_update_summary(adjacency, incoming, visible_edge_count)
	_graph.scroll_offset = Vector2(-40.0, -20.0)


func _build_map_node(scene_path: String, graph_node_name: String, map_data: Dictionary) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.name = graph_node_name
	var map_title := _get_map_title(scene_path, map_data)
	if scene_path == _start_path:
		graph_node.title = "%s · 起点" % map_title
	elif _reachable_paths.has(scene_path):
		graph_node.title = "%s · 可达" % map_title
	else:
		graph_node.title = "%s · 不可达" % map_title
	graph_node.custom_minimum_size = Vector2(300.0, 0.0)
	var title_color := REACHABLE_COLOR if _reachable_paths.has(scene_path) else BROKEN_COLOR
	graph_node.add_theme_color_override("title_color", title_color)

	var map_id := str(map_data.get("map_id", ""))
	var map_info := "地图 ID：%s" % (map_id if not map_id.is_empty() else "未设置")
	_add_graph_slot(graph_node, _make_label(map_info), false, Color.TRANSPARENT, false, Color.TRANSPARENT)

	var open_button := Button.new()
	open_button.text = "打开地图"
	open_button.pressed.connect(_open_map.bind(scene_path))
	_add_graph_slot(graph_node, open_button, false, Color.TRANSPARENT, false, Color.TRANSPARENT)

	if map_data.has("error"):
		var error_label := _make_label(str(map_data.get("error", "地图无法读取。")))
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_add_graph_slot(graph_node, error_label, false, Color.TRANSPARENT, false, Color.TRANSPARENT)

	var spawn_slots: Dictionary = {}
	var seen_spawn_ids: Dictionary = {}
	for spawn_point in map_data.get("spawn_points", []):
		var spawn_id := str(spawn_point.get("id", "")).strip_edges()
		var spawn_text := "入口 · %s" % (spawn_id if not spawn_id.is_empty() else "ID 为空")
		var duplicate_spawn_id := not spawn_id.is_empty() and seen_spawn_ids.has(spawn_id)
		if duplicate_spawn_id:
			spawn_text += " · ID 重复"
		seen_spawn_ids[spawn_id] = true
		var spawn_row := _make_label(spawn_text)
		var spawn_color := BROKEN_COLOR if spawn_id.is_empty() or duplicate_spawn_id else REACHABLE_COLOR
		var slot_index := _add_graph_slot(graph_node, spawn_row, true, spawn_color, false, Color.TRANSPARENT)
		if not spawn_id.is_empty() and not duplicate_spawn_id:
			spawn_slots[spawn_id] = slot_index
	_spawn_slot_by_path[scene_path] = spawn_slots

	var portal_slots: Dictionary = {}
	var portals: Array = map_data.get("portals", [])
	for portal_index in range(portals.size()):
		var portal: Dictionary = portals[portal_index]
		var portal_id := str(portal.get("id", "传送点")).strip_edges()
		var target_path := str(portal.get("target_scene_path", "")).strip_edges()
		var target_spawn_id := str(portal.get("target_spawn_point_id", "")).strip_edges()
		var enabled := bool(portal.get("enabled", true))
		var target_title := _get_map_title(target_path, _map_data_by_path.get(target_path, {})) if not target_path.is_empty() else "未设置目标"
		var target_is_valid := enabled and _has_target_spawn(target_path, target_spawn_id)
		var link_direction := ""
		if not enabled:
			link_direction = " · 已停用"
		elif target_is_valid:
			link_direction = " · 双向" if _has_reverse_connection(target_path, scene_path) else " · 单向"
		else:
			link_direction = " · 目标未配置"
		var portal_label := _make_label("%s → %s / %s%s" % [portal_id, target_title, target_spawn_id if not target_spawn_id.is_empty() else "入口未指定", link_direction])
		portal_label.tooltip_text = "%s\n%s → %s / %s" % [scene_path, portal_id, target_path, target_spawn_id]
		var portal_row := HBoxContainer.new()
		var locate_button := Button.new()
		locate_button.text = "定位"
		locate_button.pressed.connect(_locate_portal.bind(scene_path, portal.get("node_parts", [])))
		portal_row.add_child(locate_button)
		portal_row.add_child(portal_label)
		var output_color := REACHABLE_COLOR if target_is_valid else BROKEN_COLOR
		var slot_index := _add_graph_slot(graph_node, portal_row, false, Color.TRANSPARENT, enabled, output_color)
		portal_slots[portal_index] = slot_index
	_portal_slot_by_path[scene_path] = portal_slots
	return graph_node


func _add_graph_slot(graph_node: GraphNode, control: Control, input_enabled: bool, input_color: Color, output_enabled: bool, output_color: Color) -> int:
	graph_node.add_child(control)
	var slot_index := graph_node.get_child_count() - 1
	graph_node.set_slot(slot_index, input_enabled, PORT_TYPE, input_color, output_enabled, PORT_TYPE, output_color)
	return slot_index


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _get_map_title(scene_path: String, map_data: Dictionary) -> String:
	var display_name := str(map_data.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		return display_name
	if scene_path.is_empty():
		return "未知地图"
	return scene_path.get_file().get_basename()


func _collect_valid_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for scene_path in _map_paths:
		var map_data: Dictionary = _map_data_by_path.get(scene_path, {})
		if map_data.has("error"):
			continue
		var portals: Array = map_data.get("portals", [])
		for portal_index in range(portals.size()):
			var portal: Dictionary = portals[portal_index]
			if not bool(portal.get("enabled", true)):
				continue
			var target_path := str(portal.get("target_scene_path", "")).strip_edges()
			var target_spawn_id := str(portal.get("target_spawn_point_id", "")).strip_edges()
			if _has_target_spawn(target_path, target_spawn_id):
				result.append({
					"from_path": scene_path,
					"to_path": target_path,
					"portal_index": portal_index,
					"target_spawn_point_id": target_spawn_id,
				})
	return result


func _has_target_spawn(target_path: String, spawn_id: String) -> bool:
	if target_path.is_empty() or spawn_id.is_empty():
		return false
	var target_data: Dictionary = _map_data_by_path.get(target_path, {})
	if target_data.is_empty() or target_data.has("error"):
		return false
	for spawn_point in target_data.get("spawn_points", []):
		if str(spawn_point.get("id", "")).strip_edges() == spawn_id:
			return true
	return false


func _has_reverse_connection(from_path: String, to_path: String) -> bool:
	var source_data: Dictionary = _map_data_by_path.get(from_path, {})
	if source_data.is_empty() or source_data.has("error"):
		return false
	for portal in source_data.get("portals", []):
		if not bool(portal.get("enabled", true)):
			continue
		if str(portal.get("target_scene_path", "")).strip_edges() != to_path:
			continue
		var target_spawn_id := str(portal.get("target_spawn_point_id", "")).strip_edges()
		if _has_target_spawn(to_path, target_spawn_id):
			return true
	return false


func _build_adjacency() -> Dictionary:
	var adjacency: Dictionary = {}
	for scene_path in _map_paths:
		adjacency[scene_path] = []
	for edge in _edges:
		var from_path := str(edge.get("from_path", ""))
		var to_path := str(edge.get("to_path", ""))
		var destinations: Array = adjacency.get(from_path, [])
		if not destinations.has(to_path):
			destinations.append(to_path)
		adjacency[from_path] = destinations
	return adjacency


func _build_incoming_edges() -> Dictionary:
	var incoming: Dictionary = {}
	for scene_path in _map_paths:
		incoming[scene_path] = []
	for edge in _edges:
		var to_path := str(edge.get("to_path", ""))
		var sources: Array = incoming.get(to_path, [])
		var from_path := str(edge.get("from_path", ""))
		if not sources.has(from_path):
			sources.append(from_path)
		incoming[to_path] = sources
	return incoming


func _find_reachable_paths(adjacency: Dictionary) -> Dictionary:
	var reachable: Dictionary = {}
	if _start_path.is_empty() or not _map_data_by_path.has(_start_path):
		return reachable
	if _map_data_by_path[_start_path].has("error"):
		return reachable
	var queue: Array[String] = [_start_path]
	var cursor := 0
	while cursor < queue.size():
		var scene_path := queue[cursor]
		cursor += 1
		if reachable.has(scene_path):
			continue
		reachable[scene_path] = true
		for destination in adjacency.get(scene_path, []):
			if not reachable.has(str(destination)):
				queue.append(str(destination))
	return reachable


func _find_depths(adjacency: Dictionary) -> Dictionary:
	var depths: Dictionary = {}
	if _start_path.is_empty() or not _map_data_by_path.has(_start_path):
		return depths
	if _map_data_by_path[_start_path].has("error"):
		return depths
	depths[_start_path] = 0
	var queue: Array[String] = [_start_path]
	var cursor := 0
	while cursor < queue.size():
		var scene_path := queue[cursor]
		cursor += 1
		for destination in adjacency.get(scene_path, []):
			var destination_path := str(destination)
			if depths.has(destination_path):
				continue
			depths[destination_path] = int(depths[scene_path]) + 1
			queue.append(destination_path)
	return depths


func _update_summary(adjacency: Dictionary, incoming: Dictionary, visible_edge_count: int) -> void:
	var isolated_count := 0
	var one_way_count := 0
	for scene_path in _map_paths:
		var data: Dictionary = _map_data_by_path.get(scene_path, {})
		if data.has("error"):
			continue
		if adjacency.get(scene_path, []).is_empty() and incoming.get(scene_path, []).is_empty():
			isolated_count += 1
	for edge in _edges:
		if not _has_reverse_connection(str(edge.get("to_path", "")), str(edge.get("from_path", ""))):
			one_way_count += 1
	var valid_map_count := 0
	for scene_path in _map_paths:
		if not _map_data_by_path.get(scene_path, {}).has("error"):
			valid_map_count += 1
	var unreachable_count := maxi(0, valid_map_count - _reachable_paths.size())
	_summary_label.text = "地图 %d · 连线 %d · 不可达 %d · 孤立 %d · 单向出口 %d" % [valid_map_count, visible_edge_count, unreachable_count, isolated_count, one_way_count]


func _apply_layout() -> void:
	if _graph == null or _map_paths.is_empty():
		return
	_build_graph()
	_status_label.text = "已按起点可达关系重新排列地图。"


func _open_map(scene_path: String) -> void:
	if not FileAccess.file_exists(scene_path):
		_status_label.text = "地图文件不存在：%s" % scene_path
		return
	EditorInterface.open_scene_from_path(scene_path)
	_status_label.text = "已打开地图：%s" % scene_path


func _locate_portal(scene_path: String, node_parts: Array) -> void:
	if not FileAccess.file_exists(scene_path):
		_status_label.text = "地图文件不存在：%s" % scene_path
		return
	EditorInterface.open_scene_from_path(scene_path)
	call_deferred("_select_node_after_open", scene_path, node_parts.duplicate())


func _select_node_after_open(scene_path: String, node_parts: Array) -> void:
	for attempt in range(8):
		await get_tree().process_frame
		var edited_root := EditorInterface.get_edited_scene_root()
		if edited_root == null or edited_root.scene_file_path != scene_path:
			continue
		var target_node: Node = edited_root
		for node_part in node_parts:
			target_node = target_node.get_node_or_null(NodePath(str(node_part)))
			if target_node == null:
				break
		if target_node == null:
			_status_label.text = "地图已打开，但没有找到传送点节点。"
			return
		var editor_selection = EditorInterface.get_selection()
		editor_selection.clear()
		editor_selection.add_node(target_node)
		EditorInterface.edit_node(target_node)
		_status_label.text = "已打开并选中传送点：%s" % target_node.name
		return
	_status_label.text = "地图已打开；请切换到 2D 视图查看传送点。"


func _on_connection_request(_from_node: StringName, _from_port: int, _to_node: StringName, _to_port: int) -> void:
	_status_label.text = "连接图只读；请在地图中的传送点属性里修改目标。"


func _on_disconnection_request(_from_node: StringName, _from_port: int, _to_node: StringName, _to_port: int) -> void:
	_status_label.text = "连接图只读；请在地图中的传送点属性里修改目标。"
