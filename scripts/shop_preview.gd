extends Control
var state: RefCounted

func _ready() -> void:
	custom_minimum_size=Vector2(280,250)
	resized.connect(queue_redraw)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if state==null:return
	var area:=Vector2(minf(size.x,size.y*1.6),minf(size.y,size.x/1.6))
	var origin:Vector2=(size-area)*.5
	var positions: Dictionary={"wall":Rect2(0,0,1,.76),"floor":Rect2(0,.76,1,.24),"chair":Rect2(.05,.49,.23,.36),"planter":Rect2(.65,.42,.28,.38),"frame":Rect2(.78,.10,.18,.20),"clock":Rect2(.08,.12,.19,.22)}
	for slot in positions:
		var entry: Dictionary=state.d.equipped[slot]
		var item: Dictionary=state.world.decor[entry.id]
		var rect: Rect2=positions[slot]
		draw_texture_rect(state.content.texture(item.asset),Rect2(origin+rect.position*area,rect.size*area),false,Color(item.colors[int(entry.color)]))
	draw_rect(Rect2(origin+area*Vector2(.30,.19),area*Vector2(.38,.33)),Color("f7f5ed"))
	draw_line(origin+area*Vector2(.49,.19),origin+area*Vector2(.49,.52),Color("a8b49f"),4)
	draw_line(origin+area*Vector2(.30,.35),origin+area*Vector2(.68,.35),Color("a8b49f"),4)
