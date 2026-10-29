@tool
extends Node2D
class_name LevelAuthoringEntity

@export var entity_id := ""
@export_enum("npc", "enemy", "item", "prop", "trigger", "portal", "platform") var entity_type := "prop"
@export var display_name := ""
@export var tags: PackedStringArray = []
@export_file("*.csv") var dialogue_file := ""


func _ready() -> void:
	if display_name.is_empty():
		display_name = name
