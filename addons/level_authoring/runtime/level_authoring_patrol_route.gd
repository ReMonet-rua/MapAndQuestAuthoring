@tool
extends Node2D
class_name LevelAuthoringPatrolRoute

@export var entity_type := "enemy_route"
@export var route_id := ""
@export var route_points: PackedVector2Array = PackedVector2Array([Vector2(-96.0, 0.0), Vector2(96.0, 0.0)]):
	set(value):
		route_points = value
		_refresh_preview()


func _ready() -> void:
	_refresh_preview()


func _refresh_preview() -> void:
	var preview := get_node_or_null("Preview") as Line2D
	if preview != null:
		preview.points = route_points
