extends RefCounted

signal changed
const Content = preload("res://scripts/legacy_content_v1.gd")
var content = Content.new()
var day: int = 1
var minutes: float = 0.0
var gold: int = 100
var inventory: Dictionary = {"rose": 3, "daisy": 3, "moon": 2}
var seeds: Dictionary = {"rose": 3, "daisy": 3, "moon": 3}
var plots: Array = []
var mastery: Dictionary = {"courage": 0, "sunrise": 0, "rest": 0}
var selected: Dictionary = {"rose": 0, "daisy": 0, "moon": 0}
var stage: int = 0
var order_active: bool = false
var customer_index: int = 0
var sold_today: int = 0
var earned_today: int = 0
var paused: bool = false
var last_message: String = "첫 손님이 기다리고 있어요. 주문을 받아 보세요."

func _init() -> void:
	gold = int(content.catalog.balance.starting_gold)
	for i in 4:
		plots.append({"flower": "", "watered": false, "growth": 0.0})

func customer() -> Dictionary:
	return content.catalog.customers[customer_index % content.catalog.customers.size()]

func recipe() -> Dictionary:
	return content.catalog.recipes[customer().recipe]

func closed() -> bool:
	return minutes >= float(content.catalog.balance.day_minutes)

func say(message: String) -> void:
	last_message = message
	changed.emit()

func tick(delta: float) -> void:
	if paused or closed():
		return
	var elapsed: float = minf(delta * float(content.catalog.balance.minutes_per_second), float(content.catalog.balance.day_minutes) - minutes)
	minutes += elapsed
	var ready_now: bool = false
	for plot in plots:
		if plot.flower != "" and plot.watered:
			var limit: float = float(content.catalog.flowers[plot.flower].grow_minutes)
			var before: float = float(plot.growth)
			plot.growth = minf(limit, before + elapsed)
			ready_now = ready_now or (before < limit and plot.growth >= limit)
	if closed():
		say("오늘의 영업 시간이 끝났어요. 진행 중인 주문은 마무리할 수 있어요.")
	elif ready_now:
		say("꽃이 활짝 피었어요. 재배실에서 수확해 주세요.")

func accept_order() -> bool:
	if order_active or closed():
		return false
	order_active = true
	say("주문을 받았어요. 제작대에서 꽃을 골라 주세요.")
	return true

func buy_seed(id: String) -> bool:
	if not seeds.has(id) or seeds[id] >= int(content.catalog.balance.max_inventory):
		return false
	var cost: int = int(content.catalog.flowers[id].seed_cost)
	if gold < cost:
		say("골드가 부족해요. 보유한 꽃으로 주문을 완성해 보세요.")
		return false
	gold -= cost
	seeds[id] += 1
	say(content.catalog.flowers[id].name + " 씨앗을 구입했어요.")
	return true

func plant(index: int, id: String) -> bool:
	if index < 0 or index >= plots.size() or not seeds.has(id):
		return false
	if plots[index].flower != "" or seeds[id] <= 0:
		return false
	seeds[id] -= 1
	plots[index] = {"flower": id, "watered": false, "growth": 0.0}
	say("씨앗을 심었어요. 물을 주면 자라기 시작해요.")
	return true

func water(index: int) -> bool:
	if index < 0 or index >= plots.size() or plots[index].flower == "" or plots[index].watered:
		return false
	plots[index].watered = true
	say("물을 주었어요. 꽃은 영업 시간 동안 자라요.")
	return true

func harvest(index: int) -> bool:
	if index < 0 or index >= plots.size():
		return false
	var plot: Dictionary = plots[index]
	if plot.flower == "" or plot.growth < content.catalog.flowers[plot.flower].grow_minutes:
		return false
	var amount: int = int(content.catalog.balance.harvest_count)
	var reserved: int = int(selected[plot.flower]) if stage > 0 else 0
	if inventory[plot.flower] + amount + reserved > int(content.catalog.balance.max_inventory):
		say("꽃 보관함이 가득 찼어요.")
		return false
	inventory[plot.flower] += amount
	plots[index] = {"flower": "", "watered": false, "growth": 0.0}
	say("꽃 %d송이를 수확했어요." % amount)
	return true

func select_flower(id: String) -> bool:
	if not order_active or stage != 0 or not selected.has(id):
		return false
	var total: int = 0
	for count in selected.values():
		total += int(count)
	if inventory[id] <= selected[id] or total >= 3:
		say("꽃은 세 송이까지 고를 수 있어요. 바꾸려면 선택을 비워 주세요.")
		return false
	selected[id] += 1
	say("꽃을 골랐어요. 세 송이를 모아 줄기를 다듬어 주세요.")
	return true

func clear_bouquet() -> void:
	if stage > 0:
		for id in selected:
			inventory[id] += selected[id]
	selected = {"rose": 0, "daisy": 0, "moon": 0}
	stage = 0
	say("꽃 선택을 비웠어요. 사용한 꽃은 보관함으로 돌아왔어요.")

func craft_step() -> bool:
	if not order_active or stage >= 3:
		return false
	if stage == 0:
		var total: int = 0
		for id in selected:
			if selected[id] > inventory[id]:
				return false
			total += int(selected[id])
		if total != 3:
			say("꽃 세 송이를 먼저 골라 주세요.")
			return false
		for id in selected:
			inventory[id] -= selected[id]
	stage += 1
	say(["", "줄기를 다듬었어요. 꽃을 묶어 주세요.", "꽃을 묶었어요. 포장과 리본으로 마무리해 주세요.", "꽃다발이 완성됐어요! 카운터에서 전달해 주세요."][stage])
	return true

func matches_order() -> bool:
	var needed: Dictionary = recipe().flowers
	for id in selected:
		if selected[id] != int(needed.get(id, 0)):
			return false
	return true

func deliver() -> bool:
	if not order_active or stage != 3:
		return false
	if not matches_order():
		say("손님의 주문과 꽃 구성이 달라요. 제작대에서 다시 골라 주세요.")
		return false
	var payment: int = int(recipe().price)
	gold = mini(int(content.catalog.balance.max_gold), gold + payment)
	mastery[customer().recipe] += 1
	sold_today += 1
	earned_today += payment
	var thanks: String = customer().thanks
	customer_index += 1
	order_active = false
	stage = 0
	selected = {"rose": 0, "daisy": 0, "moon": 0}
	say("“%s”  +%d G" % [thanks, payment])
	return true

func next_day() -> bool:
	if order_active:
		say("받아 둔 주문을 먼저 마무리해 주세요.")
		return false
	day += 1
	# A small daily delivery keeps the prototype recoverable after poor spending.
	for id in seeds:
		seeds[id] = mini(int(content.catalog.balance.max_inventory), int(seeds[id]) + 1)
	minutes = 0.0
	sold_today = 0
	earned_today = 0
	say("새로운 하루! 씨앗이 종류별로 1개씩 배달됐어요.")
	return true

func cancel_order() -> void:
	if not order_active:
		return
	if stage > 0:
		for id in selected:
			inventory[id] += selected[id]
	selected = {"rose": 0, "daisy": 0, "moon": 0}
	stage = 0
	order_active = false
	say("주문을 취소하고 사용한 꽃을 돌려받았어요.")

func snapshot() -> Dictionary:
	return {"version": 1, "day": day, "minutes": minutes, "gold": gold,
		"inventory": inventory.duplicate(true), "seeds": seeds.duplicate(true),
		"plots": plots.duplicate(true), "mastery": mastery.duplicate(true),
		"selected": selected.duplicate(true), "stage": stage,
		"order_active": order_active, "customer_index": customer_index,
		"sold_today": sold_today, "earned_today": earned_today}

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

func valid(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in snapshot():
		if not data.has(key):
			return false
	if data.version != 1 or not whole(data.day, 1, 999999) or not whole(data.gold, 0, int(content.catalog.balance.max_gold)):
		return false
	if not (data.minutes is int or data.minutes is float) or not is_finite(float(data.minutes)) or data.minutes < 0 or data.minutes > content.catalog.balance.day_minutes:
		return false
	for key in ["customer_index", "sold_today", "earned_today"]:
		if not whole(data[key], 0, 999999999):
			return false
	if not whole(data.stage, 0, 3) or not data.order_active is bool:
		return false
	for key in ["inventory", "seeds", "selected", "mastery"]:
		if not data[key] is Dictionary:
			return false
		var expected: Dictionary = mastery if key == "mastery" else inventory
		if data[key].size() != expected.size():
			return false
		for id in expected:
			if not data[key].has(id) or not whole(data[key][id], 0, 999999999 if key == "mastery" else int(content.catalog.balance.max_inventory)):
				return false
	var count: int = 0
	for id in data.selected:
		count += int(data.selected[id])
		if data.stage == 0 and data.selected[id] > data.inventory[id]:
			return false
		if data.stage > 0 and data.selected[id] + data.inventory[id] > int(content.catalog.balance.max_inventory):
			return false
	if count > 3 or (data.stage > 0 and count != 3) or (not data.order_active and (count != 0 or data.stage != 0)):
		return false
	if not data.plots is Array or data.plots.size() != 4:
		return false
	for plot in data.plots:
		if not plot is Dictionary or not plot.has_all(["flower", "watered", "growth"]):
			return false
		if not plot.flower is String or not plot.watered is bool or not (plot.growth is int or plot.growth is float):
			return false
		if not is_finite(float(plot.growth)) or plot.growth < 0:
			return false
		if plot.flower == "":
			if plot.watered or plot.growth != 0:
				return false
		elif not inventory.has(plot.flower) or plot.growth > content.catalog.flowers[plot.flower].grow_minutes or (not plot.watered and plot.growth != 0):
			return false
	return true

func restore(data: Dictionary) -> bool:
	if not valid(data):
		return false
	day = int(data.day)
	minutes = float(data.minutes)
	gold = int(data.gold)
	inventory = data.inventory.duplicate(true)
	seeds = data.seeds.duplicate(true)
	plots = data.plots.duplicate(true)
	mastery = data.mastery.duplicate(true)
	selected = data.selected.duplicate(true)
	for counts in [inventory, seeds, mastery, selected]:
		for id in counts:
			counts[id] = int(counts[id])
	stage = int(data.stage)
	order_active = data.order_active
	customer_index = int(data.customer_index)
	sold_today = int(data.sold_today)
	earned_today = int(data.earned_today)
	return true

