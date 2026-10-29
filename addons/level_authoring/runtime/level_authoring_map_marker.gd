@tool
extends Node2D
class_name LevelAuthoringMapMarker

signal revealed(marker_id: String)

@export var entity_type := "map_marker"
@export var marker_id := ""
@export_enum("secret", "return_later", "ability_hint", "hidden_room") var marker_type := "secret":
	set(value):
		marker_type = value
		_update_preview()
@export var required_ability_id := "":
	set(value):
		required_ability_id = value
		_update_preview()
@export_multiline var editor_note := ""
@export var show_in_game := false:
	set(value):
		show_in_game = value
		_update_preview()
var _is_revealed := false


func _ready() -> void:
	_update_preview()


func reveal(condition_id: String = "") -> bool:
	if not required_ability_id.is_empty() and condition_id != required_ability_id:
		return false
	if _is_revealed:
		return false
	_is_revealed = true
	_update_preview()
	revealed.emit(marker_id)
	return true


func _update_preview() -> void:
	visible = Engine.is_editor_hint() or show_in_game or _is_revealed
	var label := get_node_or_null("Label") as Label
	if label == null:
		return
	match marker_type:
		"return_later":
			label.text = "稍后返回" if required_ability_id.is_empty() else "稍后返回：%s" % required_ability_id
		"ability_hint":
			label.text = "能力提示：%s" % required_ability_id
		"hidden_room":
			label.text = "隐藏房间"
		_:
			label.text = "秘密入口"
