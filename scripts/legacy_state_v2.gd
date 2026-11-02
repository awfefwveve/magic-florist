extends RefCounted
signal changed
const Content = preload("res://scripts/legacy_content_v2.gd")
var content = Content.new()
var d: Dictionary
var paused: bool = false
var last_message: String = "시계를 눌러 영업을 시작하세요. 시작 전에는 씨앗과 조합법을 준비할 수 있어요."
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	d = fresh()

func blank_craft() -> Dictionary:
	return {"kind": "", "step": "empty", "soil": 0, "items": []}

func fresh() -> Dictionary:
	var value: Dictionary = {"version": 2, "day": 1, "elapsed": 0.0, "gold": 160,
		"phase": "ready", "cursor": 0, "current": -1, "question": 0,
		"patience": 0.0, "wait": 0.0, "sold": 0, "earned": 0,
		"missed": 0, "inventory": {}, "seeds": {}, "plots": [],
		"craft": blank_craft(), "mastery": {}, "claimed": {}, "discovered": [],
		"known_recipes": [], "result": {}, "legacy_mastery": {}, "fertilizer": 2}
	for id in content.catalog.flowers:
		value.inventory[id] = 6
		value.seeds[id] = 3
		value.discovered.append(id)
	for id in content.catalog.recipes:
		value.mastery[id] = 0
		value.claimed[id] = false
		if content.catalog.recipes[id].unlock_day <= 1: value.known_recipes.append(id)
	for i in 12:
		value.plots.append({"flower": "", "watered": false, "growth": 0.0, "unlocked": i < 2, "fertilized": false})
	return value

func notify(message: String = "") -> void:
	if message != "": last_message = message
	changed.emit()

func customer() -> Dictionary:
	return content.catalog.customers[int(d.current)] if d.current >= 0 else {}

func recipe() -> Dictionary:
	return content.catalog.recipes[customer().recipe] if not customer().is_empty() else {}

func recipe_text(id: String) -> String:
	var parts: PackedStringArray = []
	for flower in content.catalog.recipes[id].flowers:
		parts.append("%s %d" % [content.catalog.flowers[flower].name, content.catalog.recipes[id].flowers[flower]])
	return " + ".join(parts)

func active_clock() -> bool:
	return not paused and d.phase in ["talk", "order", "waiting"]

func start_day() -> bool:
	if paused or d.phase != "ready": return false
	_visit()
	notify("손님이 찾아왔어요. 이야기를 듣고 주문을 받아 주세요.")
	return true

func _visit() -> void:
	var people: Array = content.catalog.customers
	for tries in people.size():
		var index: int = int(d.cursor) % people.size()
		d.cursor += 1
		if d.day >= content.catalog.recipes[people[index].recipe].unlock_day:
			d.current = index
			d.phase = "talk"
			d.question = 0
			d.patience = 0.0
			d.wait = 0.0
			return

func ask() -> bool:
	if paused or d.phase != "talk" or d.question >= 5: return false
	d.question += 1
	notify("손님의 답변이 주문 대화에 기록됐어요.")
	return true

func accept_order() -> bool:
	if paused or d.phase != "talk": return false
	d.phase = "order"
	if not d.known_recipes.has(customer().recipe): d.known_recipes.append(customer().recipe)
	notify("주문을 수락했어요. 오른쪽 제작대에서 포장지나 화분을 놓아 주세요.")
	return true

func patience_level() -> int:
	return mini(3, int(float(d.patience) / float(content.catalog.balance.patience_step_seconds)))

func patience_name() -> String:
	return ["좋음", "보통", "나쁨", "매우 나쁨"][patience_level()]

func patience_left() -> float:
	return maxf(0, 4.0 * float(content.catalog.balance.patience_step_seconds) - float(d.patience))

func tick(seconds: float) -> void:
	if not active_clock() or seconds <= 0: return
	var dt: float = minf(seconds, float(content.catalog.balance.day_seconds) - float(d.elapsed))
	d.elapsed += dt
	var ready: bool = false
	for plot in d.plots:
		if plot.flower != "" and plot.watered:
			var limit: float = float(content.catalog.flowers[plot.flower].grow_seconds)
			var before: float = float(plot.growth)
			plot.growth = minf(limit, before + dt * (1.5 if plot.fertilized else 1.0))
			ready = ready or (before < limit and plot.growth >= limit)
	if d.elapsed >= content.catalog.balance.day_seconds:
		_close()
		notify("영업 시간이 끝났어요. 오늘의 정산을 확인해 주세요.")
		return
	if d.phase in ["talk", "order"]:
		d.patience += dt
		if patience_left() <= 0:
			_refund()
			d.missed += 1
			d.current = -1
			d.phase = "waiting"
			d.wait = 0.0
			notify("손님이 기다리다 돌아갔어요. 작업 중이던 꽃은 보관함으로 돌려두었어요.")
			return
	elif d.phase == "waiting":
		d.wait += dt
		if d.wait >= content.catalog.balance.visitor_gap_seconds:
			_visit()
			notify("새 손님이 찾아왔어요.")
			return
	if ready: notify("꽃이 다 자랐어요. 왼쪽 재배실에서 수확할 수 있어요.")

func setup(kind: String) -> bool:
	if paused or d.phase != "order" or d.craft.kind != "" or kind not in ["bouquet", "pot"]: return false
	if kind == "pot" and d.day < content.catalog.balance.pot_unlock_day:
		notify("화분 제작은 2일차에 열려요.")
		return false
	d.craft.kind = kind
	d.craft.step = "placing"
	notify("포장지를 펼쳤어요. 꽃을 한 송이씩 끌어 놓고 가위로 잎을 다듬으세요." if kind == "bouquet" else "화분을 놓았어요. 흙 도구를 고른 뒤 화분을 클릭하세요.")
	return true

func can_place(id: String, at: Vector2) -> bool:
	if paused or d.phase != "order" or not d.inventory.has(id) or d.inventory[id] <= 0 or d.craft.step != "placing": return false
	if d.craft.kind == "bouquet": return d.craft.items.size() < 5 and Rect2(0.09, 0.13, 0.82, 0.69).has_point(at)
	if d.craft.kind == "pot": return d.craft.soil == 1 and d.craft.items.size() < 2 and Rect2(0.35, 0.20, 0.30, 0.53).has_point(at)
	return false

func place(id: String, at: Vector2) -> bool:
	if not can_place(id, at): return false
	d.inventory[id] -= 1
	d.craft.items.append({"id": id, "x": at.x, "y": at.y, "trimmed": false})
	notify("꽃을 놓았어요. 가위로 각 꽃의 잎 부분을 드래그하세요." if d.craft.kind == "bouquet" else "꽃을 심었어요. 다 심었으면 흙으로 덮어 주세요.")
	return true

func trim(indices: Array) -> bool:
	if paused or d.phase != "order" or d.craft.kind != "bouquet" or d.craft.step != "placing": return false
	var count: int = 0
	for index in indices:
		if index is int and index >= 0 and index < d.craft.items.size() and not d.craft.items[index].trimmed:
			d.craft.items[index].trimmed = true
			count += 1
	if count == 0: return false
	notify("잎을 다듬었어요. 손 도구로 다섯 꽃을 점선 원 안에 모아 주세요.")
	return true

func move_flower(index: int, at: Vector2) -> bool:
	if paused or d.phase != "order" or d.craft.kind != "bouquet" or d.craft.step != "placing": return false
	if index < 0 or index >= d.craft.items.size() or not Rect2(0.09, 0.13, 0.82, 0.69).has_point(at): return false
	d.craft.items[index].x = at.x
	d.craft.items[index].y = at.y
	notify()
	return true

func can_tie() -> bool:
	if d.phase != "order" or d.craft.kind != "bouquet" or d.craft.step != "placing" or d.craft.items.size() != 5: return false
	for item in d.craft.items:
		if not item.trimmed or Vector2(item.x, item.y).distance_to(Vector2(0.5, 0.43)) > 0.145: return false
	return true

func use_tool(tool: String) -> bool:
	if paused or d.phase != "order": return false
	if tool == "wire":
		if not can_tie():
			notify("꽃 5송이의 잎을 모두 다듬고 점선 원 안에 모아야 철사를 감을 수 있어요.")
			return false
		d.craft.step = "tied"
		notify("철사로 묶었어요. 리본을 고른 뒤 꽃을 클릭하세요.")
		return true
	if tool == "soil" and d.craft.kind == "pot" and d.craft.step == "placing":
		if d.craft.soil == 0:
			d.craft.soil = 1
			notify("흙을 절반 채웠어요. 꽃을 화분 안으로 끌어 넣으세요. 최대 2송이예요.")
			return true
		if d.craft.soil == 1 and not d.craft.items.is_empty():
			d.craft.soil = 2
			d.craft.step = "covered"
			notify("흙을 덮었어요. 리본 도구로 마무리하세요.")
			return true
	if tool == "ribbon" and d.craft.step in ["tied", "covered"]:
		d.craft.step = "complete"
		notify("완성했어요! 카운터에서 손님에게 꽃 장식을 전달하세요.")
		return true
	return false

func _refund() -> void:
	for item in d.craft.items: d.inventory[item.id] += 1
	d.craft = blank_craft()

func reset_craft() -> bool:
	if paused or d.phase != "order": return false
	_refund()
	notify("사용한 꽃을 돌려받았어요. 손님의 대기 시간은 유지됩니다.")
	return true

func match_count() -> int:
	var counts: Dictionary = {}
	for item in d.craft.items: counts[item.id] = int(counts.get(item.id, 0)) + 1
	var total: int = 0
	for id in recipe().flowers: total += mini(int(counts.get(id, 0)), int(recipe().flowers[id]))
	return total

func price_details() -> Dictionary:
	if recipe().is_empty(): return {}
	var matches: int = match_count()
	var ratio: float
	if d.craft.kind != recipe().kind: ratio = 0.5
	elif recipe().kind == "bouquet": ratio = 1.0 if matches >= 4 else (0.9 if matches >= 2 else 0.8)
	else: ratio = 1.0 if matches == 2 else 0.9
	var patience_ratio: float = [1.0, 0.8, 0.7, 0.6][patience_level()]
	return {"base": int(recipe().price), "matches": matches, "quality": ratio, "patience": patience_ratio, "paid": int(roundf(float(recipe().price) * ratio * patience_ratio))}

func made_recipe() -> String:
	var counts: Dictionary = {}
	for item in d.craft.items: counts[item.id] = int(counts.get(item.id, 0)) + 1
	for id in content.catalog.recipes:
		var candidate: Dictionary = content.catalog.recipes[id]
		if candidate.kind != d.craft.kind: continue
		var exact: bool = counts.size() == candidate.flowers.size()
		for flower in candidate.flowers:
			if counts.get(flower, 0) != candidate.flowers[flower]: exact = false
		if exact: return id
	return ""

func deliver() -> bool:
	if paused or d.phase != "order" or d.craft.step != "complete": return false
	var details: Dictionary = price_details()
	var actual: String = made_recipe()
	if actual != "":
		d.mastery[actual] += 1
		if not d.known_recipes.has(actual): d.known_recipes.append(actual)
	d.gold = mini(int(content.catalog.balance.max_gold), int(d.gold) + int(details.paid))
	d.sold += 1
	d.earned += details.paid
	d.result = details.duplicate(true)
	d.result["name"] = customer().name
	d.result["reply"] = customer().thanks if details.quality >= 1.0 else "조금 다른 꽃이지만 마음은 전해질 거예요. 고마워요."
	d.result["recipe"] = actual
	d.phase = "result"
	d.craft = blank_craft()
	notify("꽃을 전달하고 %d G를 받았어요. 정산을 확인한 뒤 다음 손님을 기다려 주세요." % details.paid)
	return true

func continue_service() -> bool:
	if paused or d.phase != "result": return false
	d.current = -1
	d.phase = "waiting"
	d.wait = 0.0
	notify("손님이 돌아갔어요. 잠시 후 다음 손님이 찾아옵니다.")
	return true

func _close() -> void:
	_refund()
	d.current = -1
	d.phase = "closed"

func end_day() -> bool:
	if paused or d.phase not in ["talk", "order", "waiting", "result"]: return false
	_close()
	notify("영업을 마쳤어요. 사용 중이던 꽃은 돌려두었습니다.")
	return true

func next_day() -> bool:
	if paused or d.phase != "closed": return false
	d.day += 1
	d.elapsed = 0.0
	d.sold = 0
	d.earned = 0
	d.missed = 0
	d.phase = "ready"
	d.result = {}
	d.question = 0
	d.patience = 0.0
	d.wait = 0.0
	if d.day == content.catalog.balance.pot_unlock_day:
		d.cursor = 2
		if not d.known_recipes.has("love_pot"): d.known_recipes.append("love_pot")
		notify("2일차에는 화분 제작이 열려요. 영업을 시작하면 화분 손님이 찾아옵니다.")
	else: notify("다음 날이 되었어요. 시계를 눌러 영업을 시작하세요.")
	return true

func buy_seed(id: String) -> bool:
	if paused or not d.seeds.has(id): return false
	var cost: int = int(content.catalog.flowers[id].seed_cost)
	if d.gold < cost or d.seeds[id] >= 9999: return false
	d.gold -= cost
	d.seeds[id] += 1
	notify("씨앗을 구입했어요.")
	return true

func unlock_plot(index: int) -> bool:
	if paused or index < 0 or index >= 12 or d.plots[index].unlocked: return false
	var cost: int = int(content.catalog.balance.plot_unlock_cost)
	if d.gold < cost: return false
	d.gold -= cost
	d.plots[index].unlocked = true
	notify("새 밭을 열었어요.")
	return true

func plant(index: int, id: String) -> bool:
	if paused or index < 0 or index >= 12 or not d.seeds.has(id): return false
	var plot: Dictionary = d.plots[index]
	if not plot.unlocked or plot.flower != "" or d.seeds[id] <= 0: return false
	d.seeds[id] -= 1
	plot.flower = id
	notify("씨앗을 심었어요. 물을 주면 영업 시간 동안 자라요.")
	return true

func water(index: int) -> bool:
	if paused or index < 0 or index >= 12: return false
	var plot: Dictionary = d.plots[index]
	if plot.flower == "" or plot.watered: return false
	plot.watered = true
	notify("물을 주었어요.")
	return true

func fertilize(index: int) -> bool:
	if paused or index < 0 or index >= 12 or d.fertilizer <= 0: return false
	var plot: Dictionary = d.plots[index]
	if plot.flower == "" or plot.fertilized: return false
	plot.fertilized = true
	d.fertilizer -= 1
	notify("비료를 사용했어요. 성장 속도가 1.5배가 됩니다.")
	return true

func buy_fertilizer() -> bool:
	if paused or d.gold < 12 or d.fertilizer >= 9999: return false
	d.gold -= 12
	d.fertilizer += 1
	notify("비료를 구입했어요.")
	return true

func harvest(index: int) -> bool:
	if paused or index < 0 or index >= 12: return false
	var plot: Dictionary = d.plots[index]
	if plot.flower == "": return false
	var flower: Dictionary = content.catalog.flowers[plot.flower]
	if plot.growth < flower.grow_seconds: return false
	var reserved: int = 0
	for item in d.craft.items:
		if item.id == plot.flower: reserved += 1
	if d.inventory[plot.flower] + reserved + flower.harvest_max > 9999: return false
	var count: int = rng.randi_range(int(flower.harvest_min), int(flower.harvest_max))
	d.inventory[plot.flower] += count
	if not d.discovered.has(plot.flower): d.discovered.append(plot.flower)
	for id in content.catalog.recipes:
		var info: Dictionary = content.catalog.recipes[id]
		var known: bool = d.day >= info.unlock_day
		for f in info.flowers: known = known and d.discovered.has(f)
		if known and not d.known_recipes.has(id): d.known_recipes.append(id)
	d.plots[index] = {"flower": "", "watered": false, "growth": 0.0, "unlocked": true, "fertilized": false}
	notify("%s %d송이를 수확했어요." % [flower.name, count])
	return true

func claim(id: String) -> bool:
	if paused or not d.mastery.has(id) or d.mastery[id] < 10 or d.claimed[id]: return false
	d.claimed[id] = true
	d.gold = mini(9999999, int(d.gold) + int(content.catalog.balance.mastery_reward))
	notify("조합법을 숙련했어요! 보상 %d G를 받았어요." % content.catalog.balance.mastery_reward)
	return true

func snapshot() -> Dictionary:
	return d.duplicate(true)

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

func migrate(data: Variant) -> Dictionary:
	if not data is Dictionary: return {}
	if data.get("version") == 2: return data.duplicate(true)
	if data.get("version") != 1: return {}
	const Legacy = preload("res://scripts/legacy_state_v1.gd")
	var old = Legacy.new()
	if not old.valid(data): return {}
	var result: Dictionary = fresh()
	result.day = int(data.day)
	result.gold = int(data.gold)
	result.legacy_mastery = data.mastery.duplicate(true)
	var mapping: Dictionary = {"rose": "redflora", "daisy": "yellow", "moon": "lovemis"}
	for id in mapping:
		result.inventory[mapping[id]] = int(data.inventory[id]) + (int(data.selected[id]) if data.stage > 0 else 0)
		result.seeds[mapping[id]] = int(data.seeds[id])
	for i in data.plots.size():
		var plot: Dictionary = data.plots[i]
		result.plots[i].unlocked = true
		if plot.flower != "":
			var id: String = mapping[plot.flower]
			var old_limit: float = {"rose": 24.0, "daisy": 18.0, "moon": 30.0}[plot.flower]
			result.plots[i] = {"flower": id, "watered": plot.watered, "growth": float(plot.growth) / old_limit * float(content.catalog.flowers[id].grow_seconds), "unlocked": true, "fertilized": false}
	if result.day >= 2: result.known_recipes.append("love_pot")
	return result

func valid(raw: Variant) -> bool:
	var data: Dictionary = migrate(raw)
	if data.is_empty(): return false
	for key in fresh():
		if not data.has(key): return false
	for key in ["day", "gold", "cursor", "sold", "earned", "missed", "fertilizer"]:
		if not whole(data[key], 1 if key == "day" else 0, 9999999 if key == "gold" else (9999 if key == "fertilizer" else 999999999)): return false
	if not data.phase is String or data.phase not in ["ready", "talk", "order", "result", "waiting", "closed"]: return false
	if not whole(data.current, -1, content.catalog.customers.size() - 1) or not whole(data.question, 0, 5): return false
	if not number(data.elapsed, 0, 480) or not number(data.patience, 0, 600) or not number(data.wait, 0, 1000): return false
	if data.phase in ["talk", "order", "result"] and data.current < 0: return false
	if data.phase in ["ready", "waiting", "closed"] and data.current != -1: return false
	if data.phase in ["talk", "order"] and data.patience >= 120: return false
	for key in ["inventory", "seeds", "mastery", "claimed"]:
		if not data[key] is Dictionary: return false
		var ids: Dictionary = content.catalog.flowers if key in ["inventory", "seeds"] else content.catalog.recipes
		if data[key].size() != ids.size(): return false
		for id in ids:
			if not data[key].has(id): return false
			if key == "claimed":
				if not data[key][id] is bool or (data[key][id] and data.mastery.get(id, 0) < 10): return false
			elif not whole(data[key][id], 0, 999999999 if key == "mastery" else 9999): return false
	for key in ["discovered", "known_recipes"]:
		if not data[key] is Array: return false
		var ids: Dictionary = content.catalog.flowers if key == "discovered" else content.catalog.recipes
		var seen: Array = []
		for id in data[key]:
			if not id is String or not ids.has(id) or seen.has(id): return false
			seen.append(id)
	if not data.legacy_mastery is Dictionary: return false
	for id in data.legacy_mastery:
		if id not in ["courage", "sunrise", "rest"] or not whole(data.legacy_mastery[id], 0, 999999999): return false
	if not data.plots is Array or data.plots.size() != 12: return false
	for plot in data.plots:
		if not plot is Dictionary or not plot.has_all(["flower", "watered", "growth", "unlocked", "fertilized"]): return false
		if not plot.flower is String or not plot.watered is bool or not plot.unlocked is bool or not plot.fertilized is bool or not number(plot.growth, 0, 360): return false
		if plot.flower == "":
			if plot.growth != 0 or plot.watered or plot.fertilized: return false
		elif not content.catalog.flowers.has(plot.flower) or not plot.unlocked: return false
		elif plot.growth > content.catalog.flowers[plot.flower].grow_seconds or (not plot.watered and plot.growth != 0): return false
	var craft: Variant = data.craft
	if not craft is Dictionary or not craft.has_all(["kind", "step", "soil", "items"]): return false
	if craft.kind not in ["", "bouquet", "pot"] or craft.step not in ["empty", "placing", "tied", "covered", "complete"] or not whole(craft.soil, 0, 2) or not craft.items is Array: return false
	if craft.kind == "":
		if craft.step != "empty" or craft.soil != 0 or not craft.items.is_empty(): return false
	else:
		if data.phase != "order" or craft.step == "empty": return false
		if craft.items.size() > (5 if craft.kind == "bouquet" else 2): return false
		if craft.kind == "bouquet":
			if craft.soil != 0 or craft.step == "covered": return false
			if craft.step in ["tied", "complete"] and craft.items.size() != 5: return false
		else:
			if data.day < 2 or craft.step == "tied": return false
			if craft.soil == 0 and not craft.items.is_empty(): return false
			if craft.step in ["covered", "complete"] and (craft.soil != 2 or craft.items.is_empty()): return false
			if craft.step == "placing" and craft.soil == 2: return false
	var reserved: Dictionary = {}
	for item in craft.items:
		if not item is Dictionary or not item.has_all(["id", "x", "y", "trimmed"]): return false
		if not item.id is String or not content.catalog.flowers.has(item.id) or not item.trimmed is bool: return false
		if not number(item.x, 0.09, 0.91) or not number(item.y, 0.13, 0.82): return false
		if craft.kind == "bouquet" and craft.step in ["tied", "complete"] and not item.trimmed: return false
		reserved[item.id] = int(reserved.get(item.id, 0)) + 1
	for id in reserved:
		if data.inventory[id] + reserved[id] > 9999: return false
	if not data.result is Dictionary: return false
	if data.phase == "result":
		if not data.result.has_all(["base", "matches", "quality", "patience", "paid", "name", "reply", "recipe"]): return false
		for key in ["name", "reply", "recipe"]:
			if not data.result[key] is String: return false
		for key in ["base", "matches", "paid"]:
			if not whole(data.result[key], 0, 9999999): return false
		if not number(data.result.quality, 0.5, 1.0) or not number(data.result.patience, 0.6, 1.0): return false
	return true

func restore(raw: Dictionary) -> bool:
	if not valid(raw): return false
	d = migrate(raw)
	for key in ["day", "gold", "cursor", "current", "question", "sold", "earned", "missed", "fertilizer"]: d[key] = int(d[key])
	for key in ["inventory", "seeds", "mastery"]:
		for id in d[key]: d[key][id] = int(d[key][id])
	d.craft.soil = int(d.craft.soil)
	if raw.version == 1: last_message = "이전 재화와 꽃을 옮겼어요. 기존 작업 재료는 반환했고 영업 시작 전으로 돌아왔어요."
	return true
