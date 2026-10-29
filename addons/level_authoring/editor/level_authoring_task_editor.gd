@tool
extends VBoxContainer

const QuestDefinition := preload("res://addons/level_authoring/runtime/level_authoring_quest_definition.gd")
const ProjectPaths := preload("res://addons/level_authoring/runtime/level_authoring_project_paths.gd")
const TaskValidator := preload("res://addons/level_authoring/editor/level_authoring_task_validator.gd")
const NODE_TYPE_LABELS := ["开始", "对话", "目标", "条件", "动作", "完成"]
const NODE_TYPE_IDS := ["start", "dialogue", "objective", "condition", "action", "complete"]
const CONDITION_OPERATOR_LABELS := ["条件为真", "条件为假", "等于", "不等于"]
const CONDITION_OPERATOR_IDS := ["is_true", "is_false", "equals", "not_equals"]
const ACTION_TYPE_LABELS := ["设置状态", "清除状态", "发出事件", "完成任务"]
const ACTION_TYPE_IDS := ["set_condition", "clear_condition", "emit_event", "complete_quest"]

var _task_selector: OptionButton
var _quest_id_edit: LineEdit
var _quest_title_edit: LineEdit
var _node_type_selector: OptionButton
var _graph: GraphEdit
var _step_id_edit: LineEdit
var _step_title_edit: LineEdit
var _step_type_selector: OptionButton
var _step_description_edit: TextEdit
var _condition_fields: VBoxContainer
var _step_condition_id_edit: LineEdit
var _step_condition_operator_selector: OptionButton
var _step_condition_value_edit: LineEdit
var _action_fields: VBoxContainer
var _step_action_type_selector: OptionButton
var _step_action_target_edit: LineEdit
var _step_action_value_edit: LineEdit
var _dialogue_fields: VBoxContainer
var _step_dialogue_id_edit: LineEdit
var _step_dialogue_node_edit: LineEdit
var _status_label: Label
var _validation_dialog: AcceptDialog
var _current_quest: LevelAuthoringQuestDefinition
var _current_path := ""
var _quest_paths: Array[String] = []
var _selected_step_id := ""
var _graph_name_by_step_id: Dictionary = {}
var _step_id_by_graph_name: Dictionary = {}


func _ready() -> void:
	name = "任务编辑器"
	custom_minimum_size = Vector2(860.0, 560.0)
	_build_ui()
	refresh_tasks()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "任务编辑器"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var task_row := HBoxContainer.new()
	var task_label := Label.new()
	task_label.text = "任务"
	task_row.add_child(task_label)
	_task_selector = OptionButton.new()
	_task_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_selector.item_selected.connect(_on_task_selected)
	task_row.add_child(_task_selector)
	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(refresh_tasks)
	task_row.add_child(refresh_button)
	var new_button := Button.new()
	new_button.text = "新建任务"
	new_button.pressed.connect(_on_new_task_pressed)
	task_row.add_child(new_button)
	var save_button := Button.new()
	save_button.text = "保存任务"
	save_button.pressed.connect(_on_save_task_pressed)
	task_row.add_child(save_button)
	var validate_button := Button.new()
	validate_button.text = "检查流程"
	validate_button.pressed.connect(_on_validate_quest_pressed)
	task_row.add_child(validate_button)
	add_child(task_row)

	var metadata_row := HBoxContainer.new()
	var id_label := Label.new()
	id_label.text = "ID"
	metadata_row.add_child(id_label)
	_quest_id_edit = LineEdit.new()
	_quest_id_edit.placeholder_text = "quest_id"
	_quest_id_edit.custom_minimum_size = Vector2(180.0, 0.0)
	metadata_row.add_child(_quest_id_edit)
	var title_label := Label.new()
	title_label.text = "名称"
	metadata_row.add_child(title_label)
	_quest_title_edit = LineEdit.new()
	_quest_title_edit.placeholder_text = "任务名称"
	_quest_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metadata_row.add_child(_quest_title_edit)
	add_child(metadata_row)

	var node_toolbar := HBoxContainer.new()
	var node_label := Label.new()
	node_label.text = "添加节点"
	node_toolbar.add_child(node_label)
	_node_type_selector = OptionButton.new()
	for type_label in NODE_TYPE_LABELS:
		_node_type_selector.add_item(type_label)
	node_toolbar.add_child(_node_type_selector)
	var add_node_button := Button.new()
	add_node_button.text = "添加"
	add_node_button.pressed.connect(_on_add_node_pressed)
	node_toolbar.add_child(add_node_button)
	var delete_node_button := Button.new()
	delete_node_button.text = "删除选中节点"
	delete_node_button.pressed.connect(_on_delete_selected_node_pressed)
	node_toolbar.add_child(delete_node_button)
	add_child(node_toolbar)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.right_disconnects = true
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.delete_nodes_request.connect(_on_delete_nodes_request)
	_graph.node_selected.connect(_on_graph_node_selected)
	split.add_child(_graph)

	var inspector := VBoxContainer.new()
	inspector.custom_minimum_size = Vector2(260.0, 0.0)
	var inspector_title := Label.new()
	inspector_title.text = "节点属性"
	inspector_title.add_theme_font_size_override("font_size", 15)
	inspector.add_child(inspector_title)
	var step_id_label := Label.new()
	step_id_label.text = "节点 ID"
	inspector.add_child(step_id_label)
	_step_id_edit = LineEdit.new()
	_step_id_edit.editable = false
	inspector.add_child(_step_id_edit)
	var step_title_label := Label.new()
	step_title_label.text = "节点名称"
	inspector.add_child(step_title_label)
	_step_title_edit = LineEdit.new()
	inspector.add_child(_step_title_edit)
	var step_type_label := Label.new()
	step_type_label.text = "节点类型"
	inspector.add_child(step_type_label)
	_step_type_selector = OptionButton.new()
	for type_label in NODE_TYPE_LABELS:
		_step_type_selector.add_item(type_label)
	_step_type_selector.item_selected.connect(_on_step_type_selected)
	inspector.add_child(_step_type_selector)

	_condition_fields = VBoxContainer.new()
	var condition_title := Label.new()
	condition_title.text = "条件设置"
	_condition_fields.add_child(condition_title)
	var condition_id_label := Label.new()
	condition_id_label.text = "状态 ID"
	_condition_fields.add_child(condition_id_label)
	_step_condition_id_edit = LineEdit.new()
	_step_condition_id_edit.placeholder_text = "例如 has_archive_key"
	_condition_fields.add_child(_step_condition_id_edit)
	var operator_label := Label.new()
	operator_label.text = "判断方式"
	_condition_fields.add_child(operator_label)
	_step_condition_operator_selector = OptionButton.new()
	for operator_label_text in CONDITION_OPERATOR_LABELS:
		_step_condition_operator_selector.add_item(operator_label_text)
	_condition_fields.add_child(_step_condition_operator_selector)
	var condition_value_label := Label.new()
	condition_value_label.text = "比较值"
	_condition_fields.add_child(condition_value_label)
	_step_condition_value_edit = LineEdit.new()
	_step_condition_value_edit.placeholder_text = "true、false、数量或文本"
	_condition_fields.add_child(_step_condition_value_edit)
	inspector.add_child(_condition_fields)

	_action_fields = VBoxContainer.new()
	var action_title := Label.new()
	action_title.text = "动作设置"
	_action_fields.add_child(action_title)
	var action_type_label := Label.new()
	action_type_label.text = "动作类型"
	_action_fields.add_child(action_type_label)
	_step_action_type_selector = OptionButton.new()
	for action_label in ACTION_TYPE_LABELS:
		_step_action_type_selector.add_item(action_label)
	_action_fields.add_child(_step_action_type_selector)
	var action_target_label := Label.new()
	action_target_label.text = "状态或事件 ID"
	_action_fields.add_child(action_target_label)
	_step_action_target_edit = LineEdit.new()
	_step_action_target_edit.placeholder_text = "例如 archive_door_open"
	_action_fields.add_child(_step_action_target_edit)
	var action_value_label := Label.new()
	action_value_label.text = "写入值"
	_action_fields.add_child(action_value_label)
	_step_action_value_edit = LineEdit.new()
	_step_action_value_edit.placeholder_text = "true、false、数量或文本"
	_action_fields.add_child(_step_action_value_edit)
	inspector.add_child(_action_fields)

	_dialogue_fields = VBoxContainer.new()
	var dialogue_title := Label.new()
	dialogue_title.text = "对话设置"
	_dialogue_fields.add_child(dialogue_title)
	var dialogue_id_label := Label.new()
	dialogue_id_label.text = "对话资源 ID"
	_dialogue_fields.add_child(dialogue_id_label)
	_step_dialogue_id_edit = LineEdit.new()
	_step_dialogue_id_edit.placeholder_text = "例如 npc_archivist"
	_dialogue_fields.add_child(_step_dialogue_id_edit)
	var dialogue_node_label := Label.new()
	dialogue_node_label.text = "起始对话节点"
	_dialogue_fields.add_child(dialogue_node_label)
	_step_dialogue_node_edit = LineEdit.new()
	_step_dialogue_node_edit.placeholder_text = "start"
	_dialogue_fields.add_child(_step_dialogue_node_edit)
	inspector.add_child(_dialogue_fields)

	var description_label := Label.new()
	description_label.text = "说明"
	inspector.add_child(description_label)
	_step_description_edit = TextEdit.new()
	_step_description_edit.custom_minimum_size = Vector2(0.0, 120.0)
	_step_description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	inspector.add_child(_step_description_edit)
	var apply_step_button := Button.new()
	apply_step_button.text = "应用节点属性"
	apply_step_button.pressed.connect(_on_apply_step_pressed)
	inspector.add_child(apply_step_button)
	var hint := Label.new()
	hint.text = "拖动节点调整位置，拖动端口创建流程连接。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(hint)
	split.add_child(inspector)
	add_child(split)

	_status_label = Label.new()
	_status_label.text = "请选择或新建一个任务。"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)
	_validation_dialog = AcceptDialog.new()
	_validation_dialog.title = "任务流程检查"
	add_child(_validation_dialog)


func refresh_tasks() -> void:
	if _task_selector == null:
		return
	var previous_path := _current_path
	_quest_paths.clear()
	_scan_quest_files("res://data/quests")
	_quest_paths.sort()
	_task_selector.clear()
	for quest_path in _quest_paths:
		_task_selector.add_item(quest_path.get_file().get_basename())
	if _quest_paths.is_empty():
		_on_new_task_pressed()
		return
	var selected_index := _quest_paths.find(previous_path)
	if selected_index < 0:
		selected_index = 0
	_task_selector.select(selected_index)
	_load_task(_quest_paths[selected_index])


func _scan_quest_files(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not file_name.begins_with("."):
			var child_path := directory_path.path_join(file_name)
			if directory.current_is_dir():
				_scan_quest_files(child_path)
			elif file_name.ends_with(".tres"):
				_quest_paths.append(child_path)
		file_name = directory.get_next()
	directory.list_dir_end()


func _on_task_selected(index: int) -> void:
	if index < 0 or index >= _quest_paths.size():
		return
	_load_task(_quest_paths[index])


func _load_task(path: String) -> void:
	var quest := load(path) as LevelAuthoringQuestDefinition
	if quest == null:
		_status_label.text = "无法加载任务资源：%s" % path
		return
	_current_path = path
	_current_quest = quest
	_quest_id_edit.text = quest.quest_id
	_quest_title_edit.text = quest.title
	_selected_step_id = ""
	_rebuild_graph()
	_status_label.text = "已加载任务：%s" % path


func open_task(path: String, step_id: String = "") -> void:
	if _quest_paths.is_empty():
		refresh_tasks()
	var task_index := _quest_paths.find(path)
	if task_index >= 0:
		_task_selector.select(task_index)
	_load_task(path)
	if not step_id.is_empty():
		_select_step(step_id)
		var graph_name := str(_graph_name_by_step_id.get(step_id, ""))
		var graph_node := _graph.get_node_or_null(NodePath(graph_name)) as GraphNode
		if graph_node != null:
			graph_node.selected = true
	visible = true


func _on_new_task_pressed() -> void:
	_current_path = ""
	_current_quest = QuestDefinition.new()
	_current_quest.quest_id = "new_quest"
	_current_quest.title = "新任务"
	_current_quest.description = ""
	_current_quest.steps = [{
		"step_id": "start",
		"title": "开始",
		"node_type": "start",
		"description": "任务开始",
		"position": Vector2(120.0, 180.0),
		"next_step_ids": [],
	}]
	_quest_id_edit.text = _current_quest.quest_id
	_quest_title_edit.text = _current_quest.title
	_selected_step_id = ""
	_rebuild_graph()
	_status_label.text = "已创建新任务草稿，填写信息后点击保存任务。"


func _on_save_task_pressed() -> void:
	if _current_quest == null:
		_status_label.text = "请先新建或选择任务。"
		return
	var quest_id := _sanitize_id(_quest_id_edit.text)
	if quest_id.is_empty():
		_status_label.text = "任务 ID 不能为空。"
		return
	_current_quest.quest_id = quest_id
	_current_quest.title = _quest_title_edit.text.strip_edges()
	if _current_quest.title.is_empty():
		_current_quest.title = quest_id
	for step in _current_quest.steps:
		_set_next_step_connections(step, _get_next_step_connections(step))
	var quest_path := _current_path
	if quest_path.is_empty():
		quest_path = "res://data/quests/%s.tres" % quest_id
	if not ProjectPaths.ensure_directory("res://data/quests"):
		_status_label.text = "无法创建任务目录 data/quests。"
		return
	var save_error := ResourceSaver.save(_current_quest, quest_path)
	if save_error != OK:
		_status_label.text = "任务保存失败：%s" % save_error
		return
	_current_path = quest_path
	EditorInterface.get_resource_filesystem().scan()
	refresh_tasks()
	_status_label.text = "任务已保存：%s" % quest_path


func _on_add_node_pressed() -> void:
	if _current_quest == null:
		return
	var type_index := _node_type_selector.selected
	if type_index < 0 or type_index >= NODE_TYPE_IDS.size():
		type_index = 1
	var type_id: String = NODE_TYPE_IDS[type_index]
	var node_id := _make_unique_step_id(type_id)
	var node_title: String = NODE_TYPE_LABELS[type_index]
	var node_position := Vector2(160.0 + (_current_quest.steps.size() % 4) * 230.0, 180.0 + (_current_quest.steps.size() / 4) * 150.0)
	_current_quest.steps.append({
		"step_id": node_id,
		"title": node_title,
		"node_type": type_id,
		"description": "",
		"position": node_position,
		"condition_id": "",
		"condition_operator": "is_true",
		"condition_value": "true",
		"action_type": "set_condition",
		"action_target_id": "",
		"action_value": "true",
		"dialogue_id": "",
		"dialogue_node_id": "start",
		"next_step_connections": [],
		"next_step_ids": [],
	})
	_rebuild_graph()
	_select_step(node_id)
	_status_label.text = "已添加节点：%s。保存任务后写入资源。" % node_id


func _on_delete_selected_node_pressed() -> void:
	if _selected_step_id.is_empty():
		_status_label.text = "请先选择一个节点。"
		return
	_delete_steps([_selected_step_id])


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	var step_ids: Array[String] = []
	for graph_name in nodes:
		if _step_id_by_graph_name.has(str(graph_name)):
			step_ids.append(str(_step_id_by_graph_name[str(graph_name)]))
	_delete_steps(step_ids)


func _delete_steps(step_ids: Array[String]) -> void:
	if _current_quest == null or step_ids.is_empty():
		return
	var kept_steps: Array[Dictionary] = []
	for step in _current_quest.steps:
		if not step_ids.has(str(step.get("step_id", ""))):
			kept_steps.append(step)
	_current_quest.steps = kept_steps
	for step in _current_quest.steps:
		var connections := _get_next_step_connections(step)
		var kept_connections: Array[Dictionary] = []
		for connection in connections:
			if not step_ids.has(str(connection.get("step_id", ""))):
				kept_connections.append(connection)
		_set_next_step_connections(step, kept_connections)
	_selected_step_id = ""
	_rebuild_graph()
	_status_label.text = "已删除节点，保存任务后写入资源。"


func _on_apply_step_pressed() -> void:
	if _current_quest == null or _selected_step_id.is_empty():
		_status_label.text = "请先选择一个节点。"
		return
	var step := _find_step(_selected_step_id)
	if step.is_empty():
		return
	step["title"] = _step_title_edit.text.strip_edges()
	step["description"] = _step_description_edit.text
	var type_index := _step_type_selector.selected
	if type_index >= 0 and type_index < NODE_TYPE_IDS.size():
		step["node_type"] = NODE_TYPE_IDS[type_index]
	var node_type := str(step.get("node_type", "objective"))
	if node_type == "condition":
		step["condition_id"] = _sanitize_id(_step_condition_id_edit.text)
		var operator_index := _step_condition_operator_selector.selected
		if operator_index >= 0 and operator_index < CONDITION_OPERATOR_IDS.size():
			step["condition_operator"] = CONDITION_OPERATOR_IDS[operator_index]
		step["condition_value"] = _step_condition_value_edit.text.strip_edges()
	elif node_type == "action":
		var action_index := _step_action_type_selector.selected
		if action_index >= 0 and action_index < ACTION_TYPE_IDS.size():
			step["action_type"] = ACTION_TYPE_IDS[action_index]
		step["action_target_id"] = _sanitize_id(_step_action_target_edit.text)
		step["action_value"] = _step_action_value_edit.text.strip_edges()
	elif node_type == "dialogue":
		step["dialogue_id"] = _sanitize_id(_step_dialogue_id_edit.text)
		step["dialogue_node_id"] = _sanitize_id(_step_dialogue_node_edit.text)
	_rebuild_graph()
	_select_step(_selected_step_id)
	_status_label.text = "节点属性已更新，保存任务后写入资源。"


func _on_graph_node_selected(node: Node) -> void:
	if not node.has_meta("step_id"):
		return
	_select_step(str(node.get_meta("step_id")))


func _select_step(step_id: String) -> void:
	_selected_step_id = step_id
	var step := _find_step(step_id)
	if step.is_empty():
		return
	_step_id_edit.text = step_id
	_step_title_edit.text = str(step.get("title", ""))
	_step_description_edit.text = str(step.get("description", ""))
	var type_id := str(step.get("node_type", "objective"))
	var type_index := NODE_TYPE_IDS.find(type_id)
	_step_type_selector.select(type_index if type_index >= 0 else 2)
	_step_condition_id_edit.text = str(step.get("condition_id", ""))
	var operator_index := CONDITION_OPERATOR_IDS.find(str(step.get("condition_operator", "is_true")))
	_step_condition_operator_selector.select(operator_index if operator_index >= 0 else 0)
	_step_condition_value_edit.text = str(step.get("condition_value", "true"))
	var action_index := ACTION_TYPE_IDS.find(str(step.get("action_type", "set_condition")))
	_step_action_type_selector.select(action_index if action_index >= 0 else 0)
	_step_action_target_edit.text = str(step.get("action_target_id", ""))
	_step_action_value_edit.text = str(step.get("action_value", "true"))
	_step_dialogue_id_edit.text = str(step.get("dialogue_id", ""))
	_step_dialogue_node_edit.text = str(step.get("dialogue_node_id", "start"))
	_update_step_type_fields(type_id)


func _on_step_type_selected(type_index: int) -> void:
	if type_index < 0 or type_index >= NODE_TYPE_IDS.size():
		return
	_update_step_type_fields(NODE_TYPE_IDS[type_index])


func _update_step_type_fields(type_id: String) -> void:
	_condition_fields.visible = type_id == "condition"
	_action_fields.visible = type_id == "action"
	_dialogue_fields.visible = type_id == "dialogue"


func _on_graph_node_position_changed(step_id: String) -> void:
	var graph_name: String = str(_graph_name_by_step_id.get(step_id, ""))
	var graph_node := _graph.get_node_or_null(NodePath(graph_name)) as GraphNode
	var step := _find_step(step_id)
	if graph_node == null or step.is_empty():
		return
	step["position"] = graph_node.position_offset


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_step_id: String = str(_step_id_by_graph_name.get(str(from_node), ""))
	var to_step_id: String = str(_step_id_by_graph_name.get(str(to_node), ""))
	if from_step_id.is_empty() or to_step_id.is_empty() or from_step_id == to_step_id:
		return
	var from_step := _find_step(from_step_id)
	var to_step := _find_step(to_step_id)
	if from_step.is_empty() or to_step.is_empty() or str(to_step.get("node_type", "")) == "start" or to_port != 0:
		return
	var is_condition := str(from_step.get("node_type", "")) == "condition"
	if is_condition and (from_port != 0 and from_port != 1):
		return
	if not is_condition and (from_port != 0 or str(from_step.get("node_type", "")) == "complete"):
		return
	var connections := _get_next_step_connections(from_step)
	var updated_connections: Array[Dictionary] = []
	for connection in connections:
		if int(connection.get("from_port", 0)) != from_port:
			updated_connections.append(connection)
	updated_connections.append({"from_port": from_port, "step_id": to_step_id})
	_set_next_step_connections(from_step, updated_connections)
	if not _graph.is_node_connected(str(from_node), from_port, str(to_node), to_port):
		for old_connection in _graph.get_connection_list():
			if str(old_connection["from_node"]) == str(from_node) and int(old_connection["from_port"]) == from_port:
				_graph.disconnect_node(str(old_connection["from_node"]), int(old_connection["from_port"]), str(old_connection["to_node"]), int(old_connection["to_port"]))
		_graph.connect_node(str(from_node), from_port, str(to_node), to_port)
	var branch_label := "条件成立" if from_port == 0 and is_condition else ("条件不成立" if from_port == 1 and is_condition else "下一步")
	_status_label.text = "已连接（%s）：%s → %s。保存任务后写入资源。" % [branch_label, from_step_id, to_step_id]


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_step_id: String = str(_step_id_by_graph_name.get(str(from_node), ""))
	var to_step_id: String = str(_step_id_by_graph_name.get(str(to_node), ""))
	var from_step := _find_step(from_step_id)
	if from_step.is_empty():
		return
	var connections := _get_next_step_connections(from_step)
	var kept_connections: Array[Dictionary] = []
	for connection in connections:
		if int(connection.get("from_port", 0)) != from_port or str(connection.get("step_id", "")) != to_step_id:
			kept_connections.append(connection)
	_set_next_step_connections(from_step, kept_connections)
	_graph.disconnect_node(str(from_node), from_port, str(to_node), to_port)
	_status_label.text = "已断开连接，保存任务后写入资源。"


func _rebuild_graph() -> void:
	if _graph == null:
		return
	for connection in _graph.get_connection_list():
		_graph.disconnect_node(str(connection["from_node"]), int(connection["from_port"]), str(connection["to_node"]), int(connection["to_port"]))
	for child in _graph.get_children():
		if child is GraphNode:
			child.free()
	_graph_name_by_step_id.clear()
	_step_id_by_graph_name.clear()
	if _current_quest == null:
		return
	var node_index := 0
	for step in _current_quest.steps:
		var step_id := str(step.get("step_id", "step_%d" % node_index))
		var graph_name := "TaskNode_%d" % node_index
		_graph_name_by_step_id[step_id] = graph_name
		_step_id_by_graph_name[graph_name] = step_id
		var graph_node := GraphNode.new()
		graph_node.name = graph_name
		graph_node.title = "%s  [%s]" % [str(step.get("title", step_id)), str(step.get("node_type", "objective"))]
		var position: Vector2 = step.get("position", Vector2(120.0 + node_index * 220.0, 180.0))
		graph_node.position_offset = position
		graph_node.set_meta("step_id", step_id)
		var body := Label.new()
		body.text = str(step.get("description", ""))
		body.custom_minimum_size = Vector2(170.0, 48.0)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		graph_node.add_child(body)
		var node_type := str(step.get("node_type", "objective"))
		graph_node.set_slot(0, node_type != "start", 0, Color(0.35, 0.7, 0.95, 1.0), node_type != "complete" and node_type != "condition", 0, Color(0.4, 0.9, 0.55, 1.0))
		if node_type == "condition":
			var true_label := Label.new()
			true_label.text = "条件成立"
			true_label.custom_minimum_size = Vector2(170.0, 24.0)
			graph_node.add_child(true_label)
			graph_node.set_slot(1, false, 0, Color.WHITE, true, 0, Color(0.35, 0.85, 0.5, 1.0))
			var false_label := Label.new()
			false_label.text = "条件不成立"
			false_label.custom_minimum_size = Vector2(170.0, 24.0)
			graph_node.add_child(false_label)
			graph_node.set_slot(2, false, 0, Color.WHITE, true, 0, Color(0.95, 0.55, 0.4, 1.0))
		graph_node.position_offset_changed.connect(_on_graph_node_position_changed.bind(step_id))
		_graph.add_child(graph_node)
		node_index += 1
	for step in _current_quest.steps:
		var from_step_id := str(step.get("step_id", ""))
		var from_graph_name: String = str(_graph_name_by_step_id.get(from_step_id, ""))
		if str(step.get("node_type", "objective")) == "complete":
			continue
		for connection_data in _get_next_step_connections(step):
			var to_graph_name: String = str(_graph_name_by_step_id.get(str(connection_data.get("step_id", "")), ""))
			var from_port := int(connection_data.get("from_port", 0))
			var is_condition := str(step.get("node_type", "")) == "condition"
			if not is_condition and from_port != 0:
				continue
			if not from_graph_name.is_empty() and not to_graph_name.is_empty() and _find_step(str(connection_data.get("step_id", ""))).get("node_type", "") != "start":
				_graph.connect_node(from_graph_name, from_port, to_graph_name, 0)


func _find_step(step_id: String) -> Dictionary:
	if _current_quest == null:
		return {}
	for step in _current_quest.steps:
		if str(step.get("step_id", "")) == step_id:
			return step
	return {}


func _get_next_step_connections(step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if step.has("next_step_connections") and step["next_step_connections"] is Array:
		for connection in step["next_step_connections"]:
			if connection is Dictionary and not str(connection.get("step_id", "")).is_empty():
				result.append({"from_port": int(connection.get("from_port", 0)), "step_id": str(connection.get("step_id", ""))})
		return result
	var legacy_ids: Array = []
	if step.has("next_step_ids") and step["next_step_ids"] is Array:
		legacy_ids = step["next_step_ids"]
	else:
		var legacy_id := str(step.get("next_step_id", ""))
		if not legacy_id.is_empty():
			legacy_ids = [legacy_id]
	var is_condition := str(step.get("node_type", "")) == "condition"
	for index in range(legacy_ids.size()):
		var next_id := str(legacy_ids[index])
		if not next_id.is_empty():
			result.append({"from_port": index if is_condition else 0, "step_id": next_id})
	return result


func _set_next_step_connections(step: Dictionary, connections: Array[Dictionary]) -> void:
	step["next_step_connections"] = connections.duplicate(true)
	var next_ids: Array[String] = []
	for connection in connections:
		var next_id := str(connection.get("step_id", ""))
		if not next_id.is_empty() and not next_ids.has(next_id):
			next_ids.append(next_id)
	step["next_step_ids"] = next_ids
	if next_ids.size() == 1:
		step["next_step_id"] = next_ids[0]
	else:
		step.erase("next_step_id")


func _on_validate_quest_pressed() -> void:
	if _current_quest == null:
		_status_label.text = "请先新建或选择任务。"
		return
	if not _selected_step_id.is_empty():
		_on_apply_step_pressed()
	_current_quest.quest_id = _sanitize_id(_quest_id_edit.text)
	_current_quest.title = _quest_title_edit.text.strip_edges()
	var issues: Array[Dictionary] = TaskValidator.new().validate_quest(_current_quest, _current_path)
	var error_count := 0
	var warning_count := 0
	var error_lines: PackedStringArray = []
	var warning_lines: PackedStringArray = []
	for issue in issues:
		var step_id := str(issue.get("step_id", ""))
		var line := ("[%s] " % step_id if not step_id.is_empty() else "") + str(issue.get("message", ""))
		if issue.get("severity", "warning") == "error":
			error_count += 1
			error_lines.append(line)
		else:
			warning_count += 1
			warning_lines.append(line)
	var report := "检查完成：%d 个错误，%d 条提醒。" % [error_count, warning_count]
	if not error_lines.is_empty():
		report += "\n\n错误：\n• " + "\n• ".join(error_lines)
	if not warning_lines.is_empty():
		report += "\n\n提醒：\n• " + "\n• ".join(warning_lines)
	if issues.is_empty():
		report += "\n\n当前任务流程结构完整。"
	_validation_dialog.dialog_text = report
	_validation_dialog.popup_centered(Vector2i(520, 420))
	_status_label.text = "流程检查完成：%d 个错误，%d 条提醒。" % [error_count, warning_count]


func _make_unique_step_id(type_id: String) -> String:
	var index := 1
	var candidate := "%s_%02d" % [type_id, index]
	while not _find_step(candidate).is_empty():
		index += 1
		candidate = "%s_%02d" % [type_id, index]
	return candidate


func _sanitize_id(value: String) -> String:
	var result := value.strip_edges().to_lower()
	result = result.replace(" ", "_").replace("-", "_")
	var sanitized := ""
	for character in result:
		if character.is_valid_identifier() or character == "_":
			sanitized += character
	return sanitized
