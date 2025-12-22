extends AbilityNodeBase
class_name AbilityNodeApplyStatus

## [配置] 要应用的状态列表
@export var statuses : Array[GameplayStatusData] = []
## [配置] 状态层数
@export var stacks: int = 1

func _tick(instance: BTInstance, delta: float) -> int:
	# 1. 获取上下文和施法者
	var context = _get_context(instance)
	if not is_instance_valid(context) or not is_instance_valid(context.instigator):
		push_warning("AbilityNodeApplyStatus: Instigator is not valid!")
		return Status.SUCCESS
	
	var instigator = context.instigator

	# 2. 获取目标列表
	var target_list = _get_target_list(instance, false)

	# 3. 执行应用逻辑
	for target in target_list:
		if not is_instance_valid(target): 
			continue
		
		# 获取目标的状态组件
		var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if not is_instance_valid(status_comp):
			push_warning("AbilityNodeApplyStatus: Target %s has no GameplayStatusComponent!" % target.name)
			continue
		
		# 应用所有状态
		for status_data in statuses:
			if not is_instance_valid(status_data):
				continue
			
			var status_dict = context.to_dict()
			status_comp.apply_status(status_data, instigator, stacks, status_dict)
			
	return Status.SUCCESS
