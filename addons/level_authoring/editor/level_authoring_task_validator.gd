@tool
extends RefCounted
class_name LevelAuthoringTaskValidator


func validate_quest(quest: Resource, quest_path: String = "") -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if quest == null:
		issues.append(_issue(quest_path, "", "error", "无法载入任务资源。"))
		return issues
	var quest_id := str(quest.get("quest_id")).strip_edges()
	if quest_id.is_empty():
		issues.append(_issue(quest_path, "", "error", "任务 ID 不能为空。"))
	if str(quest.get("title")).strip_edges().is_empty():
		issues.append(_issue(quest_path, "", "warning", "任务名称为空。"))
	var steps: Array = quest.get("steps") if quest.get("steps") is Array else []
	var step_by_id: Dictionary = {}
	var start_ids: Array[String] = []
	var complete_count := 0
	for step in steps:
		if not step is Dictionary:
			issues.append(_issue(quest_path, "", "error", "发现格式无效的流程节点。"))
			continue
		var step_id := str(step.get("step_id", "")).strip_edges()
		if step_id.is_empty():
			issues.append(_issue(quest_path, "", "error", "发现缺少 ID 的流程节点。"))
		elif step_by_id.has(step_id):
			issues.append(_issue(quest_path, step_id, "error", "节点 ID 重复。"))
		else:
			step_by_id[step_id] = step
		var node_type := str(step.get("node_type", "objective"))
		if node_type not in ["start", "dialogue", "objective", "condition", "action", "complete"]:
			issues.append(_issue(quest_path, step_id, "error", "未知的节点类型：%s。" % node_type))
		if node_type == "start":
			start_ids.append(step_id)
		elif node_type == "complete":
			complete_count += 1
		_match_node_configuration(step, quest_path, step_id, node_type, issues)
	if start_ids.size() != 1:
		issues.append(_issue(quest_path, "", "error", "流程需要且只能有一个开始节点（当前 %d 个）。" % start_ids.size()))
	if complete_count == 0:
		issues.append(_issue(quest_path, "", "warning", "流程中没有完成节点。"))
	for step in steps:
		if not step is Dictionary:
			continue
		var step_id := str(step.get("step_id", ""))
		var source_type := str(step.get("node_type", "objective"))
		for connection in _get_connections(step):
			var target_id := str(connection.get("step_id", ""))
			var from_port := int(connection.get("from_port", 0))
			if source_type == "complete":
				issues.append(_issue(quest_path, step_id, "error", "完成节点不能再连接后续节点。"))
			elif source_type == "condition" and from_port not in [0, 1]:
				issues.append(_issue(quest_path, step_id, "error", "条件分支端口编号无效：%d。" % from_port))
			elif source_type != "condition" and from_port != 0:
				issues.append(_issue(quest_path, step_id, "error", "该节点的连接端口编号无效：%d。" % from_port))
			if not step_by_id.has(target_id):
				issues.append(_issue(quest_path, step_id, "error", "指向不存在的节点：%s。" % target_id))
			elif str(step_by_id[target_id].get("node_type", "")) == "start":
				issues.append(_issue(quest_path, step_id, "error", "流程不能连接回开始节点「%s」。" % target_id))
	if start_ids.size() == 1:
		var reachable: Dictionary = {}
		var pending: Array[String] = [start_ids[0]]
		while not pending.is_empty():
			var current_id := pending.pop_front()
			if reachable.has(current_id) or not step_by_id.has(current_id):
				continue
			reachable[current_id] = true
			for connection in _get_connections(step_by_id[current_id]):
				var target_id := str(connection.get("step_id", ""))
				if not reachable.has(target_id):
					pending.append(target_id)
		for step_id in step_by_id:
			if not reachable.has(step_id):
				issues.append(_issue(quest_path, str(step_id), "warning", "从开始节点无法到达。"))
	return issues


func validate_quests(quest_paths: Array[String]) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var seen_quest_ids: Dictionary = {}
	for quest_path in quest_paths:
		var quest := ResourceLoader.load(quest_path)
		issues.append_array(validate_quest(quest, quest_path))
		if quest != null:
			var quest_id := str(quest.get("quest_id")).strip_edges()
			if not quest_id.is_empty():
				if seen_quest_ids.has(quest_id):
					issues.append(_issue(quest_path, "", "error", "任务 ID「%s」与 %s 重复。" % [quest_id, str(seen_quest_ids[quest_id])]))
				else:
					seen_quest_ids[quest_id] = quest_path
	return issues


func _match_node_configuration(step: Dictionary, quest_path: String, step_id: String, node_type: String, issues: Array[Dictionary]) -> void:
	if node_type == "condition":
		if str(step.get("condition_id", "")).strip_edges().is_empty():
			issues.append(_issue(quest_path, step_id, "error", "条件节点没有状态 ID。"))
		if str(step.get("condition_operator", "is_true")) not in ["is_true", "is_false", "equals", "not_equals"]:
			issues.append(_issue(quest_path, step_id, "error", "条件判断方式无效。"))
		var ports: Array[int] = []
		for connection in _get_connections(step):
			ports.append(int(connection.get("from_port", 0)))
		if not ports.has(0):
			issues.append(_issue(quest_path, step_id, "warning", "尚未连接“条件成立”分支。"))
		if not ports.has(1):
			issues.append(_issue(quest_path, step_id, "warning", "尚未连接“条件不成立”分支。"))
	elif node_type == "action":
		var action_type := str(step.get("action_type", "set_condition"))
		if action_type not in ["set_condition", "clear_condition", "emit_event", "complete_quest"]:
			issues.append(_issue(quest_path, step_id, "error", "动作类型无效：%s。" % action_type))
		if action_type != "complete_quest" and str(step.get("action_target_id", "")).strip_edges().is_empty():
			issues.append(_issue(quest_path, step_id, "error", "动作节点缺少状态或事件 ID。"))
	elif node_type == "dialogue":
		var dialogue_id := str(step.get("dialogue_id", "")).strip_edges()
		if dialogue_id.is_empty():
			issues.append(_issue(quest_path, step_id, "error", "对话节点缺少对话资源 ID。"))
		elif not FileAccess.file_exists("res://data/dialogues/%s.csv" % dialogue_id):
			issues.append(_issue(quest_path, step_id, "error", "对话资源不存在：%s。" % dialogue_id))


func _get_connections(step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if step.get("next_step_connections") is Array:
		for connection in step["next_step_connections"]:
			if connection is Dictionary and not str(connection.get("step_id", "")).is_empty():
				result.append({"from_port": int(connection.get("from_port", 0)), "step_id": str(connection.get("step_id", ""))})
		return result
	var next_ids: Array = []
	if step.get("next_step_ids") is Array:
		next_ids = step["next_step_ids"]
	else:
		var legacy_id := str(step.get("next_step_id", ""))
		if not legacy_id.is_empty():
			next_ids = [legacy_id]
	var is_condition := str(step.get("node_type", "")) == "condition"
	for index in range(next_ids.size()):
		var next_id := str(next_ids[index])
		if not next_id.is_empty():
			result.append({"from_port": index if is_condition else 0, "step_id": next_id})
	return result


func _issue(quest_path: String, step_id: String, severity: String, message: String) -> Dictionary:
	return {
		"issue_type": "task",
		"quest_path": quest_path,
		"step_id": step_id,
		"severity": severity,
		"message": message,
	}
