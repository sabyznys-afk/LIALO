extends RefCounted
class_name TableRelicManager

const MAX_TABLE_ITEM_USES: int = 3

var table_item_uses: Dictionary = {}
var broken_table_items: Dictionary = {}
var used_this_turn: Dictionary = {}


func reset_all() -> void:
	table_item_uses.clear()
	broken_table_items.clear()
	used_this_turn.clear()


func reset_turn() -> void:
	used_this_turn.clear()


func is_broken(item_id: String) -> bool:
	if broken_table_items.has(item_id):
		return true
	return int(table_item_uses.get(item_id, 0)) >= MAX_TABLE_ITEM_USES


func can_use(item_id: String) -> bool:
	if broken_table_items.has(item_id):
		return false
	return int(table_item_uses.get(item_id, 0)) < MAX_TABLE_ITEM_USES


func is_overcharge(item_id: String) -> bool:
	if broken_table_items.has(item_id):
		return false
	var uses := int(table_item_uses.get(item_id, 0))
	return bool(used_this_turn.get(item_id, false)) and uses < MAX_TABLE_ITEM_USES


func get_remaining(item_id: String) -> int:
	if broken_table_items.has(item_id):
		return 0
	return maxi(0, MAX_TABLE_ITEM_USES - int(table_item_uses.get(item_id, 0)))


func record_use(item_id: String) -> Dictionary:
	var overcharged := bool(used_this_turn.get(item_id, false))
	var uses_cost := 2 if overcharged else 1
	var prev_uses := int(table_item_uses.get(item_id, 0))
	var new_uses := mini(MAX_TABLE_ITEM_USES, prev_uses + uses_cost)
	table_item_uses[item_id] = new_uses
	used_this_turn[item_id] = true
	var rem := maxi(0, MAX_TABLE_ITEM_USES - new_uses)
	var shattered := (rem <= 0)
	if shattered:
		broken_table_items[item_id] = true
	return {
		"uses_cost": uses_cost,
		"rem": rem,
		"shattered": shattered,
		"overcharged": overcharged,
	}


func get_effective_passive_relics(run_active_relics: Array) -> Array:
	var out: Array = []
	for r in run_active_relics:
		var rid := str(r)
		if not broken_table_items.has(rid):
			out.append(r)
	return out


func load_broken_list(arr: Array) -> void:
	for item in arr:
		var rid := str(item)
		if rid != "":
			broken_table_items[rid] = true
			table_item_uses[rid] = MAX_TABLE_ITEM_USES


func export_broken_list() -> Array:
	var out: Array = []
	for k in broken_table_items.keys():
		if bool(broken_table_items[k]):
			out.append(str(k))
	return out
