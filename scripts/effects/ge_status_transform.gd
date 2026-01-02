extends GameplayEffect
class_name GE_StatusTransform

@export_group("Match Config")
## 匹配的标签：用于判断是否触发转换，以及（可选）用于移除对应标签的状态
@export var match_tags: Array[StringName] = []
## 是否要求目标同时拥有所有标签（true: AND，多标签全满足；false: OR，任意一个满足）
@export var require_all_tags: bool = false
## 是否在转换前移除所有匹配标签的状态
@export var remove_matched_statuses: bool = true

@export_group("Transform Result")
## 需要应用的新状态列表（可以是一个或多个）
@export var statuses_to_apply: Dictionary[GameplayStatusData, int] = {}

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	if match_tags.is_empty() and statuses_to_apply.is_empty():
		return

	var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not is_instance_valid(status_comp):
		return

	# 1. 检查是否满足触发条件（基于标签）
	if not _check_match_tags(target):
		return

	# 2. （可选）移除所有带 match_tags 的状态
	if remove_matched_statuses and not match_tags.is_empty():
		status_comp.remove_statuses_by_tags(match_tags)

	# 3. 应用新的状态列表（需要转换为Dictionary）
	for status_data in statuses_to_apply:
		if is_instance_valid(status_data):
			var stack := statuses_to_apply.get(status_data, 1)
			status_comp.apply_status(status_data, instigator, stack, context)
	
func _check_match_tags(target: Node) -> bool:
	if match_tags.is_empty():
		# 没有配置标签时视为"总是触发"
		return true

	if require_all_tags:
		return TagManager.has_all_tags(target, match_tags)
	else:
		return TagManager.has_any_tag(target, match_tags)
