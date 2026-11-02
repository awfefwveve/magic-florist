extends Button
signal picked(id: String)
var flower_id: String
var state: RefCounted

func _gui_input(event: InputEvent) -> void:
	if disabled or state.paused: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		picked.emit(flower_id)
		accept_event()
