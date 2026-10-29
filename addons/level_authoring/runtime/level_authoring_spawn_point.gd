@tool
extends Marker2D
class_name LevelAuthoringSpawnPoint

@export var entity_type := "spawn_point"
@export var spawn_point_id := "entry"
@export var display_name := "出生点"
@export var marker_color := Color(0.3, 0.95, 0.65, 1.0):
	set(value):
		marker_color = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 10.0, Color(marker_color.r, marker_color.g, marker_color.b, 0.18))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, marker_color, 2.0)
	draw_line(Vector2(-18.0, 0.0), Vector2(18.0, 0.0), marker_color, 2.0)
	draw_line(Vector2(0.0, -18.0), Vector2(0.0, 18.0), marker_color, 2.0)
