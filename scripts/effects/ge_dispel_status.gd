extends GameplayEffect
class_name GE_DispelStatus

## 驱散状态效果（瞬时型，基于标签或状态ID）
## 能力：
## - 按标签：匹配所有带指定标签的状态（如 status.debuff）
## - 按ID：匹配指定 ID 列表（如 "stunned", "poison"）
## - 驱散模式：
##   - ALL：移除所有匹配的状态
##   - RANDOM：从匹配列表中随机移除一定数量（由 min/max 控制）

enum SelectionMode {
	BY_TAGS,
	BY_IDS,
}

enum DispelMode {
	ALL,
	RANDOM,
}

@export_group("Selection")
@export_enum("ByTags", "ByIds") var selection_mode: int = SelectionMode.BY_TAGS
## 标签驱散：移除包含任一这些标签的状态
@export var tags_to_remove: Array[StringName] = [&"status.debuff"]
## ID 驱散：移除 ID 在此列表中的状态
@export var status_ids_to_remove: Array[StringName] = []

@export_group("Dispel Mode")
@export_enum("All", "Random") var dispel_mode: int = DispelMode.ALL
@export_range(0, 999) var min_dispel_count: int = 1
@export_range(0, 999) var max_dispel_count: int = 1

func _apply(target: Node, _instigator: Node, _context: AbilityContext) -> void:
	var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not status_comp:
		return
	
	var candidate_ids: Array[StringName] = _collect_candidate_status_ids(status_comp)
	if candidate_ids.is_empty():
		return
	
	var ids_to_dispel: Array[StringName] = _select_ids_to_dispel(candidate_ids)
	if ids_to_dispel.is_empty():
		return
	
	for status_id in ids_to_dispel:
		if status_comp.has_method("remove_status"):
			status_comp.remove_status(status_id)
		elif status_comp.has_method("remove_statuses_by_tags"):
			# 旧版本兜底：退回标签驱散一次
			status_comp.remove_statuses_by_tags(tags_to_remove)
			break

func _get_description() -> String:
	return "Dispel statuses (%s, mode: %s, range: %d-%d)\n" % [
		_get_selection_description(),
		_get_mode_description(),
		min_dispel_count,
		max_dispel_count,
	]

func _get_tags_description() -> String:
	var descriptions: Array[String] = []
	for tag in tags_to_remove:
		descriptions.append(str(tag))
	return ", ".join(descriptions)

func _get_selection_description() -> String:
	match selection_mode:
		SelectionMode.BY_TAGS:
			return "by tags: %s" % _get_tags_description()
		SelectionMode.BY_IDS:
			return "by ids: %s" % ", ".join(PackedStringArray(status_ids_to_remove))
		_:
			return "unknown"

func _get_mode_description() -> String:
	match dispel_mode:
		DispelMode.ALL:
			return "all"
		DispelMode.RANDOM:
			return "random"
		_:
			return "unknown"

## 收集所有匹配的状态ID（基于标签或ID）
func _collect_candidate_status_ids(status_comp: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	
	if not status_comp.has_method("get_active_statuses"):
		# 旧版本兼容：如果没有暴露API，只能退回到标签驱散的简单模式
		if selection_mode == SelectionMode.BY_TAGS and status_comp.has_method("remove_statuses_by_tags"):
			status_comp.remove_statuses_by_tags(tags_to_remove)
		return result
	
	var active_statuses: Array = status_comp.get_active_statuses()
	for instance in active_statuses:
		if not is_instance_valid(instance):
			continue
		var gsd: GameplayStatusData = instance.status_data
		if not is_instance_valid(gsd):
			continue
		
		var status_id: StringName = gsd.status_id
		if status_id.is_empty():
			continue
		
		match selection_mode:
			SelectionMode.BY_TAGS:
				if _status_matches_tags(gsd) and not result.has(status_id):
					result.append(status_id)
			SelectionMode.BY_IDS:
				if status_ids_to_remove.has(status_id) and not result.has(status_id):
					result.append(status_id)
	
	return result

func _status_matches_tags(gsd: GameplayStatusData) -> bool:
	for tag in gsd.tags:
		if tags_to_remove.has(tag):
			return true
	return false

## 根据驱散模式，从候选列表中选择要移除的状态ID
func _select_ids_to_dispel(candidate_ids: Array[StringName]) -> Array[StringName]:
	if candidate_ids.is_empty():
		return []
	
	if dispel_mode == DispelMode.ALL:
		return candidate_ids.duplicate()
	
	var count_min := max(0, min_dispel_count)
	var count_max := max(count_min, max_dispel_count)
	var max_possible := candidate_ids.size()
	
	if max_possible <= 0 or count_min <= 0:
		return []
	
	var dispel_count: int = count_max
	if count_min != count_max:
		dispel_count = randi_range(count_min, count_max)
	
	dispel_count = min(dispel_count, max_possible)
	
	var shuffled: Array[StringName] = candidate_ids.duplicate()
	shuffled.shuffle()
	
	var result: Array[StringName] = []
	for i in range(dispel_count):
		result.append(shuffled[i])
	
	return result