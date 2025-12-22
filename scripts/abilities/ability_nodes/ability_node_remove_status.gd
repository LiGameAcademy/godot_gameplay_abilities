extends AbilityNodeBase
class_name AbilityNodeRemoveStatus

## 移除目标身上的指定状态
## 用于切换类技能：关闭时移除状态

## [配置] 要移除的状态ID列表
@export var status_ids: Array[StringName] = []

func _tick(instance: BTInstance, delta: float) -> int:
	# 1. 获取目标列表（使用 instigator 作为回退，因为切换技能通常作用于自己）
	var target_list = _get_target_list(instance, true)
	
	if target_list.is_empty():
		return Status.SUCCESS
	
	# 2. 移除所有目标的状态
	for target in target_list:
		if not is_instance_valid(target):
			continue
		
		# 获取目标的状态组件
		var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if not is_instance_valid(status_comp):
			push_warning("AbilityNodeRemoveStatus: Target %s has no GameplayStatusComponent!" % target.name)
			continue
		
		# 移除所有指定的状态
		for status_id in status_ids:
			if status_id.is_empty():
				continue
			status_comp.remove_status(status_id)
	
	return Status.SUCCESS

