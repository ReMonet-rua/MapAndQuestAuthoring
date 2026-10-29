@tool
extends StaticBody2D
class_name LevelAuthoringBarrier

@export var entity_type := "barrier"
@export_enum("ability_gate", "locked_door", "breakable_wall", "secret_passage") var barrier_type := "ability_gate"
@export var barrier_id := ""
@export_enum("ability", "item", "quest", "key") var condition_type := "ability"
@export var required_condition_id := ""
@export var required_damage_type := ""
@export_range(1, 99, 1) var hits_required := 1
@export var hidden_until_revealed := true
@export var is_open := false:
	set(value):
		is_open = value
		_update_visual_state()

var _hit_count := 0
var _is_revealed := false


func _ready() -> void:
	_update_visual_state()


func set_open(open: bool) -> void:
	is_open = open


func unlock_with(condition_id: String) -> bool:
	if barrier_type == "breakable_wall" or required_condition_id.is_empty():
		return false
	if condition_id != required_condition_id:
		return false
	set_open(true)
	return true


func reveal() -> bool:
	if barrier_type != "secret_passage" or _is_revealed:
		return false
	_is_revealed = true
	set_open(true)
	_update_visual_state()
	return true


func apply_hit(damage_type: String = "") -> bool:
	if barrier_type != "breakable_wall" or is_open:
		return false
	if not required_damage_type.is_empty() and damage_type != required_damage_type:
		return false
	_hit_count += 1
	_update_visual_state()
	if _hit_count >= hits_required:
		set_open(true)
	return is_open


func _update_visual_state() -> void:
	var secret_visible := Engine.is_editor_hint() or barrier_type != "secret_passage" or not hidden_until_revealed or _is_revealed
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		if is_inside_tree() and not Engine.is_editor_hint():
			collision.set_deferred("disabled", is_open)
		else:
			collision.disabled = is_open

	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.visible = secret_visible
		if is_open:
			visual.color = Color(0.32, 0.85, 0.68, 0.24)
		elif barrier_type == "secret_passage":
			visual.color = Color(0.61, 0.49, 0.77, 0.85)
		elif barrier_type == "breakable_wall":
			visual.color = Color(0.77, 0.39, 0.30, 1.0)
		elif barrier_type == "locked_door":
			visual.color = Color(0.78, 0.58, 0.24, 1.0)
		else:
			visual.color = Color(0.43, 0.57, 0.83, 1.0)
	var outline := get_node_or_null("Outline") as Line2D
	if outline != null:
		outline.visible = secret_visible

	var label := get_node_or_null("Label") as Label
	if label == null:
		return
	label.visible = secret_visible
	if is_open:
		label.text = "已开启"
	elif barrier_type == "secret_passage":
		label.text = "秘密通道（揭示后调用 reveal()）"
	elif barrier_type == "breakable_wall":
		label.text = "可破坏墙 %d/%d" % [_hit_count, hits_required]
	else:
		label.text = "%s：%s" % [condition_type, required_condition_id if not required_condition_id.is_empty() else "待配置"]
