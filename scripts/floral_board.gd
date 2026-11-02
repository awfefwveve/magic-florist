extends Control
signal tool_used
var state: RefCounted
var tool: String = "hand"
var read_only: bool = false
var dragging: int = -1
var drag_point: Vector2
var scissors_down: bool = false
var previous: Vector2
var cut_indices: Array = []
var font: Font = preload("res://assets/fonts/NotoSansKR-Regular.otf")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	custom_minimum_size = Vector2.ZERO if read_only else Vector2(520, 300)

func drawing_scale() -> float:
	return minf(size.x / 820.0, size.y / 340.0)

func point(index: int) -> Vector2:
	if index == dragging: return drag_point
	var item: Dictionary = state.d.craft.items[index]
	if state.d.craft.kind == "pot":
		return Vector2(size.x * (0.45 + index * 0.10), size.y * 0.40)
	if state.d.craft.step in ["tied", "complete"]:
		return Vector2(size.x * 0.5 + (index - 2) * 26 * drawing_scale(), size.y * 0.35 + absf(index - 2) * 10 * drawing_scale())
	return Vector2(item.x, item.y) * size

func leaf_rect(index: int) -> Rect2:
	var scale_factor: float = drawing_scale()
	return Rect2(point(index) + Vector2(-30, 25) * scale_factor, Vector2(60, 52) * scale_factor)

func _draw() -> void:
	if state == null: return
	var craft: Dictionary = state.d.craft
	draw_style_box(_wood(), Rect2(Vector2.ZERO, size))
	for y in range(30, int(size.y), 62): draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.5, 0.36, 0.22, 0.10), 2)
	if craft.kind == "":
		draw_string(font, Vector2(32, 66), "먼저 포장지 또는 화분을 놓아 주세요", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("725E49"))
		return
	var factor: float = drawing_scale()
	if craft.kind == "bouquet":
		if craft.step != "complete":
			draw_texture_rect(state.content.texture("prop.paper"), Rect2(size * Vector2(0.06, 0.04), size * Vector2(0.88, 0.92)), false)
			if craft.step == "placing":
				for i in 24:
					var a: float = i * TAU / 24
					var b: float = a + TAU / 40
					draw_line((Vector2(0.5, 0.43) + Vector2(cos(a), sin(a)) * state.gather_radius()) * size, (Vector2(0.5, 0.43) + Vector2(cos(b), sin(b)) * state.gather_radius()) * size, Color(0.7,0.7,0.6,0.25), 2)
				draw_string(font, size * Vector2(0.20, 0.90), "철사 준비 완료 · 포장지 어디든 누르세요" if state.can_tie() else "꽃 5송이의 잎을 다듬고 서로 가까이 모으세요", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("38583C"))
		else:
			draw_texture_rect(state.content.texture("prop.wrap"), Rect2(size * Vector2(0.26,0.16), size * Vector2(0.49,0.79)), false)
	else:
		draw_texture_rect(state.content.texture("prop.pot"), Rect2(size * Vector2(0.5,0.59) - Vector2(125,125)*factor, Vector2(250,250)*factor), false)
		if craft.soil > 0:
			draw_ellipse_shape(size * Vector2(0.5,0.51), Vector2(82,19)*factor, Color("70513D"))
	for i in craft.items.size():
		var item: Dictionary = craft.items[i]
		var at: Vector2 = point(i)
		var texture: Texture2D = state.content.texture(state.content.catalog.flowers[item.id].asset)
		if item.trimmed:
			draw_line(at + Vector2(0,12)*factor, at + Vector2(0,77)*factor, Color("557C60"), 5*factor, true)
			draw_texture_rect_region(texture, Rect2(at + Vector2(-62,-46)*factor, Vector2(124,78)*factor), Rect2(16,0,224,141))
		else:
			draw_texture_rect(texture, Rect2(at + Vector2(-70,-46)*factor, Vector2(140,140)*factor), false)
		if tool == "scissors" and not item.trimmed and craft.kind == "bouquet" and not read_only:
			draw_rect(leaf_rect(i), Color(0.78,0.36,0.39,0.65), false, 2)
		if cut_indices.has(i): draw_circle(at, 13*factor, Color("86A77F"))
	if craft.kind == "bouquet" and craft.step in ["tied", "complete"]:
		draw_texture_rect(state.content.texture("prop.wire"), Rect2(size * Vector2(0.5,0.65)-Vector2(40,20)*factor, Vector2(80,44)*factor), false)
	if craft.step == "complete":
		draw_texture_rect(state.content.texture("prop.ribbon"), Rect2(size * Vector2(0.5,0.72)-Vector2(40,40)*factor, Vector2(80,80)*factor), false)
	if scissors_down:
		draw_texture_rect(state.content.texture("prop.scissors"), Rect2(previous-Vector2(22,22),Vector2(44,44)),false)

func draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = []
	for i in 32: points.append(center + Vector2(cos(i*TAU/32),sin(i*TAU/32))*radii)
	draw_colored_polygon(points,color)

func _wood() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("CBB08E")
	style.set_corner_radius_all(12)
	return style

func _gui_input(event: InputEvent) -> void:
	if read_only or state.paused or state.d.phase != "order": return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if tool == "scissors":
				scissors_down = true
				previous = event.position
				cut_indices.clear()
			elif tool == "hand" and state.d.craft.step == "placing":
				for i in range(state.d.craft.items.size()-1,-1,-1):
					if Rect2(point(i)-Vector2(48,48)*drawing_scale(),Vector2(96,142)*drawing_scale()).has_point(event.position):
						dragging = i
						drag_point = event.position
						break
			elif tool in ["wire", "ribbon", "soil"]:
				var target: Rect2 = Rect2(size * Vector2(0.06,0.04), size * Vector2(0.88,0.92))
				if target.has_point(event.position) and state.use_tool(tool): tool_used.emit()
		else:
			if scissors_down:
				scissors_down = false
				state.trim(cut_indices)
				cut_indices.clear()
			if dragging >= 0:
				var index: int = dragging
				dragging = -1
				state.move_flower(index,event.position/size)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion:
		if scissors_down:
			var distance: float = previous.distance_to(event.position)
			if distance >= 2:
				for i in state.d.craft.items.size():
					if state.d.craft.items[i].trimmed: continue
					var rect: Rect2 = leaf_rect(i)
					for step in range(int(distance/4)+2):
						var at: Vector2 = previous.lerp(event.position, float(step)/float(int(distance/4)+1))
						if rect.has_point(at) and not cut_indices.has(i): cut_indices.append(i)
			previous = event.position
			queue_redraw()
		elif dragging >= 0:
			drag_point = event.position
			queue_redraw()
