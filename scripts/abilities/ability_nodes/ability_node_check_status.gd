extends AbilityNodeBase
class_name AbilityNodeCheckStatus

## 检查目标是否有指定状态
## 用于切换类技能：如果状态存在则关闭，如果不存在则开启

## [配置] 要检查的状态ID列表（任意一个存在即返回成功）
@export var status_ids: Array[StringName] = []
## [配置] 如果状态存在，设置的黑板变量名（用于后续节点判断）
@export var status_exists_key: String = "status_exists"

func _tick(instance: BTInstance, delta: float) -> int:
	# 1. 验证上下文
	if not _validate_context(instance, "AbilityNodeCheckStatus"):
		instance.blackboard.set_var(status_exists_key, false)
		return Status.FAILURE
	
	# 2. 获取所有目标（使用 instigator 作为回退，因为切换技能通常作用于自己）
	var target_list = _get_target_list(instance, true)
	if target_list.is_empty():
		push_warning("AbilityNodeCheckStatus: No valid target found!")
		instance.blackboard.set_var(status_exists_key, false)
		return Status.FAILURE
	
	# 3. 检查所有目标是否有状态（任意一个目标有状态即返回成功）
	var has_status = false
	for target in target_list:
		if not is_instance_valid(target):
			continue
		
		# 获取目标的状态组件
		var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if not is_instance_valid(status_comp):
			continue
		
		# 检查是否有任意一个状态存在
		for status_id in status_ids:
			if status_id.is_empty():
				continue
			if status_comp.has_status(status_id):
				has_status = true
				break
		
		# 如果已经找到状态，提前退出
		if has_status:
			break
	
	# 5. 将结果写入黑板
	instance.blackboard.set_var(status_exists_key, has_status)
	
	# 6. 返回状态：如果状态存在返回 SUCCESS，不存在返回 FAILURE
	# 这样可以在 BTSelector 中使用：SUCCESS 分支移除状态，FAILURE 分支应用状态
	return Status.SUCCESS if has_status else Status.FAILURE
