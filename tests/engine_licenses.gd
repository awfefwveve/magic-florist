extends SceneTree

func _initialize() -> void:
	var text: String = "Godot Engine 4.7.2\nhttps://godotengine.org/license/\n\n" + Engine.get_license_text() + "\n\nTHIRD-PARTY LICENSES\n\n"
	var info: Dictionary = Engine.get_license_info()
	for title in info:
		text += str(title) + "\n" + str(info[title]) + "\n\n"
	text += "COPYRIGHT ATTRIBUTIONS\n\n" + JSON.stringify(Engine.get_copyright_info(), "  ")
	FileAccess.open("res://docs/GODOT_LICENSES.txt", FileAccess.WRITE).store_string(text)
	quit()
