@tool
extends Marker2D
class_name LevelAuthoringEnemySpawn

@export var entity_type := "enemy_spawn"
@export var spawn_id := ""
@export var wave_id := ""
@export_file("*.tscn") var enemy_scene := ""
@export var facing_direction := Vector2.RIGHT


func spawn_enemy(parent: Node = null) -> Node:
	if parent == null:
		parent = get_parent()
	if enemy_scene.is_empty() or not ResourceLoader.exists(enemy_scene) or parent == null:
		return null
	var packed_scene := load(enemy_scene) as PackedScene
	if packed_scene == null:
		return null
	var enemy := packed_scene.instantiate()
	parent.add_child(enemy)
	if enemy is Node2D:
		enemy.global_position = global_position
		if facing_direction.x != 0.0:
			enemy.scale.x = absf(enemy.scale.x) * signf(facing_direction.x)
	return enemy
