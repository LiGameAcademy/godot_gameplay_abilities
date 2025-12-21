extends BTAction
class_name AbilityNodeApplyEffect

## [配置] 要应用的效果列表
@export var effects : Array[GameplayEffect] = []
## [配置] 目标在黑板中的 Key (支持自定义，不再死板地叫 "targets")
@export var target_key: String = "targets"

func _tick(instance: BTInstance, delta: float) -> int:
	# 1. 安全获取黑板数据
	var raw_targets = instance.blackboard.get_var(target_key)
	var context : AbilityContext = instance.blackboard.get_var("context")
	var instigator = context.instigator

	# 2. 如果没目标，视为成功还是失败？通常视为成功（空挥）或忽略
	if raw_targets == null:
		return Status.SUCCESS

	# 3. 统一化处理 (不管是单个对象还是数组，都转为数组处理)
	var target_list: Array[Node] = []
	if raw_targets.is_empty():
		target_list = []
	elif raw_targets is Array:
		target_list = raw_targets as Array[Node]
	elif raw_targets is Node:
		target_list.append(raw_targets as Node)

	# 4. 执行应用逻辑
	for target in target_list:
		if not is_instance_valid(target): 
			continue
			
		for effect in effects:
			if not is_instance_valid(effect):
				continue
			effect.apply(target, instigator, context)
			
	return Status.SUCCESS
