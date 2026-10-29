@tool
extends RefCounted


static func ensure_directory(resource_path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if DirAccess.dir_exists_absolute(absolute_path):
		return true
	return DirAccess.make_dir_recursive_absolute(absolute_path) == OK
