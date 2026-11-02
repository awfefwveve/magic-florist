extends Control
var room: String
var state: RefCounted
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func box(r:Rect2,c:Color) -> void:draw_rect(Rect2(r.position*size,r.size*size),c)
func _draw() -> void:
	box(Rect2(0,0,1,1),Color("AD794C"))
	box(Rect2(0,0,1,.18 if room=="garden" else .10),Color("CCCCCC"))
	if room=="shop":
		var wall:Dictionary=state.d.equipped.wall
		box(Rect2(0,0,1,.72),Color("CCCCCC") if wall.id=="wall_basic" and wall.color==0 else Color(state.world.decor[wall.id].colors[wall.color]))
		draw_colored_polygon(PackedVector2Array([Vector2(0,.72)*size,Vector2(.2,.49)*size,Vector2(.82,.49)*size,Vector2(1,.72)*size]),Color("EEEEEE") if state.d.equipped.floor.id=="floor_basic" and state.d.equipped.floor.color==0 else Color(state.world.decor[state.d.equipped.floor.id].colors[state.d.equipped.floor.color]))
		box(Rect2(.33,0,.35,.55),Color("606060"))
		box(Rect2(.345,.03,.147,.49),Color("FAFAF6"))
		box(Rect2(.507,.03,.157,.49),Color("FAFAF6"))
		box(Rect2(.465,.21,.01,.13),Color("606060"))
		box(Rect2(.525,.21,.01,.13),Color("606060"))
		for x in [.19,.82]:draw_line(Vector2(x,0)*size,Vector2(x,.49)*size,Color("777777"),3)
		box(Rect2(0,.72,1,.20),Color("AD794C"))
		box(Rect2(0,.92,1,.08),Color("825A38"))
		box(Rect2(0,.72,.23,.18),Color("E58DA6"))
		# Optional owned decorations occupy wall/background slots, leaving counter controls fixed.
		for slot in ["frame","planter","chair"]:
			var entry:Dictionary=state.d.equipped[slot]
			var item:Dictionary=state.world.decor[entry.id]
			var r:Rect2={"frame":Rect2(.76,.15,.12,.18),"planter":Rect2(.70,.40,.15,.24),"chair":Rect2(.12,.47,.12,.23)}[slot]
			draw_texture_rect(state.content.texture(item.asset),Rect2(r.position*size,r.size*size),false,Color(item.colors[int(entry.color)]))
	elif room=="atelier":
		box(Rect2(.07,.11,.91,.24),Color("AAA6A3"))
		box(Rect2(.08,.30,.89,.045),Color("777473"))
		box(Rect2(0,.89,1,.11),Color("825A38"))
	else:
		box(Rect2(0,.90,1,.10),Color("825A38"))
