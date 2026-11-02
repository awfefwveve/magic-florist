extends RefCounted
var catalog: Dictionary
func _init() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_catalog_v1.json"))
