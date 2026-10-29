extends SceneTree

const ATLAS_PATH := "res://addons/level_authoring/assets/terrain_placeholder_atlas.svg"
const TILESET_PATH := "res://addons/level_authoring/resources/terrain_placeholder_tileset.tres"
const TILE_SIZE := Vector2i(32, 32)
const TILE_COUNT := 8


func _initialize() -> void:
	call_deferred("_generate")


func _generate() -> void:
	var atlas_texture := ResourceLoader.load(ATLAS_PATH) as Texture2D
	if atlas_texture == null:
		push_error("Unable to load placeholder tile atlas: %s" % ATLAS_PATH)
		quit(1)
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.resource_name = "占位地形"
	atlas_source.texture = atlas_texture
	atlas_source.texture_region_size = TILE_SIZE
	for tile_x in range(TILE_COUNT):
		atlas_source.create_tile(Vector2i(tile_x, 0))

	var source_id := tile_set.add_source(atlas_source, 0)
	if source_id < 0:
		push_error("Unable to add placeholder atlas source to TileSet.")
		quit(1)
		return

	_set_solid_collision(atlas_source.get_tile_data(Vector2i(0, 0), 0))
	_set_one_way_collision(atlas_source.get_tile_data(Vector2i(1, 0), 0))
	_set_solid_collision(atlas_source.get_tile_data(Vector2i(2, 0), 0))
	_set_solid_collision(atlas_source.get_tile_data(Vector2i(4, 0), 0))
	_set_polygon_collision(atlas_source.get_tile_data(Vector2i(5, 0), 0), PackedVector2Array([
		Vector2(-16.0, 16.0),
		Vector2(16.0, -16.0),
		Vector2(16.0, 16.0),
	]))
	_set_polygon_collision(atlas_source.get_tile_data(Vector2i(6, 0), 0), PackedVector2Array([
		Vector2(-16.0, -16.0),
		Vector2(16.0, 16.0),
		Vector2(-16.0, 16.0),
	]))
	_set_solid_collision(atlas_source.get_tile_data(Vector2i(7, 0), 0))

	var save_error := ResourceSaver.save(tile_set, TILESET_PATH)
	if save_error != OK:
		push_error("Unable to save placeholder TileSet: %s" % save_error)
		quit(1)
		return

	print("Created placeholder TileSet at %s" % TILESET_PATH)
	quit()


func _set_solid_collision(tile_data: TileData) -> void:
	_set_polygon_collision(tile_data, PackedVector2Array([
		Vector2(-16.0, -16.0),
		Vector2(16.0, -16.0),
		Vector2(16.0, 16.0),
		Vector2(-16.0, 16.0),
	]))


func _set_polygon_collision(tile_data: TileData, points: PackedVector2Array) -> void:
	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_points(0, 0, points)


func _set_one_way_collision(tile_data: TileData) -> void:
	_set_polygon_collision(tile_data, PackedVector2Array([
		Vector2(-16.0, -16.0),
		Vector2(16.0, -16.0),
		Vector2(16.0, -10.0),
		Vector2(-16.0, -10.0),
	]))
	tile_data.set_collision_polygon_one_way(0, 0, true)
	tile_data.set_collision_polygon_one_way_margin(0, 0, 4.0)
