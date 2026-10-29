@tool
extends Node2D
class_name LevelAuthoringMap

const BOUNDARY_LEFT := 1
const BOUNDARY_RIGHT := 2
const BOUNDARY_TOP := 4
const BOUNDARY_BOTTOM := 8

@export var map_id := ""
@export var display_name := ""
@export var map_size := Vector2(1600.0, 700.0):
	set(value):
		map_size = value
		queue_redraw()
@export var grid_size := Vector2(32.0, 32.0):
	set(value):
		grid_size = value
		queue_redraw()
@export_flags("左边界", "右边界", "上边界", "下边界") var solid_boundary_sides := BOUNDARY_LEFT | BOUNDARY_RIGHT:
	set(value):
		solid_boundary_sides = value
@export_range(8.0, 256.0, 1.0) var boundary_thickness := 32.0


func _ready() -> void:
	if display_name.is_empty():
		display_name = map_id
	if Engine.is_editor_hint():
		queue_redraw()
	else:
		_create_runtime_boundaries()


func _draw() -> void:
	if not Engine.is_editor_hint() or map_size.x <= 0.0 or map_size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.25, 0.82, 1.0, 0.9), false, 2.0)
	draw_line(Vector2.ZERO, Vector2(grid_size.x, 0.0), Color(0.25, 0.82, 1.0, 0.55), 2.0)
	draw_line(Vector2.ZERO, Vector2(0.0, grid_size.y), Color(0.25, 0.82, 1.0, 0.55), 2.0)


func _create_runtime_boundaries() -> void:
	var generated_root := Node2D.new()
	generated_root.name = "GeneratedMapBoundaries"
	generated_root.add_to_group("level_authoring_generated")
	add_child(generated_root)
	var wall_span := Vector2(map_size.x + boundary_thickness * 2.0, map_size.y + boundary_thickness * 2.0)
	if (solid_boundary_sides & BOUNDARY_LEFT) != 0:
		_add_boundary_wall(generated_root, "LeftBoundary", Vector2(boundary_thickness, wall_span.y), Vector2(-boundary_thickness * 0.5, map_size.y * 0.5))
	if (solid_boundary_sides & BOUNDARY_RIGHT) != 0:
		_add_boundary_wall(generated_root, "RightBoundary", Vector2(boundary_thickness, wall_span.y), Vector2(map_size.x + boundary_thickness * 0.5, map_size.y * 0.5))
	if (solid_boundary_sides & BOUNDARY_TOP) != 0:
		_add_boundary_wall(generated_root, "TopBoundary", Vector2(wall_span.x, boundary_thickness), Vector2(map_size.x * 0.5, -boundary_thickness * 0.5))
	if (solid_boundary_sides & BOUNDARY_BOTTOM) != 0:
		_add_boundary_wall(generated_root, "BottomBoundary", Vector2(wall_span.x, boundary_thickness), Vector2(map_size.x * 0.5, map_size.y + boundary_thickness * 0.5))


func _add_boundary_wall(parent: Node, wall_name: String, shape_size: Vector2, wall_position: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.collision_layer = 1
	wall.collision_mask = 1
	parent.add_child(wall)
	wall.position = wall_position
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = shape_size
	collision.shape = rectangle
	wall.add_child(collision)
