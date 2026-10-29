@tool
extends VBoxContainer

const MapRoot := preload("res://addons/level_authoring/runtime/level_authoring_map.gd")
const ProjectPaths := preload("res://addons/level_authoring/runtime/level_authoring_project_paths.gd")
const DialogueDefinition := preload("res://addons/level_authoring/runtime/level_authoring_dialogue_definition.gd")
const MapValidator := preload("res://addons/level_authoring/editor/level_authoring_map_validator.gd")
const PLACEHOLDER_TILESET_PATH := "res://addons/level_authoring/resources/terrain_placeholder_tileset.tres"
const ASSET_CATEGORIES := ["全部", "平台", "障碍", "危险", "机关", "检查点", "出生点", "探索标记", "能力与收集", "地图设施", "奖励", "遭遇工具", "NPC服务", "环境谜题", "NPC", "敌人", "物品", "传送点", "触发器", "角色", "实体", "其他"]
const CANVAS_TOOL_SELECT := 0
const CANVAS_TOOL_PLACE := 1
const CANVAS_TOOL_ERASE := 2
const CANVAS_ID_PROPERTIES := ["entity_id", "portal_id", "spawn_point_id", "trigger_id", "barrier_id", "hazard_id", "mechanism_id", "checkpoint_id", "marker_id", "pickup_id", "encounter_id", "spawn_id", "route_id", "service_id", "traversal_id", "flow_id", "block_id", "station_id", "chest_id"]
const GENERIC_ID_VALUES := ["", "entity", "portal", "entry", "trigger", "barrier", "hazard", "switch", "checkpoint", "pickup", "encounter", "spawn", "route", "service", "traversal", "flow", "block", "marker", "station", "chest"]
const MAP_LAYER_NAMES := ["BackgroundLayer", "TileLayer", "CollisionLayer", "DecorationLayer", "EntitiesLayer", "NPCsLayer", "ItemsLayer", "TriggersLayer", "PortalsLayer", "SpawnPoints"]
const UNSNAPPED_BRUSH_SPACING := 16.0

var plugin: EditorPlugin
var _asset_list: ItemList
var _asset_category_filter: OptionButton
var _asset_search: LineEdit
var _map_id_edit: LineEdit
var _map_selector: OptionButton
var _create_map_panel: Control
var _canvas_tool_selector: OptionButton
var _snap_to_grid_toggle: CheckButton
var _status_label: Label
var _validation_map_selector: OptionButton
var _validation_summary: Label
var _validation_issue_list: ItemList
var _validation_issue_details: Label
var _locate_validation_issue_button: Button
var _reference_node_label: Label
var _reference_map_selector: OptionButton
var _reference_spawn_selector: OptionButton
var _reference_apply_button: Button
var _reference_status_label: Label
var _reference_target_paths: Array[String] = []
var _reference_spawn_ids: Array[String] = []
var _reference_node: Node
var _editor_selection
var _editor_undo_redo
var _asset_paths: Array[String] = []
var _all_asset_paths: Array[String] = []
var _asset_category_by_path: Dictionary = {}
var _map_paths: Array[String] = []
var _selected_asset_path := ""
var _validation_issues: Array[Dictionary] = []
var _canvas_stroke_active := false
var _canvas_stroke_tool := -1
var _canvas_stroke_root: Node2D
var _canvas_stroke_undo_redo
var _canvas_stroke_operation_count := 0
var _canvas_stroke_cells: Dictionary = {}
var _canvas_stroke_nodes: Dictionary = {}
var _canvas_stroke_reserved_names: Dictionary = {}
var _canvas_stroke_last_local_position := Vector2.ZERO
var _selection_drag_active := false
var _selection_drag_start_screen := Vector2.ZERO
var _selection_drag_current_screen := Vector2.ZERO
var _selection_drag_start_world := Vector2.ZERO
var _selection_drag_additive := false
var _last_canvas_world_position := Vector2.ZERO
var _has_last_canvas_world_position := false
var _clipboard: Array[Dictionary] = []
var _clipboard_paste_offset := Vector2.ZERO
var _generated_id_counter := 0


func _ready() -> void:
	name = "关卡搭建"
	custom_minimum_size = Vector2(280.0, 0.0)
	_build_ui()
	_editor_selection = EditorInterface.get_selection()
	if not _editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		_editor_selection.selection_changed.connect(_on_editor_selection_changed)
	_editor_undo_redo = plugin.get_undo_redo() if plugin != null else null
	if _editor_undo_redo != null and not _editor_undo_redo.version_changed.is_connected(_on_editor_undo_redo_version_changed):
		_editor_undo_redo.version_changed.connect(_on_editor_undo_redo_version_changed)
	refresh_maps()
	refresh_assets()
	_update_reference_panel()


func _exit_tree() -> void:
	_finish_canvas_stroke()
	_selection_drag_active = false
	_clear_canvas_clipboard()
	if is_instance_valid(_editor_selection) and _editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		_editor_selection.selection_changed.disconnect(_on_editor_selection_changed)
	if is_instance_valid(_editor_undo_redo) and _editor_undo_redo.version_changed.is_connected(_on_editor_undo_redo_version_changed):
		_editor_undo_redo.version_changed.disconnect(_on_editor_undo_redo_version_changed)


func _build_ui() -> void:
	var tabs := TabContainer.new()
	tabs.name = "工具页签"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_build_map_page(tabs)
	_build_asset_page(tabs)
	_build_dialogue_page(tabs)
	_build_reference_page(tabs)
	_build_validation_page(tabs)

	_status_label = Label.new()
	_status_label.text = "就绪。"
	_status_label.clip_text = true
	_status_label.custom_minimum_size = Vector2(0.0, 24.0)
	add_child(_status_label)


func _build_map_page(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "地图"
	page.custom_minimum_size = Vector2(280.0, 0.0)
	tabs.add_child(page)

	var map_select_row := HBoxContainer.new()
	_map_selector = OptionButton.new()
	_map_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_selector.item_selected.connect(_on_map_selected)
	map_select_row.add_child(_map_selector)
	var refresh_maps_button := Button.new()
	refresh_maps_button.text = "刷新"
	refresh_maps_button.tooltip_text = "重新扫描 scenes/maps 中的地图场景"
	refresh_maps_button.pressed.connect(refresh_maps)
	map_select_row.add_child(refresh_maps_button)
	page.add_child(map_select_row)

	var map_actions_row := HBoxContainer.new()
	var open_selected_map_button := Button.new()
	open_selected_map_button.text = "打开"
	open_selected_map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_selected_map_button.pressed.connect(_on_open_selected_map_pressed)
	map_actions_row.add_child(open_selected_map_button)
	var run_selected_map_button := Button.new()
	run_selected_map_button.text = "运行选中"
	run_selected_map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_selected_map_button.pressed.connect(_on_run_selected_map_pressed)
	map_actions_row.add_child(run_selected_map_button)
	page.add_child(map_actions_row)

	var run_current_scene_button := Button.new()
	run_current_scene_button.text = "运行当前场景"
	run_current_scene_button.tooltip_text = "运行当前正在编辑的场景"
	run_current_scene_button.pressed.connect(_on_run_current_scene_pressed)
	page.add_child(run_current_scene_button)

	var create_map_toggle := Button.new()
	create_map_toggle.text = "新建地图"
	create_map_toggle.toggle_mode = true
	create_map_toggle.toggled.connect(_on_create_map_toggled)
	page.add_child(create_map_toggle)

	_create_map_panel = HBoxContainer.new()
	_create_map_panel.visible = false
	_map_id_edit = LineEdit.new()
	_map_id_edit.placeholder_text = "地图 ID"
	_map_id_edit.text = "new_map"
	_map_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_map_panel.add_child(_map_id_edit)
	var create_map_button := Button.new()
	create_map_button.text = "创建"
	create_map_button.pressed.connect(_on_create_map_pressed)
	_create_map_panel.add_child(create_map_button)
	page.add_child(_create_map_panel)


func _build_asset_page(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "素材"
	page.custom_minimum_size = Vector2(280.0, 0.0)
	tabs.add_child(page)

	var asset_filter_row := HBoxContainer.new()
	var category_label := Label.new()
	category_label.text = "分类"
	asset_filter_row.add_child(category_label)
	_asset_category_filter = OptionButton.new()
	_asset_category_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for category in ASSET_CATEGORIES:
		_asset_category_filter.add_item(category)
	_asset_category_filter.item_selected.connect(_on_asset_category_selected)
	asset_filter_row.add_child(_asset_category_filter)
	page.add_child(asset_filter_row)

	_asset_search = LineEdit.new()
	_asset_search.placeholder_text = "搜索素材名称或路径"
	_asset_search.clear_button_enabled = true
	_asset_search.text_changed.connect(_on_asset_search_changed)
	page.add_child(_asset_search)

	_asset_list = ItemList.new()
	_asset_list.custom_minimum_size = Vector2(260.0, 220.0)
	_asset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_list.item_selected.connect(_on_asset_selected)
	page.add_child(_asset_list)

	var asset_actions := HBoxContainer.new()
	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(refresh_assets)
	asset_actions.add_child(refresh_button)
	var place_origin_button := Button.new()
	place_origin_button.text = "放置到原点"
	place_origin_button.pressed.connect(_on_place_origin_pressed)
	asset_actions.add_child(place_origin_button)
	page.add_child(asset_actions)

	var canvas_tool_row := HBoxContainer.new()
	var canvas_tool_label := Label.new()
	canvas_tool_label.text = "工具"
	canvas_tool_row.add_child(canvas_tool_label)
	_canvas_tool_selector = OptionButton.new()
	_canvas_tool_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_tool_selector.add_item("选择")
	_canvas_tool_selector.add_item("放置")
	_canvas_tool_selector.add_item("擦除")
	_canvas_tool_selector.select(CANVAS_TOOL_SELECT)
	_canvas_tool_selector.tooltip_text = "选择：空白处拖框多选，Shift 追加；点击素材后可用 Godot 手柄移动。Ctrl+C/V 复制/粘贴，Delete 删除。放置和擦除的拖动笔划可一次撤销。"
	_canvas_tool_selector.item_selected.connect(_on_canvas_tool_selected)
	canvas_tool_row.add_child(_canvas_tool_selector)
	_snap_to_grid_toggle = CheckButton.new()
	_snap_to_grid_toggle.text = "吸附"
	_snap_to_grid_toggle.button_pressed = true
	_snap_to_grid_toggle.tooltip_text = "放置素材时吸附到地图根节点设置的网格。"
	canvas_tool_row.add_child(_snap_to_grid_toggle)
	page.add_child(canvas_tool_row)


func _build_dialogue_page(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "对话"
	page.custom_minimum_size = Vector2(280.0, 0.0)
	tabs.add_child(page)

	var selected_hint := Label.new()
	selected_hint.text = "选中场景中的 NPC 后，编辑或创建对话文件。"
	selected_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(selected_hint)

	var edit_dialogue_button := Button.new()
	edit_dialogue_button.text = "编辑选中 NPC 对话"
	edit_dialogue_button.tooltip_text = "打开 NPC 关联的 CSV 对话文件"
	edit_dialogue_button.pressed.connect(_on_edit_selected_dialogue_pressed)
	page.add_child(edit_dialogue_button)


func _build_reference_page(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "引用"
	page.custom_minimum_size = Vector2(280.0, 0.0)
	tabs.add_child(page)

	var hint := Label.new()
	hint.text = "选中传送点后，可从地图和出生点列表选择目标。修改支持撤销。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(hint)
	_reference_node_label = Label.new()
	_reference_node_label.text = "尚未选择传送点。"
	_reference_node_label.clip_text = true
	page.add_child(_reference_node_label)

	var map_row := HBoxContainer.new()
	var map_label := Label.new()
	map_label.text = "目标地图"
	map_row.add_child(map_label)
	_reference_map_selector = OptionButton.new()
	_reference_map_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reference_map_selector.item_selected.connect(_on_reference_map_selected)
	map_row.add_child(_reference_map_selector)
	page.add_child(map_row)

	var spawn_row := HBoxContainer.new()
	var spawn_label := Label.new()
	spawn_label.text = "目标入口"
	spawn_row.add_child(spawn_label)
	_reference_spawn_selector = OptionButton.new()
	_reference_spawn_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_row.add_child(_reference_spawn_selector)
	page.add_child(spawn_row)

	_reference_apply_button = Button.new()
	_reference_apply_button.text = "应用传送目标"
	_reference_apply_button.disabled = true
	_reference_apply_button.pressed.connect(_on_apply_reference_pressed)
	page.add_child(_reference_apply_button)

	_reference_status_label = Label.new()
	_reference_status_label.text = "目标会写入选中传送点的场景属性。"
	_reference_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_reference_status_label)


func _build_validation_page(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "校验"
	page.custom_minimum_size = Vector2(280.0, 0.0)
	tabs.add_child(page)

	var map_row := HBoxContainer.new()
	var map_label := Label.new()
	map_label.text = "地图"
	map_row.add_child(map_label)
	_validation_map_selector = OptionButton.new()
	_validation_map_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_validation_map_selector.item_selected.connect(_on_validation_map_selected)
	map_row.add_child(_validation_map_selector)
	page.add_child(map_row)

	var actions_row := HBoxContainer.new()
	var check_selected_button := Button.new()
	check_selected_button.text = "检查选中"
	check_selected_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check_selected_button.pressed.connect(_on_check_selected_map_pressed)
	actions_row.add_child(check_selected_button)
	var check_all_button := Button.new()
	check_all_button.text = "检查全部"
	check_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check_all_button.pressed.connect(_on_check_all_maps_pressed)
	actions_row.add_child(check_all_button)
	page.add_child(actions_row)
	var preflight_button := Button.new()
	preflight_button.text = "地图试玩前检查"
	preflight_button.tooltip_text = "检查所有已保存地图、跨地图传送、触发器和障碍配置。任务流程请在任务编辑器中单独检查。"
	preflight_button.pressed.connect(_on_preflight_pressed)
	page.add_child(preflight_button)

	_validation_summary = Label.new()
	_validation_summary.text = "检查已保存的地图、出生点与传送目标。"
	_validation_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_validation_summary)

	_validation_issue_list = ItemList.new()
	_validation_issue_list.custom_minimum_size = Vector2(260.0, 190.0)
	_validation_issue_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_validation_issue_list.item_selected.connect(_on_validation_issue_selected)
	page.add_child(_validation_issue_list)

	_validation_issue_details = Label.new()
	_validation_issue_details.text = "运行检查后，问题会显示在这里。"
	_validation_issue_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_validation_issue_details.custom_minimum_size = Vector2(0.0, 64.0)
	page.add_child(_validation_issue_details)

	_locate_validation_issue_button = Button.new()
	_locate_validation_issue_button.text = "定位所选问题"
	_locate_validation_issue_button.disabled = true
	_locate_validation_issue_button.pressed.connect(_on_locate_validation_issue_pressed)
	page.add_child(_locate_validation_issue_button)


func _on_create_map_toggled(expanded: bool) -> void:
	if _create_map_panel != null:
		_create_map_panel.visible = expanded


func refresh_maps() -> void:
	if _map_selector == null:
		return
	var previous_path := _get_selected_map_path()
	var previous_validation_path := _get_selected_validation_map_path()
	_map_paths.clear()
	_map_selector.clear()
	_scan_maps("res://scenes/maps")
	_map_paths.sort()
	for map_path in _map_paths:
		_map_selector.add_item(map_path.get_file().get_basename())
	if _validation_map_selector != null:
		_validation_map_selector.clear()
		for map_path in _map_paths:
			_validation_map_selector.add_item(map_path.get_file().get_basename())

	var preferred_path := previous_path
	if preferred_path.is_empty():
		preferred_path = _get_current_scene_path()
	if preferred_path.is_empty() or not _map_paths.has(preferred_path):
		preferred_path = _map_paths[0] if not _map_paths.is_empty() else ""
	_select_map_path(preferred_path)
	if not previous_validation_path.is_empty() and _map_paths.has(previous_validation_path):
		_select_validation_map_path(previous_validation_path)
	else:
		_select_validation_map_path(preferred_path)
	_clear_validation_results("地图列表已刷新，请重新运行检查。")
	if _map_paths.is_empty() and _status_label != null:
		_status_label.text = "没有找到地图。请在 scenes/maps 中创建或保存 .tscn 场景。"
	_update_reference_panel()


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
			elif file_name.ends_with(".tscn"):
				_map_paths.append(child_path)
		file_name = directory.get_next()
	directory.list_dir_end()


func _get_selected_map_path() -> String:
	if _map_selector == null:
		return ""
	var selected_index := _map_selector.selected
	if selected_index < 0 or selected_index >= _map_paths.size():
		return ""
	return _map_paths[selected_index]


func _get_selected_validation_map_path() -> String:
	if _validation_map_selector == null:
		return ""
	var selected_index := _validation_map_selector.selected
	if selected_index < 0 or selected_index >= _map_paths.size():
		return ""
	return _map_paths[selected_index]


func _select_map_path(scene_path: String) -> void:
	if _map_selector == null or _map_paths.is_empty():
		return
	var selected_index := _map_paths.find(scene_path)
	if selected_index < 0:
		selected_index = 0
	_map_selector.select(selected_index)


func _select_validation_map_path(scene_path: String) -> void:
	if _validation_map_selector == null or _map_paths.is_empty():
		return
	var selected_index := _map_paths.find(scene_path)
	if selected_index < 0:
		selected_index = 0
	_validation_map_selector.select(selected_index)


func _get_current_scene_path() -> String:
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	if edited_root == null:
		return ""
	return edited_root.scene_file_path


func _on_editor_selection_changed() -> void:
	_update_reference_panel()


func _on_editor_undo_redo_version_changed() -> void:
	_update_reference_panel()


func _update_reference_panel() -> void:
	if _reference_node_label == null:
		return
	_reference_node = null
	_reference_apply_button.disabled = true
	_reference_map_selector.disabled = true
	_reference_spawn_selector.disabled = true
	_reference_map_selector.clear()
	_reference_spawn_selector.clear()
	_reference_target_paths.clear()
	_reference_spawn_ids.clear()

	var selected_nodes: Array = EditorInterface.get_selection().get_selected_nodes()
	if selected_nodes.size() != 1:
		_reference_node_label.text = "尚未选择传送点。"
		_reference_status_label.text = "在场景中选中一个传送点后，可从列表指定目标地图和出生点。"
		return
	var selected_node := selected_nodes[0] as Node
	if selected_node == null or not _has_property(selected_node, "target_scene_path") or not _has_property(selected_node, "target_spawn_point_id"):
		_reference_node_label.text = "当前选择不是传送点。"
		_reference_status_label.text = "请选择具有目标地图和目标出生点属性的传送点。"
		return

	_reference_node = selected_node
	var portal_id := str(selected_node.get("portal_id")) if _has_property(selected_node, "portal_id") else str(selected_node.name)
	_reference_node_label.text = "传送点：%s" % portal_id
	for scene_path in _map_paths:
		_reference_target_paths.append(scene_path)
	var current_target_path := str(selected_node.get("target_scene_path")).strip_edges()
	if not current_target_path.is_empty() and not _reference_target_paths.has(current_target_path):
		_reference_target_paths.append(current_target_path)
	for scene_path in _reference_target_paths:
		_reference_map_selector.add_item(_get_reference_map_label(scene_path))
		_reference_map_selector.set_item_tooltip(_reference_map_selector.get_item_count() - 1, scene_path)
	if _reference_target_paths.is_empty():
		_reference_status_label.text = "请先在 scenes/maps 中创建地图。"
		return
	_reference_map_selector.disabled = false
	if current_target_path.is_empty():
		_reference_status_label.text = "当前未设置目标地图；请从列表选择地图和出生点。"
		return
	var map_index := _reference_target_paths.find(current_target_path)
	if map_index < 0:
		map_index = 0
	_reference_map_selector.select(map_index)
	_populate_reference_spawn_points(str(selected_node.get("target_spawn_point_id")))


func _get_reference_map_label(scene_path: String) -> String:
	return scene_path.get_file().get_basename()


func _format_reference_node_parts(node_parts: Array) -> String:
	if node_parts.is_empty():
		return "地图根节点"
	var parts := PackedStringArray()
	for node_part in node_parts:
		parts.append(str(node_part))
	return "/".join(parts)


func _on_reference_map_selected(index: int) -> void:
	var current_spawn_id := ""
	if is_instance_valid(_reference_node) and _has_property(_reference_node, "target_spawn_point_id"):
		current_spawn_id = str(_reference_node.get("target_spawn_point_id"))
	_populate_reference_spawn_points(current_spawn_id)


func _populate_reference_spawn_points(preferred_spawn_id: String) -> void:
	_reference_spawn_selector.clear()
	_reference_spawn_ids.clear()
	_reference_spawn_selector.disabled = true
	_reference_apply_button.disabled = true
	var map_index := _reference_map_selector.selected
	if map_index < 0 or map_index >= _reference_target_paths.size():
		_reference_status_label.text = "请选择目标地图。"
		return
	var target_path := _reference_target_paths[map_index]
	var map_data: Dictionary = MapValidator.new().read_map_data(target_path)
	if map_data.has("error"):
		_reference_status_label.text = str(map_data.get("error", "无法读取目标地图。"))
		return
	var seen_ids: Dictionary = {}
	var preferred_index := -1
	for spawn_point in map_data.get("spawn_points", []):
		var spawn_id := str(spawn_point.get("id", "")).strip_edges()
		var duplicate_id := not spawn_id.is_empty() and seen_ids.has(spawn_id)
		var label := spawn_id if not spawn_id.is_empty() else "（出生点 ID 为空）"
		if duplicate_id:
			label += " · 重复 ID"
		elif not spawn_id.is_empty():
			seen_ids[spawn_id] = true
		_reference_spawn_ids.append(spawn_id)
		_reference_spawn_selector.add_item(label)
		var spawn_index := _reference_spawn_selector.get_item_count() - 1
		_reference_spawn_selector.set_item_tooltip(spawn_index, _format_reference_node_parts(spawn_point.get("node_parts", [])))
		if spawn_id.is_empty() or duplicate_id:
			_reference_spawn_selector.set_item_disabled(spawn_index, true)
		elif spawn_id == preferred_spawn_id:
			preferred_index = spawn_index
	if preferred_index < 0:
		for spawn_index in range(_reference_spawn_ids.size()):
			if not _reference_spawn_selector.is_item_disabled(spawn_index):
				preferred_index = spawn_index
				break
	if preferred_index >= 0:
		_reference_spawn_selector.select(preferred_index)
		_reference_spawn_selector.disabled = false
		_reference_apply_button.disabled = false
		if preferred_spawn_id.is_empty():
			_reference_status_label.text = "已选择目标地图；应用后会设置出生点。"
		elif not seen_ids.has(preferred_spawn_id):
			_reference_status_label.text = "当前目标入口不存在；请改选有效出生点。"
		else:
			_reference_status_label.text = "已读取 %d 个目标出生点。" % _reference_spawn_ids.size()
	else:
		_reference_status_label.text = "目标地图没有可用的出生点；请先添加并设置出生点 ID。"


func _on_apply_reference_pressed() -> void:
	if not is_instance_valid(_reference_node):
		_reference_status_label.text = "请重新选择传送点。"
		_update_reference_panel()
		return
	var map_index := _reference_map_selector.selected
	var spawn_index := _reference_spawn_selector.selected
	if map_index < 0 or map_index >= _reference_target_paths.size() or spawn_index < 0 or spawn_index >= _reference_spawn_ids.size():
		_reference_status_label.text = "请选择有效的目标地图和出生点。"
		return
	if _reference_spawn_selector.is_item_disabled(spawn_index):
		_reference_status_label.text = "所选出生点 ID 为空或重复，不能作为传送目标。"
		return
	if plugin == null:
		_reference_status_label.text = "编辑器撤销服务不可用。"
		return
	var target_path := _reference_target_paths[map_index]
	var target_spawn_id := _reference_spawn_ids[spawn_index]
	var previous_path := str(_reference_node.get("target_scene_path"))
	var previous_spawn_id := str(_reference_node.get("target_spawn_point_id"))
	if target_path == previous_path and target_spawn_id == previous_spawn_id:
		_reference_status_label.text = "传送目标没有变化。"
		return
	var undo_redo := plugin.get_undo_redo()
	if undo_redo == null:
		_reference_status_label.text = "编辑器撤销服务不可用。"
		return
	undo_redo.create_action("关卡搭建：设置传送目标")
	undo_redo.add_do_property(_reference_node, "target_scene_path", target_path)
	undo_redo.add_undo_property(_reference_node, "target_scene_path", previous_path)
	undo_redo.add_do_property(_reference_node, "target_spawn_point_id", target_spawn_id)
	undo_redo.add_undo_property(_reference_node, "target_spawn_point_id", previous_spawn_id)
	undo_redo.add_do_reference(_reference_node)
	undo_redo.commit_action()
	_reference_status_label.text = "目标已设置为 %s / %s，可撤销。" % [_get_reference_map_label(target_path), target_spawn_id]


func refresh_assets() -> void:
	if _asset_list == null:
		return
	_all_asset_paths.clear()
	_asset_category_by_path.clear()
	_scan_assets("res://scenes/entities", _all_asset_paths)
	_scan_assets("res://scenes/actors", _all_asset_paths)
	_all_asset_paths.sort()
	for asset_path in _all_asset_paths:
		_asset_category_by_path[asset_path] = _classify_asset(asset_path)
	_rebuild_asset_list()


func _rebuild_asset_list() -> void:
	if _asset_list == null:
		return
	var previous_path := _selected_asset_path
	_asset_paths.clear()
	_asset_list.clear()
	var category_filter := _get_selected_asset_category()
	var search_text := ""
	if _asset_search != null:
		search_text = _asset_search.text.strip_edges().to_lower()
	for asset_path in _all_asset_paths:
		var category: String = str(_asset_category_by_path.get(asset_path, "其他"))
		if category_filter != "全部" and category != category_filter:
			continue
		if not search_text.is_empty() and not asset_path.to_lower().contains(search_text):
			continue
		_asset_paths.append(asset_path)
		_asset_list.add_item("%s  ·  %s" % [asset_path.get_file().get_basename(), category])
		_asset_list.set_item_tooltip(_asset_list.get_item_count() - 1, asset_path)
	if not _asset_paths.has(previous_path):
		_selected_asset_path = ""
		if _canvas_tool_selector != null:
			_canvas_tool_selector.select(CANVAS_TOOL_SELECT)
	if _asset_paths.is_empty() and _status_label != null:
		_status_label.text = "没有找到素材。请在 scenes/entities 或 scenes/actors 中放入 .tscn。"


func _get_selected_asset_category() -> String:
	if _asset_category_filter == null or _asset_category_filter.selected < 0:
		return "全部"
	return _asset_category_filter.get_item_text(_asset_category_filter.selected)


func _classify_asset(asset_path: String) -> String:
	var normalized_path := asset_path.to_lower()
	var file_name := asset_path.get_file().get_basename().to_lower()
	if file_name.contains("npc_service") or file_name.contains("service_npc") or file_name.contains("merchant") or file_name.contains("ability_trainer") or file_name.contains("map_seller") or file_name.contains("quest_board"):
		return "NPC服务"
	if file_name.contains("map_marker"):
		return "探索标记"
	if file_name.contains("station"):
		return "地图设施"
	if file_name.contains("chest"):
		return "奖励"
	if file_name.contains("secret_passage"):
		return "障碍"
	if file_name.contains("ability_pickup") or file_name.contains("collectible_pickup"):
		return "能力与收集"
	if file_name.contains("patrol_route") or file_name.contains("enemy_spawn") or file_name.contains("encounter") or file_name.contains("boss_arena") or file_name.contains("lockdown_zone"):
		return "遭遇工具"
	if file_name.contains("grapple") or file_name.contains("bounce_pad") or file_name.contains("push_block") or file_name.contains("flow_zone") or file_name.contains("water_current") or file_name.contains("wind_tunnel"):
		return "环境谜题"
	if file_name.contains("npc") or normalized_path.contains("/npc/"):
		return "NPC"
	if file_name.contains("platform"):
		return "平台"
	if file_name.contains("gate") or file_name.contains("door") or file_name.contains("barrier") or file_name.contains("breakable_wall") or file_name.contains("secret_passage"):
		return "障碍"
	if file_name.contains("hazard"):
		return "危险"
	if file_name.contains("mechanism") or file_name.contains("switch"):
		return "机关"
	if file_name.contains("checkpoint"):
		return "检查点"
	if file_name.contains("spawn_point") or file_name.contains("spawnpoint"):
		return "出生点"
	if file_name.contains("enemy") or normalized_path.contains("/enemy/"):
		return "敌人"
	if file_name.contains("item") or normalized_path.contains("/item/"):
		return "物品"
	if file_name.contains("portal") or normalized_path.contains("/portal/"):
		return "传送点"
	if file_name.contains("trigger") or normalized_path.contains("/trigger/"):
		return "触发器"
	if normalized_path.contains("/actors/"):
		return "角色"
	if normalized_path.contains("/entities/"):
		return "实体"
	return "其他"


func _scan_assets(directory_path: String, target_paths: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not file_name.begins_with("."):
			var child_path := directory_path.path_join(file_name)
			if directory.current_is_dir():
				_scan_assets(child_path, target_paths)
			elif file_name.ends_with(".tscn"):
				target_paths.append(child_path)
		file_name = directory.get_next()
	directory.list_dir_end()


func _on_asset_category_selected(_index: int) -> void:
	_rebuild_asset_list()


func _on_asset_search_changed(_new_text: String) -> void:
	_rebuild_asset_list()


func _on_asset_selected(index: int) -> void:
	if index < 0 or index >= _asset_paths.size():
		return
	_selected_asset_path = _asset_paths[index]
	_canvas_tool_selector.select(CANVAS_TOOL_PLACE)
	_status_label.text = "已选择：%s。可在 2D 视图点击或拖动放置。" % _selected_asset_path


func _on_canvas_tool_selected(index: int) -> void:
	_finish_canvas_stroke()
	if _selection_drag_active:
		_selection_drag_active = false
		_request_canvas_redraw()
	if index == CANVAS_TOOL_PLACE and _selected_asset_path.is_empty():
		_canvas_tool_selector.select(CANVAS_TOOL_SELECT)
		_status_label.text = "请先选择一个素材。"
		return
	var tool_names := ["选择工具", "放置工具", "擦除工具"]
	_status_label.text = "已切换到%s。" % tool_names[index] if index >= 0 and index < tool_names.size() else "已切换画布工具。"


func _on_create_map_pressed() -> void:
	var map_id := _sanitize_id(_map_id_edit.text)
	if map_id.is_empty():
		_status_label.text = "地图 ID 不能为空。"
		return
	if not ProjectPaths.ensure_directory("res://scenes/maps"):
		_status_label.text = "无法创建地图目录 scenes/maps。"
		return
	var map_path := "res://scenes/maps/%s.tscn" % map_id
	if FileAccess.file_exists(map_path):
		_status_label.text = "地图已存在：%s" % map_path
		return

	var map_root := MapRoot.new()
	map_root.name = _pascal_case(map_id)
	map_root.map_id = map_id
	map_root.display_name = map_id
	for layer_name in ["BackgroundLayer", "TileLayer", "CollisionLayer", "DecorationLayer", "EntitiesLayer", "NPCsLayer", "ItemsLayer", "TriggersLayer", "PortalsLayer", "SpawnPoints"]:
		var layer: Node2D
		if layer_name == "TileLayer":
			var tile_layer := TileMapLayer.new()
			tile_layer.tile_set = load(PLACEHOLDER_TILESET_PATH) as TileSet
			layer = tile_layer
		else:
			layer = Node2D.new()
		layer.name = layer_name
		map_root.add_child(layer)
		layer.owner = map_root

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(map_root)
	map_root.free()
	if pack_error != OK:
		_status_label.text = "地图模板保存失败：%s" % pack_error
		return
	var save_error := ResourceSaver.save(packed_scene, map_path)
	if save_error != OK:
		_status_label.text = "地图模板保存失败：%s" % save_error
		return

	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(map_path)
	_status_label.text = "已创建地图：%s" % map_path


func _on_place_origin_pressed() -> void:
	var edited_root := EditorInterface.get_edited_scene_root() as Node2D
	if edited_root == null:
		_status_label.text = "请先打开一个地图场景。"
		return
	_place_selected_asset(edited_root.to_global(Vector2.ZERO))


func _on_map_selected(index: int) -> void:
	if index < 0 or index >= _map_paths.size():
		return
	if _validation_map_selector != null:
		_validation_map_selector.select(index)
	_status_label.text = "已选择地图：%s" % _map_paths[index]


func _on_validation_map_selected(index: int) -> void:
	if index < 0 or index >= _map_paths.size():
		return
	if _map_selector != null:
		_map_selector.select(index)
	_status_label.text = "已选择待检查地图：%s" % _map_paths[index]


func _on_check_selected_map_pressed() -> void:
	var scene_path := _get_selected_validation_map_path()
	if scene_path.is_empty():
		_clear_validation_results("请先刷新并选择地图。")
		return
	_run_map_validation(scene_path)


func _on_check_all_maps_pressed() -> void:
	_run_map_validation("")


func _run_map_validation(selected_path: String) -> void:
	var validator = MapValidator.new()
	_validation_issues = validator.validate_maps(_map_paths, selected_path)
	var scope_label := "全部地图" if selected_path.is_empty() else selected_path.get_file().get_basename()
	_present_validation_issues(scope_label)


func _on_preflight_pressed() -> void:
	_validation_issues = MapValidator.new().validate_maps(_map_paths)
	_present_validation_issues("地图试玩前检查")


func _present_validation_issues(scope_label: String) -> void:
	_validation_issue_list.clear()
	_locate_validation_issue_button.disabled = true
	_validation_issue_details.text = "选择一条问题可查看完整说明，并定位到对应节点。"

	var error_count := 0
	var warning_count := 0
	for issue in _validation_issues:
		if issue.get("severity", "warning") == "error":
			error_count += 1
		else:
			warning_count += 1

	if _validation_issues.is_empty():
		_validation_summary.text = "%s：未发现问题。" % scope_label
		_validation_issue_list.add_item("✓ 地图结构与引用检查通过。")
		_validation_issue_list.set_item_disabled(0, true)
		_validation_issue_details.text = "没有发现地图结构、传送目标或地图运行配置问题。"
	else:
		_validation_summary.text = "%s：%d 个问题（错误 %d，警告 %d）" % [scope_label, _validation_issues.size(), error_count, warning_count]
		for issue in _validation_issues:
			var severity := "错误" if issue.get("severity", "warning") == "error" else "警告"
			var scene_path: String = str(issue.get("scene_path", ""))
			var message: String = str(issue.get("message", ""))
			var row_text := "[%s] %s · %s" % [severity, scene_path.get_file().get_basename(), message]
			var item_index := _validation_issue_list.get_item_count()
			_validation_issue_list.add_item(row_text)
			var node_parts: Array = issue.get("node_parts", [])
			_validation_issue_list.set_item_tooltip(item_index, "%s\n%s\n节点：%s" % [severity, scene_path, _format_validation_node_path(node_parts)])
			_validation_issue_list.set_item_custom_fg_color(item_index, Color(0.98, 0.43, 0.38) if severity == "错误" else Color(0.95, 0.76, 0.34))
	_status_label.text = "%s完成：%d 个错误，%d 个警告。" % [scope_label, error_count, warning_count]


func _on_validation_issue_selected(index: int) -> void:
	if index < 0 or index >= _validation_issues.size():
		_locate_validation_issue_button.disabled = true
		return
	var issue: Dictionary = _validation_issues[index]
	var severity := "错误" if issue.get("severity", "warning") == "error" else "警告"
	var issue_location := str(issue.get("scene_path", ""))
	_validation_issue_details.text = "%s：%s\n场景：%s\n节点：%s" % [severity, issue.get("message", ""), issue_location, _format_validation_node_path(issue.get("node_parts", []))]
	_locate_validation_issue_button.disabled = issue_location.is_empty() or not FileAccess.file_exists(issue_location)


func _on_locate_validation_issue_pressed() -> void:
	var selected_items := _validation_issue_list.get_selected_items()
	if selected_items.is_empty():
		return
	var issue_index: int = selected_items[0]
	if issue_index < 0 or issue_index >= _validation_issues.size():
		return
	var issue: Dictionary = _validation_issues[issue_index]
	var scene_path: String = str(issue.get("scene_path", ""))
	if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
		_status_label.text = "无法定位：问题场景已不存在。请刷新后重新检查。"
		return
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	if edited_root == null or edited_root.scene_file_path != scene_path:
		EditorInterface.open_scene_from_path(scene_path)
	call_deferred("_focus_validation_issue_node", scene_path, issue.get("node_parts", []))
	_status_label.text = "正在打开问题位置：%s" % scene_path


func _focus_validation_issue_node(scene_path: String, node_parts: Array) -> void:
	for _attempt in range(12):
		await get_tree().process_frame
		var edited_root: Node = EditorInterface.get_edited_scene_root()
		if edited_root == null or edited_root.scene_file_path != scene_path:
			continue
		var target_node := _find_node_by_parts(edited_root, node_parts)
		if target_node == null:
			break
		var editor_selection = EditorInterface.get_selection()
		editor_selection.clear()
		editor_selection.add_node(target_node)
		EditorInterface.edit_node(target_node)
		_status_label.text = "已定位问题节点：%s" % _format_validation_node_path(node_parts)
		return
	_status_label.text = "已打开问题地图，但无法定位节点；场景可能已在检查后发生变化。"


func _find_node_by_parts(root: Node, node_parts: Array) -> Node:
	var current := root
	for part in node_parts:
		var found: Node
		for child in current.get_children():
			if str(child.name) == str(part):
				found = child
				break
		if found == null:
			return null
		current = found
	return current


func _format_validation_node_path(node_parts: Array) -> String:
	if node_parts.is_empty():
		return "地图根节点"
	var path_parts := PackedStringArray()
	for part in node_parts:
		path_parts.append(str(part))
	return "/".join(path_parts)


func _clear_validation_results(message: String) -> void:
	_validation_issues.clear()
	if _validation_summary != null:
		_validation_summary.text = message
	if _validation_issue_list != null:
		_validation_issue_list.clear()
	if _validation_issue_details != null:
		_validation_issue_details.text = "运行检查后，问题会显示在这里。"
	if _locate_validation_issue_button != null:
		_locate_validation_issue_button.disabled = true


func _on_open_selected_map_pressed() -> void:
	var scene_path := _get_selected_map_path()
	if scene_path.is_empty():
		_status_label.text = "请先选择一张地图。"
		return
	_open_scene_if_available(scene_path, "选中地图")


func _on_run_selected_map_pressed() -> void:
	var scene_path := _get_selected_map_path()
	if scene_path.is_empty():
		_status_label.text = "请先选择一张地图。"
		return
	_run_scene_if_available(scene_path, "选中地图")


func _on_run_current_scene_pressed() -> void:
	var scene_path := _get_current_scene_path()
	if scene_path.is_empty():
		_status_label.text = "当前场景尚未保存，无法运行。请先保存场景。"
		return
	EditorInterface.play_current_scene()
	_status_label.text = "正在运行当前场景：%s" % scene_path


func _on_edit_selected_dialogue_pressed() -> void:
	var selected_nodes: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	if selected_nodes.is_empty():
		_status_label.text = "请先在场景树或 2D 视图中选中一个 NPC。"
		return
	var selected_node: Node = selected_nodes[0]
	if _get_property_value(selected_node, "entity_type") != "npc":
		_status_label.text = "当前选中的节点不是 NPC。"
		return
	var dialogue_path := _get_property_value(selected_node, "dialogue_file")
	if dialogue_path.is_empty():
		dialogue_path = _create_dialogue_for_node(selected_node)
		if dialogue_path.is_empty():
			return
	_open_dialogue_file(dialogue_path, selected_node)


func _create_dialogue_for_node(node: Node) -> String:
	var dialogue_id := _sanitize_id(_get_property_value(node, "entity_id"))
	if dialogue_id.is_empty():
		dialogue_id = _sanitize_id(node.name)
	if dialogue_id.is_empty():
		dialogue_id = "dialogue_%s" % Time.get_ticks_msec()
	var dialogue_path := "res://data/dialogues/%s.csv" % dialogue_id
	if not ProjectPaths.ensure_directory("res://data/dialogues"):
		_status_label.text = "无法创建对话目录 data/dialogues。"
		return ""
	if not FileAccess.file_exists(dialogue_path):
		var file := FileAccess.open(dialogue_path, FileAccess.WRITE)
		if file == null:
			_status_label.text = "无法创建对话文件：%s" % dialogue_path
			return ""
		file.store_csv_line(PackedStringArray(["dialogue_id", "node_id", "start_node_id", "speaker", "text", "next_node_id", "portrait"]))
		file.store_csv_line(PackedStringArray([dialogue_id, "start", "start", _get_property_value(node, "display_name"), "请在这里填写第一句对话。", "", ""]))
		file.close()
	if _has_property(node, "dialogue_file"):
		var old_path := _get_property_value(node, "dialogue_file")
		var undo_redo := plugin.get_undo_redo()
		undo_redo.create_action("关卡搭建：关联 NPC 对话")
		undo_redo.add_do_property(node, "dialogue_file", dialogue_path)
		undo_redo.add_undo_property(node, "dialogue_file", old_path)
		undo_redo.commit_action()
	return dialogue_path


func _open_dialogue_file(dialogue_path: String, node: Node) -> void:
	if not FileAccess.file_exists(dialogue_path):
		_status_label.text = "对话文件不存在：%s" % dialogue_path
		return
	EditorInterface.get_resource_filesystem().scan()
	OS.shell_open(ProjectSettings.globalize_path(dialogue_path))
	var definition := DialogueDefinition.from_csv(dialogue_path)
	_status_label.text = "已打开 %s 的对话，共 %d 条文本。请保存场景以保留文件引用。" % [node.name, definition.nodes.size()]


func _open_scene_if_available(scene_path: String, label: String) -> void:
	if not FileAccess.file_exists(scene_path):
		_status_label.text = "%s不存在：%s" % [label, scene_path]
		return
	EditorInterface.open_scene_from_path(scene_path)
	_status_label.text = "已打开%s：%s" % [label, scene_path]


func _run_scene_if_available(scene_path: String, label: String) -> void:
	if not FileAccess.file_exists(scene_path):
		_status_label.text = "%s不存在：%s" % [label, scene_path]
		return
	EditorInterface.play_custom_scene(scene_path)
	_status_label.text = "正在运行%s。停止运行后可继续编辑。" % label


func handle_canvas_input(event: InputEvent) -> bool:
	if event is InputEventKey and _handle_canvas_shortcut(event):
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var world_position := _canvas_position_to_world(event.position)
		_last_canvas_world_position = world_position
		_has_last_canvas_world_position = true
		if event.pressed:
			match _get_canvas_tool():
				CANVAS_TOOL_PLACE:
					if _selected_asset_path.is_empty():
						_status_label.text = "请先选择一个素材。"
						return false
					if not _begin_canvas_stroke(CANVAS_TOOL_PLACE):
						return false
					_process_placement_segment(world_position, world_position)
					return true
				CANVAS_TOOL_SELECT:
					var edited_root := EditorInterface.get_edited_scene_root() as Node2D
					if edited_root != null:
						var native_pick_radius := maxf(12.0, maxf(_get_map_grid_size(edited_root).x, _get_map_grid_size(edited_root).y) * 0.5)
						if _find_closest_selectable_node(edited_root, world_position, native_pick_radius) != null:
							return false
					_selection_drag_active = true
					_selection_drag_start_screen = event.position
					_selection_drag_current_screen = event.position
					_selection_drag_start_world = world_position
					_selection_drag_additive = event.shift_pressed
					_request_canvas_redraw()
					return true
				CANVAS_TOOL_ERASE:
					if not _begin_canvas_stroke(CANVAS_TOOL_ERASE):
						return false
					_erase_at_world_position(world_position)
					return true
		else:
			if _canvas_stroke_active:
				_finish_canvas_stroke()
				return true
			if _selection_drag_active:
				_selection_drag_current_screen = event.position
				_selection_drag_active = false
				_finish_selection_drag(world_position)
				_request_canvas_redraw()
				return true
	if event is InputEventMouseMotion:
		var world_position := _canvas_position_to_world(event.position)
		_last_canvas_world_position = world_position
		_has_last_canvas_world_position = true
		if _selection_drag_active:
			_selection_drag_current_screen = event.position
			_request_canvas_redraw()
			return true
		if _canvas_stroke_active and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if _canvas_stroke_tool == CANVAS_TOOL_PLACE:
				_process_placement_segment(_canvas_stroke_root.to_global(_canvas_stroke_last_local_position), world_position)
				return true
			if _canvas_stroke_tool == CANVAS_TOOL_ERASE:
				_erase_at_world_position(world_position)
				return true
	return false


func draw_canvas_overlay(overlay: Control) -> void:
	if not _selection_drag_active:
		return
	var selection_rect := Rect2(_selection_drag_start_screen, _selection_drag_current_screen - _selection_drag_start_screen).abs()
	overlay.draw_rect(selection_rect, Color(0.25, 0.75, 1.0, 0.12), true)
	overlay.draw_rect(selection_rect, Color(0.35, 0.82, 1.0, 0.9), false, 1.5)


func _get_canvas_tool() -> int:
	if _canvas_tool_selector == null or _canvas_tool_selector.selected < 0:
		return CANVAS_TOOL_SELECT
	return _canvas_tool_selector.selected


func _canvas_position_to_world(screen_position: Vector2) -> Vector2:
	var editor_viewport := EditorInterface.get_editor_viewport_2d()
	if editor_viewport == null:
		return screen_position
	return editor_viewport.global_canvas_transform.affine_inverse() * screen_position


func _request_canvas_redraw() -> void:
	if plugin != null:
		plugin.update_overlays()


func _begin_canvas_stroke(tool: int) -> bool:
	var edited_root := EditorInterface.get_edited_scene_root() as Node2D
	if edited_root == null:
		_status_label.text = "请先打开一张地图场景。"
		return false
	if plugin == null or plugin.get_undo_redo() == null:
		_status_label.text = "编辑器撤销服务不可用。"
		return false
	_canvas_stroke_active = true
	_canvas_stroke_tool = tool
	_canvas_stroke_root = edited_root
	_canvas_stroke_undo_redo = plugin.get_undo_redo()
	_canvas_stroke_operation_count = 0
	_canvas_stroke_cells.clear()
	_canvas_stroke_nodes.clear()
	_canvas_stroke_reserved_names.clear()
	_canvas_stroke_last_local_position = Vector2.ZERO
	return true


func _finish_canvas_stroke() -> void:
	if not _canvas_stroke_active:
		return
	var completed_tool := _canvas_stroke_tool
	var operation_count := _canvas_stroke_operation_count
	if operation_count > 0 and _canvas_stroke_undo_redo != null:
		_canvas_stroke_undo_redo.commit_action()
	_canvas_stroke_active = false
	_canvas_stroke_tool = -1
	_canvas_stroke_root = null
	_canvas_stroke_undo_redo = null
	_canvas_stroke_operation_count = 0
	_canvas_stroke_cells.clear()
	_canvas_stroke_nodes.clear()
	_canvas_stroke_reserved_names.clear()
	if operation_count > 0:
		var action_name := "放置" if completed_tool == CANVAS_TOOL_PLACE else "擦除"
		_status_label.text = "%s笔划完成：%d 个对象，可一次撤销。" % [action_name, operation_count]


func _process_placement_segment(world_from: Vector2, world_to: Vector2) -> void:
	if not _canvas_stroke_active or _canvas_stroke_root == null:
		return
	var root := _canvas_stroke_root
	var map_from := root.to_local(world_from)
	var map_to := root.to_local(world_to)
	var grid := _get_map_grid_size(root)
	var snapping := _snap_to_grid_toggle != null and _snap_to_grid_toggle.button_pressed
	var spacing := grid if snapping else Vector2(UNSNAPPED_BRUSH_SPACING, UNSNAPPED_BRUSH_SPACING)
	var start_cell := _placement_cell(map_from, grid, spacing)
	var end_cell := _placement_cell(map_to, grid, spacing)
	var cell_delta := end_cell - start_cell
	var step_count := maxi(absi(cell_delta.x), absi(cell_delta.y))
	for step_index in range(step_count + 1):
		var ratio := 1.0 if step_count == 0 else float(step_index) / float(step_count)
		var sample_position := map_from.lerp(map_to, ratio)
		var cell := _placement_cell(sample_position, grid, spacing)
		if snapping:
			sample_position = Vector2(float(cell.x) * grid.x, float(cell.y) * grid.y)
		_place_instance_at_map_position(sample_position, cell)
	_canvas_stroke_last_local_position = map_to


func _placement_cell(map_position: Vector2, grid: Vector2, spacing: Vector2) -> Vector2i:
	var snapping := _snap_to_grid_toggle != null and _snap_to_grid_toggle.button_pressed
	var step := grid if snapping else spacing
	if snapping:
		return Vector2i(roundi(map_position.x / step.x), roundi(map_position.y / step.y))
	return Vector2i(floori(map_position.x / step.x), floori(map_position.y / step.y))


func _place_instance_at_map_position(map_position: Vector2, cell: Vector2i) -> void:
	if _canvas_stroke_cells.has(cell):
		return
	var instance_data := _create_asset_instance(_canvas_stroke_root, map_position, _canvas_stroke_reserved_names)
	if instance_data.is_empty():
		return
	_canvas_stroke_cells[cell] = true
	_queue_stroke_add(instance_data["parent"], instance_data["instance"], _canvas_stroke_root)


func _create_asset_instance(edited_root: Node2D, map_position: Vector2, reserved_names: Dictionary = {}) -> Dictionary:
	var packed_scene := load(_selected_asset_path) as PackedScene
	if packed_scene == null:
		_status_label.text = "无法加载素材：%s" % _selected_asset_path
		return {}
	var instance := packed_scene.instantiate()
	if not instance is Node2D:
		instance.free()
		_status_label.text = "素材根节点必须是 Node2D。"
		return {}
	var parent := _choose_parent_layer(edited_root, instance)
	if parent == null:
		instance.free()
		_status_label.text = "当前场景缺少可用的地图图层。"
		return {}
	instance.name = _make_unique_name(parent, instance.name, reserved_names)
	var world_position := edited_root.to_global(map_position)
	instance.position = parent.to_local(world_position) if parent is Node2D else world_position
	_prepare_instance_ids(instance, edited_root, false)
	return {"parent": parent, "instance": instance}


func _queue_stroke_add(parent: Node, instance: Node, edited_root: Node) -> void:
	if _canvas_stroke_operation_count == 0:
		_canvas_stroke_undo_redo.create_action("关卡搭建：放置素材笔划")
	_canvas_stroke_undo_redo.add_do_method(self, "_do_add_instance", parent, instance, edited_root)
	_canvas_stroke_undo_redo.add_undo_method(self, "_undo_remove_instance", parent, instance)
	_canvas_stroke_undo_redo.add_do_reference(instance)
	_canvas_stroke_operation_count += 1


func _place_selected_asset(world_position: Vector2) -> void:
	var edited_root := EditorInterface.get_edited_scene_root() as Node2D
	if edited_root == null:
		_status_label.text = "请先打开一个地图场景。"
		return
	if _selected_asset_path.is_empty():
		_status_label.text = "请先选择一个素材。"
		return
	var map_position: Vector2 = edited_root.to_local(world_position)
	map_position = _snap_map_position(edited_root, map_position)
	var instance_data := _create_asset_instance(edited_root, map_position)
	if instance_data.is_empty():
		return
	var parent: Node = instance_data["parent"]
	var instance: Node = instance_data["instance"]
	var undo_redo := plugin.get_undo_redo()
	undo_redo.create_action("关卡搭建：放置 %s" % instance.name)
	undo_redo.add_do_method(self, "_do_add_instance", parent, instance, edited_root)
	undo_redo.add_undo_method(self, "_undo_remove_instance", parent, instance)
	undo_redo.add_do_reference(instance)
	undo_redo.commit_action()
	_status_label.text = "已放置：%s" % instance.name


func _get_map_grid_size(map_root: Node2D) -> Vector2:
	if _has_property(map_root, "grid_size"):
		var grid: Variant = map_root.get("grid_size")
		if grid is Vector2 and grid.x > 0.0 and grid.y > 0.0:
			return grid
	return Vector2(32.0, 32.0)


func _snap_map_position(map_root: Node2D, map_position: Vector2) -> Vector2:
	if _snap_to_grid_toggle == null or not _snap_to_grid_toggle.button_pressed:
		return map_position
	var grid := _get_map_grid_size(map_root)
	return Vector2(round(map_position.x / grid.x) * grid.x, round(map_position.y / grid.y) * grid.y)


func _handle_canvas_shortcut(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	var command_pressed := event.ctrl_pressed or event.meta_pressed
	if command_pressed:
		match event.keycode:
			KEY_C:
				return _copy_selected_canvas_nodes()
			KEY_V:
				return _paste_canvas_nodes()
			KEY_A:
				return _select_all_canvas_nodes()
	if event.keycode == KEY_DELETE:
		_finish_canvas_stroke()
		return _delete_selected_canvas_nodes()
	return false


func _finish_selection_drag(world_position: Vector2) -> void:
	var edited_root := EditorInterface.get_edited_scene_root() as Node2D
	if edited_root == null:
		return
	var editor_selection = EditorInterface.get_selection()
	var selected_nodes: Array[Node2D] = []
	if _selection_drag_start_screen.distance_to(_selection_drag_current_screen) >= 5.0:
		var selection_rect := Rect2(_selection_drag_start_world, world_position - _selection_drag_start_world).abs()
		var candidates: Array[Node2D] = []
		_collect_selectable_canvas_nodes(edited_root, edited_root, candidates)
		for candidate in candidates:
			if selection_rect.has_point(candidate.global_position):
				selected_nodes.append(candidate)
	else:
		var nearest := _find_closest_selectable_node(edited_root, world_position, _canvas_pick_radius(edited_root))
		if nearest != null:
			selected_nodes.append(nearest)
	if not _selection_drag_additive:
		editor_selection.clear()
	for selected_node in selected_nodes:
		editor_selection.add_node(selected_node)
	_status_label.text = "已选择 %d 个对象。" % selected_nodes.size()


func _select_all_canvas_nodes() -> bool:
	var edited_root := EditorInterface.get_edited_scene_root() as Node2D
	if edited_root == null:
		return false
	var selected_nodes: Array[Node2D] = []
	_collect_selectable_canvas_nodes(edited_root, edited_root, selected_nodes)
	var editor_selection = EditorInterface.get_selection()
	editor_selection.clear()
	for selected_node in selected_nodes:
		editor_selection.add_node(selected_node)
	_status_label.text = "已选择全部 %d 个对象。" % selected_nodes.size()
	return not selected_nodes.is_empty()


func _collect_selectable_canvas_nodes(node: Node, edited_root: Node2D, result: Array[Node2D]) -> void:
	for child in node.get_children():
		if child is Node2D and _is_selectable_canvas_node(child, edited_root):
			result.append(child)
		_collect_selectable_canvas_nodes(child, edited_root, result)


func _is_selectable_canvas_node(node: Node2D, edited_root: Node2D) -> bool:
	if node == edited_root or node.owner != edited_root or node is TileMapLayer:
		return false
	if str(node.name) in MAP_LAYER_NAMES or node.is_in_group("level_authoring_generated"):
		return false
	if not node.scene_file_path.is_empty():
		return true
	for property_name in CANVAS_ID_PROPERTIES:
		if _has_property(node, property_name):
			return true
	return _has_property(node, "entity_type")


func _find_closest_selectable_node(edited_root: Node2D, world_position: Vector2, radius: float, excluded_ids: Dictionary = {}) -> Node2D:
	var candidates: Array[Node2D] = []
	_collect_selectable_canvas_nodes(edited_root, edited_root, candidates)
	var nearest: Node2D
	var nearest_distance := radius
	for candidate in candidates:
		if excluded_ids.has(candidate.get_instance_id()):
			continue
		var distance := candidate.global_position.distance_to(world_position)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _canvas_pick_radius(edited_root: Node2D) -> float:
	var grid := _get_map_grid_size(edited_root)
	return maxf(24.0, maxf(grid.x, grid.y) * 1.5)


func _erase_at_world_position(world_position: Vector2) -> void:
	if not _canvas_stroke_active or _canvas_stroke_root == null:
		return
	var nearest := _find_closest_selectable_node(_canvas_stroke_root, world_position, _canvas_pick_radius(_canvas_stroke_root), _canvas_stroke_nodes)
	if nearest == null:
		return
	var parent := nearest.get_parent()
	if parent == null:
		return
	if _canvas_stroke_operation_count == 0:
		_canvas_stroke_undo_redo.create_action("关卡搭建：擦除对象笔划")
	_canvas_stroke_undo_redo.add_do_method(self, "_do_remove_instance", parent, nearest)
	_canvas_stroke_undo_redo.add_undo_method(self, "_do_add_instance", parent, nearest, _canvas_stroke_root)
	_canvas_stroke_undo_redo.add_do_reference(nearest)
	_canvas_stroke_nodes[nearest.get_instance_id()] = true
	_canvas_stroke_operation_count += 1


func _delete_selected_canvas_nodes() -> bool:
	var edited_root := EditorInterface.get_edited_scene_root() as Node2D
	if edited_root == null:
		return false
	var nodes_to_delete: Array[Node2D] = []
	for selected_node in EditorInterface.get_selection().get_selected_nodes():
		if selected_node is Node2D and selected_node.get_parent() != null and _is_selectable_canvas_node(selected_node, edited_root):
			nodes_to_delete.append(selected_node)
	if nodes_to_delete.is_empty():
		return false
	var undo_redo := plugin.get_undo_redo()
	undo_redo.create_action("关卡搭建：删除对象")
	for node in nodes_to_delete:
		var parent := node.get_parent()
		undo_redo.add_do_method(self, "_do_remove_instance", parent, node)
		undo_redo.add_undo_method(self, "_do_add_instance", parent, node, edited_root)
		undo_redo.add_do_reference(node)
	undo_redo.commit_action()
	EditorInterface.get_selection().clear()
	_status_label.text = "已删除 %d 个对象，可撤销。" % nodes_to_delete.size()
	return true


func _copy_selected_canvas_nodes() -> bool:
	var edited_root := EditorInterface.get_edited_scene_root() as Node2D
	if edited_root == null:
		return false
	var nodes_to_copy: Array[Node2D] = []
	for selected_node in EditorInterface.get_selection().get_selected_nodes():
		if selected_node is Node2D and _is_selectable_canvas_node(selected_node, edited_root):
			nodes_to_copy.append(selected_node)
	if nodes_to_copy.is_empty():
		return false
	_clear_canvas_clipboard()
	var anchor := edited_root.to_local(nodes_to_copy[0].global_position)
	for node in nodes_to_copy:
		var template := node.duplicate()
		if template == null:
			continue
		_clipboard.append({
			"template": template,
			"offset": edited_root.to_local(node.global_position) - anchor,
		})
	_clipboard_paste_offset = Vector2.ZERO
	_status_label.text = "已复制 %d 个对象。Ctrl+V 可粘贴并自动生成新 ID。" % _clipboard.size()
	return not _clipboard.is_empty()


func _paste_canvas_nodes() -> bool:
	if _clipboard.is_empty():
		return false
	var edited_root := EditorInterface.get_edited_scene_root() as Node2D
	if edited_root == null:
		return false
	var anchor_world := _last_canvas_world_position if _has_last_canvas_world_position else edited_root.to_global(Vector2.ZERO)
	var anchor := _snap_map_position(edited_root, edited_root.to_local(anchor_world)) + _clipboard_paste_offset
	var undo_redo := plugin.get_undo_redo()
	var added_nodes: Array[Node2D] = []
	var reserved_names: Dictionary = {}
	for clipboard_item in _clipboard:
		var template: Node = clipboard_item.get("template")
		if not is_instance_valid(template):
			continue
		var instance := template.duplicate()
		if not instance is Node2D:
			instance.free()
			continue
		var parent := _choose_parent_layer(edited_root, instance)
		if parent == null:
			instance.free()
			continue
		instance.name = _make_unique_name(parent, instance.name, reserved_names)
		_prepare_instance_ids(instance, edited_root, true)
		var target_world_position := edited_root.to_global(anchor + clipboard_item.get("offset", Vector2.ZERO))
		instance.position = parent.to_local(target_world_position) if parent is Node2D else target_world_position
		if added_nodes.is_empty():
			undo_redo.create_action("关卡搭建：粘贴对象")
		undo_redo.add_do_method(self, "_do_add_instance", parent, instance, edited_root)
		undo_redo.add_undo_method(self, "_undo_remove_instance", parent, instance)
		undo_redo.add_do_reference(instance)
		added_nodes.append(instance)
	if added_nodes.is_empty():
		_status_label.text = "剪贴板对象无法放置到当前地图图层。"
		return false
	undo_redo.commit_action()
	_clipboard_paste_offset += _get_map_grid_size(edited_root) if _snap_to_grid_toggle.button_pressed else Vector2(UNSNAPPED_BRUSH_SPACING, UNSNAPPED_BRUSH_SPACING)
	var editor_selection = EditorInterface.get_selection()
	editor_selection.clear()
	for node in added_nodes:
		editor_selection.add_node(node)
	_status_label.text = "已粘贴 %d 个对象，可撤销。" % added_nodes.size()
	return true


func _clear_canvas_clipboard() -> void:
	for clipboard_item in _clipboard:
		var template: Node = clipboard_item.get("template")
		if is_instance_valid(template) and template.get_parent() == null:
			template.free()
	_clipboard.clear()


func _prepare_instance_ids(node: Node, edited_root: Node2D, regenerate_all: bool) -> void:
	for property_name in CANVAS_ID_PROPERTIES:
		if not _has_property(node, property_name):
			continue
		var current_id := str(node.get(property_name)).strip_edges()
		if regenerate_all or current_id.is_empty() or GENERIC_ID_VALUES.has(current_id):
			node.set(property_name, _generate_unique_canvas_id(node, property_name, edited_root))
	for child in node.get_children():
		_prepare_instance_ids(child, edited_root, regenerate_all)


func _generate_unique_canvas_id(node: Node, property_name: String, edited_root: Node2D) -> String:
	var base_name := _sanitize_id(str(node.name))
	if base_name.is_empty():
		base_name = _sanitize_id(property_name)
	var candidate := ""
	while candidate.is_empty() or _scene_contains_canvas_id(edited_root, property_name, candidate):
		_generated_id_counter += 1
		candidate = "%s_%d_%d" % [base_name, Time.get_ticks_usec(), _generated_id_counter]
	return candidate


func _scene_contains_canvas_id(node: Node, property_name: String, identifier: String) -> bool:
	if _has_property(node, property_name) and str(node.get(property_name)) == identifier:
		return true
	for child in node.get_children():
		if _scene_contains_canvas_id(child, property_name, identifier):
			return true
	return false


func _choose_parent_layer(edited_root: Node, instance: Node) -> Node:
	var type_value := _get_property_value(instance, "entity_type")
	if type_value == "spawn_point":
		return edited_root.get_node_or_null("SpawnPoints")
	if type_value == "enemy_spawn" or type_value == "enemy_route":
		return edited_root.get_node_or_null("EntitiesLayer")
	if type_value == "platform":
		return edited_root.get_node_or_null("CollisionLayer")
	if type_value == "pushable":
		return edited_root.get_node_or_null("CollisionLayer")
	if type_value == "barrier":
		return edited_root.get_node_or_null("CollisionLayer")
	if type_value == "hazard" or type_value == "mechanism" or type_value == "checkpoint" or type_value == "encounter" or type_value == "map_marker" or type_value == "traversal" or type_value == "flow_zone" or type_value == "station":
		return edited_root.get_node_or_null("TriggersLayer")
	if type_value == "npc":
		return edited_root.get_node_or_null("NPCsLayer")
	if type_value == "item" or type_value == "chest":
		return edited_root.get_node_or_null("ItemsLayer")
	if type_value == "portal":
		return edited_root.get_node_or_null("PortalsLayer")
	if type_value == "trigger":
		return edited_root.get_node_or_null("TriggersLayer")
	return edited_root.get_node_or_null("EntitiesLayer")


func _do_add_instance(parent: Node, instance: Node, edited_root: Node) -> void:
	if not is_instance_valid(instance):
		return
	if instance.get_parent() == null:
		parent.add_child(instance)
	instance.owner = edited_root


func _undo_remove_instance(parent: Node, instance: Node) -> void:
	if is_instance_valid(instance) and instance.get_parent() == parent:
		parent.remove_child(instance)


func _do_remove_instance(parent: Node, instance: Node) -> void:
	if is_instance_valid(instance) and instance.get_parent() == parent:
		parent.remove_child(instance)


func _has_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if property_info.name == property_name:
			return true
	return false


func _get_property_value(object: Object, property_name: String) -> String:
	if not _has_property(object, property_name):
		return ""
	return str(object.get(property_name))


func _make_unique_name(parent: Node, base_name: String, reserved_names: Dictionary = {}) -> String:
	var safe_base := _sanitize_id(base_name)
	if safe_base.is_empty():
		safe_base = "Entity"
	var candidate := safe_base
	var suffix := 2
	while parent.get_node_or_null(candidate) != null or reserved_names.has(candidate):
		candidate = "%s_%d" % [safe_base, suffix]
		suffix += 1
	reserved_names[candidate] = true
	return candidate


func _sanitize_id(value: String) -> String:
	var result := value.strip_edges().to_lower()
	result = result.replace(" ", "_").replace("-", "_")
	var sanitized := ""
	for character in result:
		if character.is_valid_identifier() or character == "_":
			sanitized += character
	return sanitized


func _pascal_case(value: String) -> String:
	var result := ""
	for part in value.split("_", false):
		if not part.is_empty():
			result += part.left(1).to_upper() + part.substr(1)
	return result if not result.is_empty() else "Map"
