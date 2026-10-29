@tool
extends Area2D
class_name LevelAuthoringPickup

signal collected(pickup_id: String, pickup_type: String, amount: int, body: Node2D)

@export var entity_type := "item"
@export var pickup_id := ""
@export_enum("ability", "health", "energy", "currency", "key", "map_fragment", "upgrade", "quest_item") var pickup_type := "currency":
	set(value):
		pickup_type = value
		_update_preview()
@export var content_id := "":
	set(value):
		content_id = value
		_update_preview()
@export_range(1, 9999, 1) var amount := 1:
	set(value):
		amount = value
		_update_preview()
@export var one_shot := true
var _collected := false


func _ready() -> void:
	_update_preview()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not (body.name == "Player" or body.is_in_group("player")):
		return
	collect(body)


func collect(body: Node2D = null) -> void:
	if one_shot and _collected:
		return
	collected.emit(pickup_id, pickup_type, amount, body)
	if one_shot:
		_collected = true
		queue_free()


func _update_preview() -> void:
	var label := get_node_or_null("Label") as Label
	if label == null:
		return
	match pickup_type:
		"ability":
			label.text = "能力：%s" % content_id
		"map_fragment":
			label.text = "地图碎片"
		"upgrade":
			label.text = "升级素材"
		"key":
			label.text = "钥匙：%s" % content_id
		"health":
			label.text = "生命 +%d" % amount
		"energy":
			label.text = "能量 +%d" % amount
		_:
			label.text = "收集物 +%d" % amount
