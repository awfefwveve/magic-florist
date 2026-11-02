extends Control
const State = preload("res://scripts/progression_state.gd")
const Menu = preload("res://scripts/journal_ui.gd")
const ShopPreview = preload("res://scripts/shop_preview.gd")
const Store = preload("res://scripts/save_store.gd")
const Board = preload("res://scripts/floral_board.gd")
const FlowerSource = preload("res://scripts/flower_source.gd")
const INK = Color("344B41")
const MUTED = Color("7C8778")
const PAPER = Color("FAF7EE")
const SAGE = Color("587B65")
var state = State.new()
var store = Store.new()
var room: String = "shop"
var seed_id: String = "yellow"
var tool: String = "hand"
var garden_tool: String = "seed"
var root_box: VBoxContainer
var body: Control
var clock_label: Label
var patience_label: Label
var gold_label: Label
var toast: Label
var pause_button: Button
var board: Control
var plot_buttons: Dictionary = {}
var autosave: float = 0.0
var qa: bool = false
var build_pending: bool = false
var popup: Window
var popup_resume: bool = false
var display_epoch: int = 0
var drag_id: String = ""
var drag_preview: TextureRect
var menus: RefCounted
var sound_player: AudioStreamPlayer
var pointer_position: Vector2

func _begin_flower_drag(id: String) -> void:
	drag_id = id
	drag_preview = picture(state.content.catalog.flowers[id].asset, Vector2.ZERO)
	drag_preview.size = Vector2(100,100)
	drag_preview.position = pointer_position - Vector2(50,50)
	add_child(drag_preview)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer_position = event.position
	if drag_id == "": return
	if event is InputEventMouseMotion:
		if is_instance_valid(drag_preview): drag_preview.position = event.position - Vector2(50,50)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var id := drag_id
		drag_id = ""
		if is_instance_valid(drag_preview): drag_preview.queue_free()
		drag_preview = null
		get_viewport().set_input_as_handled()
		if is_instance_valid(board) and state.can_place(id,(event.position-board.global_position)/board.size):
			state.place(id,(event.position-board.global_position)/board.size)
		else:
			state.notify("꽃을 포장지 또는 흙을 담은 화분 안에 놓아 주세요.")

func _ready() -> void:
	get_viewport().gui_embed_subwindows = true
	menus = Menu.new(self)
	sound_player=AudioStreamPlayer.new()
	sound_player.stream=preload("res://assets/audio/click.wav")
	sound_player.volume_db=-12
	add_child(sound_player)
	qa = OS.get_cmdline_user_args().has("--qa")
	get_tree().auto_accept_quit = false
	if not qa:
		store.load_into(state)
		if store.status != "": state.last_message = store.status
	var ui_theme := Theme.new()
	ui_theme.default_font = preload("res://assets/fonts/NotoSansKR-Regular.otf")
	ui_theme.default_font_size = 20
	ui_theme.set_color("font_color", "Label", INK)
	theme = ui_theme
	state.changed.connect(_changed)
	_build()
	if not qa and not state.d.tutorial_done: call_deferred("_show_tutorial")
	if qa: call_deferred("_run_qa")

func panel_style(color: Color, radius: int = 20) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 25
	style.content_margin_right = 25
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func label(text: String, size_px: int = 22, color: Color = INK) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size_px+ (2 if state.d.settings.large_text and size_px<=24 else 0))
	item.add_theme_color_override("font_color", Color("182A20") if state.d.settings.high_contrast else color)
	return item

func paragraph(text: String, size_px: int = 23) -> Label:
	var item := label(text, size_px)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return item

func button(text: String, action: Callable, primary: bool = false) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(0, 58)
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_stylebox_override("normal", panel_style(SAGE if primary else Color("E9EBDD"), 13))
	item.add_theme_stylebox_override("hover", panel_style(Color("73917A") if primary else Color("DCE3D0"), 13))
	item.add_theme_stylebox_override("pressed", panel_style(Color("486851"), 13))
	item.add_theme_stylebox_override("disabled", panel_style(Color("EEEBE2"), 13))
	item.add_theme_color_override("font_color", PAPER if primary else INK)
	item.add_theme_color_override("font_hover_color", PAPER if primary else INK)
	item.add_theme_color_override("font_pressed_color", PAPER)
	item.add_theme_color_override("font_disabled_color", Color("A3A596"))
	item.pressed.connect(action)
	item.pressed.connect(_play_click)
	return item

func _play_click() -> void:
	if state.d.settings.sound and is_instance_valid(sound_player): sound_player.play()

func row(gap: int = 16) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", gap)
	return item

func column(gap: int = 12) -> VBoxContainer:
	var item := VBoxContainer.new()
	item.add_theme_constant_override("separation", gap)
	return item

func card(parent: Node, color: Color = PAPER) -> VBoxContainer:
	var outer := PanelContainer.new()
	outer.add_theme_stylebox_override("panel", panel_style(color))
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(outer)
	var inner := column()
	outer.add_child(inner)
	return inner

func picture(id: String, minimum: Vector2) -> TextureRect:
	var item := TextureRect.new()
	item.texture = state.content.texture(id)
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.custom_minimum_size = minimum
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func spacer(parent: Node) -> void:
	var item := Control.new()
	item.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(item)

func _build() -> void:
	build_pending = false
	drag_id = ""
	drag_preview = null
	display_epoch += 1
	for child in get_children():
		if child is Window or child is AudioStreamPlayer or child.name == "QA": continue
		remove_child(child)
		child.queue_free()
	board = null
	plot_buttons.clear()
	preload("res://scripts/scene_ui.gd").new(self).build()
	_update_status()

func _craft_hint() -> String:
	var craft: Dictionary = state.d.craft
	if craft.kind == "": return "아래의 포장지 또는 화분을 눌러 작업을 시작하세요."
	if craft.kind == "pot":
		if craft.soil == 0: return "흙 도구 선택 → 화분 클릭: 흙을 절반 채웁니다."
		if craft.soil == 1: return "꽃을 화분 안으로 끌어 넣으세요(최대 2송이). 다 심었으면 흙 도구로 덮으세요."
		return "리본 도구를 고른 뒤 화분을 클릭하면 완성됩니다."
	if craft.step == "tied": return "리본 도구를 고른 뒤 묶인 꽃을 클릭하세요. 완성되면 카운터로 자동 이동합니다."
	var trimmed: int = 0
	for item in craft.items:
		if item.trimmed: trimmed+=1
	return "꽃 %d/5 · 다듬음 %d/5  |  %s" % [craft.items.size(),trimmed,{"hand":"꽃끼리 가까이 모으세요. 이미 모여 있다면 바로 철사를 사용하세요.","scissors":"빨간 사각형의 잎 부분을 누른 채 가로질러 드래그하세요.","wire":"포장지 어디든 누르면 묶습니다." if state.can_tie() else "꽃 5송이의 잎을 다듬고 서로 가까이 모아 주세요.","ribbon":"철사로 먼저 묶은 뒤 꽃을 클릭하세요.","soil":"흙은 화분 제작에 사용합니다."}[tool]]

func _changed() -> void:
	if state.d.phase not in ["order"] and room == "atelier": room="shop"
	if state.d.phase=="order" and state.d.craft.step=="complete": room="shop"
	if state.d.phase in ["closed","result"]: room="shop"
	if not qa: store.save(state)
	if not build_pending:
		build_pending=true
		call_deferred("_build")

func _switch_room(target: String) -> void:
	if state.paused: return
	if target=="atelier" and state.d.phase!="order": return
	room=target
	_build()

func _choose_tool(id: String) -> void:
	if state.paused:return
	tool=id
	_build()

func _choose_seed(id: String) -> void:
	seed_id=id
	_build()

func _plot_action(index: int) -> void:
	var plot: Dictionary=state.d.plots[index]
	if not plot.unlocked: state.unlock_plot(index)
	elif plot.flower=="": state.plant(index,seed_id)
	elif garden_tool=="fertilizer": state.fertilize(index)
	elif not plot.watered: state.water(index)
	else: state.harvest(index)

func _toggle_pause() -> void:
	state.paused=not state.paused
	_build()

func _dialog(title: String, text: String) -> AcceptDialog:
	popup_resume=state.paused
	state.paused=true
	var dialog:=AcceptDialog.new()
	dialog.title=title
	dialog.dialog_text=text
	dialog.ok_button_text="닫기"
	dialog.confirmed.connect(_dismiss_dialog)
	dialog.canceled.connect(_dismiss_dialog)
	popup=dialog
	add_child(dialog)
	dialog.popup_centered(Vector2i(820,520))
	return dialog

func _dismiss_dialog() -> void:
	state.paused=popup_resume
	if is_instance_valid(popup): popup.queue_free()
	popup=null
	_build()

func _show_order() -> void:
	if state.d.phase!="order": return
	preload("res://scripts/scene_ui.gd").new(self).order_drawer()

func _show_book() -> void:
	menus.open("recipes")

func _show_tutorial() -> void:
	menus.open("tutorial")

func _confirm_close() -> void:
	popup_resume=state.paused
	state.paused=true
	var dialog:=ConfirmationDialog.new()
	dialog.title="영업 마치기"
	dialog.dialog_text="오늘 영업을 마칠까요? 진행 중인 주문은 취소되고 작업 중인 꽃은 반환됩니다."
	dialog.ok_button_text="영업 마치기"
	dialog.cancel_button_text="계속 영업"
	dialog.confirmed.connect(func():
		state.paused=false
		state.end_day()
		_dismiss_dialog()
	)
	dialog.canceled.connect(_dismiss_dialog)
	popup=dialog
	add_child(dialog)
	dialog.popup_centered(Vector2i(780,240))

func _update_status() -> void:
	if not is_instance_valid(clock_label): return
	var minute: int=9*60+int(minf(1.0,state.d.elapsed/state.day_limit())*480.0)
	clock_label.text="DAY %02d  %02d:%02d"%[state.d.day,minute/60,minute%60]
	gold_label.text="%d G"%state.d.gold
	if state.paused: patience_label.text="일시정지 중 · 계속하기를 누르면 시간이 다시 흐릅니다."
	elif state.d.phase in ["talk","order"]: patience_label.text="%s의 인내심: %s  ·  남은 시간 %d초  |  %s"%[state.customer().name,state.patience_name(),ceili(state.patience_left()),"대화 → 주문 수락" if state.d.phase=="talk" else "주문서 확인 → 제작 → 전달"]
	elif state.d.phase=="ready": patience_label.text="영업 준비 중 · 시계를 눌러 하루를 시작하세요."
	elif state.d.phase=="closed": patience_label.text="오늘의 영업 종료"
	elif state.d.phase=="result": patience_label.text="정산 확인 중 · 배웅한 뒤 다음 손님이 찾아옵니다."
	else: patience_label.text="다음 손님이 오고 있어요."
	if state.d.merchant.kind!="":patience_label.text="행상인과 거래 중 · 게임 시간이 멈춰 있습니다."
	var news: String=""
	if state.d.potion_left>0:news+=" · 성장 물약 %d초"%ceili(state.d.potion_left)
	if state.d.charm_until>=state.d.day:news+=" · 제작 부적 D-%d"%(state.d.charm_until-state.d.day)
	if not state.d.information.is_empty():news+=" · "+state.d.information.name+(" 진행 중" if state.d.day>=state.d.information.start else " D-%d"%(state.d.information.start-state.d.day))
	if news!="":patience_label.text+=news
	for i in plot_buttons:
		var plot:Dictionary=state.d.plots[i]
		var action:Button=plot_buttons[i]
		if not plot.unlocked:
			action.text="잠긴 밭 %02d\n열기 50 G"%(i+1)
			action.disabled=state.paused or state.d.gold<50
		elif plot.flower=="":
			action.text="빈 밭 %02d\n씨앗 심기"%(i+1)
			action.disabled=state.paused or state.d.seeds[seed_id]<=0
		else:
			var flower:Dictionary=state.content.catalog.flowers[plot.flower]
			var remaining:int=ceili(maxf(0,float(flower.grow_seconds)-float(plot.growth))/(1.5 if plot.fertilized else 1))
			action.text=flower.name+"\n"+("물 주기" if not plot.watered else ("수확하기" if remaining==0 else "%d:%02d 성장 중"%[remaining/60,remaining%60]))
			action.disabled=state.paused or (plot.watered and remaining>0 and garden_tool!="fertilizer")

func _process(delta: float) -> void:
	if not qa: state.tick(delta)
	_update_status()
	if not qa and state.active_clock():
		autosave+=delta
		if autosave>=10:
			autosave=0
			store.save(state)

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not qa:
			state.paused=true
			drag_id=""
			if is_instance_valid(drag_preview): drag_preview.queue_free()
			drag_preview=null
			store.save(state)
			if is_instance_valid(pause_button): pause_button.text="계속하기"
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		if not qa: store.save(state)
		get_tree().quit()

func _run_qa() -> void:
	var script=load("res://scripts/ui_qa_v4.gd").new()
	script.name="QA"
	add_child(script)
	script.run(self)

