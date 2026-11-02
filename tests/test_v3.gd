extends SceneTree
const State=preload("res://scripts/progression_state.gd")
const Previous=preload("res://scripts/game_state.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:int=0
var failures:int=0

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V3_FAIL: "+message)

func complete(s:RefCounted,id:String) -> void:
	s.d.current=0;s.d.order_recipe=id;s.d.phase="order";s.d.patience=0;s.d.craft=s.blank_craft()
	var info:Dictionary=s.content.catalog.recipes[id]
	s.setup(info.kind)
	if info.kind=="pot":s.use_tool("soil")
	for flower in info.flowers:
		s.d.inventory[flower]+=info.flowers[flower]
		for i in int(info.flowers[flower]):s.place(flower,Vector2(.5,.43))
	if info.kind=="pot":s.use_tool("soil")
	else:s.trim([0,1,2,3,4]);s.use_tool("wire")
	s.use_tool("ribbon")
	check(s.deliver(),"sell "+id)
	check(s.valid(s.snapshot()),"valid after sale "+id)

func _initialize() -> void:
	var s=State.new()
	check(s.valid(s.snapshot()),"fresh valid")
	check(not s.start_day(),"tutorial gate")
	s.finish_tutorial()
	check(s.d.discovered==["yellow"] and s.d.known_recipes==["friendship"],"initial discovery only yellow")
	check(not s.buy_seed("redflora") and not s.buy_seed_pack("freesia",2),"locked seeds cannot buy")
	check(s.start_day() and s.customer().recipe=="friendship","first available order")
	s.accept_order();s.setup("bouquet")
	for i in 5:s.place("yellow",Vector2(.5,.43))
	s.trim([0,1,2,3,4]);s.use_tool("wire");s.use_tool("ribbon")
	check(s.deliver() and s.d.gold==250 and s.d.total_sales==1,"natural first sale")
	s.end_day();s.next_day()
	check(s.d.day==2 and s.d.merchant.kind=="ren" and s.pot_unlocked(),"day two first sale unlock and ren arrival")
	check(not s.start_day(),"must finish merchant")
	check(s.buy_merchant("potion") and not s.buy_merchant("potion"),"one potion per visit")
	var remaining:float=s.d.potion_left
	s.tick(999)
	check(s.d.elapsed==0 and s.d.potion_left==remaining,"merchant stops clock and effect countdown")
	for i in 5:check(s.buy_merchant("seed"),"discount seed up to five")
	check(not s.buy_merchant("seed"),"sixth merchant seed rejected")
	s.finish_merchant()
	check(s.buy_seed_pack("freesia",1) and s.buy_seed_pack("lovemis",1),"new day seed unlocks")
	check(not s.buy_seed_pack("freesia",999) and not s.buy_seed_pack("freesia",-1),"batch quantity limits")
	s.plant(0,"freesia");s.water(0);s.plant(1,"lovemis");s.water(1);s.start_day();s.tick(360)
	check(s.harvest(0) and s.harvest(1),"first harvest new flowers")
	check(s.d.discovered.has("freesia") and s.d.known_recipes.has("love_pot") and not s.d.known_recipes.has("birthday"),"harvest unlocks correct recipe")
	s.end_day();s.next_day()
	check(s.d.merchant.kind=="lia","lia on configured day")
	s.d.gold=1000
	check(s.buy_merchant("information") and not s.buy_merchant("information"),"one information purchase")
	check(s.d.information.start==6 and s.d.information.end==6,"festival date countdown")
	s.finish_merchant();s.buy_seed("redflora");s.plant(0,"redflora");s.water(0);s.start_day();s.tick(360);s.harvest(0)
	check(s.d.known_recipes.size()==3,"all listed recipes discoverable")
	check(s.valid(s.snapshot()),"natural day three valid")
	var loyal=State.new();loyal.finish_tutorial();loyal.d.day=4;loyal.d.total_sales=1;loyal.d.known_recipes=["friendship","birthday","love_pot"]
	for i in 5:complete(loyal,"friendship")
	check(loyal.regular("sentinel") and loyal.d.result.paid==90,"fifth good sale unlocks regular after payout")
	complete(loyal,"friendship")
	check(loyal.d.result.paid==93 and loyal.d.result.regular==.03,"regular bonus multiplies payout")
	loyal.d.phase="order";loyal.d.craft=loyal.blank_craft();loyal.d.patience=31
	loyal.setup("bouquet")
	for i in 5:loyal.d.inventory.yellow+=1;loyal.place("yellow",Vector2(.5,.43))
	loyal.trim([0,1,2,3,4]);loyal.use_tool("wire");loyal.use_tool("ribbon");loyal.deliver()
	check(loyal.d.relationships.sentinel==6,"non-good sale not counted")
	loyal.d.gold=5000
	check(loyal.buy_decor("wall_garden") and not loyal.buy_decor("wall_garden"),"decor purchased once")
	check(loyal.decor_bonus("patience")==0,"owned inactive decor gives no effect")
	check(loyal.equip("wall_garden",1) and is_equal_approx(loyal.patience_step(),30.15),"equipped patience effect")
	check(loyal.buy_decor("wall_moon") and loyal.equip("wall_moon",2) and is_equal_approx(loyal.decor_bonus("patience"),.01),"replacement not stack same slot")
	loyal.buy_decor("floor_garden");loyal.equip("floor_garden",0)
	check(is_equal_approx(loyal.decor_bonus("patience"),.015),"different slots effects stack")
	loyal.buy_decor("clock_garden");loyal.equip("clock_garden",0)
	check(is_equal_approx(loyal.day_limit(),504.0),"extended day")
	loyal.d.phase="waiting";loyal.d.current=-1;loyal.d.elapsed=490
	check(loyal.valid(loyal.snapshot()),"extended day save valid")
	loyal.equip("clock_basic",0)
	check(loyal.d.phase=="closed","shorter day resolves immediately")
	check(not loyal.equip("chair_moon",0) and not loyal.equip("wall_moon",99),"unowned and invalid colors rejected")
	var buffs=State.new();buffs.finish_tutorial();buffs.d.day=4;buffs.d.potion_left=10
	buffs.d.seeds.freesia=1;buffs.plant(0,"freesia");buffs.water(0);buffs.start_day();buffs.tick(20)
	check(buffs.d.plots[0].growth==25 and buffs.d.potion_left==0,"potion expires partway through tick")
	buffs.d.charm_until=4
	check(is_equal_approx(buffs.gather_radius(),.2175),"charm assists gathering")
	buffs.end_day();buffs.next_day()
	check(is_equal_approx(buffs.gather_radius(),.145),"charm expires on next day")
	var event=State.new();event.finish_tutorial();event.d.day=6;event.d.total_sales=1;event.d.known_recipes=["friendship","birthday","love_pot"]
	event.d.information=s.d.information.duplicate(true);event.start_day()
	check(event.customer().recipe=="love_pot","festival enforces themed order")
	event.end_day();event.next_day()
	check(event.d.information.is_empty(),"event expires next day")
	var ending=State.new();ending.finish_tutorial();ending.d.day=4;ending.d.total_sales=1
	for id in ending.content.catalog.recipes:
		for i in 10:complete(ending,id)
		check(ending.claim(id) and not ending.claim(id),"one mastery claim "+id)
	check(ending.d.ending_unlocked,"all mastery unlocks ending")
	ending.view_ending();ending.end_day();ending.next_day();ending.finish_merchant()
	check(ending.d.ending_seen and ending.start_day(),"post-ending free play")
	var previous=Previous.new();previous.d.day=2;previous.d.gold=777;previous.start_day();previous.accept_order();previous.setup("bouquet");previous.place("yellow",Vector2(.3,.3))
	var migrated=State.new()
	check(migrated.restore(previous.snapshot()) and migrated.d.gold==777 and migrated.d.craft.items.size()==1,"v2 work and gold migrated")
	check(migrated.customer().recipe==previous.customer().recipe and migrated.d.discovered.size()==4,"v2 order and unlocks retained")
	var path:String=ProjectSettings.globalize_path("res://../../work/v3-save-tests")
	DirAccess.make_dir_recursive_absolute(path)
	var base:String=path+"/run-"+str(Time.get_ticks_usec())
	var store=Store.new(base)
	check(store.save(previous) and store.load_into(migrated) and FileAccess.file_exists(base+".v2-original"),"v2 original preserved")
	check(store.save(ending) and store.load_into(migrated) and migrated.d.ending_seen,"v3 full save roundtrip")
	for bad in [["equipped",{}],["owned",["invalid"]],["relationships",{}],["potion_left",INF],["merchant",{}],["information",{"id":"invalid"}],["settings",{}],["ending_seen",3]]:
		var data:Dictionary=ending.snapshot();data[bad[0]]=bad[1]
		check(not ending.valid(data),"reject malformed "+bad[0])
	var relief=State.new();relief.d.gold=0
	for id in relief.d.inventory:relief.d.inventory[id]=0;relief.d.seeds[id]=0
	check(relief.request_relief() and not relief.request_relief(),"softlock relief once")
	for id in s.content.assets:
		var texture:Texture2D=s.content.texture(id)
		check(texture!=null and texture.get_width()==s.content.assets[id].width and texture.get_height()==s.content.assets[id].height,"asset "+id)
	print("V3_TEST_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
