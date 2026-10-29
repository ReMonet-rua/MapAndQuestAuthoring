@tool
extends TileMapLayer

@export var generate_showcase_layout := true


func _ready() -> void:
	if generate_showcase_layout and get_used_cells().is_empty():
		_build_showcase_layout()


func _build_showcase_layout() -> void:
	# Continuous tiled floor, with materials changing by exhibit section.
	for x in range(112):
		var floor_atlas_x := 0
		if x >= 28 and x < 56:
			floor_atlas_x = 2
		elif x >= 56 and x < 82:
			floor_atlas_x = 4
		elif x >= 82:
			floor_atlas_x = 7
		set_cell(Vector2i(x, 26), 0, Vector2i(floor_atlas_x, 0))
		set_cell(Vector2i(x, 27), 0, Vector2i(7, 0))
		set_cell(Vector2i(x, 28), 0, Vector2i(2, 0))

	# One-way tile ledges are reachable with the player's double jump.
	for x in range(10, 17):
		set_cell(Vector2i(x, 22), 0, Vector2i(1, 0))
	for x in range(27, 34):
		set_cell(Vector2i(x, 21), 0, Vector2i(1, 0))
	for x in range(50, 57):
		set_cell(Vector2i(x, 23), 0, Vector2i(1, 0))
	for x in range(72, 79):
		set_cell(Vector2i(x, 21), 0, Vector2i(1, 0))
	for x in range(93, 100):
		set_cell(Vector2i(x, 22), 0, Vector2i(1, 0))

	# A reachable swatch row demonstrates all eight placeholder terrain tiles.
	for atlas_x in range(8):
		set_cell(Vector2i(5 + atlas_x, 17), 0, Vector2i(atlas_x, 0))

