@tool
extends RefCounted
class_name LevelAuthoringMapValidator

const TRACKED_ID_PROPERTIES := {
	"entity_id": "对象 ID",
	"portal_id": "传送点 ID",
	"checkpoint_id": "检查点 ID",
	"barrier_id": "障碍 ID",
	"hazard_id": "危险区域 ID",
	"marker_id": "探索标记 ID",
	"mechanism_id": "机关 ID",
	"pickup_id": "拾取物 ID",
	"encounter_id": "遭遇 ID",
	"spawn_id": "敌人出生组 ID",
	"route_id": "巡逻路线 ID",
	"service_id": "NPC 服务 ID",
	"traversal_id": "移动设施 ID",
	"flow_id": "环境区域 ID",
	"block_id": "推动物 ID",
	"station_id": "地图设施 ID",
	"chest_id": "宝箱 ID",
	"trigger_id": "触发器 ID",
}


func validate_maps(map_paths: Array[String], selected_path: String = "") -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if map_paths.is_empty() and selected_path.is_empty():
		issues.append(_make_issue("", [], "error", "没有找到地图场景。请先在 scenes/maps 中保存地图。"))
		return issues

	var paths_to_read: Array[String] = []
	for map_path in map_paths:
		paths_to_read.append(map_path)
	if not selected_path.is_empty() and not paths_to_read.has(selected_path):
		paths_to_read.append(selected_path)

	var map_data_by_path: Dictionary = {}
	for scene_path in paths_to_read:
		map_data_by_path[scene_path] = _read_map_data(scene_path)

	var map_paths_by_id: Dictionary = {}
	for scene_path in map_data_by_path:
		var map_data: Dictionary = map_data_by_path[scene_path]
		if map_data.has("error"):
			continue
		var map_id: String = str(map_data.get("map_id", ""))
		if map_id.is_empty():
			continue
		if not map_paths_by_id.has(map_id):
			map_paths_by_id[map_id] = []
		map_paths_by_id[map_id].append(scene_path)

	var paths_to_check: Array[String] = []
	if selected_path.is_empty():
		for map_path in map_paths:
			paths_to_check.append(map_path)
	else:
		paths_to_check.append(selected_path)
	for scene_path in paths_to_check:
		var map_data: Dictionary = map_data_by_path.get(scene_path, {})
		if map_data.has("error") or map_data.is_empty():
			var error_message := str(map_data.get("error", "无法读取地图场景。"))
			issues.append(_make_issue(scene_path, [], "error", error_message))
			continue

		var map_id: String = str(map_data.get("map_id", ""))
		if map_id.is_empty():
			issues.append(_make_issue(scene_path, [], "error", "地图 ID 不能为空。"))
		elif map_paths_by_id.get(map_id, []).size() > 1:
			var other_paths: Array = map_paths_by_id[map_id].duplicate()
			other_paths.erase(scene_path)
			var other_path_labels := PackedStringArray()
			for other_path in other_paths:
				other_path_labels.append(str(other_path))
			issues.append(_make_issue(scene_path, [], "error", "地图 ID「%s」重复：%s" % [map_id, ", ".join(other_path_labels)]))

		var map_size: Variant = map_data.get("map_size", Vector2.ZERO)
		if map_size is Vector2 and (map_size.x <= 0.0 or map_size.y <= 0.0):
			issues.append(_make_issue(scene_path, [], "error", "地图尺寸必须大于 0。"))

		_validate_spawn_points(scene_path, map_data, issues)
		_validate_object_ids(scene_path, map_data, issues)
		_validate_portals(scene_path, map_data, map_data_by_path, issues)
		_validate_runtime_checks(scene_path, map_data, issues)

	return issues


func read_map_data(scene_path: String) -> Dictionary:
	return _read_map_data(scene_path)


func _read_map_data(scene_path: String) -> Dictionary:
	if not FileAccess.file_exists(scene_path):
		return {"error": "地图场景文件不存在：%s" % scene_path}
	var packed_scene := ResourceLoader.load(scene_path) as PackedScene
	if packed_scene == null:
		return {"error": "无法载入场景：%s" % scene_path}
	var root := packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if root == null:
		return {"error": "无法实例化场景：%s" % scene_path}
	if not _has_property(root, "map_id"):
		root.free()
		return {"error": "场景根节点没有地图 ID；请使用关卡搭建器的地图模板。"}

	var map_data := {
		"map_id": str(root.get("map_id")).strip_edges(),
		"display_name": str(root.get("display_name")).strip_edges() if _has_property(root, "display_name") else "",
		"map_size": root.get("map_size") if _has_property(root, "map_size") else Vector2.ZERO,
		"spawn_points": [],
		"portals": [],
		"objects": [],
		"runtime_checks": [],
	}
	_collect_scene_nodes(root, [], map_data)
	root.free()
	return map_data


func _collect_scene_nodes(node: Node, node_parts: Array[String], map_data: Dictionary) -> void:
	var ids: Dictionary = {}
	for property_name in TRACKED_ID_PROPERTIES:
		if not _has_property(node, property_name):
			continue
		var identifier := str(node.get(property_name)).strip_edges()
		if not identifier.is_empty():
			ids[property_name] = identifier
	if not ids.is_empty():
		map_data["objects"].append({"node_parts": node_parts.duplicate(), "ids": ids})

	if _has_property(node, "spawn_point_id"):
		map_data["spawn_points"].append({
			"node_parts": node_parts.duplicate(),
			"id": str(node.get("spawn_point_id")).strip_edges(),
		})
	if _has_property(node, "target_scene_path"):
		map_data["portals"].append({
			"node_parts": node_parts.duplicate(),
			"id": str(node.get("portal_id")).strip_edges() if _has_property(node, "portal_id") else "",
			"enabled": bool(node.get("enabled")) if _has_property(node, "enabled") else true,
			"target_scene_path": str(node.get("target_scene_path")).strip_edges(),
			"target_spawn_point_id": str(node.get("target_spawn_point_id")).strip_edges() if _has_property(node, "target_spawn_point_id") else "",
		})
	var runtime_checks: Array = map_data.get("runtime_checks", [])
	if _has_property(node, "trigger_id"):
		runtime_checks.append({
			"kind": "trigger",
			"node_parts": node_parts.duplicate(),
			"id": str(node.get("trigger_id")).strip_edges(),
			"trigger_type": str(node.get("trigger_type")) if _has_property(node, "trigger_type") else "enter",
			"event_key": str(node.get("event_key")).strip_edges() if _has_property(node, "event_key") else "",
			"has_listener": node.has_signal("triggered") and not node.get_signal_connection_list("triggered").is_empty(),
		})
	if _has_property(node, "service_id") and _has_property(node, "dialogue_file"):
		runtime_checks.append({
			"kind": "service",
			"node_parts": node_parts.duplicate(),
			"id": str(node.get("service_id")).strip_edges(),
			"dialogue_file": str(node.get("dialogue_file")).strip_edges(),
		})
	if _has_property(node, "mechanism_id") and _has_property(node, "linked_target_path"):
		var linked_path: NodePath = node.get("linked_target_path")
		runtime_checks.append({
			"kind": "mechanism",
			"node_parts": node_parts.duplicate(),
			"id": str(node.get("mechanism_id")).strip_edges(),
			"linked_path": str(linked_path),
			"target_exists": not linked_path.is_empty() and node.get_node_or_null(linked_path) != null,
		})
	if _has_property(node, "barrier_id") and _has_property(node, "barrier_type"):
		runtime_checks.append({
			"kind": "barrier",
			"node_parts": node_parts.duplicate(),
			"id": str(node.get("barrier_id")).strip_edges(),
			"barrier_type": str(node.get("barrier_type")),
			"required_condition_id": str(node.get("required_condition_id")).strip_edges() if _has_property(node, "required_condition_id") else "",
		})
	if _has_property(node, "encounter_id") and _has_property(node, "encounter_type"):
		runtime_checks.append({
			"kind": "encounter",
			"node_parts": node_parts.duplicate(),
			"id": str(node.get("encounter_id")).strip_edges(),
			"encounter_type": str(node.get("encounter_type")),
			"wave_ids": node.get("wave_ids") if _has_property(node, "wave_ids") else PackedStringArray(),
		})
	map_data["runtime_checks"] = runtime_checks

	for child in node.get_children():
		var child_parts: Array[String] = node_parts.duplicate()
		child_parts.append(str(child.name))
		_collect_scene_nodes(child, child_parts, map_data)


func _validate_runtime_checks(scene_path: String, map_data: Dictionary, issues: Array[Dictionary]) -> void:
	for check in map_data.get("runtime_checks", []):
		var node_parts: Array = check.get("node_parts", [])
		var object_id := str(check.get("id", ""))
		match str(check.get("kind", "")):
			"trigger":
				var trigger_type := str(check.get("trigger_type", "enter"))
				if trigger_type != "enter" and str(check.get("event_key", "")).is_empty():
					issues.append(_make_issue(scene_path, node_parts, "error", "触发器「%s」类型为 %s，但没有事件 key。" % [object_id, trigger_type]))
				if not bool(check.get("has_listener", false)):
					issues.append(_make_issue(scene_path, node_parts, "warning", "触发器「%s」没有场景内信号处理器；请确认运行时代码会连接该信号，才能驱动任务或剧情。" % object_id))
			"service":
				var dialogue_file := str(check.get("dialogue_file", ""))
				if not dialogue_file.is_empty() and not FileAccess.file_exists(dialogue_file):
					issues.append(_make_issue(scene_path, node_parts, "error", "NPC 服务「%s」引用的对话文件不存在：%s" % [object_id, dialogue_file]))
			"mechanism":
				var linked_path := str(check.get("linked_path", ""))
				if not linked_path.is_empty() and not bool(check.get("target_exists", false)):
					issues.append(_make_issue(scene_path, node_parts, "error", "机关「%s」的联动目标不存在：%s" % [object_id, linked_path]))
			"barrier":
				var barrier_type := str(check.get("barrier_type", ""))
				if barrier_type in ["ability_gate", "locked_door"] and str(check.get("required_condition_id", "")).is_empty():
					issues.append(_make_issue(scene_path, node_parts, "error", "障碍「%s」需要配置解锁条件 ID。" % object_id))
			"encounter":
				var encounter_type := str(check.get("encounter_type", ""))
				var wave_ids: Variant = check.get("wave_ids", PackedStringArray())
				if encounter_type in ["waves", "ambush"] and wave_ids is PackedStringArray and wave_ids.is_empty():
					issues.append(_make_issue(scene_path, node_parts, "warning", "遭遇区「%s」没有配置波次 ID。" % object_id))


func _validate_spawn_points(scene_path: String, map_data: Dictionary, issues: Array[Dictionary]) -> void:
	var spawn_points: Array = map_data.get("spawn_points", [])
	if spawn_points.is_empty():
		issues.append(_make_issue(scene_path, [], "warning", "地图没有出生点；玩家出生和地图传送将无法定位。"))
		return

	var seen_ids: Dictionary = {}
	for spawn_point in spawn_points:
		var spawn_id: String = str(spawn_point.get("id", ""))
		var node_parts: Array = spawn_point.get("node_parts", [])
		if spawn_id.is_empty():
			issues.append(_make_issue(scene_path, node_parts, "error", "出生点 ID 不能为空。"))
			continue
		if seen_ids.has(spawn_id):
			issues.append(_make_issue(scene_path, node_parts, "error", "出生点 ID「%s」重复；首次出现于 %s。" % [spawn_id, _format_node_parts(seen_ids[spawn_id])]))
		else:
			seen_ids[spawn_id] = node_parts


func _validate_object_ids(scene_path: String, map_data: Dictionary, issues: Array[Dictionary]) -> void:
	var seen_by_property: Dictionary = {}
	for object_data in map_data.get("objects", []):
		var ids: Dictionary = object_data.get("ids", {})
		for property_name in ids:
			var identifier: String = ids[property_name]
			if not seen_by_property.has(property_name):
				seen_by_property[property_name] = {}
			var seen_ids: Dictionary = seen_by_property[property_name]
			var node_parts: Array = object_data.get("node_parts", [])
			if seen_ids.has(identifier):
				var severity := "error" if property_name == "entity_id" else "warning"
				issues.append(_make_issue(scene_path, node_parts, severity, "%s「%s」重复；首次出现于 %s。" % [TRACKED_ID_PROPERTIES[property_name], identifier, _format_node_parts(seen_ids[identifier])]))
			else:
				seen_ids[identifier] = node_parts


func _validate_portals(scene_path: String, map_data: Dictionary, map_data_by_path: Dictionary, issues: Array[Dictionary]) -> void:
	for portal in map_data.get("portals", []):
		if not bool(portal.get("enabled", true)):
			continue
		var node_parts: Array = portal.get("node_parts", [])
		var portal_name: String = str(portal.get("id", "传送点"))
		var target_path: String = str(portal.get("target_scene_path", ""))
		var target_spawn_id: String = str(portal.get("target_spawn_point_id", ""))
		if target_path.is_empty():
			issues.append(_make_issue(scene_path, node_parts, "error", "传送点「%s」尚未设置目标地图。" % portal_name))
			continue
		if not FileAccess.file_exists(target_path):
			issues.append(_make_issue(scene_path, node_parts, "error", "传送点「%s」的目标场景不存在：%s" % [portal_name, target_path]))
			continue
		if target_spawn_id.is_empty():
			issues.append(_make_issue(scene_path, node_parts, "error", "传送点「%s」尚未设置目标出生点 ID。" % portal_name))
			continue

		var target_data: Dictionary
		if map_data_by_path.has(target_path):
			target_data = map_data_by_path[target_path]
		else:
			target_data = _read_map_data(target_path)
		if target_data.has("error"):
			issues.append(_make_issue(scene_path, node_parts, "error", "传送点「%s」的目标不是有效地图：%s" % [portal_name, str(target_data["error"])]))
			continue

		var destination_found := false
		for spawn_point in target_data.get("spawn_points", []):
			if str(spawn_point.get("id", "")) == target_spawn_id:
				destination_found = true
				break
		if not destination_found:
			issues.append(_make_issue(scene_path, node_parts, "error", "传送点「%s」找不到目标地图「%s」中的出生点「%s」。" % [portal_name, str(target_data.get("map_id", target_path.get_file().get_basename())), target_spawn_id]))


func _has_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if str(property_info.name) == property_name:
			return true
	return false


func _make_issue(scene_path: String, node_parts: Array, severity: String, message: String) -> Dictionary:
	return {
		"scene_path": scene_path,
		"node_parts": node_parts.duplicate(),
		"severity": severity,
		"message": message,
	}


func _format_node_parts(node_parts: Array) -> String:
	if node_parts.is_empty():
		return "地图根节点"
	var result := ""
	for part in node_parts:
		if not result.is_empty():
			result += "/"
		result += str(part)
	return result
