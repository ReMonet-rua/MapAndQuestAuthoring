@tool
extends Area2D
class_name LevelAuthoringEncounter

signal encounter_started(encounter_id: String, encounter_type: String, wave_ids: PackedStringArray, body: Node2D)
signal encounter_completed(encounter_id: String)

@export var entity_type := "encounter"
@export var encounter_id := ""
@export_enum("waves", "ambush", "boss", "lockdown") var encounter_type := "waves":
	set(value):
		encounter_type = value
		_update_preview()
@export var wave_ids: PackedStringArray = []
@export var linked_barrier_paths: Array[NodePath] = []
@export var trigger_once := true
var _started := false


func _ready() -> void:
	_update_preview()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		activate(body)


func activate(body: Node2D = null) -> void:
	if _started and trigger_once:
		return
	_started = true
	_set_linked_barriers_open(false)
	encounter_started.emit(encounter_id, encounter_type, wave_ids, body)


func complete() -> void:
	if not _started:
		return
	_set_linked_barriers_open(true)
	encounter_completed.emit(encounter_id)
	if not trigger_once:
		_started = false


func _set_linked_barriers_open(open: bool) -> void:
	for barrier_path in linked_barrier_paths:
		var barrier := get_node_or_null(barrier_path)
		if barrier != null and barrier.has_method("set_open"):
			barrier.call("set_open", open)


func _update_preview() -> void:
	var label := get_node_or_null("Label") as Label
	if label == null:
		return
	match encounter_type:
		"ambush":
			label.text = "伏击遭遇区"
		"boss":
			label.text = "Boss 场地"
		"lockdown":
			label.text = "追猎封锁区"
		_:
			label.text = "遭遇区 / 波次"
