extends GameplayEffect
class_name GE_DispelStatus

## 驱散状态效果（瞬时型）
## 移除目标所有匹配指定标签的状态

@export var tags_to_remove: Array[StringName] = [&"magic", &"debuff"]  ## 要移除的标签

func _apply(target: Node, _instigator: Node, context: Dictionary) -> void:
	# 使用鸭子类型查询GameplayStatusComponent
	var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not status_comp:
		# 目标没有GameplayStatusComponent时静默失败
		return
	
	# 移除匹配标签的状态
	if status_comp.has_method("remove_statuses_by_tags"):
		status_comp.remove_statuses_by_tags(tags_to_remove)
	else:
		push_error("GE_DispelStatus: GameplayStatusComponent does not have remove_statuses_by_tags method!")

func _get_description() -> String:
	return "Dispel statuses with tags: %s\n" % [_get_tags_description()]

func _get_tags_description() -> String:
	var descriptions = []
	for tag in tags_to_remove:
		descriptions.append(tag)
	return descriptions.join(", ")
