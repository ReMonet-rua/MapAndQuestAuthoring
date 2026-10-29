@tool
extends "res://addons/level_authoring/runtime/level_authoring_map.gd"

var _status_label: Label


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_status_label = get_node_or_null("HUD/InfoPanel/Status") as Label
	_connect_demo_signals()


func _connect_demo_signals() -> void:
	_connect_signal("TriggersLayer/MapTerminal", "station_activated", "_on_station_activated")
	_connect_signal("TriggersLayer/RechargeShrine", "station_activated", "_on_station_activated")
	_connect_signal("ItemsLayer/RewardCache", "chest_opened", "_on_chest_opened")
	_connect_signal("TriggersLayer/SwitchDemo", "state_changed", "_on_switch_changed")
	_connect_signal("ItemsLayer/CurrencyCache", "collected", "_on_pickup_collected")
	_connect_signal("ItemsLayer/DashAbility", "collected", "_on_pickup_collected")
	_connect_signal("TriggersLayer/EncounterDemo", "encounter_started", "_on_encounter_started")
	_connect_signal("TriggersLayer/BossArenaDemo", "encounter_started", "_on_encounter_started")
	_connect_signal("TriggersLayer/LockdownDemo", "encounter_started", "_on_encounter_started")


func _connect_signal(node_path: String, signal_name: String, method_name: String) -> void:
	var source := get_node_or_null(node_path)
	var callback := Callable(self, method_name)
	if source != null and source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _on_station_activated(station_id: String, station_type: String, region_id: String, _body: Node2D) -> void:
	var description := "地图终端" if station_type == "map_station" else "恢复点"
	_set_status("%s已响应：%s / 区域 %s（此处展示信号接口）" % [description, station_id, region_id])


func _on_chest_opened(chest_id: String, reward_type: String, reward_id: String, amount: int, _body: Node2D) -> void:
	_set_status("宝箱 %s：%s · %s ×%d（奖励接口已触发）" % [chest_id, reward_type, reward_id, amount])


func _on_switch_changed(mechanism_id: String, active: bool, _body: Node2D) -> void:
	_set_status("机关 %s：%s；关联门已%s" % [mechanism_id, "开启" if active else "关闭", "打开" if active else "关闭"])


func _on_pickup_collected(pickup_id: String, pickup_type: String, amount: int, _body: Node2D) -> void:
	_set_status("拾取 %s：%s ×%d（收集信号已触发）" % [pickup_id, pickup_type, amount])


func _on_encounter_started(encounter_id: String, encounter_type: String, _wave_ids: PackedStringArray, _body: Node2D) -> void:
	_set_status("遭遇触发：%s（%s）" % [encounter_id, encounter_type])


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
