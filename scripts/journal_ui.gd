extends RefCounted
const Preview = preload("res://scripts/shop_preview.gd")
var game: Control
var tab: String="recipes"
var page: int=0
var quantity: int=1
var category: String="wall"
var selected_colors: Dictionary={}

func _init(root: Control) -> void:
	game=root

func turn_page(delta:int) -> void:
	page=maxi(0,page+delta)
	open(tab,true)

func open(target: String="recipes",keep_page:bool=false) -> void:
	if not keep_page:page=0
	tab=target
	var resume:bool=game.popup_resume if is_instance_valid(game.popup) else game.state.paused
	if is_instance_valid(game.popup):game.popup.hide();game.popup.queue_free();game.popup=null
	var dialog:AcceptDialog=game._dialog("","")
	game.popup_resume=resume
	dialog.name="JournalWindow";dialog.borderless=true
	dialog.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	dialog.get_ok_button().hide()
	dialog.popup_centered(Vector2i(game.size.x*.88,game.size.y*.86))
	var sheet:=Control.new();dialog.add_child(sheet)
	var ui=preload("res://scripts/scene_ui.gd").new(game)
	var paper:=ColorRect.new();paper.color=Color("FFFEF8");paper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.at(paper,Rect2(.085,0,.915,1),sheet)
	var crease:=ColorRect.new();crease.color=Color("E3E0D5");crease.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.at(crease,Rect2(.538,.035,.007,.87),sheet)
	var entries:Array=[["flowers","✿ 꽃"],["recipes","꽃다발"],["pots","화분"],["decor","집"],["regulars","★ 단골"]]
	for i in entries.size():
		var entry:Array=entries[i]
		var choose:Button=game.button(entry[1],open.bind(entry[0]),tab==entry[0])
		choose.name="Tab_"+entry[0];choose.add_theme_font_size_override("font_size",18)
		choose.add_theme_stylebox_override("normal",game.panel_style([Color("FF603D"),Color("25ADDF"),Color("25ADDF"),Color("F5BF41"),Color("84AB47")][i],0))
		choose.disabled=not game.state.d.tutorial_done
		ui.at(choose,Rect2(0,.07+i*.115,.088,.095),sheet)
	var close:Button=game.button("×",func():
		if tab=="tutorial":game.state.finish_tutorial()
		game._dismiss_dialog())
	close.name="BookClose";close.add_theme_font_size_override("font_size",32)
	ui.at(close,Rect2(.947,.012,.045,.076),sheet)
	var title:Label=game.label({"flowers":"마법 꽃","recipes":"꽃다발 조합법","pots":"화분 조합법","regulars":"단골 손님","decor":"인테리어","store":"상점","news":"꽃집 소식","settings":"설정","tutorial":"부모님의 꽃집 안내","ending":"계승 편지"}.get(tab,tab),22)
	ui.at(title,Rect2(.12,.016,.70,.048),sheet)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.at(scroll,Rect2(.11,.09,.86,.78),sheet)
	var content=game.column(12);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	match tab:
		"recipes","pots":recipes(content)
		"flowers":flowers(content)
		"regulars":regulars(content)
		"store":shop(content)
		"decor":decor(content)
		"news":news(content)
		"settings":settings(content)
		"tutorial":tutorial(content)
		"ending":ending(content)
	var previous:Button=game.button("←",turn_page.bind(-1));previous.disabled=page==0;previous.name="PreviousPage"
	ui.at(previous,Rect2(.105,.91,.08,.075),sheet)
	var next:Button=game.button("→",turn_page.bind(1));next.disabled=tab!="regulars" or (page+1)*4>=game.state.world.npcs.size();next.name="NextPage"
	ui.at(next,Rect2(.89,.91,.08,.075),sheet)
	var pages:Label=game.label("%d / %d"%[page+1,ceili(game.state.world.npcs.size()/4.0) if tab=="regulars" else 1],18)
	ui.at(pages,Rect2(.50,.92,.10,.05),sheet)
	if tab in ["settings","decor","store","news"]:
		for i in 3:
			var name:String=["store","decor","news"][i]
			ui.at(game.button(["상점","꾸미기","소식"][i],open.bind(name)),Rect2(.23+i*.20,.90,.18,.08),sheet)
	if tab=="ending":game.state.view_ending()

func act(action: Callable) -> void:
	game.state.paused=false
	action.call()
	game.state.paused=true
	open(tab)

func panel(parent: Control,title: String) -> VBoxContainer:
	var box: VBoxContainer=game.card(parent,Color("FFFEF8"))
	var style=game.panel_style(Color("FFFEF8"),0);style.set_border_width_all(2);style.border_color=Color("494949");style.content_margin_left=14;style.content_margin_right=14
	box.get_parent().add_theme_stylebox_override("panel",style)
	box.get_parent().size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	box.add_child(game.label(title,24))
	return box

func action_button(parent: Control,text: String,action: Callable,enabled: bool=true) -> Button:
	var item: Button=game.button(text,act.bind(action),true)
	item.disabled=not enabled
	item.custom_minimum_size.y=46
	parent.add_child(item)
	return item

func recipes(parent: Control) -> void:
	for id in game.state.content.catalog.recipes:
		var info: Dictionary=game.state.content.catalog.recipes[id]
		if (tab=="pots") != (info.kind=="pot"):continue
		var known: bool=game.state.d.known_recipes.has(id)
		var card:=panel(parent,info.name if known else "잠긴 조합법")
		if not known:
			card.add_child(game.paragraph("새로운 꽃을 수확해 발견하세요."+(" 화분은 첫 판매 후 2일차에 열립니다." if info.kind=="pot" else ""),20))
			continue
		var line=game.row()
		card.add_child(line)
		for flower in info.flowers:
			var icon=game.picture(game.state.content.catalog.flowers[flower].asset,Vector2(58,58))
			icon.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
			line.add_child(icon)
			line.add_child(game.label("×%d"%info.flowers[flower],20))
		card.add_child(game.paragraph(game.state.recipe_text(id),22))
		var count: int=game.state.d.mastery[id]
		card.add_child(game.label("%s · 기본 %d G · 판매 숙련 %d / 10"%["꽃다발" if info.kind=="bouquet" else "화분",info.price,mini(count,10)],20))
		if game.state.d.claimed[id]:card.add_child(game.label("✓ 숙련 완료 · 보상 수령",22,game.SAGE))
		else:action_button(card,"숙련 보상 받기 · 100 G",game.state.claim.bind(id),count>=10)
	if game.state.d.ending_unlocked:parent.add_child(game.button("부모님의 계승 편지",open.bind("ending"),true))

func flowers(parent:Control) -> void:
	var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",28);grid.add_theme_constant_override("v_separation",12);parent.add_child(grid)
	for id in game.state.content.catalog.flowers:
		var info:Dictionary=game.state.content.catalog.flowers[id]
		var known:bool=game.state.d.discovered.has(id)
		var box=panel(grid,info.name if known else "???")
		box.get_parent().custom_minimum_size=Vector2(0,265)
		var line=game.row(12);box.add_child(line)
		if known:
			var image=game.picture(info.asset,Vector2(120,115));image.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;line.add_child(image)
			var facts=game.column(5);facts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(facts)
			facts.add_child(game.paragraph("#"+info.meaning.replace(" · "," #"),19))
			facts.add_child(game.paragraph("성장: %d분\n수확: %d~%d송이"%[info.grow_seconds/60,info.harvest_min,info.harvest_max],18))
			box.add_child(game.paragraph({"freesia":"응원하는 마음과 열정, 행복을 전하는 붉은 꽃입니다.","lovemis":"사랑하는 마음과 행복을 전하는 분홍빛 꽃입니다.","yellow":"성실함과 우정을 전하는 노란 꽃입니다.","redflora":"깊은 사랑을 담아 전하는 붉은 꽃입니다."}[id],19))
		else:box.add_child(game.paragraph("아직 발견하지 못한 꽃입니다.\n씨앗을 심고 첫 수확을 해 보세요.",20))

func regulars(parent:Control) -> void:
	var line=game.row(16);parent.add_child(line)
	for index in range(page*4,mini((page+1)*4,game.state.world.npcs.size())):
		var npc:Dictionary=game.state.world.npcs[index]
		var visible:bool=game.state.d.met_npcs.has(npc.id) or game.state.d.relationships[npc.id]>0
		var box=panel(line,npc.name if visible else "???")
		box.get_parent().custom_minimum_size=Vector2(0,520)
		if not visible:
			box.add_child(game.label("?",76));box.add_child(game.paragraph("아직 만나지 못한 손님",19));continue
		var portrait=game.picture(npc.asset,Vector2(0,170));portrait.size_flags_vertical=Control.SIZE_SHRINK_CENTER;box.add_child(portrait)
		box.add_child(game.paragraph(npc.description+"\n단골 주문 시 +%d%% 추가 골드"%roundi(npc.bonus*100),18))
		if game.state.regular(npc.id):
			box.add_child(game.paragraph("[취향]\n"+game.state.content.catalog.recipes[npc.preference].name,19))
			box.add_child(game.picture("prop.bouquet",Vector2(90,90)))
		else:box.add_child(game.paragraph("[단골 조건]\n인내심 좋음 상태로\n주문에 맞게 판매\n(%d / %d)"%[mini(game.state.d.relationships[npc.id],npc.goal),npc.goal],18))

func shop(parent: Control) -> void:
	var quantity_row=game.row()
	parent.add_child(quantity_row)
	quantity_row.add_child(game.label("씨앗 구매 수량",22))
	var amount:=SpinBox.new()
	amount.min_value=1;amount.max_value=99;amount.step=1;amount.value=quantity
	amount.custom_minimum_size=Vector2(180,48)
	amount.value_changed.connect(func(v:float):quantity=int(v);call_deferred("open","store"))
	quantity_row.add_child(amount)
	for id in game.state.content.catalog.flowers:
		var info: Dictionary=game.state.content.catalog.flowers[id]
		var available: bool=game.state.flower_unlocked(id)
		var card:=panel(parent,info.name+" 씨앗")
		card.add_child(game.paragraph("%d일차 해금 · 보유 %d · 성장 %d분"%[game.state.world.flower_days[id],game.state.d.seeds[id],info.grow_seconds/60],19))
		action_button(card,"%d개 구입 · %d G"%[quantity,info.seed_cost*quantity],game.state.buy_seed_pack.bind(id,quantity),available and game.state.d.gold>=info.seed_cost*quantity and game.state.d.seeds[id]+quantity<=9999).name="BuySeed_"+id
	var fertilizer:=panel(parent,"비료")
	fertilizer.add_child(game.paragraph("밭에 사용하면 해당 꽃의 성장 속도 1.5배. 보유 %d개"%game.state.d.fertilizer,20))
	action_button(fertilizer,"비료 구입 · 12 G",game.state.buy_fertilizer,game.state.d.gold>=12 and game.state.d.fertilizer<9999)
	for id in game.state.world.decor:
		var item: Dictionary=game.state.world.decor[id]
		if item.cost==0:continue
		var card:=panel(parent,item.name)
		card.add_child(game.paragraph(effect_text(item)+" · %d일차 해금"%item.unlock_day,20))
		if game.state.d.owned.has(id):card.add_child(game.label("구매 완료 · 인테리어에서 장착",20,game.SAGE))
		else:action_button(card,"인테리어 구입 · %d G"%item.cost,game.state.buy_decor.bind(id),game.state.d.day>=item.unlock_day and game.state.d.gold>=item.cost).name="BuyDecor_"+id
	if game.state.relief_available():action_button(parent,"부모님께 재시작 씨앗 부탁하기",game.state.request_relief)

func effect_text(item: Dictionary) -> String:
	if item.value==0:return "기본 장식 · 추가 효과 없음"
	return {"patience":"손님 인내심","regular":"단골 방문 확률","day":"하루 영업 시간"}[item.effect]+" +%.1f%%"%(item.value*100)

func decor(parent: Control) -> void:
	var preview:=Preview.new()
	preview.state=game.state
	preview.custom_minimum_size=Vector2(650,270)
	parent.add_child(preview)
	parent.add_child(game.paragraph("장착 효과: 인내심 +%.1f%% · 단골 방문 +%.0f%%p · 영업 시간 +%.0f%%"%[game.state.decor_bonus("patience")*100,game.state.decor_bonus("regular")*100,game.state.decor_bonus("day")*100],20))
	var categories=game.row(6)
	parent.add_child(categories)
	for entry in [["wall","벽지"],["floor","바닥"],["chair","의자"],["planter","화분"],["frame","액자"],["clock","시계"]]:
		categories.add_child(game.button(entry[1],func():category=entry[0];open("decor"),category==entry[0]))
	for id in game.state.d.owned:
		var item: Dictionary=game.state.world.decor[id]
		if item.slot!=category:continue
		var card:=panel(parent,item.name)
		var color_index: int=int(selected_colors.get(id,game.state.d.equipped[item.slot].color if game.state.d.equipped[item.slot].id==id else 0))
		var pic=game.picture(item.asset,Vector2(110,110))
		pic.modulate=Color(item.colors[color_index]);card.add_child(pic)
		card.add_child(game.paragraph(effect_text(item),20))
		var colors=game.row()
		card.add_child(colors)
		for i in item.colors.size():
			var choice=game.button(("● " if i==color_index else "○ ")+["세이지","살구","하늘"][i],func():selected_colors[id]=i;open("decor"),i==color_index)
			choice.name="Color_"+id+"_"+str(i)
			colors.add_child(choice)
		var current: Dictionary=game.state.d.equipped[item.slot]
		var same: bool=current.id==id and current.color==color_index
		action_button(card,"사용 중" if same else "이 색으로 사용하기",game.state.equip.bind(id,color_index),not same).name="Equip_"+id

func news(parent: Control) -> void:
	var card:=panel(parent,"꽃집 성장 기록")
	card.add_child(game.paragraph("첫 판매 %s · 첫 수확 %s · 화분 판매 %s\n발견한 꽃 %d/4 · 조합법 %d/3 · 숙련 완료 %d/3"%["완료" if game.state.d.total_sales>0 else "진행 중","완료" if game.state.d.harvests>0 else "진행 중","완료" if game.state.d.pots_sold>0 else "진행 중",game.state.d.discovered.size(),game.state.d.known_recipes.size(),game.state.d.claimed.values().filter(func(v):return v).size()],22))
	if game.state.d.ending_unlocked:card.add_child(game.button("부모님의 계승 편지 읽기",open.bind("ending"),true))
	else:card.add_child(game.paragraph("모든 조합을 10번씩 판매하고 숙련 보상을 받으면 꽃집을 물려받습니다.",20))
	if not game.state.d.information.is_empty():
		var info: Dictionary=game.state.d.information
		var event:=panel(parent,info.name)
		event.add_child(game.paragraph("%d~%d일차 · %s\n%s"%[info.start,info.end,"진행 중" if not game.state.active_event().is_empty() else "D-%d"%(info.start-game.state.d.day),info.description],22))
	else:parent.add_child(game.paragraph("리아에게 소식을 사면 축제·기념일·유행 일정을 미리 알 수 있어요.",20))
	parent.add_child(game.paragraph("렌의 성장 물약: 남은 활동 시간 %d초\n제작 부적 (꽃 모으기 범위 +50%%): %s"%[ceili(game.state.d.potion_left),"%d일차까지"%game.state.d.charm_until if game.state.d.charm_until>=game.state.d.day else "없음"],20))
	for entry in game.state.d.journal:parent.add_child(game.paragraph(entry,19))
	parent.add_child(game.button("부모님의 운영 안내 다시 보기",open.bind("tutorial")))

func settings(parent: Control) -> void:
	for entry in [["sound","효과음"],["large_text","큰 본문 글자"],["high_contrast","높은 글자 대비"]]:
		var current: bool=game.state.d.settings[entry[0]]
		action_button(parent,entry[1]+(" · 켜짐" if current else " · 꺼짐"),game.state.set_option.bind(entry[0],not current))
	parent.add_child(game.paragraph("게임 내 활동 시간만 사용합니다. 창을 벗어나면 자동 일시정지됩니다.\n현재 언어: 한국어 · 가로 화면 · 마우스 또는 한 손가락 터치\n큰 글자는 본문과 도감에 적용됩니다.",21))

func tutorial(parent: Control) -> void:
	var card:=panel(parent,"부모님이 남긴 꽃집 안내")
	card.add_child(game.paragraph("이 꽃집은 손님이 전하고 싶은 마음을 꽃으로 만드는 곳이란다.\n처음에는 옐로튼 5송이를 준비해 두었어. 첫 판매부터 해 보렴.",24))
	for text in ["1. 시계를 눌러 영업 → 대화 → 주문 수락. 모르면 최대 다섯 번 더 물어보렴.","2. 포장지 위에 꽃 5송이를 끌어 놓고, 가위로 각 꽃의 잎 부분을 끌어 다듬어.","3. 꽃이 서로 떨어져 있다면 손 도구로 가까이 모은 뒤 철사·리본을 각각 선택하고 꽃을 클릭해.","4. 카운터에서 전달하면 정산돼. 인내심이 좋을 때 맞는 주문을 전하면 단골이 된단다.","5. 상점에서 씨앗 → 재배실에서 심고 물 주기 → 수확. 새 꽃은 새 조합법으로 이어져.","6. 첫 판매를 마치고 2일차가 되면 화분을 만들 수 있어. 새 씨앗도 매일 확인해.","7. 렌은 물건, 리아는 소식을 팔아. 장식은 구매 후 장착해야 효과가 생긴단다.","8. 모든 조합을 10번씩 팔아 숙련 보상을 받으면 이 꽃집은 네 것이야."]:
		card.add_child(game.paragraph(text,21))

func ending(parent: Control) -> void:
	if not game.state.d.ending_unlocked:
		parent.add_child(game.paragraph("모든 조합의 숙련 보상을 받은 뒤 열리는 편지입니다.",24));return
	var card:=panel(parent,"마법 꽃집의 새로운 주인에게")
	card.add_child(game.paragraph("꽃의 의미를 배우고, 손님의 이야기를 듣고, 네 손으로 마음을 전했구나.\n이제 우리만의 조합법도 모두 네 것이 되었어.\n\n오늘부터 이 꽃집을 너에게 맡기마.\n네가 피워 낼 다음 이야기를 기다릴게.\n\n사랑을 담아, 부모님이",28))
	card.add_child(game.label("꽃집 계승 완료 · 이후에도 자유롭게 영업할 수 있습니다.",22,game.SAGE))

func merchant_panel(parent: Control) -> void:
	var state=game.state
	var card=game.card(parent,Color("E4EAD9"))
	var ren: bool=state.d.merchant.kind=="ren"
	card.add_child(game.label("렌의 여행 상점" if ren else "리아의 마을 소식",32))
	card.add_child(game.paragraph("새 물건을 가져왔어요. 마음에 드는 것을 골라 보세요." if ren else "곧 마을에 특별한 일이 있어요. 미리 준비해 볼래요?",23))
	card.add_child(game.paragraph("거래 중에는 영업 시간과 꽃 성장이 멈춥니다.",20))
	var details=game.card(parent)
	if ren:
		for kind in ["seed","fertilizer","potion","charm"]:
			var bought: int=int(state.d.merchant.bought.get(kind,0))
			var name: String={"seed":state.content.catalog.flowers[state.d.merchant.offers.seed].name+" 씨앗 · 정가의 50%","fertilizer":"비료 · 할인 가격","potion":"성장 물약 · 1.5배 / %d초"%state.d.merchant.offers.potion,"charm":"제작 부적 · 모으기 범위 +50%% / %d일"%state.d.merchant.offers.charm}[kind]
			var remaining: int=(5 if kind=="seed" else 1)-bought
			var buy: Button=game.button(name+"\n%d G · 남은 수량 %d"%[state.merchant_price(kind),remaining],state.buy_merchant.bind(kind),true)
			buy.add_theme_font_size_override("font_size",19)
			buy.disabled=remaining<=0 or state.d.gold<state.merchant_price(kind)
			details.add_child(buy)
	else:
		details.add_child(game.paragraph("정보를 사면 행사 날짜와 관련 꽃을 알 수 있어요. 정보는 한 번에 하나만 보관할 수 있습니다.",23))
		if state.d.information.is_empty():
			var buy: Button=game.button("무슨 정보인가요? · %d G"%state.merchant_price("information"),state.buy_merchant.bind("information"),true)
			buy.disabled=state.d.gold<state.merchant_price("information")
			details.add_child(buy)
		else:details.add_child(game.paragraph("%d일차에 %s!\n%s"%[state.d.information.start,state.d.information.name,state.d.information.description],24))
	game.spacer(details)
	details.add_child(game.button("구매 종료 · 영업 준비",state.finish_merchant,true))

