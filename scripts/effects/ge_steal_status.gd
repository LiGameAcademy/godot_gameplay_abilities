extends GameplayEffect
class_name GE_StealStatus

## 窃取状态效果（瞬时型）
## 从目标单位窃取随机状态并应用到施法者

@export var is_debuff_only: bool = false  ## 是否只窃取Debuff

func _apply(target: Node, instigator: Node, context: AbilityContext) -> void:
	# 使用鸭子类型查询GameplayStatusComponent
	var target_status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	var instigator_status_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayStatusComponent")
	
	if not target_status_comp:
		push_error("GE_StealStatus: Target does not have a GameplayStatusComponent")
		return
	
	if not instigator_status_comp:
		push_error("GE_StealStatus: Instigator does not have a GameplayStatusComponent")
		return
	
	# 获取随机状态
	if not target_status_comp.has_method("get_random_status"):
		push_error("GE_StealStatus: GameplayStatusComponent does not have get_random_status method!")
		return
	
	var status: GameplayStatusInstance = target_status_comp.get_random_status(is_debuff_only)
	if not is_instance_valid(status):
		# 没有可窃取的状态，静默失败
		return
	
	# 从目标移除状态
	if target_status_comp.has_method("remove_status"):
		target_status_comp.remove_status(status.get_id())
	
	# 应用到施法者
	if instigator_status_comp.has_method("apply_status"):
		instigator_status_comp.apply_status(status.status_data, instigator, status.stacks, {})

func _get_description() -> String:
	if is_debuff_only:
		return "Steal a random debuff from the target unit\n"
	return "Steal a random status from the target unit\n"
