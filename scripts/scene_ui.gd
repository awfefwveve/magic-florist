extends RefCounted
var g: Control
func _init(game:Control) -> void:g=game
func at(node:Control,r:Rect2,parent:Node=null) -> Control:
	(parent if parent!=null else g.body).add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	node.anchor_left=r.position.x;node.anchor_top=r.position.y
	node.anchor_right=r.end.x;node.anchor_bottom=r.end.y
	node.offset_left=0;node.offset_top=0;node.offset_right=0;node.offset_bottom=0
	return node
func text(value:String,r:Rect2,px:int=22,parent:Node=null) -> Label:
	var l=g.paragraph(value,px)
	at(l,r,parent)
	return l
func btn(value:String,action:Callable,r:Rect2,id:String="",primary:bool=false) -> Button:
	var b:Button=g.button(value,action,primary)
	b.add_theme_font_size_override("font_size",20)
	if id!="":b.name=id
	at(b,r)
	return b
func object(value:String,asset:String,action:Callable,r:Rect2,id:String,selected:bool=false) -> Button:
	var b=btn("",action,r,id)
	var style=g.panel_style(Color(1,1,1,.16) if selected else Color(1,1,1,0),8)
	if selected:style.border_color=Color("FFF1A8");style.set_border_width_all(3)
	b.add_theme_stylebox_override("normal",style)
	b.add_theme_stylebox_override("disabled",g.panel_style(Color(0,0,0,0),8))
	b.tooltip_text=value
	if asset!="":at(g.picture(asset,Vector2.ZERO),Rect2(.08,0,.84,.72),b)
	var l=text(value,Rect2(0,.72,1,.28),18,b)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color",Color.WHITE)
	return b
func build() -> void:
	g.body=Control.new();g.body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);g.add_child(g.body)
	var bg=preload("res://scripts/scene_canvas.gd").new()
	bg.room=g.room;bg.state=g.state
	at(bg,Rect2(0,0,1,1))
	if g.room=="shop":counter()
	elif g.room=="atelier":atelier()
	else:garden()
	var bookmark=btn("주문서",g._show_order,Rect2(0,.025,.068,.092),"OrderBookmark")
	bookmark.add_theme_stylebox_override("normal",g.panel_style(Color("FF562F"),0))
	bookmark.add_theme_color_override("font_color",Color.WHITE)
	bookmark.add_theme_stylebox_override("disabled",g.panel_style(Color("C9482D"),0))
	bookmark.add_theme_color_override("font_disabled_color",Color("F6D8CE"))
	bookmark.disabled=g.state.d.phase!="order"
	g.gold_label=text("",Rect2(.76,.012,.17,.062),28)
	g.gold_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	btn("⚙",g.menus.open.bind("settings"),Rect2(.944,.012,.045,.064),"Settings")
	g.pause_button=btn("▶" if g.state.paused else "Ⅱ",g._toggle_pause,Rect2(.704,.015,.04,.061),"Pause")
	g.clock_label=text("",Rect2(.012,.965,.18,.032),16)
	g.patience_label=text("",Rect2(.19,.965,.79,.032),16)
	g.patience_label.clip_text=true
	g.toast=text(g.state.last_message,Rect2(.26,.947,.69,.026),16)
	g.toast.clip_text=true
	g.toast.add_theme_color_override("font_color",Color("FFF3DD"))
	if g.room!="shop":object("조합법 책","ui.book",g._show_book,Rect2(.86,.785,.13,.15),"Book")
	if g.state.paused and not is_instance_valid(g.popup):
		btn("일시정지 · 계속하기",g._toggle_pause,Rect2(.35,.42,.30,.12),"Resume",true)
func arrow(right:bool,target:String) -> void:
	var b=btn("▶" if right else "◀",g._switch_room.bind(target),Rect2(.954 if right else .009,.43,.035,.11),"Nav_"+target)
	b.add_theme_font_size_override("font_size",35)
	var empty:=StyleBoxEmpty.new()
	for style_name in ["normal","disabled","hover","pressed"]:b.add_theme_stylebox_override(style_name,empty)
	b.add_theme_color_override("font_color",Color.BLACK)
	b.disabled=target=="atelier" and g.state.d.phase!="order"
func counter() -> void:
	arrow(false,"garden");arrow(true,"atelier")
	object("DAY %d"%g.state.d.day,"ui.calendar",g.menus.open.bind("news"),Rect2(.014,.718,.10,.15),"Calendar")
	var action:Callable=g.state.start_day if g.state.d.phase=="ready" else (g.state.next_day if g.state.d.phase=="closed" else g._confirm_close)
	var clock_object=object("영업 시작" if g.state.d.phase=="ready" else ("다음 날" if g.state.d.phase=="closed" else "영업 마치기"),"ui.clock",action,Rect2(.12,.70,.10,.17),"Clock")
	var clock_entry:Dictionary=g.state.d.equipped.clock
	if clock_entry.id!="clock_basic" or clock_entry.color!=0:
		var clock_art:TextureRect=clock_object.get_child(0);clock_art.texture=g.state.content.texture(g.state.world.decor[clock_entry.id].asset);clock_art.modulate=Color(g.state.world.decor[clock_entry.id].colors[clock_entry.color])
	object("조합법 책","ui.book",g._show_book,Rect2(.64,.715,.16,.18),"Book")
	object("상점","ui.scroll",g.menus.open.bind("store"),Rect2(.86,.72,.12,.17),"Store")
	if g.state.d.merchant.kind!="":
		var h=g.row(15);at(h,Rect2(.14,.15,.72,.52));g.menus.merchant_panel(h);return
	var phase:String=g.state.d.phase
	if phase in ["talk","order","result"]:
		at(g.picture(g.state.customer().asset,Vector2.ZERO),Rect2(.20,.30,.25,.42))
		var speech:String=g.state.d.result.reply if phase=="result" else str(g.state.customer().lines[int(g.state.d.question)])
		var bubble=PanelContainer.new();bubble.name="SpeechBubble";var bubble_style=g.panel_style(Color.WHITE,15);bubble_style.border_color=Color("252525");bubble_style.set_border_width_all(3);bubble.add_theme_stylebox_override("panel",bubble_style);at(bubble,Rect2(.36,.14,.34,.23))
		var v=g.column(7);bubble.add_child(v);v.add_child(g.label(g.state.customer().name,20));v.add_child(g.paragraph(speech,23))
		if phase=="talk":
			if g.state.d.question<5:btn("뭐라고? 다시 말해 줄래?",g.state.ask,Rect2(.60,.43,.25,.087),"Ask")
			btn("알겠어. · 주문 수락",g.state.accept_order,Rect2(.60,.55,.25,.087),"Accept")
		elif phase=="result":
			var l=text("+%d G"%g.state.d.result.paid,Rect2(.78,.085,.15,.06),28);l.add_theme_color_override("font_color",Color("487F32"))
			btn("고마워요 · 손님 배웅",g.state.continue_service,Rect2(.61,.49,.26,.09),"Farewell")
		elif g.state.d.craft.step=="complete":
			var view=g.Board.new();view.state=g.state;view.read_only=true;view.custom_minimum_size=Vector2.ZERO;at(view,Rect2(.46,.39,.40,.30))
			btn("꽃 장식 전달하기",g.state.deliver,Rect2(.60,.60,.25,.08),"Deliver",true)
		else:btn("제작대로 이동 →",g._switch_room.bind("atelier"),Rect2(.60,.51,.25,.09),"Craft")
	else:
		var message:String="시계를 눌러 꽃집을 열어 주세요." if phase=="ready" else ("오늘 판매 %d건 · 매출 %d G\n시계를 눌러 다음 날을 준비하세요."%[g.state.d.sold,g.state.d.earned] if phase=="closed" else "다음 손님이 오고 있어요.")
		text(message,Rect2(.36,.22,.35,.18),26)
func atelier() -> void:
	arrow(false,"shop")
	var undo=btn("↶",g.state.reset_craft,Rect2(0,.14,.065,.084),"Undo");undo.add_theme_stylebox_override("normal",g.panel_style(Color("B6E9F8"),0));undo.add_theme_font_size_override("font_size",32)
	var shelf:=ScrollContainer.new();shelf.name="FlowerShelf";shelf.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;at(shelf,Rect2(.08,.11,.90,.23))
	var grid:=GridContainer.new();grid.columns=5;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;shelf.add_child(grid)
	for id in g.state.content.catalog.flowers:
		if not g.state.d.discovered.has(id):continue
		var flower:Dictionary=g.state.content.catalog.flowers[id]
		var source=g.FlowerSource.new();source.name="Flower_"+id;source.state=g.state;source.flower_id=id;source.picked.connect(g._begin_flower_drag)
		source.custom_minimum_size=Vector2(220,185);source.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		source.add_theme_stylebox_override("normal",g.panel_style(Color(0,0,0,0),0));source.add_theme_stylebox_override("disabled",g.panel_style(Color(0,0,0,0),0))
		source.disabled=g.state.d.inventory[id]<=0 or g.state.d.craft.step!="placing"
		grid.add_child(source);at(g.picture(flower.asset,Vector2.ZERO),Rect2(.13,0,.74,.78),source)
		var l=text(flower.name+" ×%d"%g.state.d.inventory[id],Rect2(0,.77,1,.20),19,source);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	g.board=g.Board.new();g.board.state=g.state;g.board.tool=g.tool;g.board.name="CraftBoard";g.board.tool_used.connect(func():g.tool="hand")
	at(g.board,Rect2(.145,.385,.70,.42))
	text(g._craft_hint(),Rect2(.15,.35,.70,.04),18).clip_text=true
	object("가위","prop.scissors",g._choose_tool.bind("scissors"),Rect2(.045,.36,.09,.13),"Tool_scissors",g.tool=="scissors")
	object("손 · 옮기기","ui.hand",g._choose_tool.bind("hand"),Rect2(.045,.52,.09,.12),"Tool_hand",g.tool=="hand")
	object("포장지","prop.paper",g.state.setup.bind("bouquet"),Rect2(.025,.80,.105,.14),"Paper").disabled=g.state.d.craft.kind!=""
	object("화분","prop.pot",g.state.setup.bind("pot"),Rect2(.15,.80,.105,.14),"Pot").disabled=g.state.d.craft.kind!="" or not g.state.pot_unlocked()
	for entry in [["wire","철사","prop.wire"],["ribbon","리본","prop.ribbon"],["soil","흙","prop.soil"]]:
		var x:float=.28+["wire","ribbon","soil"].find(entry[0])*.125
		object(entry[1],entry[2],g._choose_tool.bind(entry[0]),Rect2(x,.80,.105,.14),"Tool_"+entry[0],g.tool==entry[0])
func garden() -> void:
	arrow(true,"shop")
	for i in 12:
		var plot:Dictionary=g.state.d.plots[i]
		var r:=Rect2(.085+(i%4)*.215,.23+(i/4)*.18,.18,.115)
		var b=btn("",g._plot_action.bind(i),r,"Plot_"+str(i));b.add_theme_stylebox_override("normal",g.panel_style(Color("754B40"),2));b.add_theme_stylebox_override("disabled",g.panel_style(Color("754B40"),2));b.add_theme_color_override("font_color",Color.WHITE);b.add_theme_color_override("font_disabled_color",Color("EEEEEE"));b.add_theme_font_size_override("font_size",18)
		g.plot_buttons[i]=b
		if plot.flower!="":
			var ready:bool=plot.growth>=g.state.content.catalog.flowers[plot.flower].grow_seconds
			at(g.picture(g.state.content.catalog.flowers[plot.flower].asset if ready else "ui.sprout",Vector2.ZERO),Rect2(r.position.x+.045,r.position.y-.09,.09,.12))
	object("물 주기","ui.water",garden_tool.bind("water"),Rect2(.018,.79,.12,.16),"Water",g.garden_tool=="water")
	object("씨앗","ui.seeds",seed_picker,Rect2(.16,.79,.12,.16),"Seeds",g.garden_tool=="seed")
	object("비료 ×%d"%g.state.d.fertilizer,"ui.fertilizer",garden_tool.bind("fertilizer"),Rect2(.30,.79,.12,.16),"Fertilizer",g.garden_tool=="fertilizer")
	text("선택 씨앗: "+g.state.content.catalog.flowers[g.seed_id].name,Rect2(.45,.84,.33,.06),21)
func garden_tool(id:String) -> void:g.garden_tool=id;g._build()
func seed_picker() -> void:
	var dialog=g._dialog("심을 씨앗","");var v=g.column();dialog.add_child(v);v.position=Vector2(30,40);v.size=Vector2(650,360)
	for id in g.state.content.catalog.flowers:
		if not g.state.flower_unlocked(id):continue
		v.add_child(g.button(g.state.content.catalog.flowers[id].name+" ×%d"%g.state.d.seeds[id],func():g.seed_id=id;g.garden_tool="seed";g._dismiss_dialog()))
func order_drawer() -> void:
	var d=g._dialog("","");d.borderless=true;d.name="OrderDrawer";d.get_ok_button().hide();d.size=Vector2i(g.size.x*.31,g.size.y*.88);d.position=Vector2i(0,g.size.y*.02)
	var surface:=PanelContainer.new();surface.add_theme_stylebox_override("panel",g.panel_style(Color.WHITE,0));surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);d.add_child(surface)
	var v=g.column(18);surface.add_child(v)
	v.add_child(g.label(g.state.customer().name+"의 주문",28))
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(scroll)
	var lines=g.column(22);lines.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(lines)
	for i in int(g.state.d.question)+1:
		lines.add_child(g.paragraph(str(g.state.customer().lines[i]),20))
		if i<int(g.state.d.question):
			var reply=g.paragraph("조금 더 알려 줄래?",18);reply.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;lines.add_child(reply)
	var accepted=g.paragraph("알겠어.",18);accepted.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;lines.add_child(accepted)
	v.add_child(HSeparator.new());v.add_child(g.label("[인내심]  "+g.state.patience_name(),21))
	var bar=preload("res://scripts/patience_bar.gd").new();bar.ratio=g.state.patience_left()/(4.0*g.state.patience_step());v.add_child(bar)
	v.add_child(g.button("주문서 접기  ◀",g._dismiss_dialog))
