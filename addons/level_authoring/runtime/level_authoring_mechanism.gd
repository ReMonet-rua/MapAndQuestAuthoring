extends Area2D
class_name LevelAuthoringMechanism

signal state_changed(mechanism_id: String, active: bool, body: Node2D)

@export var entity_type := "mechanism"
@export var mechanism_id := ""
@export_enum("interact", "pressure_plate", "enter") var activation_mode := "interact"
@export var interaction_action := "interact"
@export var linked_target_path: NodePath
@export var toggle_on_interact := true
@export var is_active := false

var _bodies_in_range: Array[Node2D] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visual_state()
	_apply_linked_state(null)


func _process(_delta: float) -> void:
	if activation_mode != "interact" or _bodies_in_range.is_empty():
		return
	if InputMap.has_action(interaction_action) and Input.is_action_just_pressed(interaction_action):
		activate(_bodies_in_range[0])


func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if not _bodies_in_range.has(body):
		_bodies_in_range.append(body)
	match activation_mode:
		"pressure_plate":
			_set_active(true, body)
		"enter":
			_set_active(not is_active, body)


func _on_body_exited(body: Node2D) -> void:
	_bodies_in_range.erase(body)
	if activation_mode == "pressure_plate" and _bodies_in_range.is_empty():
		_set_active(false, body)


func activate(body: Node2D = null) -> void:
	var next_state := not is_active if toggle_on_interact else true
	_set_active(next_state, body)


func _set_active(value: bool, body: Node2D) -> void:
	if is_active == value:
		return
	is_active = value
	_update_visual_state()
	_apply_linked_state(body)
	state_changed.emit(mechanism_id, is_active, body)


func _update_visual_state() -> void:
	var base := get_node_or_null("Base") as Polygon2D
	if base != null:
		base.color = Color(0.24, 0.65, 0.54, 1.0) if is_active else Color(0.18, 0.38, 0.36, 1.0)
	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = "机关：开启" if is_active else "开关 / E 互动"


func _apply_linked_state(body: Node2D) -> void:
	if linked_target_path.is_empty():
		return
	var target := get_node_or_null(linked_target_path)
	if target == null:
		return
	if target.has_method("set_open"):
		target.call("set_open", is_active)
	elif target.has_method("set_active"):
		target.call("set_active", is_active)


func _is_player(body: Node2D) -> bool:
	return body.name == "Player" or body.is_in_group("player")
