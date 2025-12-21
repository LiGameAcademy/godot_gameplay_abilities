extends BTAction
class_name AbilityNodeApplyStatus

## [配置] 要应用的状态列表
@export var statuses : Array[GameplayStatusData] = []
## [配置] 目标在黑板中的 Key (支持自定义，不再死板地叫 "targets")
@export var target_key: String = "targets"
## [配置] 状态层数
@export var stacks: int = 1

func _tick(instance: BTInstance, delta: float) -> int:
	# 1. 安全获取黑板数据
	var raw_targets = instance.blackboard.get_var(target_key)
	var context : AbilityContext = instance.blackboard.get_var("context")
	var instigator = context.instigator

	if not is_instance_valid(instigator):
		push_warning("AbilityNodeApplyStatus: Instigator is not valid!")
		return Status.SUCCESS

	# 2. 统一化处理 (不管是单个对象还是数组，都转为数组处理)
	var target_list: Array[Node] = []
	if raw_targets.is_empty():
		target_list = []
	elif raw_targets is Array:
		target_list = raw_targets as Array[Node]
	elif raw_targets is Node:
		target_list.append(raw_targets as Node)

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
