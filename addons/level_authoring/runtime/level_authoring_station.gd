@tool
extends Area2D
class_name LevelAuthoringStation

signal station_activated(station_id: String, station_type: String, region_id: String, body: Node2D)

@export var entity_type := "station"
@export var station_id := ""
@export_enum("map_station", "recharge_station") var station_type := "map_station":
	set(value):
		station_type = value
		_update_preview()
@export var region_id := ""
@export var interaction_action := "interact"

var _bodies_in_range: Array[Node2D] = []


func _ready() -> void:
	_update_preview()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _bodies_in_range.is_empty() or not InputMap.has_action(interaction_action):
		return
	if Input.is_action_just_pressed(interaction_action):
		activate(_bodies_in_range[0])


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body) and not _bodies_in_range.has(body):
		_bodies_in_range.append(body)


func _on_body_exited(body: Node2D) -> void:
	_bodies_in_range.erase(body)


func activate(body: Node2D = null) -> void:
	station_activated.emit(station_id, station_type, region_id, body)


func _is_player(body: Node2D) -> bool:
	return body.name == "Player" or body.is_in_group("player")


func _update_preview() -> void:
	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = "地图终端 · E" if station_type == "map_station" else "恢复点 · E"
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.color = Color(0.22, 0.72, 0.92, 0.95) if station_type == "map_station" else Color(0.28, 0.88, 0.64, 0.95)
