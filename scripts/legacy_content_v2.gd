extends RefCounted

var catalog: Dictionary
var assets: Dictionary
var textures: Dictionary = {}

func _init() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_catalog_v2.json"))
	assets = JSON.parse_string(FileAccess.get_file_as_string("res://data/assets.json"))["assets"]

func texture(id: String) -> Texture2D:
	if not textures.has(id):
		if not assets.has(id):
			push_error("Unknown asset ID: " + id)
			return null
		textures[id] = load(str(assets[id]["path"])) as Texture2D
	return textures[id]
