extends "res://scripts/ui_qa.gd"

func press(prefix: String) -> void:
	var root: Node=game.popup if is_instance_valid(game.popup) else game
	for candidate in root.find_children("*","Button",true,false):
		if candidate.is_visible_in_tree() and candidate.text.begins_with(prefix) and not candidate.disabled:
			await click_control(candidate)
			return
	check(false,"missing button "+prefix)

func click_control(candidate: Control) -> void:
	var parent: Node=candidate.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(candidate)
		parent=parent.get_parent()
	await settle()
	var at: Vector2=candidate.get_global_rect().get_center()
	if candidate.get_window()!=game.get_window():at+=Vector2(candidate.get_window().position)
	await click(at)

func named(id: String) -> void:
	var root: Node=game.popup if is_instance_valid(game.popup) else game
	var candidate: Control=root.find_child(id,true,false)
	check(candidate!=null,"named control "+id)
	if candidate!=null:await click_control(candidate)

func capture(name: String) -> void:
	await settle()
	if not is_instance_valid(game.popup):
		for candidate in game.find_children("*","Button",true,false):
			if candidate.is_visible_in_tree() and not game.get_global_rect().encloses(candidate.get_global_rect()):check(false,"overflow "+name+": "+candidate.text)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")

func run(root: Control) -> void:
	game=root
	output=ProjectSettings.globalize_path("res://../../work/v3-ui")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	await settle()
	game._show_tutorial();await settle();await capture("01-tutorial")
	await press("꽃집 시작하기")
	check(game.state.d.tutorial_done,"tutorial acknowledged by mouse")
	await press("시계 · 영업 시작")
	for i in 5:await press("조금 더")
	check(game.state.d.question==5,"five followups")
	await press("알겠어요");await press("제작대 →");await press("포장지 펼치기")
	await shelf_drop("yellow",Vector2(.01,.01))
	check(game.state.d.inventory.yellow==5,"off paper does not consume")
	for i in 5:await shelf_drop("yellow",Vector2(.17+i*.16,.27))
	check(game.state.d.craft.items.size()==5,"actual five flower drag")
	if game.state.d.craft.items.size()!=5:await capture("failure");finish();return
	await capture("02-crafting")
	await press("가위 ·")
	for i in 5:
		var at: Vector2=game.board.global_position+game.board.leaf_rect(i).get_center()
		await drag(at-Vector2(25,0),at+Vector2(25,0))
	await press("손 ·")
	for i in 5:await drag(game.board.global_position+game.board.point(i),game.board.global_position+game.board.size*Vector2(.5+(i-2)*.025,.43))
	await press("철사 ·");await click(game.board.global_position+game.board.size*Vector2(.5,.5))
	await press("리본 ·");await click(game.board.global_position+game.board.size*Vector2(.5,.5))
	await press("완성한 꽃 장식 전달")
	check(game.state.d.gold==250 and game.state.d.total_sales==1,"first sale")
	await press("도감 · 소식");await capture("03-recipes")
	await press("단골");await capture("04-regulars")
	await press("상점");await named("BuyDecor_wall_garden")
	check(game.state.d.owned.has("wall_garden"),"buy decor through store")
	await press("인테리어");await named("Color_wall_garden_1");await named("Equip_wall_garden")
	check(game.state.d.equipped.wall.id=="wall_garden" and game.state.d.equipped.wall.color==1,"color preview and equip")
	await capture("05-decor")
	await press("닫기")
	game.state.end_day();await settle();await press("다음 날 준비")
	check(game.state.d.merchant.kind=="ren","ren appears")
	await capture("06-ren")
	await press("성장 물약")
	check(game.state.d.potion_left>0,"buy potion by mouse")
	await press("구매 종료")
	await press("상점");await named("BuySeed_freesia");await named("BuySeed_lovemis");await press("닫기")
	await press("← 재배실")
	await press("프레지아 ×");await press("빈 밭 01");await press("프레지아\n물 주기")
	await press("러브미스 ×");await press("빈 밭 02");await press("러브미스\n물 주기")
	await press("카운터");await press("시계 · 영업 시작")
	game.state.tick(360);await settle()
	await press("← 재배실");await press("프레지아\n수확하기");await press("러브미스\n수확하기")
	check(game.state.d.known_recipes.has("love_pot"),"mouse harvest unlocks recipe")
	await capture("07-discovered")
	# Fast-forward setup: model tests separately cover customer eligibility and timing.
	game.state.d.phase="talk";game.state.d.current=0;game.state.d.order_recipe="love_pot";game.state.d.patience=0
	game.state.notify();await settle();await press("카운터");await press("알겠어요");await press("제작대 →");await press("화분 놓기")
	await press("흙 ·");await click(game.board.global_position+game.board.size*Vector2(.5,.6))
	await shelf_drop("freesia",Vector2(.45,.4));await shelf_drop("lovemis",Vector2(.55,.4))
	await press("흙 ·");await click(game.board.global_position+game.board.size*Vector2(.5,.6))
	await press("리본 ·");await click(game.board.global_position+game.board.size*Vector2(.5,.6))
	await capture("08-pot")
	await press("완성한 꽃 장식 전달")
	check(game.state.d.pots_sold==1,"pot sold")
	game.state.end_day();await settle();await press("다음 날 준비")
	await press("무슨 정보인가요")
	check(not game.state.d.information.is_empty(),"buy lia information")
	await capture("09-lia");await press("구매 종료")
	await press("도감 · 소식");await press("소식");await capture("10-news")
	await press("설정");await press("큰 본문 글자");await press("높은 글자 대비")
	check(game.state.d.settings.large_text and game.state.d.settings.high_contrast,"settings controls")
	await capture("11-settings");await press("닫기");await capture("12-large-text")
	game.state.d.discovered=game.state.content.catalog.flowers.keys()
	game.state.d.known_recipes=game.state.content.catalog.recipes.keys()
	for id in game.state.d.mastery:game.state.d.mastery[id]=10
	await press("도감 · 소식")
	for i in 3:await press("숙련 보상 받기")
	check(game.state.d.ending_unlocked,"all claims unlock ending")
	await press("부모님의 계승 편지");await capture("13-ending")
	check(game.state.d.ending_seen,"ending read state")
	await press("닫기")
	await press("시계 · 영업 시작");await press("알겠어요");await press("제작대 →")
	await capture("14-large-text-atelier")
	var store=preload("res://scripts/save_store.gd").new(output+"/qa-save")
	var restored=preload("res://scripts/progression_state.gd").new()
	check(store.save(game.state) and store.load_into(restored) and restored.d.ending_seen and restored.d.equipped.wall.color==1,"v3 release persistence")
	finish()

func finish() -> void:
	print("V3_UI_RESULT errors=%d"%errors)
	get_tree().quit(0 if errors==0 else 1)
