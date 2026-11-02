extends Node
var game: Control
var output: String
var errors: int = 0

func check(ok:bool,message:String) -> void:
	if not ok:
		errors+=1
		push_error("UI_FAIL: "+message)

func settle() -> void:
	for i in 4: await get_tree().process_frame

func mouse(at:Vector2,pressed:bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=game.get_viewport().get_final_transform()*at
	event.global_position=event.position
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)

func motion(at:Vector2,relative:Vector2=Vector2.ZERO,down:bool=false) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=game.get_viewport().get_final_transform()*at
	event.global_position=event.position
	event.relative=relative
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)

func click(at:Vector2) -> void:
	motion(at)
	mouse(at,true)
	await get_tree().process_frame
	mouse(at,false)
	await settle()

func press(prefix:String) -> void:
	for candidate in game.find_children("*","Button",true,false):
		if candidate.is_visible_in_tree() and candidate.text.begins_with(prefix) and not candidate.disabled:
			await click(candidate.get_global_rect().get_center())
			return
	check(false,"missing active button "+prefix)

func drag(from:Vector2,to:Vector2) -> void:
	motion(from)
	mouse(from,true)
	await get_tree().process_frame
	var previous:Vector2=from
	for i in range(1,9):
		var at:Vector2=from.lerp(to,float(i)/8.0)
		motion(at,at-previous,true)
		previous=at
		await get_tree().process_frame
	mouse(to,false)
	await settle()

func shelf_drop(id:String,at:Vector2) -> void:
	var source:Button=game.find_child("Flower_"+id,true,false)
	check(source!=null,"flower shelf exists "+id)
	if source==null or not is_instance_valid(game.board): return
	await drag(source.get_global_rect().get_center(),game.board.global_position+game.board.size*at)

func capture(name:String) -> void:
	await settle()
	for candidate in game.find_children("*","Button",true,false):
		if candidate.is_visible_in_tree() and not game.get_global_rect().encloses(candidate.get_global_rect()): check(false,"layout overflow "+name+": "+candidate.text)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")

func run(root:Control) -> void:
	game=root
	output=ProjectSettings.globalize_path("res://../../work/v2-ui")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	await settle()
	await capture("01-ready")
	await press("시계 · 영업 시작")
	check(game.state.d.phase=="talk","clock opens shop through pointer")
	await press("조금 더")
	await press("조금 더")
	check(game.state.d.question==2,"dialogue followups")
	await capture("02-dialogue")
	await press("알겠어요")
	await press("제작대 →")
	await press("포장지 펼치기")
	check(game.state.d.craft.kind=="bouquet","paper setup")
	var initial:int=game.state.d.inventory.freesia
	await shelf_drop("freesia",Vector2(.01,.01))
	check(game.state.d.craft.items.is_empty() and game.state.d.inventory.freesia==initial,"invalid drop returns flower without consumption")
	var ids:Array=["freesia","freesia","lovemis","lovemis","redflora"]
	for i in 5:
		await shelf_drop(ids[i],Vector2(.17+i*.16,.27))
		check(game.state.d.craft.items.size()==i+1,"actual drag/drop flower "+str(i))
	if game.state.d.craft.items.size()!=5:
		await capture("failure-drag")
		finish()
		return
	await capture("03-placed")
	await press("가위 ·")
	await click(game.board.global_position+game.board.leaf_rect(0).get_center())
	check(not game.state.d.craft.items[0].trimmed,"scissors click alone does not trim")
	for i in 5:
		var rect:Rect2=game.board.leaf_rect(i)
		var origin:Vector2=game.board.global_position
		await drag(origin+rect.get_center()-Vector2(26,0),origin+rect.get_center()+Vector2(26,0))
		check(game.state.d.craft.items[i].trimmed,"actual scissors stroke "+str(i))
	await capture("04-trimmed")
	await press("손 ·")
	for i in 5:
		var origin:Vector2=game.board.global_position
		await drag(origin+game.board.point(i),origin+game.board.size*Vector2(.5+(i-2)*.025,.43))
	check(game.state.can_tie(),"drag gathered all flowers")
	await press("철사 ·")
	await click(game.board.global_position+game.board.size*Vector2(.5,.5))
	check(game.state.d.craft.step=="tied","wire requires target click")
	await capture("05-tied")
	await press("리본 ·")
	await click(game.board.global_position+game.board.size*Vector2(.5,.5))
	check(game.state.d.craft.step=="complete" and game.room=="shop","ribbon completes and auto-returns to counter")
	await capture("06-bouquet-complete")
	await press("완성한 꽃 장식 전달")
	check(game.state.d.gold==260 and game.state.d.phase=="result","first bouquet sold")
	await capture("07-payment")
	await press("손님 배웅")
	game.state.tick(4)
	await settle()
	check(game.state.customer().id=="amelia","next customer")
	game.state.end_day()
	await settle()
	await press("다음 날 준비")
	await press("시계 · 영업 시작")
	await press("알겠어요")
	await press("제작대 →")
	await press("화분 놓기")
	await press("흙 ·")
	await click(game.board.global_position+game.board.size*Vector2(.5,.6))
	check(game.state.d.craft.soil==1,"pot half soil")
	await shelf_drop("freesia",Vector2(.45,.4))
	await shelf_drop("lovemis",Vector2(.55,.4))
	check(game.state.d.craft.items.size()==2,"actual pot drag/drop")
	await capture("08-pot-planted")
	await press("흙 ·")
	await click(game.board.global_position+game.board.size*Vector2(.5,.6))
	check(game.state.d.craft.soil==2,"pot cover")
	await press("리본 ·")
	await click(game.board.global_position+game.board.size*Vector2(.5,.6))
	check(game.room=="shop" and game.state.d.craft.step=="complete","pot automatic return")
	await capture("09-pot-complete")
	await press("완성한 꽃 장식 전달")
	check(game.state.d.gold==340 and game.state.d.mastery.love_pot==1,"pot sold")
	await press("← 재배실")
	await capture("10-garden")
	var store=preload("res://scripts/save_store.gd").new(output+"/qa-save")
	var restored=preload("res://scripts/game_state.gd").new()
	check(store.save(game.state) and store.load_into(restored) and restored.d.gold==340,"release save round-trip")
	finish()

func finish() -> void:
	print("V2_UI_RESULT errors=%d actual_mouse_drag_and_tools=true"%errors)
	get_tree().quit(0 if errors==0 else 1)
