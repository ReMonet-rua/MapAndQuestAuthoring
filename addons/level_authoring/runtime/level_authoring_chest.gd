@tool
extends Area2D
class_name LevelAuthoringChest

signal chest_opened(chest_id: String, reward_type: String, reward_id: String, amount: int, body: Node2D)

@export var entity_type := "chest"
@export var chest_id := ""
@export_enum("currency", "key", "ability", "map_fragment", "upgrade", "quest_item") var reward_type := "currency":
	set(value):
		reward_type = value
		_update_preview()
@export var reward_id := ""
@export_range(1, 9999, 1) var amount := 1
@export var interaction_action := "interact"
@export var one_shot := true

var _opened := false
var _bodies_in_range: Array[Node2D] = []


func _ready() -> void:
	_update_preview()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _opened and one_shot:
		return
	if _bodies_in_range.is_empty() or not InputMap.has_action(interaction_action):
		return
	if Input.is_action_just_pressed(interaction_action):
		open_chest(_bodies_in_range[0])


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body) and not _bodies_in_range.has(body):
		_bodies_in_range.append(body)


func _on_body_exited(body: Node2D) -> void:
	_bodies_in_range.erase(body)


func open_chest(body: Node2D = null) -> bool:
	if _opened and one_shot:
		return false
	_opened = true
	_update_preview()
	chest_opened.emit(chest_id, reward_type, reward_id, amount, body)
	return true


func _is_player(body: Node2D) -> bool:
	return body.name == "Player" or body.is_in_group("player")


func _update_preview() -> void:
	var label := get_node_or_null("Label") as Label
	if label == null:
		return
	if _opened:
		label.text = "已开启"
	else:
		var reward := reward_id if not reward_id.is_empty() else reward_type
		label.text = "宝箱 %s · E" % reward
