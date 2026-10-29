@tool
extends AnimatableBody2D
class_name LevelAuthoringMovingPlatform

@export var entity_type := "platform"
@export var display_name := "移动平台"
@export var travel_offset := Vector2(192.0, 0.0)
@export_range(1.0, 600.0, 1.0) var speed := 80.0
@export_range(0.0, 10.0, 0.1) var pause_at_ends := 0.5

var _start_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _moving_to_end := true
var _pause_remaining := 0.0


func _ready() -> void:
	_start_position = global_position
	_target_position = _start_position + travel_offset


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or travel_offset.is_zero_approx():
		return
	if _pause_remaining > 0.0:
		_pause_remaining = maxf(_pause_remaining - delta, 0.0)
		return
	var target := _target_position if _moving_to_end else _start_position
	global_position = global_position.move_toward(target, speed * delta)
	if global_position.distance_squared_to(target) <= 0.25:
		global_position = target
		_moving_to_end = not _moving_to_end
		_pause_remaining = pause_at_ends
