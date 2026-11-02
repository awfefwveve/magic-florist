extends "res://scripts/game_state.gd"
const Previous = preload("res://scripts/legacy_state_v2.gd")
const NPC_IDS = ["sentinel","amelia","liam","adrian","sophia","vivian","julian","isla","caleb","clara"]
const SLOTS = ["wall","floor","chair","planter","frame","clock"]
var world: Dictionary
var batching: bool=false

func notify(message: String="") -> void:
	if message!="":last_message=message
	if not batching:changed.emit()

func _init() -> void:
	world = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	content.catalog.customers = world.npcs.duplicate(true)
	d = fresh()
	last_message = "부모님께 꽃집 운영을 배워 볼까요? 첫 주문은 옐로튼 5송이 꽃다발이에요."

func fresh() -> Dictionary:
	var value: Dictionary = super.fresh()
	value.version = 3
	value.discovered = ["yellow"]
	value.known_recipes = ["friendship"]
	for id in value.inventory:
		value.inventory[id] = 5 if id=="yellow" else 0
		value.seeds[id] = 3 if id=="yellow" else 0
	value.merge(extras())
	return value

func extras() -> Dictionary:
	var progress: Dictionary = {}
	var owned: Array = []
	var equipped: Dictionary = {}
	for id in NPC_IDS: progress[id] = 0
	for slot in SLOTS:
		owned.append(slot+"_basic")
		equipped[slot] = {"id":slot+"_basic","color":0}
	return {"tutorial_done":false,"total_sales":0,"harvests":0,"pots_sold":0,"order_recipe":"",
		"relationships":progress,"met_npcs":[],"owned":owned,"equipped":equipped,"potion_left":0.0,"charm_until":0,
		"information":{},"merchant":{"kind":"","offers":{},"bought":{},"information":{}},
		"wait_target":4.0,"ending_unlocked":false,"ending_seen":false,"relief_day":0,
		"settings":{"sound":true,"large_text":false,"high_contrast":false},"journal":[]}

func finish_tutorial() -> void:
	d.tutorial_done = true
	notify("부모님: 꽃의 의미를 듣고, 다섯 송이를 다듬어 선물하렴. 재배실에서 다음 주문의 꽃도 준비해 두고!")

func flower_unlocked(id: String) -> bool:
	return world.flower_days.has(id) and d.day >= world.flower_days[id]

func pot_unlocked() -> bool:
	return d.day >= 2 and d.total_sales >= 1

func refresh_recipes() -> void:
	for id in content.catalog.recipes:
		var info: Dictionary = content.catalog.recipes[id]
		var available: bool = d.day >= info.unlock_day and (info.kind!="pot" or pot_unlocked())
		for flower in info.flowers: available = available and d.discovered.has(flower)
		if available and not d.known_recipes.has(id):
			d.known_recipes.append(id)
			journal("새 조합법: "+info.name)

func journal(message: String) -> void:
	d.journal.append("%d일차 · %s" % [d.day,message])
	if d.journal.size()>40: d.journal.pop_front()

func regular(id: String) -> bool:
	var index: int = NPC_IDS.find(id)
	return index>=0 and d.relationships[id]>=world.npcs[index].goal

func active_event() -> Dictionary:
	if d.information.is_empty(): return {}
	return d.information if d.day>=d.information.start and d.day<=d.information.end else {}

func customer() -> Dictionary:
	if d.current<0: return {}
	var person: Dictionary = content.catalog.customers[int(d.current)].duplicate(true)
	var id: String = d.order_recipe
	if not content.catalog.recipes.has(id): id="friendship"
	var info: Dictionary = content.catalog.recipes[id]
	person.recipe = id
	var text: String = recipe_text(id)
	person.lines = ["%s을 부탁해요."%info.name,
		"마음을 전할 %s이 필요해요."%("꽃다발" if info.kind=="bouquet" else "화분"),
		"%s 꽃을 쓰면 좋겠어요."%" · ".join(info.flowers.keys().map(func(f):return content.catalog.flowers[f].name)),
		"조합법 책에서 %s을 확인해 주세요."%info.name,
		"재료는 %s예요."%text,"%s, 부탁드릴게요."%text]
	if regular(person.id): person.lines[0]="또 왔어요! 제가 좋아하는 %s 부탁해요."%info.name
	if not active_event().is_empty(): person.lines[0]="%s에 어울리는 %s 부탁해요."%[active_event().name,info.name]
	person.thanks="정말 마음에 들어요. 다음에도 찾아올게요!"
	return person

func _visit() -> void:
	refresh_recipes()
	var eligible: Array = []
	var loyal: Array = []
	for i in world.npcs.size():
		if d.day>=world.npcs[i].unlock_day:
			eligible.append(i)
			if regular(world.npcs[i].id): loyal.append(i)
	var index: int = eligible[int(d.cursor)%eligible.size()]
	if not loyal.is_empty() and rng.randf()<minf(.85,.25+decor_bonus("regular")):
		index=loyal[rng.randi_range(0,loyal.size()-1)]
	d.cursor+=1
	d.current=index
	if not d.met_npcs.has(world.npcs[index].id):d.met_npcs.append(world.npcs[index].id)
	d.order_recipe=d.known_recipes[int(d.cursor-1)%d.known_recipes.size()]
	var preferred: String=world.npcs[index].preference
	if regular(world.npcs[index].id) and d.known_recipes.has(preferred): d.order_recipe=preferred
	var event: Dictionary=active_event()
	if not event.is_empty() and d.known_recipes.has(event.recipe):
		if event.id!="trend" or rng.randf()<.8: d.order_recipe=event.recipe
	d.phase="talk"
	d.question=0
	d.patience=0.0
	d.wait=0.0

func start_day() -> bool:
	if not d.tutorial_done or d.merchant.kind!="": return false
	return super.start_day()

func active_clock() -> bool:
	return d.merchant.kind=="" and super.active_clock()

func decor_bonus(effect: String) -> float:
	var total: float=0
	for slot in SLOTS:
		var item: Dictionary=world.decor[d.equipped[slot].id]
		if item.effect==effect: total+=float(item.value)
	return total

func day_limit() -> float:
	return 480.0*(1.0+decor_bonus("day"))

func patience_step() -> float:
	return 30.0*(1.0+decor_bonus("patience"))

func gather_radius() -> float:
	return .145*(1.5 if d.charm_until>=d.day else 1.0)

func patience_level() -> int:
	return mini(3,int(float(d.patience)/patience_step()))

func patience_left() -> float:
	return maxf(0,4.0*patience_step()-float(d.patience))

func tick(seconds: float) -> void:
	if not active_clock() or seconds<=0: return
	var dt: float=minf(seconds,day_limit()-float(d.elapsed))
	var ready: bool=false
	var boosted: float=minf(dt,float(d.potion_left))
	for plot in d.plots:
		if plot.flower!="" and plot.watered:
			var limit: float=content.catalog.flowers[plot.flower].grow_seconds
			var before: float=plot.growth
			plot.growth=minf(limit,before+(dt+boosted*.5)*(1.5 if plot.fertilized else 1.0))
			ready=ready or (before<limit and plot.growth>=limit)
	d.potion_left=maxf(0,float(d.potion_left)-dt)
	d.elapsed+=dt
	if d.elapsed>=day_limit():
		_close();notify("하루 영업을 마쳤어요. 오늘의 결과와 새 소식을 확인하세요.");return
	if d.phase in ["talk","order"]:
		d.patience+=dt
		if patience_left()<=0:
			_refund();d.missed+=1;d.current=-1;d.phase="waiting";d.wait=0.0
			d.wait_target=rng.randf_range(world.settings.wait_min,world.settings.wait_max)
			notify("손님이 돌아갔어요. 제작 재료는 돌려두었습니다.");return
	elif d.phase=="waiting":
		d.wait+=dt
		if d.wait>=d.wait_target:
			_visit();notify("새 손님이 찾아왔어요.");return
	if ready: notify("수확할 꽃이 있어요. 재배실을 확인하세요.")

func setup(kind: String) -> bool:
	if kind=="pot" and not pot_unlocked():
		notify("첫 판매를 마친 뒤 2일차부터 화분을 만들 수 있어요.");return false
	return super.setup(kind)

func buy_seed(id: String) -> bool:
	if not flower_unlocked(id): return false
	return super.buy_seed(id)

func buy_seed_pack(id: String, count: int) -> bool:
	if paused or not flower_unlocked(id) or count<1 or count>99:return false
	var cost: int=int(content.catalog.flowers[id].seed_cost)*count
	if d.gold<cost or d.seeds[id]+count>9999:return false
	d.gold-=cost;d.seeds[id]+=count
	notify("씨앗 %d개를 구입했어요."%count)
	return true

func harvest(index: int) -> bool:
	batching=true
	var harvested: bool=super.harvest(index)
	batching=false
	if not harvested:return false
	d.harvests+=1
	# Super harvest shares the basic discovery rules; apply the stage gate too.
	if not pot_unlocked(): d.known_recipes.erase("love_pot")
	refresh_recipes()
	notify("새 꽃과 조합법은 도감에서 확인할 수 있어요.")
	return true

func price_details() -> Dictionary:
	var result: Dictionary=super.price_details()
	if result.is_empty(): return result
	var person: Dictionary=customer()
	var bonus: float=float(person.bonus) if regular(person.id) else 0.0
	result["regular"]=bonus
	result.paid=int(roundf(float(result.base)*float(result.quality)*float(result.patience)*(1.0+bonus)))
	return result

func deliver() -> bool:
	if paused or d.phase!="order" or d.craft.step!="complete":return false
	var person: Dictionary=customer()
	var good: bool=patience_level()==0 and price_details().quality>=1.0
	var was_regular: bool=regular(person.id)
	var was_pot: bool=d.craft.kind=="pot"
	batching=true
	var delivered: bool=super.deliver()
	batching=false
	if not delivered:return false
	d.total_sales+=1
	if was_pot:d.pots_sold+=1
	if good:d.relationships[person.id]+=1
	if not was_regular and regular(person.id):journal(person.name+"님이 단골이 되었어요!")
	refresh_recipes()
	notify("판매 완료! 단골 진행과 숙련도는 도감에 기록됩니다.")
	return true

func continue_service() -> bool:
	batching=true
	var continued: bool=super.continue_service()
	batching=false
	if not continued:return false
	d.wait_target=rng.randf_range(world.settings.wait_min,world.settings.wait_max)
	notify()
	return true

func next_day() -> bool:
	if paused or d.phase!="closed":return false
	d.day+=1;d.elapsed=0.0;d.sold=0;d.earned=0;d.missed=0;d.current=-1
	d.phase="ready";d.result={};d.question=0;d.patience=0.0;d.wait=0.0
	if not d.information.is_empty() and d.day>d.information.end:
		journal(d.information.name+" 종료");d.information={}
	refresh_recipes()
	schedule_merchant()
	notify("새 하루를 준비하세요. 상점에서 새로 열린 씨앗도 확인할 수 있어요.")
	return true

func schedule_merchant() -> void:
	d.merchant={"kind":"","offers":{},"bought":{},"information":{}}
	var cfg: Dictionary=world.merchant
	if d.day>=cfg.ren_start and (int(d.day)-int(cfg.ren_start))%int(cfg.interval)==0 and d.potion_left<=0 and d.charm_until<d.day:
		var choices: Array=[]
		for id in world.flower_days:
			if flower_unlocked(id):choices.append(id)
		var seed: String=choices[rng.randi_range(0,choices.size()-1)]
		d.merchant.kind="ren"
		d.merchant.offers={"seed":seed,"potion":rng.randi_range(180,300),"charm":rng.randi_range(1,3),"fertilizer":true}
	elif d.day>=cfg.lia_start and (int(d.day)-int(cfg.lia_start))%int(cfg.interval)==0 and d.information.is_empty():
		d.merchant.kind="lia"
		var event: Dictionary=world.events[int((d.day-3)/3)%world.events.size()].duplicate(true)
		event["start"]=int(d.day)+3
		event["end"]=int(event.start)+int(event.duration)-1
		d.merchant.information=event

func merchant_price(kind: String) -> int:
	match kind:
		"seed":return maxi(1,int(roundf(content.catalog.flowers[d.merchant.offers.seed].seed_cost*.5))) if d.merchant.kind=="ren" else 0
		"fertilizer":return 10
		"potion":return int(world.merchant.potion_cost)
		"charm":return int(world.merchant.charm_cost)
		"information":return int(world.merchant.information_cost)
	return 0

func buy_merchant(kind: String) -> bool:
	if paused or d.phase!="ready":return false
	var cost: int=merchant_price(kind)
	if cost<=0 or d.gold<cost:return false
	if kind=="information":
		if d.merchant.kind!="lia" or not d.information.is_empty():return false
		d.information=d.merchant.information.duplicate(true)
		journal("정보 구입: %s (%d일차)"%[d.information.name,d.information.start])
	elif d.merchant.kind=="ren":
		if kind not in ["seed","fertilizer","potion","charm"]:return false
		var bought: int=int(d.merchant.bought.get(kind,0))
		if bought >= (5 if kind=="seed" else 1):return false
		match kind:
			"seed":
				if d.seeds[d.merchant.offers.seed]>=9999:return false
				d.seeds[d.merchant.offers.seed]+=1
			"fertilizer":
				if d.fertilizer>=9999:return false
				d.fertilizer+=1
			"potion":d.potion_left=float(d.merchant.offers.potion)
			"charm":d.charm_until=int(d.day)+int(d.merchant.offers.charm)-1
		d.merchant.bought[kind]=bought+1
	else:return false
	d.gold-=cost
	notify("구매했어요. 효과와 정보는 상단 소식에서 확인할 수 있어요.")
	return true

func finish_merchant() -> void:
	d.merchant.kind=""
	notify("다음에 또 만나요! 시계를 눌러 영업을 시작하세요.")

func buy_decor(id: String) -> bool:
	if paused or not world.decor.has(id) or d.owned.has(id):return false
	var item: Dictionary=world.decor[id]
	if d.day<item.unlock_day or d.gold<item.cost:return false
	d.gold-=item.cost;d.owned.append(id)
	notify("인테리어를 구입했어요. 도감의 인테리어 탭에서 장착하세요.")
	return true

func equip(id: String, color_index: int) -> bool:
	if paused or not world.decor.has(id) or not d.owned.has(id):return false
	var item: Dictionary=world.decor[id]
	if color_index<0 or color_index>=item.colors.size():return false
	d.equipped[item.slot]={"id":id,"color":color_index}
	# Shorter days or patience must resolve immediately, including a paused menu edit.
	if d.phase in ["talk","order","waiting","result"] and d.elapsed>=day_limit():_close()
	elif d.phase in ["talk","order"] and patience_left()<=0:
		_refund();d.current=-1;d.phase="waiting";d.wait=0.0;d.missed+=1
	notify("%s을 적용했어요. 같은 종류의 이전 장식은 보관함으로 돌아갑니다."%item.name)
	return true

func claim(id: String) -> bool:
	batching=true
	var claimed: bool=super.claim(id)
	batching=false
	if not claimed:return false
	var all_done: bool=true
	for recipe_id in content.catalog.recipes:all_done=all_done and d.claimed[recipe_id]
	if all_done and not d.ending_unlocked:
		d.ending_unlocked=true
		journal("모든 조합을 숙련했어요. 부모님의 편지가 도착했습니다.")
	notify("숙련 보상을 받았어요."+(" 꽃집 계승 편지를 확인하세요!" if d.ending_unlocked else ""))
	return true

func view_ending() -> void:
	if not d.ending_unlocked:return
	d.ending_seen=true
	notify("마법 꽃집의 새 주인이 되었어요. 이후에도 자유롭게 영업할 수 있습니다.")

func relief_available() -> bool:
	if d.relief_day==d.day or d.gold>=6:return false
	for id in d.seeds:
		if d.seeds[id]>0 or d.inventory[id]>0:return false
	for plot in d.plots:
		if plot.flower!="":return false
	return d.craft.items.is_empty()

func request_relief() -> bool:
	if paused or not relief_available():return false
	d.seeds.yellow+=3;d.relief_day=d.day
	notify("부모님이 옐로튼 씨앗 3개를 보내 주셨어요. 다시 꽃을 키워 보세요.")
	return true

func set_option(key: String, value: bool) -> void:
	if not d.settings.has(key):return
	d.settings[key]=value
	notify()

func migrate(raw: Variant) -> Dictionary:
	if not raw is Dictionary:return {}
	if raw.get("version")==3:return raw.duplicate(true)
	var old=Previous.new()
	if not old.valid(raw):return {}
	var result: Dictionary=old.migrate(raw)
	var old_index: int=int(result.current)
	var order_id: String=""
	var npc_id: String=""
	if old_index>=0:
		order_id=old.content.catalog.customers[old_index].recipe
		npc_id=old.content.catalog.customers[old_index].id.replace("_pot","")
	result.merge(extras())
	result.version=3;result.tutorial_done=true
	result.current=NPC_IDS.find(npc_id) if old_index>=0 else -1
	result.order_recipe=order_id
	if npc_id!="":result.met_npcs.append(npc_id)
	result.total_sales=maxi(1,int(result.sold))
	for count in result.mastery.values():result.total_sales+=int(count)
	result.ending_unlocked=result.claimed.values().all(func(v):return v)
	return result

func valid(raw: Variant) -> bool:
	var value: Dictionary=migrate(raw)
	if value.is_empty():return false
	for key in fresh():
		if not value.has(key):return false
	if not whole(value.day,1,999999999) or not number(value.elapsed,0,672) or not number(value.patience,0,1000) or not value.phase is String:return false
	for key in extras():
		if not value.has(key):return false
	for key in ["tutorial_done","ending_unlocked","ending_seen"]:
		if not value[key] is bool:return false
	for key in ["total_sales","harvests","pots_sold","charm_until","relief_day"]:
		if not whole(value[key],0,999999999):return false
	if not number(value.potion_left,0,300) or not number(value.wait_target,0,60):return false
	if not value.order_recipe is String or (value.order_recipe!="" and not content.catalog.recipes.has(value.order_recipe)):return false
	if value.phase in ["talk","order","result"] and value.order_recipe=="":return false
	if not value.relationships is Dictionary or value.relationships.size()!=10:return false
	for id in NPC_IDS:
		if not value.relationships.has(id) or not whole(value.relationships[id],0,999999999):return false
	if not value.met_npcs is Array:return false
	var met: Array=[]
	for id in value.met_npcs:
		if not id is String or id not in NPC_IDS or met.has(id):return false
		met.append(id)
	if not value.owned is Array or not value.equipped is Dictionary or value.equipped.size()!=6:return false
	var seen: Array=[]
	for id in value.owned:
		if not id is String or not world.decor.has(id) or seen.has(id):return false
		seen.append(id)
	var duration: float=480.0
	var patience: float=30.0
	for slot in SLOTS:
		if not value.equipped.has(slot):return false
		var equipped: Variant=value.equipped[slot]
		if not equipped is Dictionary or not equipped.has_all(["id","color"]):return false
		if not equipped.id is String or not value.owned.has(equipped.id):return false
		var item: Dictionary=world.decor[equipped.id]
		if item.slot!=slot or not whole(equipped.color,0,item.colors.size()-1):return false
		if item.effect=="day":duration+=480.0*float(item.value)
		if item.effect=="patience":patience+=30.0*float(item.value)
	if not number(value.elapsed,0,672) or not number(value.patience,0,1000):return false
	if value.phase in ["talk","order","waiting"] and value.elapsed>=duration:return false
	if value.phase in ["talk","order"] and value.patience>=patience*4:return false
	if not valid_information(value.information):return false
	if not value.merchant is Dictionary or not value.merchant.has_all(["kind","offers","bought","information"]):return false
	var merchant: Dictionary=value.merchant
	if merchant.kind not in ["","ren","lia"] or not merchant.offers is Dictionary or not merchant.bought is Dictionary:return false
	if not valid_information(merchant.information):return false
	if merchant.kind!="" and value.phase!="ready":return false
	if merchant.kind=="ren":
		if not merchant.offers.has_all(["seed","potion","charm","fertilizer"]):return false
		if not content.catalog.flowers.has(merchant.offers.seed) or not whole(merchant.offers.potion,180,300) or not whole(merchant.offers.charm,1,3):return false
	if merchant.kind=="lia" and merchant.information.is_empty():return false
	for key in merchant.bought:
		if key not in ["seed","potion","charm","fertilizer"] or not whole(merchant.bought[key],0,5 if key=="seed" else 1):return false
	if not value.settings is Dictionary or not value.settings.has_all(["sound","large_text","high_contrast"]):return false
	for key in value.settings:
		if not value.settings[key] is bool:return false
	if not value.journal is Array or value.journal.size()>40:return false
	for entry in value.journal:
		if not entry is String or entry.length()>300:return false
	if value.ending_seen and not value.ending_unlocked:return false
	if value.ending_unlocked:
		if not value.claimed is Dictionary:return false
		for id in content.catalog.recipes:
			if value.claimed.get(id)!=true:return false
	var basic: Dictionary=value.duplicate(true)
	basic.elapsed=minf(float(basic.elapsed),480.0)
	basic.patience=minf(float(basic.patience),119.9) if basic.phase in ["talk","order"] else minf(float(basic.patience),600.0)
	return super.valid(basic)

func valid_information(info: Variant) -> bool:
	if not info is Dictionary:return false
	if info.is_empty():return true
	if not info.has_all(["id","name","recipe","flower","duration","description","start","end"]):return false
	if info.id not in ["festival","anniversary","trend"] or not content.catalog.recipes.has(info.recipe) or not content.catalog.flowers.has(info.flower):return false
	if not info.name is String or not info.description is String:return false
	return whole(info.start,1,999999999) and whole(info.end,info.start,info.start+1) and whole(info.duration,1,2)

func restore(raw: Dictionary) -> bool:
	if not valid(raw):return false
	d=migrate(raw)
	for key in ["day","gold","cursor","current","question","sold","earned","missed","fertilizer","total_sales","harvests","pots_sold","charm_until","relief_day"]:d[key]=int(d[key])
	for key in ["inventory","seeds","mastery","relationships"]:
		for id in d[key]:d[key][id]=int(d[key][id])
	d.craft.soil=int(d.craft.soil)
	return true
